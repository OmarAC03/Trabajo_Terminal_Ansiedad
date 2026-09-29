import { useState } from 'react';
import axios from 'axios';
import { EmailAuthProvider, reauthenticateWithCredential, updatePassword } from 'firebase/auth';
import {
  UserRound, KeyRound, Lock, Pencil, Copy, Check, Save, X, CheckCircle2, CircleAlert, Info,
} from 'lucide-react';
import { auth } from './firebase';
import { PageHeader, Card, Button, Badge, Avatar, Field, Alert, Disclaimer } from './ui/components';

const USUARIOS_URL = 'https://tt-ansiedad-backend.onrender.com/api/usuarios';
const MIN_PASSWORD = 6; // mínimo que exige Firebase Auth

// Traduce los códigos de error de Firebase al cambiar la contraseña.
function mensajeErrorPassword(error) {
  switch (error?.code) {
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
      return 'La contraseña actual no es correcta.';
    case 'auth/weak-password':
      return `La nueva contraseña es muy débil (mínimo ${MIN_PASSWORD} caracteres).`;
    case 'auth/too-many-requests':
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    case 'auth/network-request-failed':
      return 'Sin conexión. Revisa tu red e inténtalo de nuevo.';
    case 'auth/requires-recent-login':
      return 'Por seguridad, cierra sesión, vuelve a entrar e inténtalo de nuevo.';
    default:
      return 'No se pudo cambiar la contraseña. Inténtalo de nuevo.';
  }
}

// Perfil del especialista (Fase 2e): datos de la cuenta, edición del nombre,
// código de vinculación y cambio de contraseña. `perfil` viene de App.js
// (GET /api/usuarios/:uid, solo el propio); tras guardar el nombre se avisa
// con `onPerfilActualizado` para que el resto del portal lo vea de inmediato.
function PerfilEspecialista({ perfil, onPerfilActualizado }) {
  if (!perfil) {
    return (
      <div className="ui-page ui-page-wide">
        <PageHeader title="Mi perfil" subtitle="Datos de tu cuenta de especialista" />
        <Card><div className="ui-empty">Cargando tus datos…</div></Card>
      </div>
    );
  }

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader title="Mi perfil" subtitle="Datos de tu cuenta de especialista" />
      {/* Cuenta + código a la izquierda, contraseña a la derecha (antes eran
          3 tarjetas en una rejilla de 2 y la tercera quedaba sola). */}
      <div className="ui-profile-cols">
        <div className="ui-stack">
          <DatosCuenta perfil={perfil} onPerfilActualizado={onPerfilActualizado} />
          <CodigoCard codigo={perfil.codigo_vinculacion} />
        </div>
        <CambiarPassword />
      </div>
      <div style={{ marginTop: 20 }}>
        <Disclaimer icon={Info}>
          Acerca del sistema: el Portal Clínico TT muestra parámetros fisiológicos (frecuencia cardiaca,
          SpO2 y HRV) asociados a la ansiedad como apoyo al especialista. No emite diagnósticos: la
          interpretación clínica de los datos corresponde al profesional de salud.
        </Disclaimer>
      </div>
    </div>
  );
}

function DatosCuenta({ perfil, onPerfilActualizado }) {
  const [editando, setEditando] = useState(false);
  const [nombre, setNombre] = useState('');
  const [guardando, setGuardando] = useState(false);
  const [aviso, setAviso] = useState(null); // { tone, texto }

  const empezarEdicion = () => {
    setNombre(perfil.nombre || '');
    setAviso(null);
    setEditando(true);
  };

  const guardar = async (e) => {
    e.preventDefault();
    const limpio = nombre.trim();
    if (!limpio) {
      setAviso({ tone: 'altos', texto: 'El nombre no puede quedar vacío.' });
      return;
    }
    if (limpio === perfil.nombre) {
      setEditando(false);
      return;
    }
    setGuardando(true);
    setAviso(null);
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.put(
        `${USUARIOS_URL}/${auth.currentUser.uid}`,
        { nombre: limpio },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      onPerfilActualizado(res.data);
      setEditando(false);
      setAviso({ tone: 'normal', texto: 'Nombre actualizado.' });
    } catch (error) {
      console.error('Error al actualizar el nombre:', error);
      setAviso({ tone: 'altos', texto: error.response?.data?.error || 'No se pudo guardar el nombre. Inténtalo de nuevo.' });
    } finally {
      setGuardando(false);
    }
  };

  return (
    <Card
      title="Datos de la cuenta"
      icon={UserRound}
      actions={!editando && <Button variant="soft" size="sm" icon={Pencil} onClick={empezarEdicion}>Editar nombre</Button>}
    >
      <div className="ui-profile-identity">
        <Avatar nombre={perfil.nombre} size={56} />
        <div style={{ minWidth: 0 }}>
          <div className="ui-profile-name">{perfil.nombre}</div>
          <div style={{ marginTop: 6 }}><Badge tone="primary" dot={false}>Especialista</Badge></div>
        </div>
      </div>

      {editando ? (
        <form onSubmit={guardar}>
          <Field
            id="perfil-nombre"
            label="Nombre"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            maxLength={100}
            autoFocus
            disabled={guardando}
          />
          <div style={{ display: 'flex', gap: 8, marginBottom: aviso ? 16 : 0 }}>
            <Button type="submit" icon={Save} disabled={guardando}>{guardando ? 'Guardando…' : 'Guardar'}</Button>
            <Button variant="secondary" icon={X} disabled={guardando} onClick={() => { setEditando(false); setAviso(null); }}>
              Cancelar
            </Button>
          </div>
        </form>
      ) : (
        <Field id="perfil-email" label="Correo electrónico" value={perfil.email || ''} disabled readOnly
          help="El correo no se puede cambiar desde el portal." />
      )}

      {aviso && <Alert tone={aviso.tone} icon={aviso.tone === 'altos' ? CircleAlert : CheckCircle2}>{aviso.texto}</Alert>}
    </Card>
  );
}

function CodigoCard({ codigo }) {
  const [copiado, setCopiado] = useState(false);

  const copiar = async () => {
    try {
      await navigator.clipboard.writeText(codigo);
      setCopiado(true);
      setTimeout(() => setCopiado(false), 2000);
    } catch (error) {
      console.error('No se pudo copiar el código:', error);
    }
  };

  return (
    <Card title="Código de vinculación" icon={KeyRound} subtitle="Compártelo con tus pacientes para que se vinculen desde la app.">
      {codigo ? (
        <div className="ui-code-box">
          <span className="ui-mono ui-code-value">{codigo}</span>
          <Button variant="secondary" size="sm" icon={copiado ? Check : Copy} onClick={copiar}>
            {copiado ? 'Copiado' : 'Copiar'}
          </Button>
        </div>
      ) : (
        <p className="ui-muted" style={{ margin: 0 }}>Tu cuenta aún no tiene código de vinculación.</p>
      )}
      <p className="ui-caption" style={{ marginTop: 12 }}>
        Cada paciente puede estar vinculado a un solo especialista. Solo verás los indicadores fisiológicos
        de los pacientes vinculados a ti.
      </p>
    </Card>
  );
}

function CambiarPassword() {
  const [actual, setActual] = useState('');
  const [nueva, setNueva] = useState('');
  const [confirmacion, setConfirmacion] = useState('');
  const [guardando, setGuardando] = useState(false);
  const [aviso, setAviso] = useState(null);

  const cambiar = async (e) => {
    e.preventDefault();
    setAviso(null);
    if (!actual || !nueva || !confirmacion) {
      setAviso({ tone: 'altos', texto: 'Completa los tres campos.' });
      return;
    }
    if (nueva.length < MIN_PASSWORD) {
      setAviso({ tone: 'altos', texto: `La nueva contraseña debe tener al menos ${MIN_PASSWORD} caracteres.` });
      return;
    }
    if (nueva !== confirmacion) {
      setAviso({ tone: 'altos', texto: 'La confirmación no coincide con la nueva contraseña.' });
      return;
    }
    if (nueva === actual) {
      setAviso({ tone: 'altos', texto: 'La nueva contraseña debe ser distinta de la actual.' });
      return;
    }

    setGuardando(true);
    try {
      // Firebase exige una sesión reciente para updatePassword; reautenticar
      // con la contraseña actual evita el error auth/requires-recent-login y
      // confirma que quien cambia la contraseña es el dueño de la cuenta.
      const usuario = auth.currentUser;
      const credencial = EmailAuthProvider.credential(usuario.email, actual);
      await reauthenticateWithCredential(usuario, credencial);
      await updatePassword(usuario, nueva);
      setActual('');
      setNueva('');
      setConfirmacion('');
      setAviso({ tone: 'normal', texto: 'Contraseña actualizada. Úsala la próxima vez que inicies sesión.' });
    } catch (error) {
      console.error('Error al cambiar la contraseña:', error);
      setAviso({ tone: 'altos', texto: mensajeErrorPassword(error) });
    } finally {
      setGuardando(false);
    }
  };

  return (
    <Card title="Cambiar contraseña" icon={Lock} subtitle="Por seguridad te pedimos tu contraseña actual.">
      <form onSubmit={cambiar}>
        <Field id="pw-actual" label="Contraseña actual" type="password" autoComplete="current-password"
          value={actual} onChange={(e) => setActual(e.target.value)} disabled={guardando} />
        <Field id="pw-nueva" label="Nueva contraseña" type="password" autoComplete="new-password"
          value={nueva} onChange={(e) => setNueva(e.target.value)} disabled={guardando}
          help={`Mínimo ${MIN_PASSWORD} caracteres.`} />
        <Field id="pw-confirmacion" label="Confirmar nueva contraseña" type="password" autoComplete="new-password"
          value={confirmacion} onChange={(e) => setConfirmacion(e.target.value)} disabled={guardando} />
        <Button type="submit" icon={Lock} disabled={guardando}>
          {guardando ? 'Actualizando…' : 'Actualizar contraseña'}
        </Button>
      </form>
      {aviso && (
        <div style={{ marginTop: 16 }}>
          <Alert tone={aviso.tone} icon={aviso.tone === 'altos' ? CircleAlert : CheckCircle2}>{aviso.texto}</Alert>
        </div>
      )}
    </Card>
  );
}

export default PerfilEspecialista;
