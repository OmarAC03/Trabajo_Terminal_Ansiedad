import { RefreshCw, Info, Users, CircleAlert, ChevronRight, ArrowUp, Flag } from 'lucide-react';
import { Card, Button, Badge, Avatar, Alert, Disclaimer, tonoIdentidad } from './ui/components';
import CodigoVinculacion from './CodigoVinculacion';
import { grupoRecencia } from './actividad';
import { etiquetaEvaluacion, evaluacionUltimaSesion, textoEtapa } from './semaforo';
import { textoSeveridad, resumenTabla, TONO_SEVERIDAD, TONO_GAD7, CORTE_VALORAR } from './gad7';

// Piezas compartidas por el Dashboard y la sección Pacientes (Fase A). Solo
// presentan lo que App.js ya trae de GET /api/pacientes.

export const haceTiempo = (fecha) => {
  const minutos = Math.floor((Date.now() - new Date(fecha).getTime()) / 60000);
  if (minutos < 1) return 'hace un momento';
  if (minutos < 60) return `hace ${minutos} min`;
  const horas = Math.floor(minutos / 60);
  if (horas < 24) return `hace ${horas} h`;
  const dias = Math.floor(horas / 24);
  if (dias < 7) return dias === 1 ? 'hace 1 día' : `hace ${dias} días`;
  return new Date(fecha).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' });
};

// "mar 14 oct, 10:12": la fecha exacta debajo del tiempo relativo.
export const fechaCorta = (fecha) =>
  new Date(fecha).toLocaleString('es-MX', {
    weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
  });

export const plural =(n, singular, pluralTexto) => `${n} ${n === 1 ? singular : pluralTexto}`;

// "Tu código" + "Actualizar" en las acciones del encabezado de página.
export function AccionesEncabezado({ perfil, onActualizar }) {
  return (
    <>
      <CodigoVinculacion codigo={perfil?.codigo_vinculacion || null} />
      <Button icon={RefreshCw} onClick={onActualizar}>Actualizar</Button>
    </>
  );
}

// Estado de una sesión contra la línea base del paciente (Fase M3, solo
// especialista): Normal / Elevados / Altos con su color, o en gris el motivo
// por el que no hay estado (Calibrando / Calidad insuficiente). `conEtapa`
// pone debajo la etapa de la base; "FC ↑" si la FC quedó por encima de lo
// habitual (solo acompaña, no cambia el estado).
export function BadgeEstado({ evaluacion, conEtapa = false }) {
  const e = etiquetaEvaluacion(evaluacion);
  return (
    <div>
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
        <Badge tone={e.tono} dot={e.conEstado}>{e.texto}</Badge>
        {evaluacion?.fc_por_encima && (
          <span className="ui-muted" title="FC por encima de su rango habitual (solo acompaña, no cambia el estado)"
            style={{ display: 'inline-flex', alignItems: 'center', fontSize: 'var(--text-xs)', fontWeight: 600 }}>
            FC<ArrowUp size={12} />
          </span>
        )}
      </span>
      {conEtapa && evaluacion?.etapa && e.texto !== textoEtapa(evaluacion.etapa) && (
        <div className="ui-when-abs">{textoEtapa(evaluacion.etapa)}</div>
      )}
    </div>
  );
}

// Severidad del GAD-7 (M5a): Mínima / Leve / Moderada / Grave, las cuatro en
// gris. Es un instrumento de tamizaje, no el semáforo de los indicadores.
export function BadgeSeveridad({ severidad }) {
  return <Badge tone={TONO_SEVERIDAD} dot={false}>{textoSeveridad(severidad)}</Badge>;
}

// Marca del GAD-7 ≥ 10 en violeta: llama la atención sin parecer "Altos".
export function BadgeValorar() {
  return (
    <span title={`Puntaje GAD-7 de ${CORTE_VALORAR} o más: sugiere valorarlo clínicamente`}>
      <Badge tone={TONO_GAD7} dot={false}>
        <Flag size={12} />
        Valorar (≥{CORTE_VALORAR})
      </Badge>
    </span>
  );
}

// Celda "GAD-7": último puntaje y severidad, la marca de valorar y, debajo,
// cuándo respondió y si ya le toca el siguiente. "—" si nunca respondió.
function CeldaGad7({ paciente }) {
  const g = resumenTabla(paciente);
  if (!g) return <span className="ui-muted">—</span>;
  return (
    <div>
      <span className="ui-gad7-celda">
        <span className="ui-num">{g.puntaje}</span>
        <span className="ui-muted">· {g.severidad}</span>
        {g.valorar && <BadgeValorar />}
      </span>
      <div className="ui-gad7-sub">{haceTiempo(g.fecha)}{g.toca && ' · le toca responder'}</div>
    </div>
  );
}

// Aviso de 403 (si lo hay) + disclaimer de alcance (sección 3 del marco).
export function AvisosPacientes({ errorAcceso }) {
  return (
    <div className="ui-stack" style={{ gap: 12, marginBottom: 20 }}>
      {errorAcceso && <Alert tone="altos" icon={CircleAlert}>{errorAcceso}</Alert>}
      <Disclaimer icon={Info}>
        Este sistema monitorea parámetros fisiológicos (frecuencia cardiaca, SpO2 y HRV) asociados a la
        ansiedad como apoyo al especialista. Los datos fisiológicos son de apoyo: la interpretación y el
        diagnóstico corresponden al profesional de salud.
      </Disclaimer>
    </div>
  );
}

// Tabla de pacientes con su actividad de medición (cuándo fue su última
// sesión y cuántas hizo en 7 días) y, desde M3, el estado de esa última
// sesión contra la línea base de CADA paciente. Sin BPM/SpO2/HRV: un
// valor absoluto de varios pacientes en una lista invita a compararlos entre
// sí, y eso es justo lo que DESARROLLO_FUNDAMENTADO.md §2 descarta. Los
// valores siguen en el detalle de cada paciente. Desde M5a, también el último
// GAD-7 (sin reordenar por su puntaje).
//
// Muestra `pacientes` en el orden recibido; `vacio` es el texto cuando la
// lista llega vacía y `filtros` va entre el encabezado de la tarjeta y la
// tabla (búsqueda de la sección Pacientes).
export function TablaPacientes({ pacientes, onSeleccionar, subtitle, vacio, filtros }) {
  return (
    <Card className="ui-card-flush" title="Pacientes" icon={Users} iconTone="indigo" subtitle={subtitle}>
      {filtros}
      {pacientes.length === 0 ? (
        <div className="ui-empty">{vacio}</div>
      ) : (
        <div className="ui-table-wrap">
          <table className="ui-table">
            <thead>
              <tr>
                <th>Paciente</th>
                <th>Última sesión</th>
                <th>Estado (última sesión)</th>
                <th>Sesiones (7 días)</th>
                <th>GAD-7</th>
                <th><span className="sr-only">Acción</span></th>
              </tr>
            </thead>
            <tbody>
              {pacientes.map((p) => (
                <tr key={p.id} className="ui-table-row-link" onClick={() => onSeleccionar(p)}>
                  <td>
                    <div className="ui-person">
                      <Avatar nombre={p.nombre} size={38} tone={tonoIdentidad(p.id)} />
                      <div>
                        <div className="ui-person-name">{p.nombre}</div>
                        <div className="ui-person-sub">{p.email}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    {p.ultima_sesion ? (
                      <>
                        <span className="ui-when-rel">
                          <span className={`ui-rec-dot rec-${grupoRecencia(p)}`} />
                          {haceTiempo(p.ultima_sesion)}
                          {p.ultima_sesion_origen === 'simulacion' && <Badge tone="neutral">Simulación</Badge>}
                        </span>
                        <div className="ui-when-abs">{fechaCorta(p.ultima_sesion)}</div>
                      </>
                    ) : (
                      <span className="ui-when-rel ui-muted" style={{ fontWeight: 500 }}>
                        <span className="ui-rec-dot rec-nunca" />
                        Sin sesiones
                      </span>
                    )}
                  </td>
                  <td>
                    {p.ultima_sesion
                      ? <BadgeEstado evaluacion={evaluacionUltimaSesion(p)} conEtapa />
                      : <span className="ui-muted">—</span>}
                  </td>
                  <td>
                    {Number(p.sesiones_7d) > 0 ? (
                      <span className="ui-pill tone-cyan">{Number(p.sesiones_7d)}</span>
                    ) : (
                      <span className="ui-num ui-muted">0</span>
                    )}
                  </td>
                  <td><CeldaGad7 paciente={p} /></td>
                  <td style={{ textAlign: 'right', width: 1 }}>
                    <button
                      type="button"
                      className="ui-row-go"
                      aria-label={`Ver detalle de ${p.nombre}`}
                      onClick={(e) => {
                        e.stopPropagation(); // la fila ya abre el detalle
                        onSeleccionar(p);
                      }}
                    >
                      <ChevronRight size={18} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
