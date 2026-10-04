import { useEffect, useState } from 'react';
import axios from 'axios';
import { Pencil, Save, X, ArrowLeft, Check, CircleAlert, TriangleAlert } from 'lucide-react';
import { auth } from './firebase';
import { Card, Button, Field, Select, Alert } from './ui/components';

const ADMIN_USUARIOS_URL = 'https://tt-ansiedad-backend.onrender.com/api/admin/usuarios';

// Mismos límites que valida el backend (validarEdicionAdmin): las columnas de
// `usuarios` son varchar(100). Aquí solo se avisa antes de enviar; la regla
// que manda es la del servidor.
const MAX_LARGO = 100;
const FORMATO_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Panel de edición de una cuenta (Fase C, paso 2): nombre, correo y, si es
// paciente, su especialista. Si cambia el correo o el especialista se pide
// confirmación con el resumen y sus consecuencias; solo el nombre se guarda
// directo. `especialistas` son las cuentas de especialista ya cargadas en la
// tabla (no se pide nada nuevo).
function EditarUsuario({ usuario, especialistas, onCerrar, onGuardado }) {
  const [nombre, setNombre] = useState(usuario.nombre || '');
  const [email, setEmail] = useState(usuario.email || '');
  const [especialistaId, setEspecialistaId] = useState(usuario.especialista_id || '');
  const [confirmando, setConfirmando] = useState(false);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState('');

  const esPaciente = usuario.rol === 'paciente';
  const esPropia = usuario.id === auth.currentUser?.uid;

  // Escape cierra el panel (salvo mientras se guarda).
  useEffect(() => {
    const alTeclear = (e) => {
      if (e.key === 'Escape' && !guardando) onCerrar();
    };
    window.addEventListener('keydown', alTeclear);
    return () => window.removeEventListener('keydown', alTeclear);
  }, [guardando, onCerrar]);

  const nombreLimpio = nombre.trim();
  const emailLimpio = email.trim().toLowerCase();
  const cambiaNombre = nombreLimpio !== (usuario.nombre || '');
  const cambiaEmail = emailLimpio !== (usuario.email || '').toLowerCase();
  const cambiaEspecialista = esPaciente && (especialistaId || null) !== (usuario.especialista_id || null);
  const hayCambios = cambiaNombre || cambiaEmail || cambiaEspecialista;

  const errorNombre = !nombreLimpio
    ? 'El nombre no puede quedar vacío.'
    : nombreLimpio.length > MAX_LARGO ? `Máximo ${MAX_LARGO} caracteres.` : '';
  const errorEmail = emailLimpio.length > MAX_LARGO
    ? `Máximo ${MAX_LARGO} caracteres.`
    : !FORMATO_EMAIL.test(emailLimpio) ? 'Escribe un correo con formato válido (nombre@dominio.com).' : '';
  // Solo cuentan los campos que cambian (como en el backend, que valida solo
  // lo que se envía): un correo antiguo con formato raro no bloquea editar
  // el nombre.
  const valido = !(cambiaNombre && errorNombre) && !(cambiaEmail && errorEmail);

  // Opciones: especialistas activos + el actual aunque ya no esté activo, para
  // que el select muestre bien el valor de hoy.
  const opciones = especialistas.filter((e) => e.estado === 'activa' || e.id === usuario.especialista_id);
  const nombreEspecialista = (id) =>
    id ? especialistas.find((e) => e.id === id)?.nombre || 'Especialista desconocido' : 'Sin especialista';

  const guardar = async () => {
    setGuardando(true);
    setError('');
    const cuerpo = {};
    if (cambiaNombre) cuerpo.nombre = nombreLimpio;
    if (cambiaEmail) cuerpo.email = emailLimpio;
    if (cambiaEspecialista) cuerpo.especialista_id = especialistaId || null;
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.put(`${ADMIN_USUARIOS_URL}/${usuario.id}`, cuerpo, {
        headers: { Authorization: `Bearer ${token}` },
      });
      // Si el admin cambió su propio correo, refresca el usuario de Firebase
      // para que "Cambiar contraseña" (que reautentica con el correo) use el
      // nuevo sin tener que volver a entrar.
      if (esPropia && cambiaEmail) {
        await auth.currentUser.reload().catch((e) => console.error('No se pudo refrescar la sesión:', e));
      }
      onGuardado(res.data);
    } catch (e) {
      console.error('Error al editar el usuario:', e);
      setError(e.response?.data?.error || 'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.');
      setGuardando(false);
    }
  };

  const enviar = (e) => {
    e.preventDefault();
    if (!hayCambios || !valido || guardando) return;
    if ((cambiaEmail || cambiaEspecialista) && !confirmando) {
      setError('');
      setConfirmando(true);
      return;
    }
    guardar();
  };

  return (
    <div className="ui-modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && !guardando && onCerrar()}>
      <div className="ui-modal" role="dialog" aria-modal="true" aria-labelledby="editar-usuario-titulo">
        <Card
          title={<span id="editar-usuario-titulo">{confirmando ? 'Confirmar cambios' : 'Editar cuenta'}</span>}
          icon={confirmando ? TriangleAlert : Pencil}
          subtitle={`${usuario.nombre} · ${usuario.email}${esPropia ? ' (tu cuenta)' : ''}`}
        >
          <form onSubmit={enviar}>
            {confirmando ? (
              <Resumen
                cambiaNombre={cambiaNombre}
                cambiaEmail={cambiaEmail}
                cambiaEspecialista={cambiaEspecialista}
                usuario={usuario}
                nombreLimpio={nombreLimpio}
                emailLimpio={emailLimpio}
                especialistaAntes={nombreEspecialista(usuario.especialista_id)}
                especialistaDespues={nombreEspecialista(especialistaId)}
                desvincula={cambiaEspecialista && !especialistaId}
                esPropia={esPropia}
              />
            ) : (
              <>
                <Field
                  id="editar-nombre"
                  label="Nombre"
                  value={nombre}
                  onChange={(e) => setNombre(e.target.value)}
                  maxLength={MAX_LARGO}
                  autoFocus
                  disabled={guardando}
                  help={cambiaNombre && errorNombre ? errorNombre : undefined}
                />
                <Field
                  id="editar-email"
                  label="Correo electrónico"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  maxLength={MAX_LARGO}
                  disabled={guardando}
                  help={
                    cambiaEmail && errorEmail
                      ? errorEmail
                      : 'Es el correo con el que esta persona inicia sesión. No se le envía ningún aviso: avísale tú. Su contraseña no cambia.'
                  }
                />
                {esPaciente && (
                  <Select
                    id="editar-especialista"
                    label="Especialista"
                    value={especialistaId}
                    onChange={(e) => setEspecialistaId(e.target.value)}
                    disabled={guardando}
                    help="Reasigna o desvincula al paciente. Solo aparecen especialistas con cuenta activa."
                  >
                    <option value="">Sin especialista</option>
                    {opciones.map((e) => (
                      <option key={e.id} value={e.id}>
                        {e.nombre}{e.estado !== 'activa' ? ` (${e.estado})` : ''}
                      </option>
                    ))}
                  </Select>
                )}
              </>
            )}

            {error && <Alert tone="altos" icon={CircleAlert}>{error}</Alert>}

            <div className="ui-modal-actions">
              {confirmando ? (
                <>
                  <Button variant="secondary" icon={ArrowLeft} disabled={guardando} onClick={() => setConfirmando(false)}>
                    Volver
                  </Button>
                  <Button type="submit" icon={Check} disabled={guardando}>
                    {guardando ? 'Guardando…' : 'Confirmar y guardar'}
                  </Button>
                </>
              ) : (
                <>
                  <Button variant="secondary" icon={X} disabled={guardando} onClick={onCerrar}>Cancelar</Button>
                  <Button type="submit" icon={Save} disabled={!hayCambios || !valido || guardando}>
                    {guardando ? 'Guardando…' : 'Guardar'}
                  </Button>
                </>
              )}
            </div>
          </form>
        </Card>
      </div>
    </div>
  );
}

// Resumen "antes → después" y consecuencias, antes de confirmar.
function Resumen({
  cambiaNombre, cambiaEmail, cambiaEspecialista, usuario, nombreLimpio, emailLimpio,
  especialistaAntes, especialistaDespues, desvincula, esPropia,
}) {
  return (
    <>
      <ul className="ui-cambios">
        {cambiaNombre && <li><strong>Nombre:</strong> {usuario.nombre} → {nombreLimpio}</li>}
        {cambiaEmail && (
          <li><strong>Correo:</strong> <span className="ui-mono">{usuario.email}</span> → <span className="ui-mono">{emailLimpio}</span></li>
        )}
        {cambiaEspecialista && <li><strong>Especialista:</strong> {especialistaAntes} → {especialistaDespues}</li>}
      </ul>
      <div className="ui-stack" style={{ gap: 8 }}>
        {cambiaEmail && (
          <Alert tone="elevados" icon={TriangleAlert}>
            {esPropia
              ? 'Es tu propia cuenta: tu próximo inicio de sesión será con el correo nuevo y tu misma contraseña.'
              : 'Su próximo inicio de sesión será con el correo nuevo y su misma contraseña. No se le envía ningún aviso: avísale tú.'}
          </Alert>
        )}
        {cambiaEspecialista && (
          <Alert tone="elevados" icon={TriangleAlert}>
            {usuario.especialista_id
              ? 'El especialista anterior dejará de ver a este paciente de inmediato (lista, indicadores fisiológicos, mensajes y ejercicios). '
              : ''}
            {desvincula
              ? 'El paciente quedará sin especialista y su app le mostrará la opción de vincularse con un código.'
              : 'El nuevo especialista no verá la conversación ni los ejercicios anteriores.'}
            {' '}No se borra ningún dato.
          </Alert>
        )}
      </div>
    </>
  );
}

export default EditarUsuario;
