import { useEffect, useState } from 'react';
import axios from 'axios';
import {
  Search, RefreshCw, Users, UserRound, Stethoscope, ShieldCheck, ShieldAlert, CircleAlert, CheckCircle2, Pencil,
} from 'lucide-react';
import { auth } from './firebase';
import { PageHeader, Card, KpiCard, Button, Badge, Avatar, Alert, Disclaimer } from './ui/components';
import { plural } from './PacientesComun';
import EditarUsuario from './EditarUsuario';

const ADMIN_USUARIOS_URL = 'https://tt-ansiedad-backend.onrender.com/api/admin/usuarios';

// Sección "Usuarios" del admin (Fase C, paso 1): todas las cuentas de
// GET /api/admin/usuarios con búsqueda y filtros por rol y estado, en el
// navegador. Solo datos de cuenta: nunca lecturas, mensajes ni ejercicios.
// Paso 2: botón "Editar" por fila (nombre, correo y especialista del paciente).

const ROLES = {
  paciente: { etiqueta: 'Paciente', filtro: 'Pacientes', tone: 'neutral' },
  especialista: { etiqueta: 'Especialista', filtro: 'Especialistas', tone: 'primary' },
  admin: { etiqueta: 'Administrador', filtro: 'Administradores', tone: 'primary' },
};

// Sin datos fisiológicos en esta pantalla, así que verde/ámbar/rojo no se
// confunden con el semáforo.
const ESTADOS = {
  activa: { etiqueta: 'Activa', filtro: 'Activas', tone: 'normal' },
  suspendida: { etiqueta: 'Suspendida', filtro: 'Suspendidas', tone: 'elevados' },
  eliminada: { etiqueta: 'Eliminada', filtro: 'Eliminadas', tone: 'altos' },
};

// Minúsculas y sin acentos, para que "maria" encuentre "María".
const normalizar = (texto) =>
  (texto || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

const formatoFecha = (fecha) =>
  fecha ? new Date(fecha).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

// `onPropiaEditada`: avisa a AdminApp si el admin editó su propia cuenta, para
// que la barra superior y "Mi perfil" muestren el nombre y correo nuevos.
function AdminUsuarios({ onPropiaEditada }) {
  const [usuarios, setUsuarios] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busqueda, setBusqueda] = useState('');
  const [filtroRol, setFiltroRol] = useState(null);
  const [filtroEstado, setFiltroEstado] = useState(null);
  const [editando, setEditando] = useState(null); // cuenta abierta en el panel
  const [aviso, setAviso] = useState('');

  const cargar = async () => {
    setError('');
    setAviso('');
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.get(ADMIN_USUARIOS_URL, { headers: { Authorization: `Bearer ${token}` } });
      setUsuarios(res.data);
    } catch (e) {
      console.error('Error al obtener los usuarios:', e);
      setError(
        e.response?.status === 403
          ? 'Tu cuenta no tiene permiso de administrador.'
          : 'No se pudo cargar la lista de usuarios. Inténtalo de nuevo con "Actualizar".'
      );
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    cargar();
  }, []);

  const termino = normalizar(busqueda.trim());
  const visibles = usuarios.filter(
    (u) =>
      (filtroRol === null || u.rol === filtroRol) &&
      (filtroEstado === null || u.estado === filtroEstado) &&
      (termino === '' || normalizar(u.nombre).includes(termino) || normalizar(u.email).includes(termino))
  );
  const hayFiltro = termino !== '' || filtroRol !== null || filtroEstado !== null;
  const contar = (rol) => usuarios.filter((u) => u.rol === rol).length;
  const especialistas = usuarios.filter((u) => u.rol === 'especialista');

  // Reemplaza la fila con la respuesta del backend y recarga la lista en
  // segundo plano (una reasignación cambia el conteo de pacientes de dos
  // especialistas).
  const alGuardar = (fila) => {
    setUsuarios((lista) => lista.map((u) => (u.id === fila.id ? fila : u)));
    setEditando(null);
    if (fila.id === auth.currentUser?.uid) onPropiaEditada?.(fila);
    cargar().then(() => setAviso(`Cambios guardados en la cuenta de ${fila.nombre}.`));
  };

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader
        title="Usuarios"
        subtitle={plural(usuarios.length, 'cuenta registrada', 'cuentas registradas')}
        actions={<Button icon={RefreshCw} onClick={cargar}>Actualizar</Button>}
      />

      <div className="ui-stack" style={{ gap: 12, marginBottom: 20 }}>
        {error && <Alert tone="altos" icon={CircleAlert}>{error}</Alert>}
        {aviso && <Alert tone="normal" icon={CheckCircle2}>{aviso}</Alert>}
        <Disclaimer icon={ShieldAlert}>
          Gestión de cuentas. Este panel no da acceso a datos clínicos (lecturas, mensajes ni ejercicios).
        </Disclaimer>
      </div>

      <div className="ui-grid ui-grid-kpi" style={{ marginBottom: 20 }}>
        <KpiCard label="Cuentas" value={usuarios.length} icon={Users} />
        <KpiCard label="Pacientes" value={contar('paciente')} icon={UserRound} tone="neutral" />
        <KpiCard label="Especialistas" value={contar('especialista')} icon={Stethoscope} />
        <KpiCard label="Administradores" value={contar('admin')} icon={ShieldCheck} />
      </div>

      <Card
        className="ui-card-flush"
        title="Cuentas"
        icon={Users}
        subtitle={
          hayFiltro
            ? `${plural(visibles.length, 'resultado', 'resultados')} de ${usuarios.length}`
            : 'En orden alfabético'
        }
      >
        <div className="ui-table-toolbar">
          <label className="ui-search">
            <Search size={16} />
            <span className="sr-only">Buscar usuario</span>
            <input
              type="search"
              className="ui-input"
              placeholder="Buscar por nombre o email"
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
            />
          </label>
          <Segmentado opciones={ROLES} valor={filtroRol} onCambiar={setFiltroRol} etiqueta="Filtrar por rol" />
          <Segmentado opciones={ESTADOS} valor={filtroEstado} onCambiar={setFiltroEstado} etiqueta="Filtrar por estado" />
        </div>

        {loading ? (
          <div className="ui-empty">Cargando usuarios…</div>
        ) : visibles.length === 0 ? (
          <div className="ui-empty">
            {usuarios.length === 0 ? 'No hay cuentas para mostrar.' : 'Ninguna cuenta coincide con la búsqueda o los filtros.'}
          </div>
        ) : (
          <div className="ui-table-wrap">
            <table className="ui-table">
              <thead>
                <tr>
                  <th>Usuario</th>
                  <th>Rol</th>
                  <th>Estado</th>
                  <th>Vinculación</th>
                  <th>Registro</th>
                  <th><span className="sr-only">Acciones</span></th>
                </tr>
              </thead>
              <tbody>
                {visibles.map((u) => (
                  <tr key={u.id}>
                    <td>
                      <div className="ui-person">
                        <Avatar nombre={u.nombre} size={38} />
                        <div>
                          <div className="ui-person-name">
                            {u.nombre}
                            {u.id === auth.currentUser?.uid && <span className="ui-muted"> (tú)</span>}
                          </div>
                          <div className="ui-person-sub">{u.email}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <Badge tone={ROLES[u.rol]?.tone || 'neutral'} dot={false}>{ROLES[u.rol]?.etiqueta || u.rol}</Badge>
                    </td>
                    <td>
                      <Badge tone={ESTADOS[u.estado]?.tone || 'neutral'}>{ESTADOS[u.estado]?.etiqueta || u.estado}</Badge>
                    </td>
                    <td className="ui-muted"><Vinculacion usuario={u} /></td>
                    <td className="ui-muted">{formatoFecha(u.fecha_registro)}</td>
                    <td style={{ textAlign: 'right' }}>
                      <Button
                        variant="soft"
                        size="sm"
                        icon={Pencil}
                        disabled={u.estado === 'eliminada'}
                        title={u.estado === 'eliminada' ? 'Una cuenta eliminada no se puede editar' : undefined}
                        onClick={() => { setAviso(''); setEditando(u); }}
                      >
                        Editar
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {editando && (
        <EditarUsuario
          usuario={editando}
          especialistas={especialistas}
          onCerrar={() => setEditando(null)}
          onGuardado={alGuardar}
        />
      )}
    </div>
  );
}

// Filtro segmentado "Todos" + una opción por clave de `opciones`.
function Segmentado({ opciones, valor, onCambiar, etiqueta }) {
  return (
    <div className="ui-segmented" role="group" aria-label={etiqueta}>
      {[null, ...Object.keys(opciones)].map((clave) => (
        <button
          key={String(clave)}
          type="button"
          className={`ui-segmented-item${valor === clave ? ' is-active' : ''}`}
          aria-pressed={valor === clave}
          onClick={() => onCambiar(clave)}
        >
          {clave === null ? 'Todos' : opciones[clave].filtro}
        </button>
      ))}
    </div>
  );
}

function Vinculacion({ usuario }) {
  if (usuario.rol === 'paciente') {
    return usuario.especialista_nombre ? `Especialista: ${usuario.especialista_nombre}` : 'Sin especialista';
  }
  if (usuario.rol === 'especialista') {
    return plural(usuario.pacientes_vinculados ?? 0, 'paciente vinculado', 'pacientes vinculados');
  }
  return '—';
}

export default AdminUsuarios;
