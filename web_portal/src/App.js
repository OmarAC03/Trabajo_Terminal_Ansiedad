import React, { useEffect, useRef, useState } from 'react';
import axios from 'axios';
import { LogOut, Users, UserRound, LayoutDashboard, MessageCircle, FileText, Info } from 'lucide-react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from './firebase';
import Login from './Login';
import RegistroEspecialista from './RegistroEspecialista';
import RecuperarPassword from './RecuperarPassword';
import PacientesList from './PacientesList';
import PacienteDetalle from './PacienteDetalle';
import PerfilEspecialista from './PerfilEspecialista';
import Dashboard from './Dashboard';
import Mensajes from './Mensajes';
import Reportes from './Reportes';
import AcercaProyecto from './AcercaProyecto';
import AdminApp from './AdminApp';
import Layout from './ui/Layout';
import { API_BASE } from './config';
import { codigoBloqueo, guardarAvisoCierre, MENSAJES_BLOQUEO } from './cuentas';
import { contarPendientes, conversacionesUrl } from './chat';

const API_URL = `${API_BASE}/api/pacientes`;
const USUARIOS_URL = `${API_BASE}/api/usuarios`;

function App() {
  // undefined = todavía no sabemos si hay sesión, null = no hay sesión.
  const [usuario, setUsuario] = useState(undefined);
  const [pacientes, setPacientes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorAcceso, setErrorAcceso] = useState('');
  // Perfil propio (nombre, email, codigo_vinculacion) de GET /api/usuarios/:uid.
  const [perfil, setPerfil] = useState(null);
  // Sección elegida en el sidebar: 'dashboard' | 'pacientes' | 'mensajes' |
  // 'reportes' | 'perfil' | 'acerca'.
  const [seccion, setSeccion] = useState('dashboard');
  // Bandeja de Mensajes (GET /api/especialista/conversaciones), en el mismo
  // polling: así la pastilla del menú se actualiza sola.
  const [conversaciones, setConversaciones] = useState(null);
  const [errorConversaciones, setErrorConversaciones] = useState('');
  const bandejaCargada = useRef(false);
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

  // Bloque 1, paso 1: si el backend responde 403 con `cuenta_suspendida` o
  // `cuenta_eliminada` a CUALQUIER petición (lista, detalle, chat, admin…),
  // se cierra la sesión y el login muestra por qué. Un solo interceptor en
  // vez de revisarlo en cada pantalla.
  useEffect(() => {
    const id = axios.interceptors.response.use(
      (respuesta) => respuesta,
      (error) => {
        const codigo = codigoBloqueo(error);
        if (codigo && auth.currentUser) {
          guardarAvisoCierre(MENSAJES_BLOQUEO[codigo]);
          setPacienteSeleccionadoId(null);
          setSeccion('dashboard');
          setPerfil(null);
          setPacientes([]);
          setConversaciones(null);
          bandejaCargada.current = false;
          setErrorAcceso('');
          signOut(auth);
        }
        return Promise.reject(error);
      }
    );
    return () => axios.interceptors.response.eject(id);
  }, []);

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

    const [pacientesResultado, perfilResultado, conversacionesResultado] = await Promise.allSettled([
      axios.get(API_URL, { headers: { Authorization: `Bearer ${token}` } }),
      axios.get(`${USUARIOS_URL}/${auth.currentUser.uid}`, { headers: { Authorization: `Bearer ${token}` } }),
      axios.get(conversacionesUrl, { headers: { Authorization: `Bearer ${token}` } }),
    ]);
    procesarConversaciones(conversacionesResultado);

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

  function procesarConversaciones(resultado) {
    if (resultado.status === 'fulfilled') {
      bandejaCargada.current = true;
      setConversaciones(resultado.value.data);
      setErrorConversaciones('');
    } else {
      console.error('Error al obtener las conversaciones:', resultado.reason);
      // Sin red se conserva la última bandeja; el aviso solo si nunca cargó.
      if (!bandejaCargada.current) setErrorConversaciones('No se pudieron cargar las conversaciones. Se reintenta solo.');
    }
  }

  // Solo la bandeja (al enviar o recibir un mensaje en la sección Mensajes).
  const recargarConversaciones = async () => {
    if (!auth.currentUser || rolRef.current !== 'especialista') return;
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.get(conversacionesUrl, { headers: { Authorization: `Bearer ${token}` } });
      procesarConversaciones({ status: 'fulfilled', value: res });
    } catch (error) {
      procesarConversaciones({ status: 'rejected', reason: error });
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
    setConversaciones(null);
    bandejaCargada.current = false;
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
        { id: 'mensajes', label: 'Mensajes', icon: MessageCircle, contador: contarPendientes(conversaciones) },
        { id: 'reportes', label: 'Reportes', icon: FileText },
      ],
    },
    {
      titulo: 'Cuenta',
      items: [
        { id: 'perfil', label: 'Mi perfil', icon: UserRound },
        { id: 'acerca', label: 'Acerca del proyecto', icon: Info },
        { id: 'salir', label: 'Salir', icon: LogOut, onClick: cerrarSesion },
      ],
    },
  ];

  const navegar = (id) => {
    // Cualquier sección del sidebar cierra el detalle del paciente.
    setPacienteSeleccionadoId(null);
    setSeccion(id);
  };

  // Desde la bandeja de Mensajes: abre el detalle del paciente.
  const abrirPaciente = (id) => {
    setSeccion('pacientes');
    setPacienteSeleccionadoId(id);
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
      ) : seccion === 'acerca' ? (
        <AcercaProyecto />
      ) : seccion === 'mensajes' ? (
        <Mensajes
          conversaciones={conversaciones}
          cargando={conversaciones === null && !errorConversaciones}
          error={errorConversaciones}
          onActualizar={recargarConversaciones}
          onAbrirPaciente={abrirPaciente}
        />
      ) : seccion === 'reportes' ? (
        <Reportes pacientes={pacientes} />
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
