import { useState } from 'react';
import axios from 'axios';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { CircleAlert, UserPlus } from 'lucide-react';
import { auth } from './firebase';
import AuthLayout from './ui/AuthLayout';
import { Alert, Button, Field } from './ui/components';

const API_URL = "https://tt-ansiedad-backend.onrender.com/api/especialistas";

const ERRORES_FIREBASE = {
  'auth/email-already-in-use': 'Ya existe una cuenta con ese correo.',
  'auth/invalid-email': 'El correo no es válido.',
  'auth/weak-password': 'La contraseña debe tener al menos 6 caracteres.',
};

function RegistroEspecialista({ onVolver, onRegistrado }) {
  const [nombre, setNombre] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [codigoInstitucion, setCodigoInstitucion] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    let credencial;
    try {
      credencial = await createUserWithEmailAndPassword(auth, email, password);
    } catch (err) {
      setError(ERRORES_FIREBASE[err.code] || 'No se pudo crear la cuenta. Intenta de nuevo.');
      setLoading(false);
      return;
    }

    try {
      const token = await credencial.user.getIdToken();
      await axios.post(
        API_URL,
        { nombre, email, codigo_institucion: codigoInstitucion },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      onRegistrado();
    } catch (err) {
      // El backend rechazó el registro (p. ej. código de institución
      // incorrecto): borramos la cuenta de Firebase recién creada para no
      // dejarla huérfana y que el usuario pueda reintentar con el mismo correo.
      try {
        await credencial.user.delete();
      } catch (errBorrado) {
        await signOut(auth);
      }
      setError(err.response?.data?.error || 'No se pudo completar el registro. Intenta de nuevo.');
      setLoading(false);
    }
  };

  return (
    <AuthLayout
      title="Registro de especialista"
      subtitle="Crea tu cuenta con el código que te entregó tu institución."
      footer={
        <>
          ¿Ya tienes cuenta?{' '}
          <Button variant="link" onClick={onVolver} disabled={loading}>Iniciar sesión</Button>
        </>
      }
    >
      <form onSubmit={handleSubmit}>
        <Field
          id="registro-nombre"
          label="Nombre completo"
          type="text"
          autoComplete="name"
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          required
        />
        <Field
          id="registro-email"
          label="Correo electrónico"
          type="email"
          autoComplete="email"
          placeholder="nombre@institucion.mx"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <Field
          id="registro-password"
          label="Contraseña"
          type="password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          help="Mínimo 6 caracteres."
          required
        />
        <Field
          id="registro-codigo"
          label="Código de institución"
          type="password"
          autoComplete="off"
          value={codigoInstitucion}
          onChange={(e) => setCodigoInstitucion(e.target.value)}
          help="Te lo entrega tu institución; sin él no se puede crear la cuenta."
          required
        />

        {error && (
          <div className="ui-auth-alert">
            <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
          </div>
        )}

        <Button type="submit" icon={UserPlus} disabled={loading} className="ui-btn-block">
          {loading ? 'Registrando…' : 'Registrarme'}
        </Button>
      </form>
    </AuthLayout>
  );
}

export default RegistroEspecialista;
