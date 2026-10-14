import { RefreshCw, Info, Users, CircleAlert } from 'lucide-react';
import { Card, Button, Badge, Avatar, Alert, Disclaimer } from './ui/components';
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

// Tabla de pacientes con su actividad de medición: cuándo fue su última
// sesión y cuántas hizo en 7 días. Sin estado (el semáforo de umbrales fijos
// se retiró; la columna vuelve con M3 y la línea base) y sin BPM/SpO2/HRV: un
// valor absoluto de varios pacientes en una lista invita a compararlos entre
// sí, y eso es justo lo que DESARROLLO_FUNDAMENTADO.md §2 descarta. Los
// valores siguen en el detalle de cada paciente.
//
// Muestra `pacientes` en el orden recibido; `vacio` es el texto cuando la
// lista llega vacía y `filtros` va entre el encabezado de la tarjeta y la
// tabla (búsqueda de la sección Pacientes).
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
                <th>Última sesión</th>
                <th>Sesiones (7 días)</th>
                <th><span className="sr-only">Acción</span></th>
              </tr>
            </thead>
            <tbody>
              {pacientes.map((p) => (
                <tr key={p.id} className="ui-table-row-link" onClick={() => onSeleccionar(p)}>
                  <td>
                    <div className="ui-person">
                      <Avatar nombre={p.nombre} size={38} tone="neutral" />
                      <div>
                        <div className="ui-person-name">{p.nombre}</div>
                        <div className="ui-person-sub">{p.email}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    {p.ultima_sesion ? (
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                        {haceTiempo(p.ultima_sesion)}
                        {p.ultima_sesion_origen === 'simulacion' && <Badge tone="neutral">Simulación</Badge>}
                      </span>
                    ) : (
                      <span className="ui-muted">Sin sesiones</span>
                    )}
                  </td>
                  <td><span className="ui-num">{Number(p.sesiones_7d) || 0}</span></td>
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
