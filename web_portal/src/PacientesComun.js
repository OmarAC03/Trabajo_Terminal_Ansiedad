import { RefreshCw, Info, Users, CircleAlert, ChevronRight } from 'lucide-react';
import { Card, Button, Badge, Avatar, Alert, Disclaimer, tonoIdentidad } from './ui/components';
import CodigoVinculacion from './CodigoVinculacion';
import { grupoRecencia } from './actividad';

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
                <th>Sesiones (7 días)</th>
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
                    {Number(p.sesiones_7d) > 0 ? (
                      <span className="ui-pill tone-cyan">{Number(p.sesiones_7d)}</span>
                    ) : (
                      <span className="ui-num ui-muted">0</span>
                    )}
                  </td>
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
