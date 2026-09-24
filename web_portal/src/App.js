import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Activity, RefreshCw, LogOut, Info } from 'lucide-react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from './firebase';
import Login from './Login';
import RegistroEspecialista from './RegistroEspecialista';
import PacientesList from './PacientesList';
import CodigoVinculacion from './CodigoVinculacion';

const API_URL = "https://tt-ansiedad-backend.onrender.com/api/pacientes";
const USUARIOS_URL = "https://tt-ansiedad-backend.onrender.com/api/usuarios";

function App() {
  // undefined = todavía no sabemos si hay sesión, null = no hay sesión.
  const [usuario, setUsuario] = useState(undefined);
  const [pacientes, setPacientes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorAcceso, setErrorAcceso] = useState('');
  const [codigoVinculacion, setCodigoVinculacion] = useState(null);
  // 'login' | 'registro'. Mientras es 'registro' no se carga el dashboard:
  // Firebase abre sesión al crear la cuenta, pero la fila en `usuarios` aún
  // no existe hasta que el backend termina el registro.
  const [vista, setVista] = useState('login');

  useEffect(() => onAuthStateChanged(auth, setUsuario), []);

  // Pide la lista de pacientes y el perfil propio (para el codigo_vinculacion)
  // en cada vuelta del polling. Antes el perfil se pedía una sola vez al
  // entrar; si esa única petición fallaba (p. ej. el cold start de Render,
  // ver sección 7 de CONTEXTO_PROYECTO.md) el código no se volvía a intentar
  // y la barra se quedaba vacía toda la sesión, aunque pacientes sí se
  // recuperaba en la siguiente vuelta. Con Promise.allSettled cada resultado
  // se procesa por separado: uno puede fallar sin bloquear al otro, y ambos
  // se reintentan solos cada 15s.
  const fetchData = async () => {
    if (!auth.currentUser) return;
    let token;
    try {
      token = await auth.currentUser.getIdToken();
    } catch (error) {
      console.error("Error al obtener el token de sesión:", error);
      setLoading(false);
      return;
    }

    const [pacientesResultado, perfilResultado] = await Promise.allSettled([
      axios.get(API_URL, { headers: { Authorization: `Bearer ${token}` } }),
      axios.get(`${USUARIOS_URL}/${auth.currentUser.uid}`, { headers: { Authorization: `Bearer ${token}` } }),
    ]);

    if (pacientesResultado.status === 'fulfilled') {
      setPacientes(pacientesResultado.value.data);
      setErrorAcceso('');
    } else {
      const error = pacientesResultado.reason;
      if (error.response?.status === 403) {
        setErrorAcceso('Tu cuenta no tiene permiso de especialista para ver estos datos.');
      }
      console.error("Error al obtener pacientes:", error);
    }

    if (perfilResultado.status === 'fulfilled') {
      setCodigoVinculacion(perfilResultado.value.data.codigo_vinculacion || null);
    } else {
      console.error("Error al obtener el código de vinculación:", perfilResultado.reason);
    }

    setLoading(false);
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

      <div style={styles.codigoBar}>
        <CodigoVinculacion codigo={codigoVinculacion} />
      </div>

      <main style={styles.main}>
        <div style={styles.disclaimer}>
          <Info size={16} style={{ flexShrink: 0, marginTop: '1px' }} />
          <span>
            Este sistema monitorea parámetros fisiológicos (frecuencia cardiaca, SpO2 y HRV) asociados
            a la ansiedad como apoyo al especialista. Los datos fisiológicos son de apoyo: la
            interpretación y el diagnóstico corresponden al profesional de salud.
          </span>
        </div>
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
  disclaimer: { display: 'flex', gap: '8px', alignItems: 'flex-start', backgroundColor: '#f1f5f9', color: '#64748b', fontSize: '13px', lineHeight: 1.4, padding: '10px 16px', borderRadius: '10px', marginBottom: '20px' },
  codigoBar: { paddingTop: '20px' },
  main: { padding: '40px' },
  center: { textAlign: 'center', marginTop: '50px', color: '#666' }
};

export default App;