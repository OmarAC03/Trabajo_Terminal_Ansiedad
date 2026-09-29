import { useEffect, useState } from 'react';
import axios from 'axios';
import { CircleAlert, ClipboardList, Eye, EyeOff, Info, Send } from 'lucide-react';
import { auth } from './firebase';
import { TECNICAS, tituloTecnica } from './tecnicas';
import { Alert, Badge, Button, Card, Disclaimer, Select, Textarea } from './ui/components';

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
    <Card
      className="ui-section-gap"
      title="Asignar ejercicio"
      subtitle="Técnicas de la app o un ejercicio personalizado para este paciente"
      icon={ClipboardList}
    >
      <Disclaimer icon={Info}>
        Los ejercicios son una herramienta de apoyo complementaria; no sustituyen el tratamiento ni el criterio clínico.
      </Disclaimer>

      <form onSubmit={asignar} style={{ marginTop: 16 }}>
        <Select id="ejercicio-opcion" label="Ejercicio" value={opcion} onChange={(e) => setOpcion(e.target.value)}>
          {TECNICAS.map((t) => (
            <option key={t.id} value={t.id}>{t.titulo}</option>
          ))}
          <option value={PERSONALIZADO}>Ejercicio personalizado…</option>
        </Select>

        {esPersonalizado && (
          <Textarea
            id="ejercicio-texto"
            label="Describe el ejercicio"
            value={textoPersonalizado}
            onChange={(e) => setTextoPersonalizado(e.target.value)}
            placeholder="Ej. Caminar 15 minutos al aire libre después de comer."
            maxLength={500}
            rows={3}
            help={`${textoPersonalizado.length}/500`}
          />
        )}

        <Textarea
          id="ejercicio-nota"
          label="Nota para el paciente (opcional)"
          value={nota}
          onChange={(e) => setNota(e.target.value)}
          placeholder="Ej. Practícalo por la noche antes de dormir."
          maxLength={1000}
          rows={2}
        />

        {errorForm && (
          <div style={{ marginBottom: 16 }}>
            <Alert tone="altos" icon={CircleAlert}>{errorForm}</Alert>
          </div>
        )}

        <Button type="submit" icon={Send} disabled={!puedeEnviar}>
          {enviando ? 'Asignando…' : 'Asignar ejercicio'}
        </Button>
      </form>

      <hr className="ui-card-divider" />

      <h3 className="ui-subtitle">Ejercicios asignados</h3>
      {errorLista ? (
        <Alert tone="altos" icon={CircleAlert}>{errorLista}</Alert>
      ) : cargando ? (
        <div className="ui-empty">Cargando ejercicios…</div>
      ) : ejercicios.length === 0 ? (
        <div className="ui-empty">Aún no has asignado ejercicios a este paciente.</div>
      ) : (
        <div>
          {ejercicios.map((e) => (
            <div key={e.id} className="ui-exercise">
              <div className="ui-exercise-body">
                <div className="ui-list-title ui-exercise-title">
                  {e.tecnica_id ? tituloTecnica(e.tecnica_id) : e.texto_personalizado}
                </div>
                <div className="ui-list-time">{e.tecnica_id ? 'Técnica de la app' : 'Ejercicio personalizado'}</div>
                {e.nota && <div className="ui-exercise-note">{e.nota}</div>}
                <div className="ui-list-time" style={{ marginTop: 6 }}>Asignado el {fecha(e.fecha_asignacion)}</div>
              </div>
              <Badge tone={e.visto ? 'primary' : 'neutral'} dot={false}>
                {e.visto ? <Eye size={12} /> : <EyeOff size={12} />}
                {e.visto ? 'Visto por el paciente' : 'Aún no lo ve'}
              </Badge>
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}

export default EjerciciosPaciente;
