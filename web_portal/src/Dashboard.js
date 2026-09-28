import { ResponsiveContainer, PieChart, Pie, Cell, Tooltip } from 'recharts';
import {
  RefreshCw, Info, Users, CircleCheck, TriangleAlert, CircleAlert, HeartPulse, ChartPie, ChevronRight,
} from 'lucide-react';
import { PageHeader, Card, KpiCard, Button, Badge, Avatar, Alert, Disclaimer } from './ui/components';
import { getStatusColor, getStatusLabel, getStatusTone, getStatusOrden } from './semaforo';
import CodigoVinculacion from './CodigoVinculacion';

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

const haceTiempo = (fecha) => {
  const minutos = Math.floor((Date.now() - new Date(fecha).getTime()) / 60000);
  if (minutos < 1) return 'hace un momento';
  if (minutos < 60) return `hace ${minutos} min`;
  const horas = Math.floor(minutos / 60);
  if (horas < 24) return `hace ${horas} h`;
  const dias = Math.floor(horas / 24);
  if (dias < 7) return dias === 1 ? 'hace 1 día' : `hace ${dias} días`;
  return new Date(fecha).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' });
};

const porcentaje = (n, total) => (total === 0 ? 0 : Math.round((n / total) * 100));

const plural = (n, singular, pluralTexto) => `${n} ${n === 1 ? singular : pluralTexto}`;

// Altos → Elevados → Normal → Sin lecturas; dentro de cada estado, la
// lectura más reciente primero.
const ordenarPorEstado = (pacientes) =>
  [...pacientes].sort(
    (a, b) =>
      getStatusOrden(a.ultimo_estado) - getStatusOrden(b.ultimo_estado) ||
      new Date(b.ultima_lectura || 0) - new Date(a.ultima_lectura || 0) ||
      a.nombre.localeCompare(b.nombre)
  );

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
        actions={
          <>
            <CodigoVinculacion codigo={perfil?.codigo_vinculacion || null} />
            <Button icon={RefreshCw} onClick={onActualizar}>Actualizar</Button>
          </>
        }
      />

      <div className="ui-stack" style={{ gap: 12, marginBottom: 20 }}>
        {errorAcceso && <Alert tone="altos" icon={CircleAlert}>{errorAcceso}</Alert>}
        <Disclaimer icon={Info}>
          Este sistema monitorea parámetros fisiológicos (frecuencia cardiaca, SpO2 y HRV) asociados a la
          ansiedad como apoyo al especialista. Los datos fisiológicos son de apoyo: la interpretación y el
          diagnóstico corresponden al profesional de salud.
        </Disclaimer>
      </div>

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
            <TablaPacientes pacientes={pacientes} onSeleccionar={onSeleccionar} />
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

function TablaPacientes({ pacientes, onSeleccionar }) {
  return (
    <Card
      className="ui-card-flush"
      title="Pacientes"
      icon={Users}
      subtitle="Ordenados por indicadores de la última lectura · se actualiza cada 15 s"
    >
      {pacientes.length === 0 ? (
        <div className="ui-empty">
          Todavía no tienes pacientes vinculados. Comparte tu código para que se vinculen desde la app.
        </div>
      ) : (
        <div className="ui-table-wrap">
          <table className="ui-table">
            <thead>
              <tr>
                <th>Paciente</th>
                <th>BPM</th>
                <th>SpO2</th>
                <th>HRV</th>
                <th>Estado</th>
                <th>Última lectura</th>
                <th><span className="sr-only">Acción</span></th>
              </tr>
            </thead>
            <tbody>
              {ordenarPorEstado(pacientes).map((p) => (
                <tr key={p.id} className="ui-table-row-link" onClick={() => onSeleccionar(p)}>
                  <td>
                    <div className="ui-person">
                      <Avatar nombre={p.nombre} size={38} tone={getStatusTone(p.ultimo_estado)} />
                      <div>
                        <div className="ui-person-name">{p.nombre}</div>
                        <div className="ui-person-sub">{p.email}</div>
                      </div>
                    </div>
                  </td>
                  <td><Valor valor={p.ultimo_bpm} /></td>
                  <td><Valor valor={p.ultimo_spo2} unidad="%" /></td>
                  <td><Valor valor={p.ultimo_hrv} unidad="ms" /></td>
                  <td>
                    <Badge tone={getStatusTone(p.ultimo_estado)}>{getStatusLabel(p.ultimo_estado)}</Badge>
                  </td>
                  <td className="ui-muted">{p.ultima_lectura ? haceTiempo(p.ultima_lectura) : '—'}</td>
                  <td style={{ textAlign: 'right' }}>
                    <Button
                      variant="soft"
                      size="sm"
                      onClick={(e) => {
                        e.stopPropagation(); // la fila ya abre el detalle
                        onSeleccionar(p);
                      }}
                    >
                      Ver detalle
                    </Button>
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

function Valor({ valor, unidad }) {
  if (valor == null) return <span className="ui-muted">—</span>;
  return (
    <span className="ui-num">
      {valor}
      {unidad && <span className="ui-unit">{unidad}</span>}
    </span>
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
