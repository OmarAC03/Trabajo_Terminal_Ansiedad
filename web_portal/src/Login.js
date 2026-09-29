import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { CircleAlert, LogIn } from 'lucide-react';
import { auth } from './firebase';
import AuthLayout from './ui/AuthLayout';
import { Alert, Button, Field } from './ui/components';

// Solo se separan los errores que no dicen nada de la cuenta (red, límite de
// intentos). Correo inexistente y contraseña incorrecta dan el mismo mensaje
// para no revelar qué correos están registrados.
function mensajeErrorLogin(error) {
  switch (error?.code) {
    case 'auth/network-request-failed':
      return 'Sin conexión. Revisa tu red e inténtalo de nuevo.';
    case 'auth/too-many-requests':
      return 'Demasiados intentos. Espera unos minutos o restablece tu contraseña.';
    default:
      return 'Correo o contraseña incorrectos.';
  }
}

function Login({ onIrARegistro, onOlvidePassword }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err) {
      setError(mensajeErrorLogin(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout
      title="Iniciar sesión"
      subtitle="Acceso para especialistas"
      footer={
        <>
          ¿Eres especialista y no tienes cuenta?{' '}
          <Button variant="link" onClick={onIrARegistro}>Regístrate</Button>
        </>
      }
    >
      <form onSubmit={handleSubmit}>
        <Field
          id="login-email"
          label="Correo electrónico"
          type="email"
          autoComplete="email"
          placeholder="nombre@institucion.mx"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />

        <div className="ui-field">
          <div className="ui-auth-label-row">
            <label className="ui-label" htmlFor="login-password">Contraseña</label>
            <Button variant="link" onClick={() => onOlvidePassword(email.trim())}>
              ¿Olvidaste tu contraseña?
            </Button>
          </div>
          <input
            id="login-password"
            className="ui-input"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>

        {error && (
          <div className="ui-auth-alert">
            <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
          </div>
        )}

        <Button type="submit" icon={LogIn} disabled={loading} className="ui-btn-block">
          {loading ? 'Entrando…' : 'Entrar'}
        </Button>
      </form>
    </AuthLayout>
  );
}

export default Login;
