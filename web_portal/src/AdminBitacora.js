import { useEffect, useMemo, useState } from 'react';
import axios from 'axios';
import { RefreshCw, ScrollText, ShieldAlert, CircleAlert, Search, ChevronDown } from 'lucide-react';
import { auth } from './firebase';
import { PageHeader, Card, Button, Badge, Alert, Disclaimer, Field, Select } from './ui/components';
import { plural } from './PacientesComun';
import { API_BASE } from './config';
import {
  ACCIONES, textoAccion, toneAccion, textoRol, nombreDe, textoDetalle, parametrosConsulta, rangoValido,
} from './bitacora';

const BITACORA_URL = `${API_BASE}/api/admin/bitacora`;
const USUARIOS_URL = `${API_BASE}/api/admin/usuarios`;

const formatoFecha = (fecha) =>
  new Date(fecha).toLocaleString('es-MX', {
    day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit',
  });

const SIN_FILTROS = { desde: '', hasta: '', usuario: '', accion: '' };

// Sección "Bitácora" del admin (Bloque 2, paso 1: WEB-RF-31 / RNF-WEB-05).
// Solo lectura: quién hizo qué, sobre quién y cuándo. La tabla no tiene
// contenido clínico (lo garantiza el backend). Los filtros se aplican con
// "Buscar"; "Cargar más" pide la página siguiente con el cursor.
function AdminBitacora() {
  const [filas, setFilas] = useState([]);
  const [siguiente, setSiguiente] = useState(null);
  const [usuarios, setUsuarios] = useState([]);
  const [filtros, setFiltros] = useState(SIN_FILTROS);
  const [aplicados, setAplicados] = useState(SIN_FILTROS);
  const [loading, setLoading] = useState(true);
  const [cargandoMas, setCargandoMas] = useState(false);
  const [error, setError] = useState('');

  const nombres = useMemo(() => new Map(usuarios.map((u) => [u.id, u.nombre])), [usuarios]);

  const pedir = async (conFiltros, antesDe) => {
    const token = await auth.currentUser.getIdToken();
    const res = await axios.get(BITACORA_URL, {
      headers: { Authorization: `Bearer ${token}` },
      params: parametrosConsulta(conFiltros, antesDe),
    });
    return res.data;
  };

  const buscar = async (conFiltros) => {
    setError('');
    setLoading(true);
    try {
      const datos = await pedir(conFiltros, null);
      setFilas(datos.filas);
      setSiguiente(datos.siguiente);
      setAplicados(conFiltros);
    } catch (e) {
      console.error('Error al obtener la bitácora:', e);
      setError(e.response?.data?.error || 'No se pudo cargar la bitácora. Inténtalo de nuevo con "Actualizar".');
    } finally {
      setLoading(false);
    }
  };

  const cargarMas = async () => {
    setCargandoMas(true);
    setError('');
    try {
      const datos = await pedir(aplicados, siguiente);
      setFilas((previas) => [...previas, ...datos.filas]);
      setSiguiente(datos.siguiente);
    } catch (e) {
      console.error('Error al cargar más de la bitácora:', e);
      setError('No se pudieron cargar más entradas. Inténtalo de nuevo.');
    } finally {
      setCargandoMas(false);
    }
  };

  useEffect(() => {
    buscar(SIN_FILTROS);
    // La lista de cuentas alimenta el filtro "Usuario" y los nombres del
    // detalle (especialista anterior / nuevo).
    (async () => {
      try {
        const token = await auth.currentUser.getIdToken();
        const res = await axios.get(USUARIOS_URL, { headers: { Authorization: `Bearer ${token}` } });
        setUsuarios(res.data);
      } catch (e) {
        console.error('No se pudo obtener la lista de usuarios para el filtro:', e);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const cambiar = (campo) => (e) => setFiltros((f) => ({ ...f, [campo]: e.target.value }));
  const rangoOk = rangoValido(filtros);

  const alBuscar = (e) => {
    e.preventDefault();
    if (rangoOk) buscar(filtros);
  };

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader
        title="Bitácora"
        subtitle="Accesos a datos clínicos y acciones sobre las cuentas"
        actions={<Button icon={RefreshCw} onClick={() => buscar(aplicados)}>Actualizar</Button>}
      />

      <div className="ui-stack" style={{ gap: 12, marginBottom: 20 }}>
        {error && <Alert tone="altos" icon={CircleAlert}>{error}</Alert>}
        <Disclaimer icon={ShieldAlert}>
          Registro de solo lectura: quién hizo qué, sobre qué cuenta y cuándo. No incluye contenido clínico.
          Las entradas no se pueden editar ni borrar.
        </Disclaimer>
      </div>

      <Card className="ui-card-flush" title="Entradas" icon={ScrollText} subtitle="Más recientes primero">
        <form className="ui-filtros" onSubmit={alBuscar}>
          <Field id="bitacora-desde" label="Desde" type="date" value={filtros.desde} onChange={cambiar('desde')} />
          <Field
            id="bitacora-hasta"
            label="Hasta"
            type="date"
            value={filtros.hasta}
            onChange={cambiar('hasta')}
            help={rangoOk ? undefined : '"Desde" no puede ser posterior a "Hasta".'}
          />
          <Select id="bitacora-usuario" label="Usuario" value={filtros.usuario} onChange={cambiar('usuario')}>
            <option value="">Todos</option>
            {usuarios.map((u) => (
              <option key={u.id} value={u.id}>{u.nombre} · {textoRol(u.rol)}</option>
            ))}
          </Select>
          <Select id="bitacora-accion" label="Acción" value={filtros.accion} onChange={cambiar('accion')}>
            <option value="">Todas</option>
            {Object.keys(ACCIONES).map((a) => (
              <option key={a} value={a}>{textoAccion(a)}</option>
            ))}
          </Select>
          <div className="ui-filtros-acciones">
            <Button type="submit" icon={Search} disabled={!rangoOk || loading}>Buscar</Button>
            <Button
              variant="secondary"
              onClick={() => { setFiltros(SIN_FILTROS); buscar(SIN_FILTROS); }}
              disabled={loading}
            >
              Limpiar
            </Button>
          </div>
        </form>

        {loading ? (
          <div className="ui-empty">Cargando bitácora…</div>
        ) : filas.length === 0 ? (
          <div className="ui-empty">No hay entradas con estos filtros.</div>
        ) : (
          <>
            <div className="ui-table-wrap">
              <table className="ui-table">
                <thead>
                  <tr>
                    <th>Fecha</th>
                    <th>Quién</th>
                    <th>Acción</th>
                    <th>Sobre</th>
                    <th>Detalle</th>
                  </tr>
                </thead>
                <tbody>
                  {filas.map((f) => (
                    <tr key={f.id}>
                      <td className="ui-muted" style={{ whiteSpace: 'nowrap' }}>{formatoFecha(f.fecha)}</td>
                      <td>
                        <div className="ui-person-name">{nombreDe(f.actor_id, f.actor_nombre, nombres)}</div>
                        <div className="ui-person-sub">{textoRol(f.actor_rol)}</div>
                      </td>
                      <td><Badge tone={toneAccion(f.accion)}>{textoAccion(f.accion)}</Badge></td>
                      <td>
                        {f.objetivo_id ? (
                          <>
                            <div className="ui-person-name">{nombreDe(f.objetivo_id, f.objetivo_nombre, nombres)}</div>
                            <div className="ui-person-sub">{textoRol(f.objetivo_rol)}</div>
                          </>
                        ) : '—'}
                      </td>
                      <td className="ui-muted">{textoDetalle(f, nombres) || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="ui-table-footer">
              <span className="ui-muted">{plural(filas.length, 'entrada mostrada', 'entradas mostradas')}</span>
              {siguiente && (
                <Button variant="secondary" size="sm" icon={ChevronDown} onClick={cargarMas} disabled={cargandoMas}>
                  {cargandoMas ? 'Cargando…' : 'Cargar más'}
                </Button>
              )}
            </div>
          </>
        )}
      </Card>
    </div>
  );
}

export default AdminBitacora;
