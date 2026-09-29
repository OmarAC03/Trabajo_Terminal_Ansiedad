import { useEffect, useRef, useState } from 'react';
import axios from 'axios';
import { io } from 'socket.io-client';
import { CircleAlert, MessageCircle, Send } from 'lucide-react';
import { auth } from './firebase';
import { Alert, Button, Card } from './ui/components';

const BACKEND_URL = "https://tt-ansiedad-backend.onrender.com";

// Agrega mensajes sin duplicar (el historial y el socket pueden traer el
// mismo mensaje si llega justo mientras se carga) y en orden cronológico.
const combinar = (actuales, nuevos) => {
  const porId = new Map(actuales.map((m) => [m.id, m]));
  nuevos.forEach((m) => porId.set(m.id, m));
  return [...porId.values()].sort((a, b) => new Date(a.fecha_envio) - new Date(b.fecha_envio));
};

const hora = (fecha) =>
  fecha ? new Date(fecha).toLocaleString([], { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '';

// Chat especialista ↔ paciente dentro del detalle (Portal Web Fase 2b).
// El backend solo deja entrar/escribir si el paciente está vinculado a este
// especialista, y solo le envía mensajes de sus propios pacientes.
function ChatPaciente({ paciente }) {
  const [mensajes, setMensajes] = useState([]);
  const [texto, setTexto] = useState('');
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);
  const socketRef = useRef(null);
  const listaRef = useRef(null);
  const miUid = auth.currentUser?.uid;

  useEffect(() => {
    let cancelado = false;
    setMensajes([]);
    setCargando(true);
    setError('');

    // `auth` como función: Socket.io la vuelve a llamar en cada reconexión,
    // así se manda un token fresco aunque el anterior (1 h) ya haya vencido.
    const socket = io(BACKEND_URL, {
      transports: ['websocket'],
      auth: (cb) => auth.currentUser.getIdToken().then((token) => cb({ token })),
    });
    socketRef.current = socket;

    socket.on('recibir_mensaje', (m) => {
      // Al especialista le llegan mensajes de todos SUS pacientes: aquí solo
      // se muestran los de la conversación abierta.
      if (m.paciente_id === paciente.id) setMensajes((prev) => combinar(prev, [m]));
    });
    socket.on('connect_error', (e) => console.error('Error de conexión del chat:', e.message));

    const cargarHistorial = async () => {
      try {
        const token = await auth.currentUser.getIdToken();
        const res = await axios.get(`${BACKEND_URL}/api/mensajes/${paciente.id}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!cancelado) setMensajes((prev) => combinar(prev, res.data));
      } catch (e) {
        if (cancelado) return;
        console.error('Error al cargar el historial del chat:', e);
        setError(
          e.response?.status === 403
            ? 'Este paciente no está vinculado a tu cuenta.'
            : 'No se pudo cargar el historial de mensajes.'
        );
      } finally {
        if (!cancelado) setCargando(false);
      }
    };
    cargarHistorial();

    return () => {
      cancelado = true;
      socket.disconnect();
      socketRef.current = null;
    };
  }, [paciente.id]);

  // Mantener la vista en el último mensaje.
  useEffect(() => {
    if (listaRef.current) listaRef.current.scrollTop = listaRef.current.scrollHeight;
  }, [mensajes]);

  const enviar = (e) => {
    e.preventDefault();
    const limpio = texto.trim();
    if (!limpio || !socketRef.current || enviando) return;

    setEnviando(true);
    setError('');
    socketRef.current
      .timeout(10000)
      .emit('enviar_mensaje', { paciente_id: paciente.id, texto: limpio }, (err, resp) => {
        setEnviando(false);
        if (err) {
          setError('El servidor no respondió. Revisa tu conexión e intenta de nuevo.');
        } else if (!resp?.ok) {
          setError(resp?.error || 'No se pudo enviar el mensaje.');
        } else {
          setTexto('');
        }
      });
  };

  return (
    <Card
      className="ui-chat"
      title="Mensajes"
      subtitle={`Conversación con ${paciente.nombre}`}
      icon={MessageCircle}
    >
      <div ref={listaRef} className="ui-chat-list">
        {cargando ? (
          <div className="ui-chat-empty">Cargando mensajes…</div>
        ) : mensajes.length === 0 ? (
          <div className="ui-chat-empty">Aún no hay mensajes en esta conversación.</div>
        ) : (
          mensajes.map((m) => {
            // Mensajes antiguos sin remitente_id los envió el paciente (antes
            // solo la app podía escribir).
            const esMio = (m.remitente_id || m.paciente_id) === miUid;
            return (
              <div key={m.id} className={`ui-chat-row ${esMio ? 'is-mine' : ''}`}>
                <div className="ui-chat-bubble">
                  <div>{m.texto}</div>
                  <div className="ui-chat-time">{hora(m.fecha_envio)}</div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {error && (
        <div style={{ marginTop: 12 }}>
          <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
        </div>
      )}

      <form onSubmit={enviar} className="ui-chat-form">
        <input
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          placeholder="Escribe un mensaje…"
          aria-label="Mensaje para el paciente"
          maxLength={2000}
          className="ui-input"
        />
        <Button type="submit" icon={Send} disabled={!texto.trim() || enviando}>
          {enviando ? 'Enviando…' : 'Enviar'}
        </Button>
      </form>
    </Card>
  );
}

export default ChatPaciente;
