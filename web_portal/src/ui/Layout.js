import { NOMBRE_APP, NOMBRE_MASCOTA } from '../marca';
import mascota from './avatar_meditando.png';
import { Avatar } from './components';
import './ui.css';

// Estructura base del portal (Fase 2e): sidebar a la izquierda con secciones
// de navegación, barra superior con el usuario y el área de contenido.
//
// `secciones`: [{ titulo, items: [{ id, label, icon, onClick?, contador? }] }].
// Un item con `onClick` propio (p. ej. "Salir") no cambia la sección activa;
// `contador` > 0 se muestra como una pastilla (p. ej. solicitudes pendientes).
function Layout({ secciones, activa, onNavegar, usuarioNombre, usuarioRol, children }) {
  return (
    <div className="ui-shell">
      <aside className="ui-sidebar">
        <div className="ui-brand">
          <span className="ui-brand-mascota"><img src={mascota} alt={NOMBRE_MASCOTA} /></span>
          <span>{NOMBRE_APP}</span>
        </div>
        <nav className="ui-nav" aria-label="Navegación principal">
          {secciones.map((seccion) => (
            <div key={seccion.titulo}>
              <div className="ui-nav-section">{seccion.titulo}</div>
              {seccion.items.map(({ id, label, icon: Icon, onClick, contador }) => (
                <button
                  key={id}
                  type="button"
                  className={`ui-nav-item${activa === id ? ' is-active' : ''}`}
                  aria-current={activa === id ? 'page' : undefined}
                  onClick={onClick || (() => onNavegar(id))}
                >
                  {Icon && <Icon size={18} />}
                  {label}
                  {contador > 0 && <span className="ui-nav-count">{contador}</span>}
                </button>
              ))}
            </div>
          ))}
        </nav>
      </aside>

      <div className="ui-main">
        <header className="ui-topbar">
          <div className="ui-topbar-user">
            <span className="ui-topbar-name">{usuarioNombre || 'Especialista'}</span>
            {usuarioRol && <span className="ui-topbar-role">{usuarioRol}</span>}
          </div>
          <Avatar nombre={usuarioNombre} />
        </header>
        <main className="ui-content">{children}</main>
      </div>
    </div>
  );
}

export default Layout;
