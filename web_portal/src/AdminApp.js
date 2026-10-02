import { useState } from 'react';
import { LogOut, Users, UserRound } from 'lucide-react';
import Layout from './ui/Layout';
import AdminUsuarios from './AdminUsuarios';
import PerfilEspecialista from './PerfilEspecialista';

// Portal del administrador (Fase C). App.js lo muestra en lugar del portal de
// especialista cuando el perfil propio trae `rol === 'admin'`; mismo login y
// mismo Layout. Esto es solo la interfaz: la seguridad real es requiereAdmin
// en el backend, que rechaza con 403 cualquier /api/admin/* de otro rol.
function AdminApp({ perfil, onPerfilActualizado, onCerrarSesion }) {
  // 'usuarios' | 'perfil'
  const [seccion, setSeccion] = useState('usuarios');

  const secciones = [
    {
      titulo: 'Administración',
      items: [{ id: 'usuarios', label: 'Usuarios', icon: Users }],
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
      ) : (
        <AdminUsuarios />
      )}
    </Layout>
  );
}

export default AdminApp;
