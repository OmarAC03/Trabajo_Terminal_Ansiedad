import { RefreshCw, Info, Users, CircleAlert } from 'lucide-react';
import { Card, Button, Badge, Avatar, Alert, Disclaimer } from './ui/components';
import { getStatusLabel, getStatusTone, getStatusOrden } from './semaforo';
import CodigoVinculacion from './CodigoVinculacion';

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

export const plural = (n, singular, pluralTexto) => `${n} ${n === 1 ? singular : pluralTexto}`;

// Altos → Elevados → Normal → Sin lecturas; dentro de cada estado, la
// lectura más reciente primero.
export const ordenarPorEstado = (pacientes) =>
  [...pacientes].sort(
    (a, b) =>
      getStatusOrden(a.ultimo_estado) - getStatusOrden(b.ultimo_estado) ||
      new Date(b.ultima_lectura || 0) - new Date(a.ultima_lectura || 0) ||
      a.nombre.localeCompare(b.nombre)
  );

// "Tu código" + "Actualizar" en las acciones del encabezado de página.
export function AccionesEncabezado({ perfil, onActualizar }) {
  return (
    <>
      <CodigoVinculacion codigo={perfil?.codigo_vinculacion || null} />
      <Button icon={RefreshCw} onClick={onActualizar}>Actualizar</Button>
    </>
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

// Tabla de pacientes con su última lectura. Muestra `pacientes` en el orden
// recibido; `vacio` es el texto cuando la lista llega vacía y `filtros` va
// entre el encabezado de la tarjeta y la tabla (búsqueda de la sección
// Pacientes).
export function TablaPacientes({ pacientes, onSeleccionar, subtitle, vacio, filtros }) {
  return (
    <Card className="ui-card-flush" title="Pacientes" icon={Users} subtitle={subtitle}>
      {filtros}
      {pacientes.length === 0 ? (
        <div className="ui-empty">{vacio}</div>
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
              {pacientes.map((p) => (
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
