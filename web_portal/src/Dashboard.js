import { ResponsiveContainer, PieChart, Pie, Cell, Tooltip } from 'recharts';
import { Users, CircleCheck, TriangleAlert, CircleAlert, HeartPulse, ChartPie, ChevronRight } from 'lucide-react';
import { PageHeader, Card, KpiCard } from './ui/components';
import { getStatusColor, getStatusLabel, getStatusTone } from './semaforo';
import {
  haceTiempo, plural, ordenarPorEstado, AccionesEncabezado, AvisosPacientes, TablaPacientes,
} from './PacientesComun';

// Dashboard de monitoreo (Fase A). Solo presenta lo que App.js ya trae de
// GET /api/pacientes (una fila por paciente vinculado, con su última lectura):
// no pide nada por su cuenta. Los conteos Normal/Elevados/Altos se basan en la
// ÚLTIMA lectura de cada paciente, que puede ser antigua; por eso la tabla
// muestra "hace X". Indicadores fisiológicos de apoyo, nunca diagnóstico
// (MARCO_ALCANCE_Y_LENGUAJE.md).

// Estados en el orden en que se muestran (null = sin lecturas).
const ESTADOS = ['Baja', 'Moderada', 'Alta', null];

const MAX_LECTURAS_ALTAS = 5;

const fechaDeHoy = () => {
  const texto = new Date().toLocaleDateString('es-MX', {
    weekday: 'long', day: 'numeric', month: 'short', year: 'numeric',
  });
  return texto.charAt(0).toUpperCase() + texto.slice(1);
};

const porcentaje = (n, total) => (total === 0 ? 0 : Math.round((n / total) * 100));

// "BPM 91 · HRV 24 ms · SpO2 97%" con los valores que existan.
const resumenLectura = (p) =>
  [
    p.ultimo_bpm != null && `BPM ${p.ultimo_bpm}`,
    p.ultimo_hrv != null && `HRV ${p.ultimo_hrv} ms`,
    p.ultimo_spo2 != null && `SpO2 ${p.ultimo_spo2}%`,
  ]
    .filter(Boolean)
    .join(' · ');

function Dashboard({ pacientes, loading, perfil, errorAcceso, onSeleccionar, onActualizar }) {
  const total = pacientes.length;
  const conteo = (estado) => pacientes.filter((p) => (p.ultimo_estado || null) === estado).length;
  const normal = conteo('Baja');
  const elevados = conteo('Moderada');
  const altos = conteo('Alta');
  const conLecturas = pacientes.filter((p) => p.ultima_lectura).length;

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader
        title="Dashboard de monitoreo"
        subtitle={`${fechaDeHoy()} · ${plural(total, 'paciente vinculado', 'pacientes vinculados')}`}
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
              value={total}
              hint={`${conLecturas} con lecturas registradas`}
              icon={Users}
              tone="primary"
            />
            <KpiCard
              label="Normal"
              value={normal}
              hint={`${porcentaje(normal, total)}% del grupo`}
              hintTone="normal"
              icon={CircleCheck}
              tone="normal"
            />
            <KpiCard
              label="Elevados"
              value={elevados}
              hint={`${porcentaje(elevados, total)}% del grupo`}
              hintTone="elevados"
              icon={TriangleAlert}
              tone="elevados"
            />
            <KpiCard
              label="Altos"
              value={altos}
              hint={`${porcentaje(altos, total)}% del grupo`}
              hintTone="altos"
              icon={CircleAlert}
              tone="altos"
            />
          </div>
          <p className="ui-caption">Conteos según los indicadores fisiológicos de la última lectura de cada paciente.</p>

          <div className="ui-dashboard-cols">
            <TablaPacientes
              pacientes={ordenarPorEstado(pacientes)}
              onSeleccionar={onSeleccionar}
              subtitle="Ordenados por indicadores de la última lectura · se actualiza cada 15 s"
              vacio="Todavía no tienes pacientes vinculados. Comparte tu código para que se vinculen desde la app."
            />
            <div className="ui-stack">
              <LecturasAltas pacientes={pacientes} onSeleccionar={onSeleccionar} />
              <Distribucion pacientes={pacientes} total={total} />
            </div>
          </div>
        </>
      )}
    </div>
  );
}

// Pacientes cuya última lectura fue Altos, la más reciente primero. No es un
// sistema de alertas (no se activan ni se "atienden"): es la misma última
// lectura de la tabla, filtrada.
function LecturasAltas({ pacientes, onSeleccionar }) {
  const lista = pacientes
    .filter((p) => p.ultimo_estado === 'Alta')
    .sort((a, b) => new Date(b.ultima_lectura) - new Date(a.ultima_lectura))
    .slice(0, MAX_LECTURAS_ALTAS);

  return (
    <Card title="Últimas lecturas altas" icon={HeartPulse} subtitle="Pacientes cuya última lectura fue Altos">
      {lista.length === 0 ? (
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>
          Ningún paciente tiene su última lectura en Altos.
        </div>
      ) : (
        lista.map((p) => (
          <button key={p.id} type="button" className="ui-list-item tone-altos" onClick={() => onSeleccionar(p)}>
            <CircleAlert size={18} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="ui-list-title">{p.nombre}</div>
              {resumenLectura(p) && <div className="ui-list-sub">{resumenLectura(p)}</div>}
              <div className="ui-list-time">{haceTiempo(p.ultima_lectura)}</div>
            </div>
            <ChevronRight size={16} style={{ color: 'var(--color-text-muted)' }} />
          </button>
        ))
      )}
    </Card>
  );
}

function Distribucion({ pacientes, total }) {
  const datos = ESTADOS.map((estado) => ({
    estado,
    nombre: getStatusLabel(estado),
    valor: pacientes.filter((p) => (p.ultimo_estado || null) === estado).length,
  }));

  return (
    <Card title="Distribución del grupo" icon={ChartPie} subtitle="Según la última lectura de cada paciente">
      {total === 0 ? (
        <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>Sin pacientes vinculados.</div>
      ) : (
        <>
          <div className="ui-donut">
            <ResponsiveContainer>
              <PieChart>
                <Pie
                  data={datos.filter((d) => d.valor > 0)}
                  dataKey="valor"
                  nameKey="nombre"
                  innerRadius={62}
                  outerRadius={86}
                  startAngle={90}
                  endAngle={-270}
                  paddingAngle={2}
                  stroke="none"
                  isAnimationActive={false}
                >
                  {datos
                    .filter((d) => d.valor > 0)
                    .map((d) => (
                      <Cell key={d.nombre} fill={getStatusColor(d.estado)} />
                    ))}
                </Pie>
                <Tooltip formatter={(valor) => plural(valor, 'paciente', 'pacientes')} />
              </PieChart>
            </ResponsiveContainer>
            <div className="ui-donut-center">
              <span className="ui-donut-total">{total}</span>
              <span className="ui-muted" style={{ fontSize: 'var(--text-xs)' }}>total</span>
            </div>
          </div>
          <div className="ui-legend">
            {datos.map((d) => (
              <div key={d.nombre} className={`ui-legend-row tone-${getStatusTone(d.estado)}`}>
                <span className="ui-legend-dot" />
                {d.nombre}
                <span className="ui-legend-value">
                  {d.valor} ({porcentaje(d.valor, total)}%)
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
