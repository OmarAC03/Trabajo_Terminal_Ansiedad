import {
  Users, CalendarCheck, Activity, CalendarX, CalendarClock, History, Watch, FlaskConical, ChevronRight, Target,
} from 'lucide-react';
import { PageHeader, Card, KpiCard, Avatar, tonoIdentidad } from './ui/components';
import {
  haceTiempo, plural, AccionesEncabezado, AvisosPacientes, TablaPacientes,
} from './PacientesComun';
import {
  DIAS_ACTIVIDAD, resumenActividad, ordenarPorActividad, actividadReciente, conteoRecencia, conteoEstado,
} from './actividad';

// Dashboard de monitoreo. Solo presenta lo que App.js ya trae de
// GET /api/pacientes: no pide nada por su cuenta.
//
// Muestra ACTIVIDAD de medición (quién midió y cuándo) y, desde M3, el estado
// de la última sesión de cada paciente contra SU línea base (columna de la
// tabla + tarjeta "Estado de la última sesión"). El semáforo de umbrales fijos
// de las lecturas viejas se retiró porque no tiene fundamento
// (DESARROLLO_FUNDAMENTADO.md §2). El color organiza por tipo de dato (cada
// KPI su acento, cada paciente su color de identidad, la recencia en un solo
// azul); verde/ámbar/rojo solo para el estado. La lista NO se reordena por
// gravedad: sigue por actividad (decisión de M3 paso 4).

const MAX_ACTIVIDAD_RECIENTE = 5;

const fechaDeHoy = () => {
  const texto = new Date().toLocaleDateString('es-MX', {
    weekday: 'long', day: 'numeric', month: 'short', year: 'numeric',
  });
  return texto.charAt(0).toUpperCase() + texto.slice(1);
};

const porcentaje = (n, total) => (total === 0 ? 0 : Math.round((n / total) * 100));

function Dashboard({ pacientes, loading, perfil, errorAcceso, onSeleccionar, onActualizar }) {
  const r = resumenActividad(pacientes);

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader
        title="Dashboard de monitoreo"
        subtitle={`${fechaDeHoy()} · ${plural(r.total, 'paciente vinculado', 'pacientes vinculados')}`}
        actions={<AccionesEncabezado perfil={perfil} onActualizar={onActualizar} />}
      />

      <AvisosPacientes errorAcceso={errorAcceso} />

      {loading ? (
        <Card><div className="ui-empty">Cargando pacientes…</div></Card>
      ) : (
        <>
          <div className="ui-grid ui-grid-kpi">
            <KpiCard
              label="Pacientes vinculados"
              value={r.total}
              hint={`${r.conSesiones} con al menos una sesión`}
              icon={Users}
              tone="indigo"
              barra={porcentaje(r.conSesiones, r.total)}
            />
            <KpiCard
              label={`Midieron en ${DIAS_ACTIVIDAD} días`}
              value={r.midieron}
              hint={`${porcentaje(r.midieron, r.total)}% del grupo`}
              icon={CalendarCheck}
              tone="primary"
              barra={porcentaje(r.midieron, r.total)}
            />
            <KpiCard
              label={`Sesiones en ${DIAS_ACTIVIDAD} días`}
              value={r.sesiones}
              hint="De todo el grupo"
              icon={Activity}
              tone="cyan"
            />
            <KpiCard
              label={`Sin sesiones en ${DIAS_ACTIVIDAD} días`}
              value={r.sinMedir}
              hint={`${porcentaje(r.sinMedir, r.total)}% del grupo`}
              icon={CalendarX}
              tone="neutral"
              barra={porcentaje(r.sinMedir, r.total)}
            />
          </div>
          <p className="ui-caption">
            Los indicadores de arriba son actividad de medición. El estado (Normal / Elevados / Altos) es el de la
            última sesión de cada paciente comparada con su propia línea base; no es un diagnóstico.
          </p>

          <div className="ui-dashboard-cols">
            <TablaPacientes
              pacientes={ordenarPorActividad(pacientes)}
              onSeleccionar={onSeleccionar}
              subtitle="Última sesión más reciente primero · se actualiza cada 15 s"
              vacio="Todavía no tienes pacientes vinculados. Comparte tu código para que se vinculen desde la app."
            />
            <div className="ui-stack">
              <EstadoUltimaSesion pacientes={pacientes} total={r.total} />
              <ActividadReciente pacientes={pacientes} onSeleccionar={onSeleccionar} />
              <UltimaSesionGrupo pacientes={pacientes} total={r.total} />
            </div>
          </div>
        </>
      )}
    </div>
  );
}

// Los pacientes que midieron más recientemente. No es un sistema de alertas:
// solo dice quién midió y cuándo.
function ActividadReciente({ pacientes, onSeleccionar }) {
  const lista = actividadReciente(pacientes, MAX_ACTIVIDAD_RECIENTE);

  return (
    <Card
      title="Actividad reciente"
      icon={History}
      iconTone="primary"
      subtitle="Las sesiones de medición más recientes del grupo"
    >
      {lista.length === 0 ? (
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>
          Ningún paciente ha hecho una sesión de medición todavía.
        </div>
      ) : (
        <div className="ui-timeline">
          {lista.map((p) => {
            const simulacion = p.ultima_sesion_origen === 'simulacion';
            const Origen = simulacion ? FlaskConical : Watch;
            return (
              <button key={p.id} type="button" className="ui-timeline-item" onClick={() => onSeleccionar(p)}>
                <Avatar nombre={p.nombre} size={36} tone={tonoIdentidad(p.id)} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="ui-list-title">{p.nombre}</div>
                  <div className="ui-timeline-meta">
                    <Origen size={13} />
                    {haceTiempo(p.ultima_sesion)} · {simulacion ? 'Simulación' : 'Sensor'}
                  </div>
                </div>
                <span className="ui-row-go" aria-hidden="true">
                  <ChevronRight size={16} />
                </span>
              </button>
            );
          })}
        </div>
      )}
    </Card>
  );
}

// Cuántos pacientes hay en cada estado según su última sesión, contra la
// línea base de cada uno. Misma forma que "Última sesión del grupo".
function EstadoUltimaSesion({ pacientes, total }) {
  const grupos = conteoEstado(pacientes);
  return (
    <Card
      title="Estado de la última sesión"
      icon={Target}
      iconTone="cyan"
      subtitle="Contra la línea base de cada paciente"
    >
      {total === 0 ? (
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>Sin pacientes vinculados.</div>
      ) : (
        <>
          <div
            className="ui-stackbar"
            role="img"
            aria-label={grupos.map((g) => `${g.texto}: ${g.valor}`).join(', ')}
          >
            {grupos
              .filter((g) => g.valor > 0)
              .map((g) => (
                <span key={g.clave} className={`tone-${g.clave}`} style={{ flex: g.valor }} />
              ))}
          </div>
          <div className="ui-legend">
            {grupos.map((g) => (
              <div key={g.clave} className="ui-legend-row">
                <span className={`ui-legend-dot tone-${g.clave}`} />
                {g.texto}
                <span className="ui-legend-value">
                  {g.valor}
                  <span className="ui-legend-pct">{porcentaje(g.valor, total)}%</span>
                </span>
              </div>
            ))}
          </div>
          <p className="ui-muted" style={{ fontSize: 'var(--text-sm)', margin: '12px 0 0' }}>
            Sin estado: calibrando su línea base, señal bajo la calidad mínima o sin sesiones.
          </p>
        </>
      )}
    </Card>
  );
}

// Cuándo fue la última sesión de cada paciente (cada uno cuenta una vez).
// Reemplaza a la dona del semáforo: agrupa por fecha, no por un estado, en un
// solo azul que se aclara con el tiempo.
function UltimaSesionGrupo({ pacientes, total }) {
  const grupos = conteoRecencia(pacientes);
  return (
    <Card
      title="Última sesión del grupo"
      icon={CalendarClock}
      iconTone="primary"
      subtitle="Cada paciente cuenta una vez, según su última sesión"
    >
      {total === 0 ? (
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>Sin pacientes vinculados.</div>
      ) : (
        <>
          <div
            className="ui-stackbar"
            role="img"
            aria-label={grupos.map((g) => `${g.texto}: ${g.valor}`).join(', ')}
          >
            {grupos
              .filter((g) => g.valor > 0)
              .map((g) => (
                <span key={g.clave} className={`rec-${g.clave}`} style={{ flex: g.valor }} />
              ))}
          </div>
          <div className="ui-legend">
            {grupos.map((g) => (
              <div key={g.clave} className="ui-legend-row">
                <span className={`ui-legend-dot rec-${g.clave}`} />
                {g.texto}
                <span className="ui-legend-value">
                  {g.valor}
                  <span className="ui-legend-pct">{porcentaje(g.valor, total)}%</span>
                </span>
              </div>
            ))}
          </div>
        </>
      )}
    </Card>
  );
}

export default Dashboard;
