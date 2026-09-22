import { useState } from 'react';
import axios from 'axios';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { auth } from './firebase';

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
    <div style={styles.container}>
      <form onSubmit={handleSubmit} style={styles.card}>
        <h1 style={styles.title}>Portal Clínico TT</h1>
        <p style={styles.subtitle}>Registro de especialista</p>
        <input
          type="text"
          placeholder="Nombre completo"
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          style={styles.input}
          required
        />
        <input
          type="email"
          placeholder="Correo"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          style={styles.input}
          required
        />
        <input
          type="password"
          placeholder="Contraseña (mínimo 6 caracteres)"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          style={styles.input}
          required
        />
        <input
          type="password"
          placeholder="Código de institución"
          value={codigoInstitucion}
          onChange={(e) => setCodigoInstitucion(e.target.value)}
          style={styles.input}
          required
        />
        {error && <p style={styles.error}>{error}</p>}
        <button type="submit" disabled={loading} style={styles.button}>
          {loading ? 'Registrando...' : 'Registrarme'}
        </button>
        <button type="button" onClick={onVolver} disabled={loading} style={styles.linkButton}>
          Ya tengo cuenta — Iniciar sesión
        </button>
      </form>
    </div>
  );
}

const styles = {
  container: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f6f8fb',
    fontFamily: 'Segoe UI, sans-serif',
  },
  card: {
    backgroundColor: '#fff',
    padding: '40px',
    borderRadius: '15px',
    boxShadow: '0 4px 6px rgba(0,0,0,0.05)',
    width: '320px',
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  title: { margin: 0, color: '#1a1a1a', textAlign: 'center' },
  subtitle: { margin: '0 0 10px', color: '#666', textAlign: 'center', fontSize: '13px' },
  input: { padding: '10px 12px', borderRadius: '8px', border: '1px solid #ddd', fontSize: '14px' },
  button: {
    padding: '10px 20px',
    borderRadius: '8px',
    border: 'none',
    backgroundColor: '#1E6AFB',
    color: '#fff',
    cursor: 'pointer',
    fontSize: '14px',
  },
  linkButton: {
    padding: '4px',
    border: 'none',
    backgroundColor: 'transparent',
    color: '#1E6AFB',
    cursor: 'pointer',
    fontSize: '13px',
  },
  error: { color: '#ef4444', fontSize: '13px', margin: 0 },
};

export default RegistroEspecialista;
