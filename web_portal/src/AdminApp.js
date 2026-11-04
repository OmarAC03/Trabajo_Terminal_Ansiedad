import { useEffect, useState } from 'react';
import axios from 'axios';
import { LogOut, Users, UserRound, UserX, ScrollText } from 'lucide-react';
import { auth } from './firebase';
import Layout from './ui/Layout';
import AdminUsuarios from './AdminUsuarios';
import AdminSolicitudes from './AdminSolicitudes';
import AdminBitacora from './AdminBitacora';
import PerfilEspecialista from './PerfilEspecialista';
import { API_BASE } from './config';
import { contarPendientes } from './solicitudes';

// Portal del administrador (Fase C). App.js lo muestra en lugar del portal de
// especialista cuando el perfil propio trae `rol === 'admin'`; mismo login y
// mismo Layout. Esto es solo la interfaz: la seguridad real es requiereAdmin
// en el backend, que rechaza con 403 cualquier /api/admin/* de otro rol.
function AdminApp({ perfil, onPerfilActualizado, onCerrarSesion }) {
  // 'usuarios' | 'solicitudes' | 'bitacora' | 'perfil'
  const [seccion, setSeccion] = useState('usuarios');
  // Solicitudes de eliminación pendientes (Bloque 1, paso 3), para el
  // contador del sidebar. Se cuenta al entrar; la sección lo actualiza.
  const [pendientes, setPendientes] = useState(0);

  useEffect(() => {
    (async () => {
      try {
        const token = await auth.currentUser.getIdToken();
        const res = await axios.get(`${API_BASE}/api/admin/solicitudes-eliminacion`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        setPendientes(contarPendientes(res.data));
      } catch (e) {
        console.error('No se pudo contar las solicitudes de eliminación:', e);
      }
    })();
  }, []);

  const secciones = [
    {
      titulo: 'Administración',
      items: [
        { id: 'usuarios', label: 'Usuarios', icon: Users },
        { id: 'solicitudes', label: 'Solicitudes de eliminación', icon: UserX, contador: pendientes },
        { id: 'bitacora', label: 'Bitácora', icon: ScrollText },
      ],
    },
    {
      titulo: 'Cuenta',
      items: [
        { id: 'perfil', label: 'Mi perfil', icon: UserRound },
        { id: 'salir', label: 'Salir', icon: LogOut, onClick: onCerrarSesion },
      ],
    },
  ];

  return (
    <Layout
      secciones={secciones}
      activa={seccion}
      onNavegar={setSeccion}
      usuarioNombre={perfil?.nombre}
      usuarioRol="Administrador"
    >
      {seccion === 'perfil' ? (
        <PerfilEspecialista perfil={perfil} onPerfilActualizado={onPerfilActualizado} esAdmin />
      ) : seccion === 'solicitudes' ? (
        <AdminSolicitudes onPendientes={setPendientes} />
      ) : seccion === 'bitacora' ? (
        <AdminBitacora />
      ) : (
        <AdminUsuarios
          onPropiaEditada={(fila) => onPerfilActualizado({ ...perfil, nombre: fila.nombre, email: fila.email })}
        />
      )}
    </Layout>
  );
}

export default AdminApp;
