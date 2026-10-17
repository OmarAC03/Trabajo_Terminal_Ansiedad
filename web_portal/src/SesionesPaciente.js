import { useEffect, useState } from 'react';
import axios from 'axios';
import { Timer, Heart, Clock, ClipboardList, Activity, List, CircleAlert, Target } from 'lucide-react';
import {
  ResponsiveContainer, ComposedChart, Area, Line, XAxis, YAxis, Tooltip, Legend, CartesianGrid,
} from 'recharts';
import { auth } from './firebase';
import { Card, KpiCard, Badge, Alert } from './ui/components';
import { haceTiempo, BadgeEstado } from './PacientesComun';
import {
  SESIONES_URL, LINEA_BASE_URL, normalizarSesion, resumenSesiones, datosTendencia,
  origenesPresentes, origenMasReciente, textoOrigen,
  porcentajeCalidad, duracionTexto, fechaHora, evaSobre10,
} from './sesiones';
import { colorEstado, textoEstado, textoSinEstado, textoEtapa, textoCalibracion } from './semaforo';
import SesionDetalle from './SesionDetalle';

// Mismos colores por métrica que SesionDetalle.js (FC = --color-primary,
// HRV = --color-cyan). El verde/ámbar/rojo del estado solo aparece en los
// puntos de HRV, que es lo que se clasifica; la franja del rango habitual va
// en cian claro (es de la HRV, no un estado).
const COLORES = { bpm: '#2563eb', hrv: '#0891b2' };
const EJE = { fontSize: 11, fill: '#94a3b8' };

// Sesiones de medición del paciente (Fase M1, portal): indicadores de los
// últimos 30 días, HRV y FC por sesión, y la tabla de sesiones con su calidad
// de señal y su origen. Desde M3, el estado de cada sesión contra la línea
// base INDIVIDUAL del paciente (solo el especialista lo ve; el paciente
// nunca recibe la etiqueta), la franja de su rango habitual en la gráfica y
// la calibración de la base por origen (GET /api/linea-base).
function SesionesPaciente({ paciente, recarga }) {
  const [sesiones, setSesiones] = useState([]);
  const [lineaBase, setLineaBase] = useState(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  // Sesión abierta en el detalle (se muestra en lugar de la lista, sin router).
  const [sesionId, setSesionId] = useState(null);
  // Origen elegido en la gráfica; null = el de la sesión más reciente.
  const [origen, setOrigen] = useState(null);

  useEffect(() => {
    let cancelado = false;

    const cargar = async () => {
      setCargando(true);
      setError('');
      try {
        const token = await auth.currentUser.getIdToken();
        const headers = { Authorization: `Bearer ${token}` };
        // La línea base no es indispensable: si falla, la lista se muestra igual.
        const [res, base] = await Promise.all([
          axios.get(`${SESIONES_URL}/${paciente.id}?limite=200`, { headers }),
          axios.get(`${LINEA_BASE_URL}/${paciente.id}`, { headers }).catch((e) => {
            console.error('Error al cargar la línea base del paciente:', e);
            return null;
          }),
        ]);
        if (cancelado) return;
        setSesiones(res.data.map(normalizarSesion));
        setLineaBase(base ? base.data : null);
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

  if (sesionId) {
    return <SesionDetalle paciente={paciente} sesionId={sesionId} onVolver={() => setSesionId(null)} />;
  }
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
  const origenes = origenesPresentes(sesiones);
  const origenGrafica = origenes.includes(origen) ? origen : origenMasReciente(sesiones);
  const tendencia = datosTendencia(sesiones, { origen: origenGrafica });

  return (
    <div className="ui-stack">
      <Kpis resumen={resumen} />
      {lineaBase && <TarjetaLineaBase lineaBase={lineaBase} origenes={origenes} />}
      <GraficaTendencia
        datos={tendencia}
        origenes={origenes}
        origen={origenGrafica}
        onOrigen={setOrigen}
      />
      <TablaSesiones sesiones={sesiones} onSeleccionar={setSesionId} />
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
      <KpiCard label="HRV promedio (RMSSD)" value={conUnidad(resumen.hrvPromedio, 'ms')} hint="Últimos 30 días" icon={Timer} tone="cyan" />
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

// Calibración de la línea base HOY, por origen (cada uno tiene su propia
// base): la etapa y, cuando ya hay base, el rango habitual con el que se
// compararía una medición de hoy.
function TarjetaLineaBase({ lineaBase, origenes }) {
  const filas = origenes.map((o) => lineaBase.origenes?.[o]).filter(Boolean);
  if (filas.length === 0) return null;

  return (
    <Card
      title="Línea base individual"
      subtitle="Contra qué se compara una medición de hoy"
      icon={Target}
      iconTone="cyan"
    >
      <div className="ui-stack" style={{ gap: 12 }}>
        {filas.map((c) => (
          <div key={c.origen} style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
            <Badge tone="neutral" dot={false}>{textoOrigen(c.origen)}</Badge>
            <strong>{textoCalibracion(c)}</strong>
            <span className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>
              {c.banda ? (
                <>
                  Rango habitual de HRV {c.banda.rango_hrv_ms.min.toFixed(1)}–{c.banda.rango_hrv_ms.max.toFixed(1)} ms
                  {' · '}FC habitual hasta {Math.round(c.banda.fc_limite_superior)} lpm
                </>
              ) : (
                `Sin comparación hasta tener ${c.dias_minimos} días con medición (lleva ${c.dias_con_medicion}).`
              )}
            </span>
          </div>
        ))}
      </div>
      <p className="ui-muted" style={{ fontSize: 'var(--text-sm)', margin: '12px 0 0' }}>
        Cada sesión se compara con la media de los últimos {lineaBase.origenes?.simulacion?.dias_objetivo ?? 7} días
        con medición del propio paciente (sin el día de la sesión). La base es preliminar desde 3 días y se
        consolida con 7; mientras es preliminar, la banda es más tolerante. Indicador de apoyo, no un diagnóstico.
      </p>
    </Card>
  );
}

// Punto de HRV coloreado por el estado de su sesión; hueco gris si no tiene.
function PuntoEstado({ cx, cy, payload, index }) {
  if (cx == null || cy == null) return null;
  const conEstado = payload.estado != null;
  const color = colorEstado(payload.estado);
  return (
    <circle
      key={`p-${index}`}
      cx={cx}
      cy={cy}
      r={conEstado ? 4 : 3.5}
      fill={conEstado ? color : '#ffffff'}
      stroke={color}
      strokeWidth={conEstado ? 1 : 1.5}
    />
  );
}

function TooltipTendencia({ active, payload }) {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div style={{ background: '#fff', borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13, padding: '8px 12px' }}>
      <div style={{ fontWeight: 600, marginBottom: 4 }}>{fechaHora(d.fecha)}</div>
      <div>HRV {Math.round(d.hrv)} ms{d.banda && ` · habitual ${d.banda[0].toFixed(1)}–${d.banda[1].toFixed(1)} ms`}</div>
      <div>FC {Math.round(d.bpm)} lpm</div>
      <div style={{ color: colorEstado(d.estado), fontWeight: 600, marginTop: 4 }}>
        {d.estado ? textoEstado(d.estado) : textoSinEstado(d.motivo_sin_estado)}
        {d.etapa && <span className="ui-muted" style={{ fontWeight: 400 }}> · base {textoEtapa(d.etapa).toLowerCase()}</span>}
      </div>
    </div>
  );
}

function GraficaTendencia({ datos, origenes, origen, onOrigen }) {
  const selector = origenes.length > 1 && (
    <div className="ui-segmented" role="group" aria-label="Origen de las sesiones">
      {origenes.map((o) => (
        <button
          key={o}
          type="button"
          className={`ui-segmented-item${o === origen ? ' is-active' : ''}`}
          aria-pressed={o === origen}
          onClick={() => onOrigen(o)}
        >
          {textoOrigen(o)}
        </button>
      ))}
    </div>
  );

  return (
    <Card
      title="HRV y FC por sesión"
      subtitle={`Un punto por sesión, últimos 30 días · ${textoOrigen(origen)}`}
      icon={Activity}
      actions={selector}
    >
      {datos.length === 0 ? (
        <div className="ui-empty">Sin sesiones de este origen en los últimos 30 días.</div>
      ) : (
        <>
          <div style={{ width: '100%', height: 280 }}>
            <ResponsiveContainer>
              <ComposedChart data={datos} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
                <CartesianGrid stroke="#e2e8f0" vertical={false} />
                <XAxis dataKey="x" tick={EJE} axisLine={{ stroke: '#e2e8f0' }} tickLine={false} />
                <YAxis tick={EJE} axisLine={false} tickLine={false} />
                <Tooltip content={<TooltipTendencia />} />
                <Legend wrapperStyle={{ fontSize: 12 }} iconType="circle" />
                {/* Franja: el rango habitual de CADA sesión (±k1 contra sus días previos). */}
                <Area
                  type="linear"
                  dataKey="banda"
                  name="Rango habitual de HRV (ms)"
                  fill={COLORES.hrv}
                  fillOpacity={0.12}
                  stroke="none"
                  connectNulls={false}
                  isAnimationActive={false}
                  activeDot={false}
                />
                <Line
                  type="monotone"
                  dataKey="hrv"
                  name="HRV, RMSSD (ms)"
                  stroke={COLORES.hrv}
                  strokeWidth={2}
                  dot={PuntoEstado}
                  isAnimationActive={false}
                />
                <Line type="monotone" dataKey="bpm" name="FC promedio (lpm)" stroke={COLORES.bpm} strokeWidth={2} dot={{ r: 3 }} />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
          <p className="ui-muted" style={{ fontSize: 'var(--text-sm)', margin: '8px 0 0' }}>
            Puntos de HRV por estado contra su línea base: verde Normal, ámbar Elevados, rojo Altos; hueco gris
            si aún se calibra o la señal no alcanzó la calidad mínima. La franja se corta mientras no hay base.
          </p>
        </>
      )}
    </Card>
  );
}

function TablaSesiones({ sesiones, onSeleccionar }) {
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
              <th>Estado</th>
              <th>Duración</th>
              <th>HRV</th>
              <th>FC</th>
              <th>SpO2</th>
              <th>EVA</th>
              <th>Calidad de señal</th>
              <th>Origen</th>
            </tr>
          </thead>
          <tbody>
            {sesiones.map((s) => (
              <tr
                key={s.id}
                className="ui-table-row-link"
                tabIndex={0}
                onClick={() => onSeleccionar(s.id)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') onSeleccionar(s.id);
                }}
              >
                <td className="ui-person-name">{fechaHora(s.fecha_inicio)}</td>
                <td>{s.evaluacion ? <BadgeEstado evaluacion={s.evaluacion} conEtapa /> : <span className="ui-muted">—</span>}</td>
                <td className="ui-muted">{duracionTexto(s.duracion_total_seg)}</td>
                <td><span className="ui-num">{Math.round(s.hrv_rmssd)}</span><span className="ui-unit">ms</span></td>
                <td><span className="ui-num">{Math.round(s.bpm_promedio)}</span><span className="ui-unit">lpm</span></td>
                <td><span className="ui-num">{Math.round(s.spo2_promedio)}</span><span className="ui-unit">%</span></td>
                {/* EVA: lo que reportó el paciente, sin color ni semáforo; "—" si la omitió. */}
                <td>
                  {s.eva_valor == null
                    ? <span className="ui-muted">—</span>
                    : <><span className="ui-num">{evaSobre10(s.eva_valor)}</span><span className="ui-unit">/10</span></>}
                </td>
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
