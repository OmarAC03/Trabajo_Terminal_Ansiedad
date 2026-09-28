import { useEffect, useState } from 'react';
import axios from 'axios';
import {
  ArrowLeft, Heart, Timer, TriangleAlert, Clock, Info, Mail, RefreshCw, CircleAlert, Activity, List,
} from 'lucide-react';
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, Legend, CartesianGrid } from 'recharts';
import { auth } from './firebase';
import { getStatusLabel, getStatusTone } from './semaforo';
import { Card, KpiCard, Button, Badge, Avatar, Alert, Disclaimer } from './ui/components';
import { haceTiempo } from './PacientesComun';
import ChatPaciente from './ChatPaciente';
import EjerciciosPaciente from './EjerciciosPaciente';

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
function PacienteDetalle({ paciente, onVolver, recarga, onActualizar, errorAcceso }) {
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
    <div className="ui-page ui-page-wide">
      <div style={{ marginBottom: 16 }}>
        <Button variant="secondary" size="sm" icon={ArrowLeft} onClick={onVolver}>Volver</Button>
      </div>

      <Card>
        <div className="ui-detail-header-row">
          <div className="ui-person">
            <Avatar nombre={paciente.nombre} size={56} tone={getStatusTone(paciente.ultimo_estado)} />
            <div style={{ minWidth: 0 }}>
              <h1 className="ui-page-title" style={{ fontSize: 'var(--text-xl)' }}>{paciente.nombre}</h1>
              <div className="ui-detail-meta">
                <span className="ui-detail-email"><Mail size={14} /> {paciente.email}</span>
                <Badge tone={getStatusTone(paciente.ultimo_estado)}>{getStatusLabel(paciente.ultimo_estado)}</Badge>
                <span className="ui-muted">
                  {paciente.ultima_lectura ? `Última lectura ${haceTiempo(paciente.ultima_lectura)}` : 'Sin lecturas registradas'}
                </span>
              </div>
            </div>
          </div>
          <div className="ui-detail-actions">
            <div className="ui-segmented" role="group" aria-label="Periodo">
              {PERIODOS.map((p) => (
                <button
                  key={p.valor}
                  type="button"
                  className={`ui-segmented-item${periodo === p.valor ? ' is-active' : ''}`}
                  aria-pressed={periodo === p.valor}
                  onClick={() => setPeriodo(p.valor)}
                >
                  {p.label}
                </button>
              ))}
            </div>
            <Button icon={RefreshCw} onClick={onActualizar}>Actualizar</Button>
          </div>
        </div>
      </Card>

      <div className="ui-stack" style={{ gap: 12, margin: '20px 0' }}>
        {errorAcceso && <Alert tone="altos" icon={CircleAlert}>{errorAcceso}</Alert>}
        <Disclaimer icon={Info}>
          Datos fisiológicos de apoyo. La interpretación y el diagnóstico corresponden al profesional de salud.
        </Disclaimer>
      </div>

      {/* Dos columnas en pantalla ancha: datos + ejercicios | chat. Es solo
          CSS: el chat queda montado siempre en el mismo lugar del árbol, así
          que cambiar de periodo o de ancho de ventana no reconecta el socket. */}
      <div className="ui-detail-cols">
        <div>
          {error ? (
            <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
          ) : cargando ? (
            <Card><div className="ui-empty">Cargando datos del paciente…</div></Card>
          ) : periodo === 'dia' ? (
            <VistaDia lecturas={lecturas} paciente={paciente} />
          ) : (
            <VistaAgregada dias={dias} paciente={paciente} periodo={periodo} />
          )}

          <EjerciciosPaciente paciente={paciente} recarga={recarga} />
        </div>

        <div className="ui-detail-side">
          <ChatPaciente paciente={paciente} />
        </div>
      </div>
    </div>
  );
}

const SUBTITULO_PERIODO = { dia: 'Promedio de hoy', semana: 'Promedio de 7 días', mes: 'Promedio de 30 días' };

function VistaDia({ lecturas, paciente }) {
  if (lecturas.length === 0) {
    return (
      <div className="ui-stack">
        <Kpis bpm={null} hrv={null} altas={0} paciente={paciente} periodo="dia" />
        <Card><div className="ui-empty">Sin lecturas hoy. Cambia a Semana o Mes para ver días anteriores.</div></Card>
      </div>
    );
  }

  const promedio = (campo) => lecturas.reduce((a, l) => a + Number(l[campo]), 0) / lecturas.length;
  const altas = lecturas.filter((l) => l.estado_ansiedad === 'Alta').length;
  const datosGrafica = lecturas.map((l) => ({ x: hora(l.fecha_medicion), bpm: l.bpm, spo2: l.spo2, hrv: l.hrv }));

  return (
    <div className="ui-stack">
      <Kpis bpm={promedio('bpm')} hrv={promedio('hrv')} altas={altas} paciente={paciente} periodo="dia" />
      <Grafica titulo="Tendencia de indicadores fisiológicos" subtitulo="Lecturas de hoy" datos={datosGrafica} />
      <TablaLecturas
        titulo="Lecturas de hoy"
        subtitulo={`${lecturas.length} ${lecturas.length === 1 ? 'lectura' : 'lecturas'}, la más reciente primero`}
        columnas={['Hora']}
        filas={[...lecturas].reverse().map((l) => ({
          key: l.id,
          celdas: [hora(l.fecha_medicion)],
          bpm: l.bpm,
          spo2: l.spo2,
          hrv: l.hrv,
          estado: l.estado_ansiedad,
        }))}
      />
    </div>
  );
}

function VistaAgregada({ dias, paciente, periodo }) {
  if (dias.length === 0) {
    return (
      <div className="ui-stack">
        <Kpis bpm={null} hrv={null} altas={0} paciente={paciente} periodo={periodo} />
        <Card>
          <div className="ui-empty">
            {periodo === 'semana' ? 'Sin lecturas en los últimos 7 días.' : 'Sin lecturas en los últimos 30 días.'}
          </div>
        </Card>
      </div>
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
    <div className="ui-stack">
      <Kpis
        bpm={promedioPonderado(dias, 'bpm_promedio')}
        hrv={promedioPonderado(dias, 'hrv_promedio')}
        altas={altas}
        paciente={paciente}
        periodo={periodo}
      />
      <Grafica
        titulo="Tendencia de indicadores fisiológicos"
        subtitulo={periodo === 'semana' ? 'Promedio por día, últimos 7 días' : 'Promedio por día, últimos 30 días'}
        datos={datosGrafica}
      />
      <TablaLecturas
        titulo="Resumen por día"
        subtitulo="Promedios diarios, el día más reciente primero"
        columnas={['Día', 'Lecturas', 'Altas']}
        filas={[...dias].reverse().map((d) => ({
          key: d.dia,
          celdas: [etiquetaDia(d.dia), d.total_registros, d.episodios_altos],
          bpm: d.bpm_promedio,
          spo2: d.spo2_promedio,
          hrv: d.hrv_promedio,
          estado: estadoDelDia(d),
        }))}
      />
    </div>
  );
}

function Kpis({ bpm, hrv, altas, paciente, periodo }) {
  const conUnidad = (v, unidad) =>
    v == null ? '--' : (
      <>
        {Math.round(v)}
        <span className="ui-unit" style={{ fontSize: 'var(--text-md)' }}>{unidad}</span>
      </>
    );
  const tonoUltima = getStatusTone(paciente.ultimo_estado);
  return (
    <div className="ui-grid ui-grid-kpi">
      <KpiCard label="BPM promedio" value={conUnidad(bpm, 'BPM')} hint={SUBTITULO_PERIODO[periodo]} icon={Heart} tone="primary" />
      <KpiCard label="HRV promedio" value={conUnidad(hrv, 'ms')} hint={SUBTITULO_PERIODO[periodo]} icon={Timer} tone="primary" />
      <KpiCard
        label="Lecturas altas"
        value={altas}
        hint="Con indicadores Altos"
        hintTone={altas > 0 ? 'altos' : undefined}
        icon={TriangleAlert}
        tone="altos"
      />
      <KpiCard
        label="Última lectura"
        value={
          <span style={{ fontSize: 'var(--text-xl)' }}>
            {paciente.ultima_lectura ? haceTiempo(paciente.ultima_lectura) : 'Sin lecturas'}
          </span>
        }
        hint={getStatusLabel(paciente.ultimo_estado)}
        hintTone={tonoUltima}
        icon={Clock}
        tone={tonoUltima}
      />
    </div>
  );
}

// Colores de gráfica de GUIA_ESTILO_PORTAL.md (chart-1/2/3).
const COLORES_GRAFICA = { bpm: '#2563eb', spo2: '#16a34a', hrv: '#d97706' };
const EJE = { fontSize: 11, fill: '#94a3b8' };

function Grafica({ titulo, subtitulo, datos }) {
  return (
    <Card title={titulo} subtitle={subtitulo} icon={Activity}>
      <div style={{ width: '100%', height: 280 }}>
        <ResponsiveContainer>
          <LineChart data={datos} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
            <CartesianGrid stroke="#e2e8f0" vertical={false} />
            <XAxis dataKey="x" tick={EJE} axisLine={{ stroke: '#e2e8f0' }} tickLine={false} />
            <YAxis tick={EJE} axisLine={false} tickLine={false} />
            <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13 }} />
            <Legend wrapperStyle={{ fontSize: 12 }} iconType="circle" />
            <Line type="monotone" dataKey="bpm" name="BPM" stroke={COLORES_GRAFICA.bpm} strokeWidth={2} dot={false} />
            <Line type="monotone" dataKey="spo2" name="SpO2 (%)" stroke={COLORES_GRAFICA.spo2} strokeWidth={2} dot={false} />
            <Line type="monotone" dataKey="hrv" name="HRV (ms)" stroke={COLORES_GRAFICA.hrv} strokeWidth={2} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
}

// Lecturas del día o resumen por día. `columnas` son las primeras columnas
// propias de cada vista (sus valores van en `celdas`, en el mismo orden);
// BPM, SpO2, HRV y el estado son comunes.
function TablaLecturas({ titulo, subtitulo, columnas, filas }) {
  return (
    <Card className="ui-card-flush" title={titulo} subtitle={subtitulo} icon={List}>
      <div className="ui-table-wrap">
        <table className="ui-table">
          <thead>
            <tr>
              {columnas.map((c) => <th key={c}>{c}</th>)}
              <th>BPM</th>
              <th>SpO2</th>
              <th>HRV</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            {filas.map((f) => (
              <tr key={f.key}>
                {f.celdas.map((celda, i) => (
                  <td key={columnas[i]} className={i === 0 ? 'ui-person-name' : 'ui-num'}>{celda}</td>
                ))}
                <td><span className="ui-num">{f.bpm}</span></td>
                <td><span className="ui-num">{f.spo2}</span><span className="ui-unit">%</span></td>
                <td><span className="ui-num">{f.hrv}</span><span className="ui-unit">ms</span></td>
                <td><Badge tone={getStatusTone(f.estado)}>{getStatusLabel(f.estado)}</Badge></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

export default PacienteDetalle;
