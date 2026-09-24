import { useEffect, useState } from 'react';
import axios from 'axios';
import { ArrowLeft, Heart, Timer, AlertTriangle, Clock, Info, Mail } from 'lucide-react';
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, Legend, CartesianGrid } from 'recharts';
import { auth } from './firebase';
import { getStatusColor, getStatusLabel } from './semaforo';

const LECTURAS_URL = "https://tt-ansiedad-backend.onrender.com/api/lecturas";

const PERIODOS = [
  { valor: 'dia', label: 'Día' },
  { valor: 'semana', label: 'Semana' },
  { valor: 'mes', label: 'Mes' },
];

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const hora = (fecha) =>
  fecha ? new Date(fecha).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '--:--';

const etiquetaDia = (fecha) => {
  const d = new Date(fecha);
  return `${d.getDate()} ${MESES[d.getMonth()]}`;
};

const esHoy = (fecha) => {
  if (!fecha) return false;
  const f = new Date(fecha);
  const hoy = new Date();
  return f.getFullYear() === hoy.getFullYear() && f.getMonth() === hoy.getMonth() && f.getDate() === hoy.getDate();
};

// Promedio ponderado por número de lecturas de cada día (mismo cálculo que
// HistorialProvider.promedioPonderado en la app).
const promedioPonderado = (dias, campo) => {
  const total = dias.reduce((a, d) => a + Number(d.total_registros), 0);
  if (total === 0) return null;
  return dias.reduce((a, d) => a + Number(d[campo]) * Number(d.total_registros), 0) / total;
};

// Estado "predominante" de un día agregado, para pintar su semáforo: si hubo
// alguna lectura alta el día es Alta, si no alguna moderada, si no Baja
// (mismo criterio que _buildResumenDiaCard en la app).
const estadoDelDia = (d) => {
  if (Number(d.episodios_altos) > 0) return 'Alta';
  if (Number(d.episodios_moderados) > 0) return 'Moderada';
  return 'Baja';
};

// Detalle de un paciente (Portal Web Fase 2a). Muestra indicadores
// fisiológicos de apoyo — NO un diagnóstico (MARCO_ALCANCE_Y_LENGUAJE.md).
function PacienteDetalle({ paciente, onVolver, recarga }) {
  const [periodo, setPeriodo] = useState('dia');
  const [lecturas, setLecturas] = useState([]); // vista Día
  const [dias, setDias] = useState([]); // vista Semana/Mes (periodo actual)
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    // Evita que una respuesta lenta de un periodo anterior pise la del
    // periodo recién elegido.
    let cancelado = false;

    const cargar = async () => {
      setCargando(true);
      setError('');
      try {
        const token = await auth.currentUser.getIdToken();
        const headers = { Authorization: `Bearer ${token}` };

        if (periodo === 'dia') {
          const res = await axios.get(`${LECTURAS_URL}/${paciente.id}?limite=200`, { headers });
          if (cancelado) return;
          const hoy = res.data
            .filter((l) => esHoy(l.fecha_medicion))
            .sort((a, b) => new Date(a.fecha_medicion) - new Date(b.fecha_medicion));
          setLecturas(hoy);
        } else {
          const res = await axios.get(`${LECTURAS_URL}/${paciente.id}/resumen?periodo=${periodo}`, { headers });
          if (cancelado) return;
          const diasPorPeriodo = res.data.dias_por_periodo || (periodo === 'mes' ? 30 : 7);
          const corte = Date.now() - diasPorPeriodo * 24 * 60 * 60 * 1000;
          setDias((res.data.serie_completa || []).filter((d) => new Date(d.dia).getTime() > corte));
        }
      } catch (e) {
        if (cancelado) return;
        console.error('Error al cargar el detalle del paciente:', e);
        setError(
          e.response?.status === 403
            ? 'Este paciente no está vinculado a tu cuenta.'
            : 'No se pudieron cargar los datos. Intenta de nuevo en unos segundos.'
        );
      } finally {
        if (!cancelado) setCargando(false);
      }
    };

    cargar();
    return () => {
      cancelado = true;
    };
  }, [paciente.id, periodo, recarga]);

  return (
    <div>
      <button onClick={onVolver} style={styles.volverBtn}>
        <ArrowLeft size={18} /> Volver a la lista
      </button>

      <div style={styles.encabezado}>
        <div>
          <h2 style={styles.nombre}>{paciente.nombre}</h2>
          <div style={styles.email}><Mail size={14} /> {paciente.email}</div>
        </div>
        <div style={styles.selector}>
          {PERIODOS.map((p) => (
            <button
              key={p.valor}
              onClick={() => setPeriodo(p.valor)}
              style={{ ...styles.chip, ...(periodo === p.valor ? styles.chipActivo : {}) }}
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      <div style={styles.disclaimer}>
        <Info size={16} style={{ flexShrink: 0, marginTop: '1px' }} />
        <span>Datos fisiológicos de apoyo. La interpretación y el diagnóstico corresponden al profesional de salud.</span>
      </div>

      {error ? (
        <div style={styles.errorBanner}>{error}</div>
      ) : cargando ? (
        <div style={styles.centro}>Cargando datos del paciente...</div>
      ) : periodo === 'dia' ? (
        <VistaDia lecturas={lecturas} paciente={paciente} />
      ) : (
        <VistaAgregada dias={dias} paciente={paciente} periodo={periodo} />
      )}
    </div>
  );
}

function VistaDia({ lecturas, paciente }) {
  if (lecturas.length === 0) {
    return (
      <>
        <Kpis bpm={null} hrv={null} altas={0} paciente={paciente} />
        <div style={styles.vacio}>Sin lecturas hoy. Cambia a Semana o Mes para ver días anteriores.</div>
      </>
    );
  }

  const promedio = (campo) => lecturas.reduce((a, l) => a + Number(l[campo]), 0) / lecturas.length;
  const altas = lecturas.filter((l) => l.estado_ansiedad === 'Alta').length;
  const datosGrafica = lecturas.map((l) => ({ x: hora(l.fecha_medicion), bpm: l.bpm, spo2: l.spo2, hrv: l.hrv }));

  return (
    <>
      <Kpis bpm={promedio('bpm')} hrv={promedio('hrv')} altas={altas} paciente={paciente} />
      <Grafica titulo="Tendencia de indicadores fisiológicos (hoy)" datos={datosGrafica} />
      <h3 style={styles.subtitulo}>Lecturas de hoy</h3>
      <div style={styles.lista}>
        {[...lecturas].reverse().map((l) => (
          <FilaLectura
            key={l.id}
            titulo={hora(l.fecha_medicion)}
            estado={l.estado_ansiedad}
            datos={[['BPM', l.bpm], ['SpO2', `${l.spo2}%`], ['HRV', `${l.hrv} ms`]]}
          />
        ))}
      </div>
    </>
  );
}

function VistaAgregada({ dias, paciente, periodo }) {
  if (dias.length === 0) {
    return (
      <>
        <Kpis bpm={null} hrv={null} altas={0} paciente={paciente} />
        <div style={styles.vacio}>
          {periodo === 'semana' ? 'Sin lecturas en los últimos 7 días.' : 'Sin lecturas en los últimos 30 días.'}
        </div>
      </>
    );
  }

  const altas = dias.reduce((a, d) => a + Number(d.episodios_altos), 0);
  const datosGrafica = dias.map((d) => ({
    x: etiquetaDia(d.dia),
    bpm: Number(d.bpm_promedio),
    spo2: Number(d.spo2_promedio),
    hrv: Number(d.hrv_promedio),
  }));

  return (
    <>
      <Kpis
        bpm={promedioPonderado(dias, 'bpm_promedio')}
        hrv={promedioPonderado(dias, 'hrv_promedio')}
        altas={altas}
        paciente={paciente}
      />
      <Grafica titulo="Tendencia de indicadores fisiológicos (promedio por día)" datos={datosGrafica} />
      <h3 style={styles.subtitulo}>Resumen por día</h3>
      <div style={styles.lista}>
        {[...dias].reverse().map((d) => (
          <FilaLectura
            key={d.dia}
            titulo={etiquetaDia(d.dia)}
            detalle={`${d.total_registros} lecturas · ${d.episodios_altos} altas`}
            estado={estadoDelDia(d)}
            datos={[['BPM', d.bpm_promedio], ['SpO2', `${d.spo2_promedio}%`], ['HRV', `${d.hrv_promedio} ms`]]}
          />
        ))}
      </div>
    </>
  );
}

function Kpis({ bpm, hrv, altas, paciente }) {
  const redondear = (v) => (v == null ? '--' : Math.round(v));
  const ultima = paciente.ultima_lectura ? new Date(paciente.ultima_lectura).toLocaleString() : 'Sin lecturas';
  return (
    <div style={styles.kpis}>
      <Kpi icono={<Heart size={20} color="#3b82f6" />} valor={redondear(bpm)} unidad="BPM" label="BPM promedio" />
      <Kpi icono={<Timer size={20} color="#f59e0b" />} valor={redondear(hrv)} unidad="ms" label="HRV promedio" />
      <Kpi icono={<AlertTriangle size={20} color="#ef4444" />} valor={altas} label="Lecturas altas" />
      <Kpi
        icono={<Clock size={20} color={getStatusColor(paciente.ultimo_estado)} />}
        valor={<span style={styles.kpiValorChico}>{ultima}</span>}
        label={`Última lectura · ${getStatusLabel(paciente.ultimo_estado)}`}
      />
    </div>
  );
}

function Kpi({ icono, valor, unidad, label }) {
  return (
    <div style={styles.kpi}>
      {icono}
      <div style={styles.kpiValor}>
        {valor}
        {unidad && <span style={styles.kpiUnidad}> {unidad}</span>}
      </div>
      <div style={styles.kpiLabel}>{label}</div>
    </div>
  );
}

function Grafica({ titulo, datos }) {
  return (
    <div style={styles.tarjeta}>
      <div style={styles.tarjetaTitulo}>{titulo}</div>
      <div style={{ width: '100%', height: 280 }}>
        <ResponsiveContainer>
          <LineChart data={datos} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
            <CartesianGrid stroke="#f0f0f0" vertical={false} />
            <XAxis dataKey="x" tick={{ fontSize: 11, fill: '#999' }} />
            <YAxis tick={{ fontSize: 11, fill: '#999' }} />
            <Tooltip />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            <Line type="monotone" dataKey="bpm" name="BPM" stroke="#3b82f6" strokeWidth={2} dot={false} />
            <Line type="monotone" dataKey="spo2" name="SpO2 (%)" stroke="#10b981" strokeWidth={2} dot={false} />
            <Line type="monotone" dataKey="hrv" name="HRV (ms)" stroke="#f59e0b" strokeWidth={2} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

function FilaLectura({ titulo, detalle, estado, datos }) {
  const color = getStatusColor(estado);
  return (
    <div style={styles.fila}>
      <div style={{ ...styles.filaBarra, backgroundColor: color }} />
      <div style={styles.filaTitulo}>
        <div style={styles.filaHora}>{titulo}</div>
        {detalle && <div style={styles.filaDetalle}>{detalle}</div>}
      </div>
      {datos.map(([label, valor]) => (
        <div key={label} style={styles.miniDato}>
          <div style={styles.miniValor}>{valor}</div>
          <div style={styles.miniLabel}>{label}</div>
        </div>
      ))}
      <span style={{ ...styles.badge, color, backgroundColor: `${color}1a` }}>{getStatusLabel(estado)}</span>
    </div>
  );
}

const styles = {
  volverBtn: { display: 'flex', alignItems: 'center', gap: '6px', background: 'none', border: 'none', color: '#1E6AFB', cursor: 'pointer', fontSize: '14px', padding: 0, marginBottom: '16px' },
  encabezado: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', flexWrap: 'wrap', gap: '16px', marginBottom: '16px' },
  nombre: { margin: 0, fontSize: '24px', color: '#1a1a1a' },
  email: { display: 'flex', alignItems: 'center', gap: '6px', fontSize: '14px', color: '#666', marginTop: '4px' },
  selector: { display: 'flex', gap: '8px' },
  chip: { padding: '8px 18px', borderRadius: '12px', border: '1px solid #ddd', backgroundColor: '#fff', color: '#555', fontWeight: 'bold', cursor: 'pointer' },
  chipActivo: { backgroundColor: '#1E6AFB', borderColor: '#1E6AFB', color: '#fff' },
  disclaimer: { display: 'flex', gap: '8px', alignItems: 'flex-start', backgroundColor: '#f1f5f9', color: '#64748b', fontSize: '13px', lineHeight: 1.4, padding: '10px 16px', borderRadius: '10px', marginBottom: '20px' },
  errorBanner: { backgroundColor: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', padding: '12px 20px', borderRadius: '10px' },
  centro: { textAlign: 'center', marginTop: '40px', color: '#666' },
  vacio: { textAlign: 'center', color: '#999', padding: '40px 0' },
  kpis: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px', marginBottom: '20px' },
  kpi: { backgroundColor: '#fff', border: '1px solid #eee', borderRadius: '15px', padding: '16px' },
  kpiValor: { fontSize: '24px', fontWeight: 'bold', color: '#1a1a1a', marginTop: '8px' },
  kpiValorChico: { fontSize: '14px' },
  kpiUnidad: { fontSize: '12px', color: '#999', fontWeight: 'normal' },
  kpiLabel: { fontSize: '12px', color: '#777', marginTop: '2px' },
  tarjeta: { backgroundColor: '#fff', border: '1px solid #eee', borderRadius: '15px', padding: '16px', marginBottom: '20px' },
  tarjetaTitulo: { fontSize: '14px', fontWeight: 'bold', color: '#555', marginBottom: '12px' },
  subtitulo: { fontSize: '15px', color: '#555', margin: '0 0 12px' },
  lista: { display: 'flex', flexDirection: 'column', gap: '10px' },
  fila: { display: 'flex', alignItems: 'center', gap: '16px', backgroundColor: '#fff', border: '1px solid #eee', borderRadius: '12px', padding: '12px 16px', flexWrap: 'wrap' },
  filaBarra: { width: '6px', height: '36px', borderRadius: '4px' },
  filaTitulo: { flex: 1, minWidth: '100px' },
  filaHora: { fontWeight: 'bold', fontSize: '14px', color: '#333' },
  filaDetalle: { fontSize: '12px', color: '#888' },
  miniDato: { textAlign: 'center', minWidth: '56px' },
  miniValor: { fontWeight: 'bold', fontSize: '14px', color: '#1a1a1a' },
  miniLabel: { fontSize: '10px', color: '#999', fontWeight: 600 },
  badge: { padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 'bold', whiteSpace: 'nowrap' },
};

export default PacienteDetalle;
