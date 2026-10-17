import { ArrowLeft, Info, Mail, RefreshCw, CircleAlert } from 'lucide-react';
import { Card, Button, Avatar, Alert, Disclaimer, tonoIdentidad } from './ui/components';
import { haceTiempo, BadgeEstado } from './PacientesComun';
import { evaluacionUltimaSesion } from './semaforo';
import ChatPaciente from './ChatPaciente';
import EjerciciosPaciente from './EjerciciosPaciente';
import SesionesPaciente from './SesionesPaciente';

// Detalle de un paciente (Portal Web Fase 2a; sesiones desde la Fase M1).
// Muestra indicadores fisiológicos de apoyo — NO un diagnóstico
// (MARCO_ALCANCE_Y_LENGUAJE.md). Solo sesiones de medición: la vista de
// lecturas sueltas del método previo se retiró (la tabla
// `lecturas_biometricas` y GET /api/lecturas siguen en el backend).
function PacienteDetalle({ paciente, onVolver, recarga, onActualizar, errorAcceso }) {
  return (
    <div className="ui-page ui-page-wide">
      <div style={{ marginBottom: 16 }}>
        <Button variant="secondary" size="sm" icon={ArrowLeft} onClick={onVolver}>Volver</Button>
      </div>

      <Card>
        <div className="ui-detail-header-row">
          <div className="ui-person">
            <Avatar nombre={paciente.nombre} size={56} tone={tonoIdentidad(paciente.id)} />
            <div style={{ minWidth: 0 }}>
              <h1 className="ui-page-title" style={{ fontSize: 'var(--text-xl)' }}>{paciente.nombre}</h1>
              <div className="ui-detail-meta">
                <span className="ui-detail-email"><Mail size={14} /> {paciente.email}</span>
                {/* Actividad + estado de la última sesión contra su línea base (M3). */}
                <span className="ui-muted">
                  {paciente.ultima_sesion ? `Última sesión ${haceTiempo(paciente.ultima_sesion)}` : 'Aún sin sesiones de medición'}
                </span>
                {paciente.ultima_sesion && <BadgeEstado evaluacion={evaluacionUltimaSesion(paciente)} />}
              </div>
            </div>
          </div>
          <div className="ui-detail-actions">
            <Button icon={RefreshCw} onClick={onActualizar}>Actualizar</Button>
          </div>
        </div>
      </Card>

      <div className="ui-stack" style={{ gap: 12, margin: '20px 0' }}>
        {errorAcceso && <Alert tone="altos" icon={CircleAlert}>{errorAcceso}</Alert>}
        <Disclaimer icon={Info}>
          Datos fisiológicos de apoyo. La interpretación y el diagnóstico corresponden al profesional de salud.
        </Disclaimer>
      </div>

      {/* Dos columnas en pantalla ancha: datos + ejercicios | chat. Es solo
          CSS: el chat queda montado siempre en el mismo lugar del árbol, así
          que abrir una sesión o cambiar el ancho de la ventana no reconecta
          el socket. */}
      <div className="ui-detail-cols">
        <div>
          <SesionesPaciente paciente={paciente} recarga={recarga} />
          <EjerciciosPaciente paciente={paciente} recarga={recarga} />
        </div>

        <div className="ui-detail-side">
          <ChatPaciente paciente={paciente} />
        </div>
      </div>
    </div>
  );
}

export default PacienteDetalle;
