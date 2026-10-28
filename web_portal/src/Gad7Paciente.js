import { Fragment, useEffect, useState } from 'react';
import axios from 'axios';
import { ClipboardCheck, ChevronDown, ChevronRight, CircleAlert, Info } from 'lucide-react';
import {
  ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, CartesianGrid, ReferenceLine,
} from 'recharts';
import { auth } from './firebase';
import { Card, Alert, Disclaimer } from './ui/components';
import { haceTiempo, BadgeSeveridad, BadgeValorar } from './PacientesComun';
import { fechaHora } from './sesiones';
import {
  GAD7_URL, PUNTAJE_MAXIMO, CORTE_VALORAR, REFERENCIAS_GAD7, COLOR_GAD7,
  textoSeveridad, textoProximo, textoDificultad, detalleItems, datosGrafica,
} from './gad7';

const EJE = { fontSize: 11, fill: '#94a3b8' };
const GRIS_REFERENCIA = '#cbd5e1'; // --color-border-strong

// GAD-7 del paciente (Fase M5a, paso 5): último resultado, cuándo le toca el
// próximo, historial (gráfica + tabla) y, al hacer clic en una fila, sus 7
// respuestas. Datos de GET /api/gad7/:pacienteId (vista del especialista).
// Tonos neutros a propósito: es un instrumento de tamizaje, no el semáforo
// de los indicadores fisiológicos, y no es un diagnóstico.
function Gad7Paciente({ paciente, recarga }) {
  const [datos, setDatos] = useState(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  // Respuesta con el detalle abierto en la tabla (una a la vez).
  const [abierta, setAbierta] = useState(null);

  useEffect(() => {
    let cancelado = false;

    const cargar = async () => {
      setCargando(true);
      setError('');
      try {
        const token = await auth.currentUser.getIdToken();
        const res = await axios.get(`${GAD7_URL}/${paciente.id}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (cancelado) return;
        setDatos({ estado: res.data.estado, respuestas: res.data.respuestas || [] });
      } catch (e) {
        if (cancelado) return;
        console.error('Error al cargar el GAD-7 del paciente:', e);
        setError(
          e.response?.status === 403
            ? 'Este paciente no está vinculado a tu cuenta.'
            : 'No se pudo cargar el GAD-7. Intenta de nuevo en unos segundos.'
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

  const tarjeta = (contenido) => (
    <Card
      className="ui-section-gap"
      title="GAD-7 (tamizaje quincenal)"
      subtitle="Cuestionario de ansiedad generalizada que el paciente responde en la app cada 14 días"
      icon={ClipboardCheck}
      iconTone="violet"
    >
      {contenido}
      <div style={{ marginTop: 16 }}>
        <Disclaimer icon={Info}>
          El GAD-7 es un instrumento de tamizaje autoaplicado; no es un diagnóstico. Un puntaje de {CORTE_VALORAR} o
          más sugiere valorarlo clínicamente (Spitzer et al., 2006). El paciente no ve su resultado.
        </Disclaimer>
      </div>
    </Card>
  );

  if (error) return <div className="ui-section-gap"><Alert tone="altos" icon={CircleAlert}>{error}</Alert></div>;
  if (cargando || !datos) return tarjeta(<div className="ui-empty">Cargando GAD-7…</div>);

  const { estado, respuestas } = datos;
  if (respuestas.length === 0) {
    return tarjeta(
      <div className="ui-empty">
        Aún no ha respondido el GAD-7.
        {estado && <div className="ui-muted" style={{ marginTop: 6 }}>{textoProximo(estado)}</div>}
      </div>
    );
  }

  return tarjeta(
    <div className="ui-stack" style={{ gap: 24 }}>
      <UltimoResultado respuesta={respuestas[0]} estado={estado} />
      {respuestas.length >= 2 && <GraficaHistorial datos={datosGrafica(respuestas)} />}
      <TablaHistorial
        respuestas={respuestas}
        abierta={abierta}
        onAlternar={(id) => setAbierta((actual) => (actual === id ? null : id))}
      />
    </div>
  );
}

function UltimoResultado({ respuesta, estado }) {
  return (
    <div className="ui-gad7-resumen">
      <div className="ui-gad7-puntaje">
        {respuesta.puntaje}
        <span className="ui-unit" style={{ fontSize: 'var(--text-md)' }}>/ {PUNTAJE_MAXIMO}</span>
      </div>
      <div className="ui-stack" style={{ gap: 6 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <BadgeSeveridad severidad={respuesta.severidad} />
          {respuesta.valorar && <BadgeValorar />}
        </div>
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>
          Último cuestionario {haceTiempo(respuesta.fecha_respuesta)} · {fechaHora(respuesta.fecha_respuesta)}
        </div>
        {estado && <div style={{ fontSize: 'var(--text-sm)', fontWeight: 600 }}>{textoProximo(estado)}</div>}
      </div>
    </div>
  );
}

// Punto del puntaje: relleno si es para valorar (≥ 10), hueco si no.
function PuntoGad7({ cx, cy, payload, index }) {
  if (cx == null || cy == null) return null;
  return (
    <circle
      key={`g-${index}`}
      cx={cx}
      cy={cy}
      r={4}
      fill={payload.valorar ? COLOR_GAD7 : '#ffffff'}
      stroke={COLOR_GAD7}
      strokeWidth={1.5}
    />
  );
}

function TooltipGad7({ active, payload }) {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div style={{ background: '#fff', borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13, padding: '8px 12px' }}>
      <div style={{ fontWeight: 600, marginBottom: 4 }}>{fechaHora(d.fecha)}</div>
      <div>Puntaje {d.puntaje} / {PUNTAJE_MAXIMO} · {textoSeveridad(d.severidad)}</div>
      {d.valorar && <div style={{ color: COLOR_GAD7, fontWeight: 600, marginTop: 4 }}>Valorar (≥{CORTE_VALORAR})</div>}
    </div>
  );
}

function GraficaHistorial({ datos }) {
  return (
    <div>
      <div className="ui-gad7-subtitulo">Puntaje por cuestionario</div>
      <div style={{ width: '100%', height: 240 }}>
        <ResponsiveContainer>
          <LineChart data={datos} margin={{ top: 10, right: 70, left: -20, bottom: 0 }}>
            <CartesianGrid stroke="#e2e8f0" vertical={false} />
            <XAxis dataKey="x" tick={EJE} axisLine={{ stroke: '#e2e8f0' }} tickLine={false} />
            <YAxis domain={[0, PUNTAJE_MAXIMO]} ticks={[0, 5, 10, 15, 21]} tick={EJE} axisLine={false} tickLine={false} />
            <Tooltip content={<TooltipGad7 />} />
            {/* Inicio de cada tramo (Spitzer et al., 2006), en gris: no son un semáforo. */}
            {REFERENCIAS_GAD7.map((r) => (
              <ReferenceLine
                key={r.valor}
                y={r.valor}
                stroke={GRIS_REFERENCIA}
                strokeDasharray="4 4"
                strokeWidth={r.valor === CORTE_VALORAR ? 2 : 1}
                label={{ value: r.texto, position: 'right', fill: '#64748b', fontSize: 11 }}
              />
            ))}
            <Line
              type="monotone"
              dataKey="puntaje"
              name="Puntaje GAD-7"
              stroke={COLOR_GAD7}
              strokeWidth={2}
              dot={PuntoGad7}
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <p className="ui-muted" style={{ fontSize: 'var(--text-sm)', margin: '8px 0 0' }}>
        Líneas punteadas: inicio de los tramos Leve (5), Moderada (10) y Grave (15). Punto relleno: puntaje de{' '}
        {CORTE_VALORAR} o más.
      </p>
    </div>
  );
}

function TablaHistorial({ respuestas, abierta, onAlternar }) {
  return (
    <div>
      <div className="ui-gad7-subtitulo">
        Historial · {respuestas.length} {respuestas.length === 1 ? 'cuestionario' : 'cuestionarios'}, el más reciente
        primero · clic para ver las respuestas
      </div>
      <div className="ui-table-wrap">
        <table className="ui-table">
          <thead>
            <tr>
              <th><span className="sr-only">Abrir</span></th>
              <th>Fecha</th>
              <th>Puntaje</th>
              <th>Severidad</th>
              <th>Valorar</th>
            </tr>
          </thead>
          <tbody>
            {respuestas.map((r) => {
              const abiertaEsta = abierta === r.id;
              return (
                <Fragment key={r.id}>
                  <tr
                    className={`ui-table-row-link${abiertaEsta ? ' is-open' : ''}`}
                    tabIndex={0}
                    aria-expanded={abiertaEsta}
                    onClick={() => onAlternar(r.id)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') onAlternar(r.id);
                    }}
                  >
                    <td style={{ width: 1 }} className="ui-muted">
                      {abiertaEsta ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                    </td>
                    <td className="ui-person-name">{fechaHora(r.fecha_respuesta)}</td>
                    <td><span className="ui-num">{r.puntaje}</span><span className="ui-unit">/ {PUNTAJE_MAXIMO}</span></td>
                    <td><BadgeSeveridad severidad={r.severidad} /></td>
                    <td>{r.valorar ? <BadgeValorar /> : <span className="ui-muted">—</span>}</td>
                  </tr>
                  {abiertaEsta && (
                    <tr className="ui-gad7-detalle-row">
                      <td colSpan={5}>
                        <DetalleRespuesta respuesta={r} />
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// Las 7 respuestas, la dificultad y la versión del texto. La escala de cada
// ítem (0–3) va en puntos violeta, sin color por gravedad.
function DetalleRespuesta({ respuesta }) {
  return (
    <div className="ui-gad7-detalle">
      <ol className="ui-gad7-items">
        {detalleItems(respuesta).map((it) => (
          <li key={it.numero} className="ui-gad7-item">
            <span className="ui-gad7-item-num">{it.numero}</span>
            <span className="ui-gad7-item-texto">{it.texto}</span>
            <span className="ui-gad7-item-resp">
              <span className="ui-gad7-escala" aria-hidden="true">
                {[1, 2, 3].map((n) => (
                  <span key={n} className={`ui-gad7-escala-punto${it.valor >= n ? ' is-on' : ''}`} />
                ))}
              </span>
              {it.opcion}
              <span className="ui-unit">({it.valor})</span>
            </span>
          </li>
        ))}
      </ol>
      <div className="ui-gad7-dificultad">
        <strong>Dificultad en su vida diaria:</strong> {textoDificultad(respuesta.dificultad, respuesta.puntaje)}
        <span className="ui-muted"> · No suma al puntaje · Versión {respuesta.version}</span>
      </div>
    </div>
  );
}

export default Gad7Paciente;
