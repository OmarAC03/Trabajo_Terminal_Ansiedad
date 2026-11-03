import { useEffect, useState } from 'react';
import axios from 'axios';
import { RefreshCw, UserX, ShieldAlert, CircleAlert, CheckCircle2, Trash2, X, TriangleAlert } from 'lucide-react';
import { auth } from './firebase';
import { PageHeader, Card, Button, Badge, Avatar, Alert, Disclaimer, Field } from './ui/components';
import { plural } from './PacientesComun';
import { API_BASE } from './config';
import { SE_BORRA, SE_CONSERVA, contarPendientes, puedeAtender, confirmacionValida, textoEstado } from './solicitudes';

const SOLICITUDES_URL = `${API_BASE}/api/admin/solicitudes-eliminacion`;

const formatoFecha = (fecha) =>
  fecha ? new Date(fecha).toLocaleString('es-MX', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';

// Sección "Solicitudes de eliminación" del admin (Bloque 1, paso 3: RF-19 /
// RF-34). El paciente la pide desde la app; aquí se atiende confirmando con
// el correo de la cuenta. Qué se borra y qué se conserva lo decide el backend
// (backend/eliminacion.js); aquí solo se explica. `onPendientes(n)` actualiza
// el contador del sidebar.
function AdminSolicitudes({ onPendientes }) {
  const [solicitudes, setSolicitudes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [aviso, setAviso] = useState('');
  const [atendiendo, setAtendiendo] = useState(null);

  const cargar = async () => {
    setError('');
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.get(SOLICITUDES_URL, { headers: { Authorization: `Bearer ${token}` } });
      setSolicitudes(res.data);
      onPendientes?.(contarPendientes(res.data));
    } catch (e) {
      console.error('Error al obtener las solicitudes:', e);
      setError('No se pudieron cargar las solicitudes. Inténtalo de nuevo con "Actualizar".');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    cargar();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const alAtender = (nombre) => {
    setAtendiendo(null);
    cargar().then(() => setAviso(`Se eliminó la cuenta de ${nombre} y sus datos.`));
  };

  const pendientes = contarPendientes(solicitudes);

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader
        title="Solicitudes de eliminación"
        subtitle={pendientes > 0 ? plural(pendientes, 'solicitud pendiente', 'solicitudes pendientes') : 'Sin solicitudes pendientes'}
        actions={<Button icon={RefreshCw} onClick={() => { setAviso(''); cargar(); }}>Actualizar</Button>}
      />

      <div className="ui-stack" style={{ gap: 12, marginBottom: 20 }}>
        {error && <Alert tone="altos" icon={CircleAlert}>{error}</Alert>}
        {aviso && <Alert tone="normal" icon={CheckCircle2}>{aviso}</Alert>}
        <Disclaimer icon={ShieldAlert}>
          El paciente pidió eliminar su cuenta y sus datos desde la app. Al atenderla se borran de forma
          definitiva: no se puede deshacer.
        </Disclaimer>
      </div>

      <Card className="ui-card-flush" title="Solicitudes" icon={UserX} subtitle="Pendientes primero">
        {loading ? (
          <div className="ui-empty">Cargando solicitudes…</div>
        ) : solicitudes.length === 0 ? (
          <div className="ui-empty">No hay solicitudes de eliminación.</div>
        ) : (
          <div className="ui-table-wrap">
            <table className="ui-table">
              <thead>
                <tr>
                  <th>Cuenta</th>
                  <th>Estado</th>
                  <th>Solicitada</th>
                  <th>Atendida</th>
                  <th><span className="sr-only">Acciones</span></th>
                </tr>
              </thead>
              <tbody>
                {solicitudes.map((s) => (
                  <tr key={s.id}>
                    <td>
                      <div className="ui-person">
                        <Avatar nombre={s.nombre} size={38} />
                        <div>
                          <div className="ui-person-name">{s.nombre}</div>
                          <div className="ui-person-sub">{s.email}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <Badge tone={s.estado === 'pendiente' ? 'elevados' : 'neutral'}>{textoEstado(s)}</Badge>
                    </td>
                    <td className="ui-muted">{formatoFecha(s.fecha_solicitud)}</td>
                    <td className="ui-muted">
                      {s.atendida_en ? `${formatoFecha(s.atendida_en)}${s.atendida_por_nombre ? ` · ${s.atendida_por_nombre}` : ''}` : '—'}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      {puedeAtender(s) && (
                        <Button variant="soft" size="sm" icon={Trash2} onClick={() => { setAviso(''); setAtendiendo(s); }}>
                          Atender
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {atendiendo && (
        <ConfirmarEliminacion solicitud={atendiendo} onCerrar={() => setAtendiendo(null)} onAtendida={alAtender} />
      )}
    </div>
  );
}

// Confirmación: lo que se borra y lo que se conserva, y el correo escrito.
function ConfirmarEliminacion({ solicitud, onCerrar, onAtendida }) {
  const [escrito, setEscrito] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState('');
  const valido = confirmacionValida(escrito, solicitud.email);

  useEffect(() => {
    const alTeclear = (e) => {
      if (e.key === 'Escape' && !enviando) onCerrar();
    };
    window.addEventListener('keydown', alTeclear);
    return () => window.removeEventListener('keydown', alTeclear);
  }, [enviando, onCerrar]);

  const atender = async (e) => {
    e.preventDefault();
    if (!valido || enviando) return;
    setEnviando(true);
    setError('');
    try {
      const token = await auth.currentUser.getIdToken();
      await axios.post(`${SOLICITUDES_URL}/${solicitud.id}/atender`, null, { headers: { Authorization: `Bearer ${token}` } });
      onAtendida(solicitud.nombre);
    } catch (err) {
      console.error('Error al atender la solicitud:', err);
      setError(err.response?.data?.error || 'No se pudo atender la solicitud. Revisa tu conexión e inténtalo de nuevo.');
      setEnviando(false);
    }
  };

  return (
    <div className="ui-modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && !enviando && onCerrar()}>
      <div className="ui-modal" role="dialog" aria-modal="true" aria-labelledby="eliminar-titulo">
        <Card
          title={<span id="eliminar-titulo">Eliminar cuenta y datos</span>}
          icon={TriangleAlert}
          subtitle={`${solicitud.nombre} · ${solicitud.email}`}
        >
          <form onSubmit={atender}>
            <strong>Se borra de forma definitiva:</strong>
            <ul className="ui-cambios">
              {SE_BORRA.map((t) => <li key={t}>{t}</li>)}
            </ul>
            <strong>Se conserva:</strong>
            <ul className="ui-cambios">
              {SE_CONSERVA.map((t) => <li key={t}>{t}</li>)}
            </ul>
            <Field
              id="eliminar-confirmacion"
              label="Para confirmar, escribe el correo de la cuenta"
              value={escrito}
              onChange={(e) => setEscrito(e.target.value)}
              placeholder={solicitud.email}
              autoComplete="off"
              autoFocus
              disabled={enviando}
            />
            {error && <Alert tone="altos" icon={CircleAlert}>{error}</Alert>}
            <div className="ui-modal-actions">
              <Button variant="secondary" icon={X} disabled={enviando} onClick={onCerrar}>Cancelar</Button>
              <Button type="submit" icon={Trash2} disabled={!valido || enviando}>
                {enviando ? 'Eliminando…' : 'Eliminar definitivamente'}
              </Button>
            </div>
          </form>
        </Card>
      </div>
    </div>
  );
}

export default AdminSolicitudes;
