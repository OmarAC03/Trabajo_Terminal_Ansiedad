import { useEffect, useState } from 'react';
import axios from 'axios';
import { Timer, Heart, Clock, ClipboardList, Activity, List, CircleAlert } from 'lucide-react';
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, Legend, CartesianGrid } from 'recharts';
import { auth } from './firebase';
import { Card, KpiCard, Badge, Alert } from './ui/components';
import { haceTiempo } from './PacientesComun';
import {
  SESIONES_URL, normalizarSesion, resumenSesiones, datosTendencia,
  porcentajeCalidad, duracionTexto, fechaHora,
} from './sesiones';

// Colores de gráfica de GUIA_ESTILO_PORTAL.md (los mismos de PacienteDetalle).
const COLORES = { bpm: '#2563eb', hrv: '#d97706' };
const EJE = { fontSize: 11, fill: '#94a3b8' };

// Sesiones de medición del paciente (Fase M1, portal): indicadores de los
// últimos 30 días, HRV y FC por sesión, y la tabla de sesiones con su calidad
// de señal y su origen. Para el especialista: él interpreta; no hay semáforo
// (el estado contra la línea base llega en M3).
function SesionesPaciente({ paciente, recarga }) {
  const [sesiones, setSesiones] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelado = false;

    const cargar = async () => {
      setCargando(true);
      setError('');
      try {
        const token = await auth.currentUser.getIdToken();
        const res = await axios.get(`${SESIONES_URL}/${paciente.id}?limite=200`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (cancelado) return;
        setSesiones(res.data.map(normalizarSesion));
      } catch (e) {
        if (cancelado) return;
        console.error('Error al cargar las sesiones del paciente:', e);
        setError(
          e.response?.status === 403
            ? 'Este paciente no está vinculado a tu cuenta.'
            : 'No se pudieron cargar las sesiones. Intenta de nuevo en unos segundos.'
        );
      } finally {
        if (!cancelado) setCargando(false);
      }
    };

    cargar();
    return () => {
      cancelado = true;
    };
  }, [paciente.id, recarga]);

  if (error) return <Alert tone="altos" icon={CircleAlert}>{error}</Alert>;
  if (cargando) return <Card><div className="ui-empty">Cargando sesiones de medición…</div></Card>;
  if (sesiones.length === 0) {
    return (
      <Card title="Sesiones de medición" icon={ClipboardList}>
        <div className="ui-empty">Este paciente aún no tiene sesiones de medición.</div>
      </Card>
    );
  }

  const resumen = resumenSesiones(sesiones);
  const tendencia = datosTendencia(sesiones);

  return (
    <div className="ui-stack">
      <Kpis resumen={resumen} />
      {tendencia.length > 0 && <GraficaTendencia datos={tendencia} />}
      <TablaSesiones sesiones={sesiones} />
    </div>
  );
}

function Kpis({ resumen }) {
  const conUnidad = (v, unidad) =>
    v == null ? '--' : (
      <>
        {Math.round(v)}
        <span className="ui-unit" style={{ fontSize: 'var(--text-md)' }}>{unidad}</span>
      </>
    );
  return (
    <div className="ui-grid ui-grid-kpi">
      <KpiCard label="Sesiones" value={resumen.total} hint="Últimos 30 días" icon={ClipboardList} tone="primary" />
      <KpiCard label="HRV promedio (RMSSD)" value={conUnidad(resumen.hrvPromedio, 'ms')} hint="Últimos 30 días" icon={Timer} tone="primary" />
      <KpiCard label="FC promedio" value={conUnidad(resumen.bpmPromedio, 'lpm')} hint="Últimos 30 días" icon={Heart} tone="primary" />
      <KpiCard
        label="Última medición"
        value={<span style={{ fontSize: 'var(--text-xl)' }}>{resumen.ultima ? haceTiempo(resumen.ultima) : '—'}</span>}
        hint={resumen.ultima ? fechaHora(resumen.ultima) : undefined}
        icon={Clock}
        tone="primary"
      />
    </div>
  );
}

function GraficaTendencia({ datos }) {
  return (
    <Card title="HRV y FC por sesión" subtitle="Un punto por sesión, últimos 30 días" icon={Activity}>
      <div style={{ width: '100%', height: 260 }}>
        <ResponsiveContainer>
          <LineChart data={datos} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
            <CartesianGrid stroke="#e2e8f0" vertical={false} />
            <XAxis dataKey="x" tick={EJE} axisLine={{ stroke: '#e2e8f0' }} tickLine={false} />
            <YAxis tick={EJE} axisLine={false} tickLine={false} />
            <Tooltip
              contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13 }}
              formatter={(v) => Math.round(v)}
            />
            <Legend wrapperStyle={{ fontSize: 12 }} iconType="circle" />
            <Line type="monotone" dataKey="hrv" name="HRV, RMSSD (ms)" stroke={COLORES.hrv} strokeWidth={2} dot={{ r: 3 }} />
            <Line type="monotone" dataKey="bpm" name="FC promedio (lpm)" stroke={COLORES.bpm} strokeWidth={2} dot={{ r: 3 }} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
}

function TablaSesiones({ sesiones }) {
  return (
    <Card
      className="ui-card-flush"
      title="Sesiones de medición"
      subtitle={`${sesiones.length} ${sesiones.length === 1 ? 'sesión' : 'sesiones'}, la más reciente primero`}
      icon={List}
    >
      <div className="ui-table-wrap">
        <table className="ui-table">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Duración</th>
              <th>HRV</th>
              <th>FC</th>
              <th>SpO2</th>
              <th>Calidad de señal</th>
              <th>Origen</th>
            </tr>
          </thead>
          <tbody>
            {sesiones.map((s) => (
              <tr key={s.id}>
                <td className="ui-person-name">{fechaHora(s.fecha_inicio)}</td>
                <td className="ui-muted">{duracionTexto(s.duracion_total_seg)}</td>
                <td><span className="ui-num">{Math.round(s.hrv_rmssd)}</span><span className="ui-unit">ms</span></td>
                <td><span className="ui-num">{Math.round(s.bpm_promedio)}</span><span className="ui-unit">lpm</span></td>
                <td><span className="ui-num">{Math.round(s.spo2_promedio)}</span><span className="ui-unit">%</span></td>
                <td><span className="ui-num">{porcentajeCalidad(s.indice_calidad)}</span><span className="ui-unit">%</span></td>
                <td>{s.origen === 'simulacion' ? <Badge tone="neutral">Simulación</Badge> : <span className="ui-muted">Sensor</span>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

export default SesionesPaciente;
