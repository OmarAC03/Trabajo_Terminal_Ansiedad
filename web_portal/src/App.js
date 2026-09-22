import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Activity, RefreshCw, LogOut } from 'lucide-react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from './firebase';
import Login from './Login';
import RegistroEspecialista from './RegistroEspecialista';
import PacientesList from './PacientesList';

const API_URL = "https://tt-ansiedad-backend.onrender.com/api/pacientes";

function App() {
  // undefined = todavía no sabemos si hay sesión, null = no hay sesión.
  const [usuario, setUsuario] = useState(undefined);
  const [pacientes, setPacientes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorAcceso, setErrorAcceso] = useState('');
  // 'login' | 'registro'. Mientras es 'registro' no se carga el dashboard:
  // Firebase abre sesión al crear la cuenta, pero la fila en `usuarios` aún
  // no existe hasta que el backend termina el registro.
  const [vista, setVista] = useState('login');

  useEffect(() => onAuthStateChanged(auth, setUsuario), []);

  const fetchData = async () => {
    if (!auth.currentUser) return;
    try {
      const token = await auth.currentUser.getIdToken();
      const response = await axios.get(API_URL, { headers: { Authorization: `Bearer ${token}` } });
      setPacientes(response.data);
      setErrorAcceso('');
    } catch (error) {
      if (error.response?.status === 403) {
        setErrorAcceso('Tu cuenta no tiene permiso de especialista para ver estos datos.');
      }
      console.error("Error al obtener datos:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!usuario || vista === 'registro') return;
    fetchData();
    const interval = setInterval(fetchData, 15000); // Actualiza cada 15 seg
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [usuario, vista]);

  if (usuario === undefined) {
    return <div style={styles.center}>Cargando...</div>;
  }
  if (vista === 'registro') {
    return (
      <RegistroEspecialista
        onVolver={() => setVista('login')}
        onRegistrado={() => setVista('login')}
      />
    );
  }
  if (usuario === null) {
    return <Login onIrARegistro={() => setVista('registro')} />;
  }

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}><Activity color="#1E6AFB" size={32} /> Portal Clínico TT</h1>
        <div style={styles.headerActions}>
          <button onClick={fetchData} style={styles.refreshBtn}>
            <RefreshCw size={20} /> Actualizar
          </button>
          <button onClick={() => signOut(auth)} style={styles.logoutBtn}>
            <LogOut size={20} /> Salir
          </button>
        </div>
      </header>

      <main style={styles.main}>
        {errorAcceso && <div style={styles.errorBanner}>{errorAcceso}</div>}
        {loading ? (
          <div style={styles.center}>Cargando pacientes...</div>
        ) : (
          <PacientesList pacientes={pacientes} />
        )}
      </main>
    </div>
  );
}

// Estilos básicos (CSS-in-JS para rapidez)
const styles = {
  container: { backgroundColor: '#f6f8fb', minHeight: '100vh', fontFamily: 'Segoe UI, sans-serif' },
  header: { backgroundColor: '#fff', padding: '20px 40px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', boxShadow: '0 2px 10px rgba(0,0,0,0.05)' },
  title: { display: 'flex', alignItems: 'center', gap: '12px', margin: 0, color: '#1a1a1a' },
  headerActions: { display: 'flex', gap: '12px' },
  refreshBtn: { display: 'flex', gap: '8px', padding: '10px 20px', borderRadius: '8px', border: 'none', backgroundColor: '#1E6AFB', color: '#fff', cursor: 'pointer' },
  logoutBtn: { display: 'flex', gap: '8px', padding: '10px 20px', borderRadius: '8px', border: '1px solid #ddd', backgroundColor: '#fff', color: '#444', cursor: 'pointer' },
  errorBanner: { backgroundColor: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', padding: '12px 20px', borderRadius: '10px', marginBottom: '20px' },
  main: { padding: '40px' },
  center: { textAlign: 'center', marginTop: '50px', color: '#666' }
};

export default App;