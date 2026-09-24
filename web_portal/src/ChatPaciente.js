import { useEffect, useRef, useState } from 'react';
import axios from 'axios';
import { io } from 'socket.io-client';
import { MessageCircle, Send } from 'lucide-react';
import { auth } from './firebase';

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
    <div style={styles.tarjeta}>
      <div style={styles.titulo}>
        <MessageCircle size={18} color="#1E6AFB" /> Mensajes con {paciente.nombre}
      </div>

      <div ref={listaRef} style={styles.lista}>
        {cargando ? (
          <div style={styles.vacio}>Cargando mensajes...</div>
        ) : mensajes.length === 0 ? (
          <div style={styles.vacio}>Aún no hay mensajes en esta conversación.</div>
        ) : (
          mensajes.map((m) => {
            // Mensajes antiguos sin remitente_id los envió el paciente (antes
            // solo la app podía escribir).
            const esMio = (m.remitente_id || m.paciente_id) === miUid;
            return (
              <div key={m.id} style={{ ...styles.fila, justifyContent: esMio ? 'flex-end' : 'flex-start' }}>
                <div style={{ ...styles.burbuja, ...(esMio ? styles.burbujaMia : styles.burbujaOtra) }}>
                  <div>{m.texto}</div>
                  <div style={{ ...styles.hora, color: esMio ? 'rgba(255,255,255,0.75)' : '#999' }}>
                    {hora(m.fecha_envio)}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {error && <div style={styles.error}>{error}</div>}

      <form onSubmit={enviar} style={styles.form}>
        <input
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          placeholder="Escribe un mensaje..."
          maxLength={2000}
          style={styles.input}
        />
        <button type="submit" disabled={!texto.trim() || enviando} style={styles.boton}>
          <Send size={16} /> {enviando ? 'Enviando...' : 'Enviar'}
        </button>
      </form>
    </div>
  );
}

const styles = {
  tarjeta: { backgroundColor: '#fff', border: '1px solid #eee', borderRadius: '15px', padding: '16px', marginTop: '20px' },
  titulo: { display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px', fontWeight: 'bold', color: '#555', marginBottom: '12px' },
  lista: { height: '360px', overflowY: 'auto', backgroundColor: '#f6f8fb', borderRadius: '10px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '8px' },
  vacio: { margin: 'auto', color: '#999', fontSize: '13px' },
  fila: { display: 'flex' },
  burbuja: { maxWidth: '70%', padding: '8px 12px', borderRadius: '14px', fontSize: '14px', lineHeight: 1.4, whiteSpace: 'pre-wrap', wordBreak: 'break-word' },
  burbujaMia: { backgroundColor: '#1E6AFB', color: '#fff', borderBottomRightRadius: '4px' },
  burbujaOtra: { backgroundColor: '#fff', color: '#1a1a1a', border: '1px solid #e5e7eb', borderBottomLeftRadius: '4px' },
  hora: { fontSize: '10px', marginTop: '4px', textAlign: 'right' },
  error: { backgroundColor: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', padding: '8px 12px', borderRadius: '8px', fontSize: '13px', marginTop: '10px' },
  form: { display: 'flex', gap: '8px', marginTop: '12px' },
  input: { flex: 1, padding: '10px 14px', borderRadius: '20px', border: '1px solid #ddd', fontSize: '14px', outline: 'none' },
  boton: { display: 'flex', alignItems: 'center', gap: '6px', padding: '10px 18px', borderRadius: '20px', border: 'none', backgroundColor: '#1E6AFB', color: '#fff', cursor: 'pointer', fontWeight: 'bold' },
};

export default ChatPaciente;
