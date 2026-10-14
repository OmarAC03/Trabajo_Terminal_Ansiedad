import { Users, CalendarCheck, Activity, CalendarX, History, Clock, ChevronRight } from 'lucide-react';
import { PageHeader, Card, KpiCard } from './ui/components';
import {
  haceTiempo, plural, AccionesEncabezado, AvisosPacientes, TablaPacientes,
} from './PacientesComun';
import {
  DIAS_ACTIVIDAD, resumenActividad, ordenarPorActividad, actividadReciente, conteoRecencia,
} from './actividad';

// Dashboard de monitoreo. Solo presenta lo que App.js ya trae de
// GET /api/pacientes: no pide nada por su cuenta.
//
// Muestra ACTIVIDAD de medición (quién midió y cuándo), no un estado: el
// semáforo de umbrales fijos de las lecturas viejas se retiró porque no tiene
// fundamento (DESARROLLO_FUNDAMENTADO.md §2). Todo va en tono primario o
// neutro, sin verde/ámbar/rojo. Cuando M3 traiga el estado contra la línea
// base de cada paciente, se agregan sus conteos y su columna encima de esto.

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
              tone="primary"
            />
            <KpiCard
              label={`Midieron en ${DIAS_ACTIVIDAD} días`}
              value={r.midieron}
              hint={`${porcentaje(r.midieron, r.total)}% del grupo`}
              icon={CalendarCheck}
              tone="primary"
            />
            <KpiCard
              label={`Sesiones en ${DIAS_ACTIVIDAD} días`}
              value={r.sesiones}
              hint="De todo el grupo"
              icon={Activity}
              tone="primary"
            />
            <KpiCard
              label={`Sin sesiones en ${DIAS_ACTIVIDAD} días`}
              value={r.sinMedir}
              hint={`${porcentaje(r.sinMedir, r.total)}% del grupo`}
              icon={CalendarX}
              tone="neutral"
            />
          </div>
          <p className="ui-caption">
            Actividad de medición, no un estado. La clasificación de los indicadores (Normal / Elevados / Altos)
            llegará con la línea base de cada paciente.
          </p>

          <div className="ui-dashboard-cols">
            <TablaPacientes
              pacientes={ordenarPorActividad(pacientes)}
              onSeleccionar={onSeleccionar}
              subtitle="Última sesión más reciente primero · se actualiza cada 15 s"
              vacio="Todavía no tienes pacientes vinculados. Comparte tu código para que se vinculen desde la app."
            />
            <div className="ui-stack">
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
    <Card title="Actividad reciente" icon={History} subtitle="Las sesiones de medición más recientes del grupo">
      {lista.length === 0 ? (
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>
          Ningún paciente ha hecho una sesión de medición todavía.
        </div>
      ) : (
        lista.map((p) => (
          <button key={p.id} type="button" className="ui-list-item tone-primary" onClick={() => onSeleccionar(p)}>
            <Clock size={18} style={{ color: 'var(--color-primary)' }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="ui-list-title">{p.nombre}</div>
              <div className="ui-list-time">
                {haceTiempo(p.ultima_sesion)}
                {p.ultima_sesion_origen === 'simulacion' && <> · Simulación</>}
              </div>
            </div>
            <ChevronRight size={16} style={{ color: 'var(--color-text-muted)' }} />
          </button>
        ))
      )}
    </Card>
  );
}

// Cuándo fue la última sesión de cada paciente (cada uno cuenta una vez).
// Reemplaza a la dona del semáforo: agrupa por fecha, no por un estado.
function UltimaSesionGrupo({ pacientes, total }) {
  return (
    <Card title="Última sesión del grupo" icon={CalendarCheck} subtitle="Cada paciente cuenta una vez, según su última sesión">
      {total === 0 ? (
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>Sin pacientes vinculados.</div>
      ) : (
        <div className="ui-legend" style={{ marginTop: 0 }}>
          {conteoRecencia(pacientes).map((g) => (
            <div key={g.clave} className={`ui-legend-row tone-${g.clave === 'nunca' ? 'neutral' : 'primary'}`}>
              <span className="ui-legend-dot" />
              {g.texto}
              <span className="ui-legend-value">
                {g.valor} ({porcentaje(g.valor, total)}%)
              </span>
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}

export default Dashboard;
