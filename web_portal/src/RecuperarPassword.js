import { useState } from 'react';
import { sendPasswordResetEmail } from 'firebase/auth';
import { ArrowLeft, CircleAlert, MailCheck, Send } from 'lucide-react';
import { auth } from './firebase';
import AuthLayout from './ui/AuthLayout';
import { Alert, Button, Field } from './ui/components';

// Mismo texto exista o no la cuenta: no se revela qué correos están
// registrados (y Firebase, con la protección contra enumeración activa, ni
// siquiera avisa si el correo no existe).
const MENSAJE_ENVIADO =
  'Si existe una cuenta con ese correo, te enviamos un enlace para restablecer tu contraseña. ' +
  'Revisa también tu carpeta de spam.';

// Devuelve null cuando el resultado debe tratarse como envío exitoso.
function mensajeErrorRecuperar(error) {
  switch (error?.code) {
    case 'auth/user-not-found':
      return null; // Por si la protección contra enumeración está apagada.
    case 'auth/invalid-email':
    case 'auth/missing-email':
      return 'Escribe un correo electrónico válido.';
    case 'auth/too-many-requests':
      return 'Demasiadas solicitudes. Espera unos minutos e inténtalo de nuevo.';
    case 'auth/network-request-failed':
      return 'Sin conexión. Revisa tu red e inténtalo de nuevo.';
    default:
      return 'No se pudo enviar el enlace. Inténtalo de nuevo.';
  }
}

// Restablecer contraseña por correo (HU02). Firebase manda el enlace y
// hospeda la página donde se escribe la contraseña nueva; no pasa por el
// backend ni por la base de datos.
function RecuperarPassword({ emailInicial = '', onVolver }) {
  const [email, setEmail] = useState(emailInicial);
  const [enviando, setEnviando] = useState(false);
  const [enviado, setEnviado] = useState(false);
  const [error, setError] = useState('');

  const enviar = async (e) => {
    e.preventDefault();
    setEnviando(true);
    setError('');
    try {
      auth.languageCode = 'es'; // idioma del correo de Firebase
      await sendPasswordResetEmail(auth, email.trim());
      setEnviado(true);
    } catch (err) {
      const mensaje = mensajeErrorRecuperar(err);
      if (mensaje) {
        console.error('Error al enviar el correo de restablecimiento:', err);
        setError(mensaje);
      } else {
        setEnviado(true);
      }
    } finally {
      setEnviando(false);
    }
  };

  return (
    <AuthLayout
      title="Restablecer contraseña"
      subtitle="Te enviaremos un enlace a tu correo para crear una contraseña nueva."
      footer={
        <Button variant="link" icon={ArrowLeft} onClick={onVolver}>Volver a iniciar sesión</Button>
      }
    >
      <form onSubmit={enviar}>
        <Field
          id="recuperar-email"
          label="Correo electrónico"
          type="email"
          autoComplete="email"
          placeholder="nombre@institucion.mx"
          value={email}
          onChange={(e) => { setEmail(e.target.value); setEnviado(false); }}
          autoFocus={!emailInicial}
          required
        />

        {enviado && (
          <div className="ui-auth-alert">
            <Alert tone="primary" icon={MailCheck}>{MENSAJE_ENVIADO}</Alert>
          </div>
        )}
        {error && (
          <div className="ui-auth-alert">
            <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
          </div>
        )}

        <Button
          type="submit"
          icon={Send}
          disabled={enviando}
          variant={enviado ? 'secondary' : 'primary'}
          className="ui-btn-block"
        >
          {enviando ? 'Enviando…' : enviado ? 'Reenviar enlace' : 'Enviar enlace'}
        </Button>
      </form>
    </AuthLayout>
  );
}

export default RecuperarPassword;
