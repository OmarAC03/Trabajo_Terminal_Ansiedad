import { useState } from 'react';
import { CircleAlert, Inbox, MessageCircle, UserRound } from 'lucide-react';
import ChatPaciente from './ChatPaciente';
import { Alert, Avatar, Button, Card, PageHeader } from './ui/components';
import { contarPendientes, estadoConversacion, fechaBandeja } from './chat';

// Sección "Mensajes" del portal (versión final, Fase 2): bandeja con todas
// las conversaciones a la izquierda y el chat abierto a la derecha.
// "Pendiente de responder" = el último mensaje es del paciente (decisión D1,
// opción b, sin DDL): deja de estarlo cuando el especialista responde, no al
// abrir la conversación. `conversaciones` viene de App.js
// (GET /api/especialista/conversaciones, en el mismo polling de 15 s).
function Mensajes({ conversaciones, cargando, error, onActualizar, onAbrirPaciente }) {
  const [abiertaId, setAbiertaId] = useState(null);
  const lista = conversaciones || [];
  const abierta = lista.find((c) => c.paciente_id === abiertaId) || null;
  const pendientes = contarPendientes(lista);

  const subtitulo = pendientes === 0
    ? 'No tienes conversaciones pendientes de responder'
    : pendientes === 1
      ? '1 conversación pendiente de responder'
      : `${pendientes} conversaciones pendientes de responder`;

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader title="Mensajes" subtitle={subtitulo} />
      {error && (
        <div style={{ marginBottom: 16 }}>
          <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
        </div>
      )}
      <div className="ui-bandeja">
        <Card title="Conversaciones" icon={Inbox} className="ui-bandeja-lista">
          {cargando && lista.length === 0 ? (
            <div className="ui-empty">Cargando conversaciones…</div>
          ) : lista.length === 0 ? (
            <div className="ui-empty">
              Aún no tienes pacientes vinculados. Cuando un paciente se vincule con tu código, su conversación
              aparecerá aquí.
            </div>
          ) : (
            <ul className="ui-bandeja-items" aria-label="Conversaciones con tus pacientes">
              {lista.map((c) => (
                <li key={c.paciente_id}>
                  <button
                    type="button"
                    className={`ui-bandeja-item${c.paciente_id === abiertaId ? ' is-active' : ''}${c.pendiente ? ' is-pendiente' : ''}`}
                    aria-current={c.paciente_id === abiertaId ? 'true' : undefined}
                    onClick={() => setAbiertaId(c.paciente_id)}
                  >
                    <Avatar nombre={c.nombre} size={36} />
                    <span className="ui-bandeja-texto">
                      <span className="ui-bandeja-nombre">{c.nombre}</span>
                      <span className="ui-bandeja-estado">{estadoConversacion(c)}</span>
                    </span>
                    <span className="ui-bandeja-meta">
                      <span className="ui-bandeja-fecha">{fechaBandeja(c.ultima_fecha)}</span>
                      {c.pendiente && (
                        <span className="ui-bandeja-count" aria-label={`${c.sin_responder} sin responder`}>
                          {c.sin_responder}
                        </span>
                      )}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
          <p className="ui-caption" style={{ margin: '12px 0 0' }}>
            Una conversación deja de estar pendiente cuando respondes.
          </p>
        </Card>

        <div className="ui-bandeja-chat">
          {abierta ? (
            <>
              <ChatPaciente
                key={abierta.paciente_id}
                paciente={{ id: abierta.paciente_id, nombre: abierta.nombre }}
                onCambio={onActualizar}
                alto={420}
              />
              {onAbrirPaciente && (
                <div style={{ marginTop: 12 }}>
                  <Button variant="secondary" size="sm" icon={UserRound} onClick={() => onAbrirPaciente(abierta.paciente_id)}>
                    Ver el detalle de {abierta.nombre}
                  </Button>
                </div>
              )}
            </>
          ) : (
            <Card title="Mensajes" icon={MessageCircle}>
              <div className="ui-empty">Elige una conversación de la lista para leerla y responder.</div>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

export default Mensajes;
