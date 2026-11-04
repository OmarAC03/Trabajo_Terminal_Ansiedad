import { useCallback, useEffect, useState } from 'react';
import axios from 'axios';
import { CircleAlert, History, Lock, NotebookPen, Pencil, Save, X } from 'lucide-react';
import { auth } from './firebase';
import { Alert, Button, Card, Disclaimer, Field, Textarea } from './ui/components';
import {
  CONTENIDO_MAXIMO, notasUrl, diaLocal, textoDia, largo, errorBorrador, hayCambios, textoVersion, mensajeError,
} from './notas';

const fechaHora = (f) =>
  f ? new Date(f).toLocaleString('es-MX', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';

const encabezados = async () => ({ Authorization: `Bearer ${await auth.currentUser.getIdToken()}` });

// Formulario de una nota (nueva o en edición): fecha clínica + texto.
function FormNota({ id, borrador, onCambiar, onGuardar, guardando, error, textoBoton, onCancelar }) {
  const hoy = diaLocal();
  const problema = errorBorrador(borrador, hoy);
  const n = largo(borrador.contenido);
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!problema && !guardando) onGuardar();
      }}
    >
      <Field
        id={`${id}-fecha`}
        label="Fecha"
        type="date"
        max={hoy}
        value={borrador.fecha}
        onChange={(e) => onCambiar({ ...borrador, fecha: e.target.value })}
      />
      <Textarea
        id={`${id}-contenido`}
        label="Nota"
        value={borrador.contenido}
        onChange={(e) => onCambiar({ ...borrador, contenido: e.target.value })}
        placeholder="Observaciones de la consulta, acuerdos, seguimiento…"
        rows={4}
        help={`${n}/${CONTENIDO_MAXIMO}`}
      />
      {error && (
        <div style={{ marginBottom: 16 }}>
          <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
        </div>
      )}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <Button type="submit" icon={Save} disabled={Boolean(problema) || guardando}>
          {guardando ? 'Guardando…' : textoBoton}
        </Button>
        {onCancelar && (
          <Button variant="secondary" icon={X} onClick={onCancelar} disabled={guardando}>Cancelar</Button>
        )}
      </div>
    </form>
  );
}

// Versiones anteriores de una nota (se piden al abrir el historial).
function HistorialNota({ pacienteId, nota }) {
  const [versiones, setVersiones] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelado = false;
    (async () => {
      try {
        const res = await axios.get(`${notasUrl(pacienteId)}/${nota.id}/versiones`, { headers: await encabezados() });
        if (!cancelado) setVersiones(res.data);
      } catch (e) {
        console.error('Error al cargar el historial de la nota:', e);
        if (!cancelado) setError(mensajeError(e, 'No se pudo cargar el historial.'));
      }
    })();
    return () => {
      cancelado = true;
    };
  }, [pacienteId, nota.id, nota.version]);

  if (error) return <Alert tone="altos" icon={CircleAlert}>{error}</Alert>;
  if (!versiones) return <div className="ui-list-time">Cargando historial…</div>;
  return (
    <div className="ui-nota-historial">
      {versiones.map((v) => (
        <div key={v.version} className="ui-nota-version">
          <div className="ui-list-time">
            Versión {v.version} · {textoDia(v.fecha)} · escrita el {fechaHora(v.escrita_en)}, reemplazada el {fechaHora(v.reemplazada_en)}
          </div>
          <div className="ui-exercise-note">{v.contenido}</div>
        </div>
      ))}
    </div>
  );
}

// Notas clínicas del especialista sobre un paciente (Bloque 2, paso 2:
// WEB-RF-27 / RN-15). Privadas del par paciente–especialista: el paciente no
// las ve, el admin no ve su contenido. No se borran; editar guarda versión.
function NotasPaciente({ paciente, recarga }) {
  const [notas, setNotas] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [errorLista, setErrorLista] = useState('');

  const [nueva, setNueva] = useState(() => ({ fecha: diaLocal(), contenido: '' }));
  const [guardandoNueva, setGuardandoNueva] = useState(false);
  const [errorNueva, setErrorNueva] = useState('');

  const [editando, setEditando] = useState(null); // { id, version, fecha, contenido }
  const [guardandoEdicion, setGuardandoEdicion] = useState(false);
  const [errorEdicion, setErrorEdicion] = useState('');
  const [historial, setHistorial] = useState(null); // id de la nota con historial abierto

  const cargar = useCallback(async () => {
    setCargando(true);
    setErrorLista('');
    try {
      const res = await axios.get(notasUrl(paciente.id), { headers: await encabezados() });
      setNotas(res.data);
    } catch (e) {
      console.error('Error al cargar las notas clínicas:', e);
      setErrorLista(mensajeError(e, 'No se pudieron cargar las notas.'));
    } finally {
      setCargando(false);
    }
  }, [paciente.id]);

  useEffect(() => {
    cargar();
  }, [cargar, recarga]);

  const crear = async () => {
    setGuardandoNueva(true);
    setErrorNueva('');
    try {
      const res = await axios.post(
        notasUrl(paciente.id),
        { fecha: nueva.fecha, contenido: nueva.contenido.trim() },
        { headers: await encabezados() }
      );
      setNotas((prev) => [res.data, ...prev].sort((a, b) => (a.fecha < b.fecha ? 1 : a.fecha > b.fecha ? -1 : 0)));
      setNueva({ fecha: diaLocal(), contenido: '' });
    } catch (e) {
      console.error('Error al guardar la nota:', e);
      setErrorNueva(mensajeError(e, 'No se pudo guardar la nota. Intenta de nuevo.'));
    } finally {
      setGuardandoNueva(false);
    }
  };

  const guardarEdicion = async () => {
    const nota = notas.find((n) => n.id === editando.id);
    if (nota && !hayCambios(nota, editando)) {
      setEditando(null);
      return;
    }
    setGuardandoEdicion(true);
    setErrorEdicion('');
    try {
      const res = await axios.put(
        `${notasUrl(paciente.id)}/${editando.id}`,
        { fecha: editando.fecha, contenido: editando.contenido.trim(), version: editando.version },
        { headers: await encabezados() }
      );
      setNotas((prev) => prev.map((n) => (n.id === res.data.id ? res.data : n)));
      setEditando(null);
    } catch (e) {
      console.error('Error al editar la nota:', e);
      setErrorEdicion(mensajeError(e, 'No se pudo guardar la edición. Intenta de nuevo.'));
      // Otra pestaña la editó: se trae la versión vigente y se deja abierto
      // el borrador para que el especialista lo copie si lo necesita.
      if (e.response?.status === 409) {
        await cargar();
        setEditando((ed) => (ed ? { ...ed, version: null } : ed));
      }
    } finally {
      setGuardandoEdicion(false);
    }
  };

  const abrirEdicion = (n) => {
    setErrorEdicion('');
    setEditando({ id: n.id, version: n.version, fecha: n.fecha, contenido: n.contenido });
  };

  return (
    <Card
      className="ui-section-gap"
      title="Notas clínicas"
      subtitle="Notas de seguimiento por fecha, con historial de cambios"
      icon={NotebookPen}
    >
      <Disclaimer icon={Lock}>
        Solo tú ves estas notas, y solo mientras este paciente esté vinculado a tu cuenta. El paciente no tiene acceso.
        No se pueden borrar: cada edición conserva la versión anterior.
      </Disclaimer>

      <div style={{ marginTop: 16 }}>
        <FormNota
          id="nota-nueva"
          borrador={nueva}
          onCambiar={setNueva}
          onGuardar={crear}
          guardando={guardandoNueva}
          error={errorNueva}
          textoBoton="Guardar nota"
        />
      </div>

      <hr className="ui-card-divider" />

      <h3 className="ui-subtitle">Notas guardadas</h3>
      {errorLista ? (
        <Alert tone="altos" icon={CircleAlert}>{errorLista}</Alert>
      ) : cargando ? (
        <div className="ui-empty">Cargando notas…</div>
      ) : notas.length === 0 ? (
        <div className="ui-empty">Aún no has escrito notas sobre este paciente.</div>
      ) : (
        <div>
          {notas.map((n) => (
            <div key={n.id} className="ui-exercise">
              <div className="ui-exercise-body">
                {editando?.id === n.id ? (
                  editando.version === null ? (
                    <>
                      <Alert tone="altos" icon={CircleAlert}>{errorEdicion}</Alert>
                      <div className="ui-exercise-note">Tu borrador (no guardado):</div>
                      <div className="ui-exercise-note">{editando.contenido}</div>
                      <div style={{ marginTop: 8 }}>
                        <Button variant="secondary" size="sm" onClick={() => abrirEdicion(n)}>Editar la versión actual</Button>
                      </div>
                    </>
                  ) : (
                    <FormNota
                      id={`nota-${n.id}`}
                      borrador={editando}
                      onCambiar={setEditando}
                      onGuardar={guardarEdicion}
                      guardando={guardandoEdicion}
                      error={errorEdicion}
                      textoBoton="Guardar cambios"
                      onCancelar={() => setEditando(null)}
                    />
                  )
                ) : (
                  <>
                    <div className="ui-list-title">{textoDia(n.fecha)}</div>
                    <div className="ui-exercise-title" style={{ marginTop: 4 }}>{n.contenido}</div>
                    <div className="ui-list-time" style={{ marginTop: 6 }}>{textoVersion(n, fechaHora)}</div>
                    {historial === n.id && <HistorialNota pacienteId={paciente.id} nota={n} />}
                  </>
                )}
              </div>
              {editando?.id !== n.id && (
                <div style={{ display: 'flex', gap: 8 }}>
                  <Button variant="secondary" size="sm" icon={Pencil} onClick={() => abrirEdicion(n)}>Editar</Button>
                  {n.version > 1 && (
                    <Button
                      variant="secondary"
                      size="sm"
                      icon={History}
                      onClick={() => setHistorial((h) => (h === n.id ? null : n.id))}
                      aria-expanded={historial === n.id}
                    >
                      {historial === n.id ? 'Ocultar historial' : 'Historial'}
                    </Button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}

export default NotasPaciente;
