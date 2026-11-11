import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import axios from 'axios';
import { io } from 'socket.io-client';
import { CircleAlert, MessageCircle, Send } from 'lucide-react';
import { auth } from './firebase';
import { Alert, Button, Card } from './ui/components';
import { API_BASE } from './config';
import { altoCaja, conSeparadores, horaLocal, teclaEnvia, TEXTO_MAXIMO } from './chat';

const BACKEND_URL = API_BASE;

// Agrega mensajes sin duplicar (el historial y el socket pueden traer el
// mismo mensaje si llega justo mientras se carga) y en orden cronológico.
const combinar = (actuales, nuevos) => {
  const porId = new Map(actuales.map((m) => [m.id, m]));
  nuevos.forEach((m) => porId.set(m.id, m));
  return [...porId.values()].sort((a, b) => new Date(a.fecha_envio) - new Date(b.fecha_envio));
};

// Chat especialista ↔ paciente (Portal Web Fase 2b), en el detalle del
// paciente y en la sección Mensajes. El backend solo deja entrar/escribir si
// el paciente está vinculado a este especialista, y solo le envía mensajes de
// sus propios pacientes. Separadores por día y hora en hora de México
// (chat.js). `onCambio` avisa cuando llega o sale un mensaje, para que la
// bandeja actualice "Pendiente de responder".
function ChatPaciente({ paciente, onCambio, alto }) {
  const [mensajes, setMensajes] = useState([]);
  const [texto, setTexto] = useState('');
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);
  const socketRef = useRef(null);
  const listaRef = useRef(null);
  const cajaRef = useRef(null);
  const onCambioRef = useRef(onCambio);
  onCambioRef.current = onCambio;
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
      if (onCambioRef.current) onCambioRef.current();
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

  // La caja crece de 1 a 5 líneas con el texto y después hace scroll por dentro.
  useLayoutEffect(() => {
    const caja = cajaRef.current;
    if (!caja) return;
    const estilo = window.getComputedStyle(caja);
    const px = (v) => parseFloat(v) || 0;
    const altoLinea = px(estilo.lineHeight) || 20;
    // Con box-sizing: border-box el alto incluye relleno y borde; scrollHeight
    // trae el contenido más el relleno, sin el borde.
    const borde = px(estilo.borderTopWidth) + px(estilo.borderBottomWidth);
    const relleno = px(estilo.paddingTop) + px(estilo.paddingBottom) + borde;
    caja.style.height = 'auto';
    const { alto: altoNuevo, conScroll } = altoCaja({ scrollHeight: caja.scrollHeight + borde, altoLinea, relleno });
    caja.style.height = `${altoNuevo}px`;
    caja.style.overflowY = conScroll ? 'auto' : 'hidden';
  }, [texto]);

  const enviar = (e) => {
    if (e) e.preventDefault();
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
          if (onCambioRef.current) onCambioRef.current();
        }
      });
  };

  // Enter envía; Shift+Enter hace salto de línea (chat.js).
  const alTeclear = (e) => {
    if (!teclaEnvia(e)) return;
    e.preventDefault();
    enviar();
  };

  return (
    <Card
      className="ui-chat"
      title="Mensajes"
      subtitle={`Conversación con ${paciente.nombre}`}
      icon={MessageCircle}
    >
      <div ref={listaRef} className="ui-chat-list" style={alto ? { height: alto } : undefined}>
        {cargando ? (
          <div className="ui-chat-empty">Cargando mensajes…</div>
        ) : mensajes.length === 0 ? (
          <div className="ui-chat-empty">Aún no hay mensajes en esta conversación.</div>
        ) : (
          conSeparadores(mensajes).map((item) => {
            if (item.tipo === 'dia') {
              return (
                <div key={item.clave} className="ui-chat-day" role="separator">
                  <span>{item.etiqueta}</span>
                </div>
              );
            }
            const m = item.mensaje;
            // Mensajes antiguos sin remitente_id los envió el paciente (antes
            // solo la app podía escribir).
            const esMio = (m.remitente_id || m.paciente_id) === miUid;
            return (
              <div key={item.clave} className={`ui-chat-row ${esMio ? 'is-mine' : ''}`}>
                <div className="ui-chat-bubble">
                  <div>{m.texto}</div>
                  <div className="ui-chat-time">{horaLocal(m.fecha_envio)}</div>
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
        <textarea
          ref={cajaRef}
          rows={1}
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          onKeyDown={alTeclear}
          placeholder="Escribe un mensaje…"
          aria-label="Mensaje para el paciente"
          aria-describedby="chat-ayuda"
          maxLength={TEXTO_MAXIMO}
          className="ui-input ui-chat-input"
        />
        <Button type="submit" icon={Send} disabled={!texto.trim() || enviando}>
          {enviando ? 'Enviando…' : 'Enviar'}
        </Button>
      </form>
      <div id="chat-ayuda" className="ui-chat-help">Enter envía · Shift+Enter hace un salto de línea</div>
    </Card>
  );
}

export default ChatPaciente;
