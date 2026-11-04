import { useState } from 'react';
import axios from 'axios';
import { CircleAlert, Flag, Plus, Trash2 } from 'lucide-react';
import { auth } from './firebase';
import { Alert, Button, Field, Select } from './ui/components';
import { fechaHora } from './sesiones';
import { marcadoresUrl, TIPOS_MARCADOR, DESCRIPCION_MAXIMA, textoTipo, valorLocal, isoDesdeLocal, errorMarcador } from './marcadores';

const VACIO = () => ({ tipo: 'consulta', fecha: valorLocal(), descripcion: '' });

// Agregar y borrar marcadores clínicos (Bloque 2, paso 3: WEB-RF-28), debajo
// de la gráfica de HRV/FC. El estado (la lista) vive en SesionesPaciente,
// que también los dibuja en la gráfica; `numeros` es id → número en ella.
function MarcadoresPanel({ paciente, marcadores, numeros, onCambio }) {
  const [borrador, setBorrador] = useState(VACIO);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState('');
  const [confirmar, setConfirmar] = useState(null); // id del marcador a borrar
  const [borrando, setBorrando] = useState(false);

  const problema = errorMarcador(borrador);
  const cambiar = (campo) => (e) => setBorrador((b) => ({ ...b, [campo]: e.target.value }));
  const headers = async () => ({ Authorization: `Bearer ${await auth.currentUser.getIdToken()}` });

  const agregar = async (e) => {
    e.preventDefault();
    if (problema || guardando) return;
    setGuardando(true);
    setError('');
    try {
      const res = await axios.post(
        marcadoresUrl(paciente.id),
        { tipo: borrador.tipo, fecha: isoDesdeLocal(borrador.fecha), descripcion: borrador.descripcion.trim() || null },
        { headers: await headers() }
      );
      onCambio([...marcadores, res.data]);
      setBorrador(VACIO());
    } catch (err) {
      console.error('Error al guardar el marcador:', err);
      setError(err.response?.data?.error || 'No se pudo guardar el marcador. Intenta de nuevo.');
    } finally {
      setGuardando(false);
    }
  };

  const borrar = async (id) => {
    setBorrando(true);
    setError('');
    try {
      await axios.delete(`${marcadoresUrl(paciente.id)}/${id}`, { headers: await headers() });
      onCambio(marcadores.filter((m) => m.id !== id));
      setConfirmar(null);
    } catch (err) {
      console.error('Error al borrar el marcador:', err);
      setError(err.response?.data?.error || 'No se pudo borrar el marcador. Intenta de nuevo.');
    } finally {
      setBorrando(false);
    }
  };

  // Más recientes primero en la lista (la gráfica los numera del más antiguo).
  const lista = [...marcadores].sort((a, b) => new Date(b.fecha) - new Date(a.fecha));

  return (
    <div className="ui-marcadores">
      <h3 className="ui-subtitle"><Flag size={16} /> Marcadores clínicos</h3>
      <p className="ui-muted" style={{ fontSize: 'var(--text-sm)', margin: '0 0 12px' }}>
        Eventos para leer la gráfica en contexto. Solo tú los ves; el paciente no.
      </p>

      <form className="ui-filtros" onSubmit={agregar}>
        <Select id="marcador-tipo" label="Tipo" value={borrador.tipo} onChange={cambiar('tipo')}>
          {TIPOS_MARCADOR.map((t) => (
            <option key={t.id} value={t.id}>{t.etiqueta}</option>
          ))}
        </Select>
        <Field id="marcador-fecha" label="Fecha y hora" type="datetime-local" max={valorLocal()} value={borrador.fecha} onChange={cambiar('fecha')} />
        <Field
          id="marcador-descripcion"
          label="Descripción (opcional)"
          value={borrador.descripcion}
          onChange={cambiar('descripcion')}
          maxLength={DESCRIPCION_MAXIMA}
          placeholder="Ej. Primera consulta presencial"
        />
        <div className="ui-filtros-acciones">
          <Button type="submit" icon={Plus} disabled={Boolean(problema) || guardando}>
            {guardando ? 'Guardando…' : 'Agregar marcador'}
          </Button>
        </div>
      </form>

      {(error || (problema && borrador.fecha)) && (
        <div style={{ margin: '12px 0' }}>
          <Alert tone="altos" icon={CircleAlert}>{error || problema}</Alert>
        </div>
      )}

      {lista.length === 0 ? (
        <div className="ui-empty">Sin marcadores todavía.</div>
      ) : (
        <ul className="ui-marcadores-lista">
          {lista.map((m) => (
            <li key={m.id} className="ui-marcador">
              <span className="ui-marcador-num" aria-label={numeros.has(m.id) ? `Marcador ${numeros.get(m.id)} en la gráfica` : 'Fuera de la gráfica'}>
                {numeros.get(m.id) ?? '·'}
              </span>
              <div className="ui-exercise-body">
                <div className="ui-list-title">{textoTipo(m.tipo)}</div>
                <div className="ui-list-time">{fechaHora(m.fecha)}</div>
                {m.descripcion && <div className="ui-exercise-note">{m.descripcion}</div>}
              </div>
              {confirmar === m.id ? (
                <div style={{ display: 'flex', gap: 8 }}>
                  <Button variant="secondary" size="sm" onClick={() => setConfirmar(null)} disabled={borrando}>No</Button>
                  <Button size="sm" icon={Trash2} onClick={() => borrar(m.id)} disabled={borrando}>
                    {borrando ? 'Borrando…' : 'Sí, borrar'}
                  </Button>
                </div>
              ) : (
                <Button variant="secondary" size="sm" icon={Trash2} onClick={() => setConfirmar(m.id)} aria-label={`Borrar marcador ${textoTipo(m.tipo)}`}>
                  Borrar
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default MarcadoresPanel;
