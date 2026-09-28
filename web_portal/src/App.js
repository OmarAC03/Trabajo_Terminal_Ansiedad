import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { RefreshCw, LogOut, Info, Users, UserRound, LayoutDashboard } from 'lucide-react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from './firebase';
import Login from './Login';
import RegistroEspecialista from './RegistroEspecialista';
import PacientesList from './PacientesList';
import PacienteDetalle from './PacienteDetalle';
import CodigoVinculacion from './CodigoVinculacion';
import PerfilEspecialista from './PerfilEspecialista';
import Dashboard from './Dashboard';
import Layout from './ui/Layout';

const API_URL = "https://tt-ansiedad-backend.onrender.com/api/pacientes";
const USUARIOS_URL = "https://tt-ansiedad-backend.onrender.com/api/usuarios";

function App() {
  // undefined = todavía no sabemos si hay sesión, null = no hay sesión.
  const [usuario, setUsuario] = useState(undefined);
  const [pacientes, setPacientes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorAcceso, setErrorAcceso] = useState('');
  // Perfil propio (nombre, email, codigo_vinculacion) de GET /api/usuarios/:uid.
  const [perfil, setPerfil] = useState(null);
  // Sección elegida en el sidebar: 'dashboard' | 'pacientes' | 'perfil'.
  const [seccion, setSeccion] = useState('dashboard');
  // 'login' | 'registro'. Mientras es 'registro' no se carga el dashboard:
  // Firebase abre sesión al crear la cuenta, pero la fila en `usuarios` aún
  // no existe hasta que el backend termina el registro.
  const [vista, setVista] = useState('login');
  // Paciente abierto en el detalle (Fase 2a), o null para ver la lista. Se
  // guarda solo el id y el objeto se toma de `pacientes`, así el detalle
  // recibe la "última lectura" fresca de cada vuelta del polling.
  const [pacienteSeleccionadoId, setPacienteSeleccionadoId] = useState(null);
  // Se incrementa con el botón "Actualizar" para que el detalle recargue.
  const [recargaDetalle, setRecargaDetalle] = useState(0);
  const pacienteSeleccionado = pacientes.find((p) => p.id === pacienteSeleccionadoId) || null;

  useEffect(() => onAuthStateChanged(auth, setUsuario), []);

  // Pide la lista de pacientes y el perfil propio (nombre y codigo_vinculacion)
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
      setPerfil(perfilResultado.value.data);
    } else {
      console.error("Error al obtener el perfil:", perfilResultado.reason);
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

  const cerrarSesion = () => {
    setPacienteSeleccionadoId(null);
    setSeccion('dashboard');
    setPerfil(null);
    signOut(auth);
  };

  const actualizar = () => {
    fetchData();
    setRecargaDetalle((n) => n + 1);
  };

  const secciones = [
    {
      titulo: 'Principal',
      items: [
        { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
        { id: 'pacientes', label: 'Pacientes', icon: Users },
      ],
    },
    {
      titulo: 'Cuenta',
      items: [
        { id: 'perfil', label: 'Mi perfil', icon: UserRound },
        { id: 'salir', label: 'Salir', icon: LogOut, onClick: cerrarSesion },
      ],
    },
  ];

  const navegar = (id) => {
    // "Dashboard" y "Pacientes" en el sidebar siempre cierran el detalle.
    if (id === 'dashboard' || id === 'pacientes') setPacienteSeleccionadoId(null);
    setSeccion(id);
  };

  return (
    <Layout
      secciones={secciones}
      activa={seccion}
      onNavegar={navegar}
      usuarioNombre={perfil?.nombre}
      usuarioRol="Especialista"
    >
      {seccion === 'perfil' ? (
        <PerfilEspecialista perfil={perfil} onPerfilActualizado={setPerfil} />
      ) : seccion === 'dashboard' && !pacienteSeleccionado ? (
        <Dashboard
          pacientes={pacientes}
          loading={loading}
          perfil={perfil}
          errorAcceso={errorAcceso}
          onSeleccionar={(p) => setPacienteSeleccionadoId(p.id)}
          onActualizar={actualizar}
        />
      ) : (
        // Lista y detalle aún con sus estilos viejos (pasos 2 y 3 de la Fase A).
        // El detalle se abre desde el Dashboard o desde la lista.
        <>
          <div style={styles.toolbar}>
            <CodigoVinculacion codigo={perfil?.codigo_vinculacion || null} />
            <button
              onClick={actualizar}
              style={styles.refreshBtn}
            >
              <RefreshCw size={20} /> Actualizar
            </button>
          </div>

          <div style={styles.main}>
            {errorAcceso && <div style={styles.errorBanner}>{errorAcceso}</div>}
            {pacienteSeleccionado ? (
              // El detalle trae su propio disclaimer de alcance (sección 3 del marco).
              <PacienteDetalle
                paciente={pacienteSeleccionado}
                recarga={recargaDetalle}
                onVolver={() => setPacienteSeleccionadoId(null)}
              />
            ) : (
              <>
                <div style={styles.disclaimer}>
                  <Info size={16} style={{ flexShrink: 0, marginTop: '1px' }} />
                  <span>
                    Este sistema monitorea parámetros fisiológicos (frecuencia cardiaca, SpO2 y HRV) asociados
                    a la ansiedad como apoyo al especialista. Los datos fisiológicos son de apoyo: la
                    interpretación y el diagnóstico corresponden al profesional de salud.
                  </span>
                </div>
                {loading ? (
                  <div style={styles.center}>Cargando pacientes...</div>
                ) : (
                  <PacientesList pacientes={pacientes} onSeleccionar={(p) => setPacienteSeleccionadoId(p.id)} />
                )}
              </>
            )}
          </div>
        </>
      )}
    </Layout>
  );
}

// Estilos básicos (CSS-in-JS para rapidez). Las pantallas nuevas usan la base
// de src/ui/ (tokens.css + components.js); estos quedan hasta el rediseño.
const styles = {
  // Fila con el código de vinculación y "Actualizar" (antes vivían en el header).
  toolbar: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap', padding: '20px 40px 0' },
  refreshBtn: { display: 'flex', gap: '8px', marginLeft: 'auto', padding: '10px 20px', borderRadius: '8px', border: 'none', backgroundColor: '#1E6AFB', color: '#fff', cursor: 'pointer' },
  errorBanner: { backgroundColor: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', padding: '12px 20px', borderRadius: '10px', marginBottom: '20px' },
  disclaimer: { display: 'flex', gap: '8px', alignItems: 'flex-start', backgroundColor: '#f1f5f9', color: '#64748b', fontSize: '13px', lineHeight: 1.4, padding: '10px 16px', borderRadius: '10px', marginBottom: '20px' },
  main: { padding: '40px' },
  center: { textAlign: 'center', marginTop: '50px', color: '#666' }
};

export default App;
