import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from './firebase';

function Login({ onIrARegistro }) {
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
      setError('Correo o contraseña incorrectos.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <form onSubmit={handleSubmit} style={styles.card}>
        <h1 style={styles.title}>Portal Clínico TT</h1>
        <p style={styles.subtitle}>Acceso para especialistas</p>
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
          placeholder="Contraseña"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          style={styles.input}
          required
        />
        {error && <p style={styles.error}>{error}</p>}
        <button type="submit" disabled={loading} style={styles.button}>
          {loading ? 'Entrando...' : 'Entrar'}
        </button>
        <button type="button" onClick={onIrARegistro} style={styles.linkButton}>
          ¿Eres especialista? Regístrate
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

export default Login;
