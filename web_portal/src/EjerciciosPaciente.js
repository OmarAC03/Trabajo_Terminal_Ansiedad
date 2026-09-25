import { useEffect, useState } from 'react';
import axios from 'axios';
import { ClipboardList, Eye, EyeOff, Info, Send } from 'lucide-react';
import { auth } from './firebase';
import { TECNICAS, tituloTecnica } from './tecnicas';

const EJERCICIOS_URL = "https://tt-ansiedad-backend.onrender.com/api/ejercicios";

// Valor del <select> para "escribir uno propio" (no es un slug de técnica).
const PERSONALIZADO = '__personalizado__';

const fecha = (f) =>
  f ? new Date(f).toLocaleString([], { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '';

// Asignar ejercicios a un paciente + lista de los ya asignados (Portal Web
// Fase 2c). El backend solo acepta pacientes vinculados a este especialista
// y pone el especialista_id desde el token.
function EjerciciosPaciente({ paciente, recarga }) {
  const [ejercicios, setEjercicios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [errorLista, setErrorLista] = useState('');

  const [opcion, setOpcion] = useState(TECNICAS[0].id);
  const [textoPersonalizado, setTextoPersonalizado] = useState('');
  const [nota, setNota] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [errorForm, setErrorForm] = useState('');

  useEffect(() => {
    let cancelado = false;

    const cargar = async () => {
      setCargando(true);
      setErrorLista('');
      try {
        const token = await auth.currentUser.getIdToken();
        const res = await axios.get(`${EJERCICIOS_URL}/${paciente.id}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!cancelado) setEjercicios(res.data);
      } catch (e) {
        if (cancelado) return;
        console.error('Error al cargar los ejercicios asignados:', e);
        setErrorLista(
          e.response?.status === 403
            ? 'Este paciente no está vinculado a tu cuenta.'
            : 'No se pudieron cargar los ejercicios asignados.'
        );
      } finally {
        if (!cancelado) setCargando(false);
      }
    };

    cargar();
    return () => {
      cancelado = true;
    };
  }, [paciente.id, recarga]);

  const esPersonalizado = opcion === PERSONALIZADO;
  const puedeEnviar = !enviando && (!esPersonalizado || textoPersonalizado.trim().length > 0);

  const asignar = async (e) => {
    e.preventDefault();
    if (!puedeEnviar) return;

    setEnviando(true);
    setErrorForm('');
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.post(
        EJERCICIOS_URL,
        {
          paciente_id: paciente.id,
          ...(esPersonalizado ? { texto_personalizado: textoPersonalizado.trim() } : { tecnica_id: opcion }),
          nota: nota.trim() || null,
        },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      setEjercicios((prev) => [res.data.data, ...prev]);
      setTextoPersonalizado('');
      setNota('');
    } catch (e) {
      console.error('Error al asignar el ejercicio:', e);
      setErrorForm(e.response?.data?.error || 'No se pudo asignar el ejercicio. Intenta de nuevo.');
    } finally {
      setEnviando(false);
    }
  };

  return (
    <div style={styles.tarjeta}>
      <div style={styles.titulo}>
        <ClipboardList size={18} color="#1E6AFB" /> Asignar ejercicio
      </div>

      <div style={styles.disclaimer}>
        <Info size={14} style={{ flexShrink: 0, marginTop: '1px' }} />
        <span>
          Los ejercicios son una herramienta de apoyo complementaria; no sustituyen el tratamiento ni el criterio clínico.
        </span>
      </div>

      <form onSubmit={asignar} style={styles.form}>
        <label style={styles.label}>
          Ejercicio
          <select value={opcion} onChange={(e) => setOpcion(e.target.value)} style={styles.input}>
            {TECNICAS.map((t) => (
              <option key={t.id} value={t.id}>{t.titulo}</option>
            ))}
            <option value={PERSONALIZADO}>Ejercicio personalizado…</option>
          </select>
        </label>

        {esPersonalizado && (
          <label style={styles.label}>
            Describe el ejercicio
            <textarea
              value={textoPersonalizado}
              onChange={(e) => setTextoPersonalizado(e.target.value)}
              placeholder="Ej. Caminar 15 minutos al aire libre después de comer."
              maxLength={500}
              rows={3}
              style={{ ...styles.input, resize: 'vertical' }}
            />
          </label>
        )}

        <label style={styles.label}>
          Nota para el paciente (opcional)
          <textarea
            value={nota}
            onChange={(e) => setNota(e.target.value)}
            placeholder="Ej. Practícalo por la noche antes de dormir."
            maxLength={1000}
            rows={2}
            style={{ ...styles.input, resize: 'vertical' }}
          />
        </label>

        {errorForm && <div style={styles.error}>{errorForm}</div>}

        <button type="submit" disabled={!puedeEnviar} style={{ ...styles.boton, opacity: puedeEnviar ? 1 : 0.6 }}>
          <Send size={16} /> {enviando ? 'Asignando...' : 'Asignar ejercicio'}
        </button>
      </form>

      <h3 style={styles.subtitulo}>Ejercicios asignados</h3>
      {errorLista ? (
        <div style={styles.error}>{errorLista}</div>
      ) : cargando ? (
        <div style={styles.vacio}>Cargando ejercicios...</div>
      ) : ejercicios.length === 0 ? (
        <div style={styles.vacio}>Aún no has asignado ejercicios a este paciente.</div>
      ) : (
        <div style={styles.lista}>
          {ejercicios.map((e) => (
            <div key={e.id} style={styles.fila}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={styles.filaTitulo}>
                  {e.tecnica_id ? tituloTecnica(e.tecnica_id) : e.texto_personalizado}
                </div>
                <div style={styles.filaTipo}>{e.tecnica_id ? 'Técnica de la app' : 'Ejercicio personalizado'}</div>
                {e.nota && <div style={styles.filaNota}>{e.nota}</div>}
                <div style={styles.filaFecha}>Asignado el {fecha(e.fecha_asignacion)}</div>
              </div>
              <span style={{ ...styles.estado, ...(e.visto ? styles.estadoVisto : styles.estadoPendiente) }}>
                {e.visto ? <Eye size={12} /> : <EyeOff size={12} />}
                {e.visto ? 'Visto por el paciente' : 'Aún no lo ve'}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

const styles = {
  tarjeta: { backgroundColor: '#fff', border: '1px solid #eee', borderRadius: '15px', padding: '16px', marginTop: '20px' },
  titulo: { display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px', fontWeight: 'bold', color: '#555', marginBottom: '12px' },
  disclaimer: { display: 'flex', gap: '8px', alignItems: 'flex-start', backgroundColor: '#f1f5f9', color: '#64748b', fontSize: '12px', lineHeight: 1.4, padding: '8px 12px', borderRadius: '8px', marginBottom: '14px' },
  form: { display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '20px' },
  label: { display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '13px', fontWeight: 600, color: '#555' },
  input: { padding: '10px 12px', borderRadius: '10px', border: '1px solid #ddd', fontSize: '14px', fontFamily: 'inherit', fontWeight: 'normal', outline: 'none', backgroundColor: '#fff' },
  boton: { alignSelf: 'flex-start', display: 'flex', alignItems: 'center', gap: '6px', padding: '10px 18px', borderRadius: '20px', border: 'none', backgroundColor: '#1E6AFB', color: '#fff', cursor: 'pointer', fontWeight: 'bold' },
  error: { backgroundColor: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', padding: '8px 12px', borderRadius: '8px', fontSize: '13px' },
  subtitulo: { fontSize: '14px', color: '#555', margin: '0 0 10px' },
  vacio: { textAlign: 'center', color: '#999', fontSize: '13px', padding: '20px 0' },
  lista: { display: 'flex', flexDirection: 'column', gap: '10px' },
  fila: { display: 'flex', alignItems: 'flex-start', gap: '12px', backgroundColor: '#f6f8fb', borderRadius: '12px', padding: '12px 14px', flexWrap: 'wrap' },
  filaTitulo: { fontWeight: 'bold', fontSize: '14px', color: '#1a1a1a', whiteSpace: 'pre-wrap', wordBreak: 'break-word' },
  filaTipo: { fontSize: '11px', color: '#888', marginTop: '2px' },
  filaNota: { fontSize: '13px', color: '#444', marginTop: '6px', whiteSpace: 'pre-wrap', wordBreak: 'break-word' },
  filaFecha: { fontSize: '11px', color: '#999', marginTop: '6px' },
  estado: { display: 'flex', alignItems: 'center', gap: '4px', padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 'bold', whiteSpace: 'nowrap' },
  estadoVisto: { color: '#0f766e', backgroundColor: '#ccfbf1' },
  estadoPendiente: { color: '#64748b', backgroundColor: '#e2e8f0' },
};

export default EjerciciosPaciente;
