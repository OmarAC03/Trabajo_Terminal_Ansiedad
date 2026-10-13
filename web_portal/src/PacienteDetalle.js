import { ArrowLeft, Info, Mail, RefreshCw, CircleAlert } from 'lucide-react';
import { getStatusLabel, getStatusTone } from './semaforo';
import { Card, Button, Badge, Avatar, Alert, Disclaimer } from './ui/components';
import { haceTiempo } from './PacientesComun';
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
            <Avatar nombre={paciente.nombre} size={56} tone={getStatusTone(paciente.ultimo_estado)} />
            <div style={{ minWidth: 0 }}>
              <h1 className="ui-page-title" style={{ fontSize: 'var(--text-xl)' }}>{paciente.nombre}</h1>
              <div className="ui-detail-meta">
                <span className="ui-detail-email"><Mail size={14} /> {paciente.email}</span>
                <Badge tone={getStatusTone(paciente.ultimo_estado)}>{getStatusLabel(paciente.ultimo_estado)}</Badge>
                <span className="ui-muted">
                  {paciente.ultima_lectura ? `Última lectura ${haceTiempo(paciente.ultima_lectura)}` : 'Sin lecturas registradas'}
                </span>
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
