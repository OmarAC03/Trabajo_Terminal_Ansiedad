import React, { useEffect, useRef, useState } from 'react';
import axios from 'axios';
import { LogOut, Users, UserRound, LayoutDashboard } from 'lucide-react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from './firebase';
import Login from './Login';
import RegistroEspecialista from './RegistroEspecialista';
import RecuperarPassword from './RecuperarPassword';
import PacientesList from './PacientesList';
import PacienteDetalle from './PacienteDetalle';
import PerfilEspecialista from './PerfilEspecialista';
import Dashboard from './Dashboard';
import AdminApp from './AdminApp';
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
  // 'login' | 'registro' | 'recuperar'. Mientras es 'registro' no se carga el
  // dashboard: Firebase abre sesión al crear la cuenta, pero la fila en
  // `usuarios` aún no existe hasta que el backend termina el registro.
  const [vista, setVista] = useState('login');
  // Correo escrito en el login, para prellenar "¿Olvidaste tu contraseña?".
  const [emailRecuperar, setEmailRecuperar] = useState('');
  // Paciente abierto en el detalle (Fase 2a), o null para ver la lista. Se
  // guarda solo el id y el objeto se toma de `pacientes`, así el detalle
  // recibe la "última lectura" fresca de cada vuelta del polling.
  const [pacienteSeleccionadoId, setPacienteSeleccionadoId] = useState(null);
  // Se incrementa con el botón "Actualizar" para que el detalle recargue.
  const [recargaDetalle, setRecargaDetalle] = useState(0);
  const pacienteSeleccionado = pacientes.find((p) => p.id === pacienteSeleccionadoId) || null;
  // Rol de la cuenta (Fase C): undefined = aún no se sabe; 'admin' muestra
  // <AdminApp>; cualquier otro valor (o null si no hay perfil) sigue con el
  // portal de especialista. El ref lo lee fetchData dentro del intervalo.
  const [rol, setRol] = useState(undefined);
  const rolRef = useRef(undefined);

  useEffect(() => onAuthStateChanged(auth, (u) => {
    rolRef.current = undefined;
    setRol(undefined);
    setUsuario(u);
  }), []);

  // Pide la lista de pacientes y el perfil propio (nombre y codigo_vinculacion)
  // en cada vuelta del polling. Antes el perfil se pedía una sola vez al
  // entrar; si esa única petición fallaba (p. ej. el cold start de Render,
  // ver sección 7 de CONTEXTO_PROYECTO.md) el código no se volvía a intentar
  // y la barra se quedaba vacía toda la sesión, aunque pacientes sí se
  // recuperaba en la siguiente vuelta. Con Promise.allSettled cada resultado
  // se procesa por separado: uno puede fallar sin bloquear al otro, y ambos
  // se reintentan solos cada 15s.
  const fetchData = async () => {
    // El admin no usa este polling: <AdminApp> carga sus propios datos.
    if (!auth.currentUser || rolRef.current === 'admin') return;
    let token;
    try {
      token = await auth.currentUser.getIdToken();
    } catch (error) {
      console.error("Error al obtener el token de sesión:", error);
      setLoading(false);
      return;
    }

    // Fase C: la primera vez se pide SOLO el perfil propio, para saber el rol
    // antes de pedir /api/pacientes (un admin no debe pedirlo). Ya conocido el
    // rol, las siguientes vueltas son las de siempre.
    if (rolRef.current === undefined) {
      let rolCuenta;
      try {
        const res = await axios.get(`${USUARIOS_URL}/${auth.currentUser.uid}`, { headers: { Authorization: `Bearer ${token}` } });
        setPerfil(res.data);
        rolCuenta = res.data.rol;
      } catch (error) {
        console.error("Error al obtener el perfil:", error);
        // Sin respuesta (sin red / cold start de Render): se reintenta en la
        // siguiente vuelta. Con respuesta (p. ej. 404 sin fila): se sigue con
        // el portal de especialista, que muestra el aviso de acceso como antes.
        if (!error.response) return;
        rolCuenta = null;
      }
      rolRef.current = rolCuenta;
      setRol(rolCuenta);
      if (rolCuenta === 'admin') return;
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
    if (vista === 'recuperar') {
      return <RecuperarPassword emailInicial={emailRecuperar} onVolver={() => setVista('login')} />;
    }
    return (
      <Login
        onIrARegistro={() => setVista('registro')}
        onOlvidePassword={(email) => { setEmailRecuperar(email); setVista('recuperar'); }}
      />
    );
  }

  const cerrarSesion = () => {
    setPacienteSeleccionadoId(null);
    setSeccion('dashboard');
    setPerfil(null);
    setPacientes([]);
    setErrorAcceso('');
    signOut(auth);
  };

  // Mientras no se sabe el rol no se muestra ningún portal, para que un admin
  // no vea por un instante el de especialista (ni al revés).
  if (rol === undefined) {
    return <div style={styles.center}>Cargando...</div>;
  }
  if (rol === 'admin') {
    return <AdminApp perfil={perfil} onPerfilActualizado={setPerfil} onCerrarSesion={cerrarSesion} />;
  }

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
      ) : pacienteSeleccionado ? (
        // Se abre desde el Dashboard o desde Pacientes; "Volver" regresa a esa
        // sección. Trae su propio disclaimer de alcance (sección 3 del marco).
        <PacienteDetalle
          paciente={pacienteSeleccionado}
          recarga={recargaDetalle}
          onVolver={() => setPacienteSeleccionadoId(null)}
          onActualizar={actualizar}
          errorAcceso={errorAcceso}
        />
      ) : seccion === 'pacientes' ? (
        <PacientesList
          pacientes={pacientes}
          loading={loading}
          perfil={perfil}
          errorAcceso={errorAcceso}
          onSeleccionar={(p) => setPacienteSeleccionadoId(p.id)}
          onActualizar={actualizar}
        />
      ) : (
        <Dashboard
          pacientes={pacientes}
          loading={loading}
          perfil={perfil}
          errorAcceso={errorAcceso}
          onSeleccionar={(p) => setPacienteSeleccionadoId(p.id)}
          onActualizar={actualizar}
        />
      )}
    </Layout>
  );
}

// Estilos básicos (CSS-in-JS para rapidez). Las pantallas nuevas usan la base
// de src/ui/ (tokens.css + components.js); estos quedan hasta el rediseño.
const styles = {
  center: { textAlign: 'center', marginTop: '50px', color: '#666' }
};

export default App;
