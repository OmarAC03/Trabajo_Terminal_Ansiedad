import { Activity } from 'lucide-react';
import { Avatar } from './components';
import './ui.css';

// Estructura base del portal (Fase 2e): sidebar a la izquierda con secciones
// de navegación, barra superior con el usuario y el área de contenido.
//
// `secciones`: [{ titulo, items: [{ id, label, icon, onClick? }] }]. Un item
// con `onClick` propio (p. ej. "Salir") no cambia la sección activa.
function Layout({ secciones, activa, onNavegar, usuarioNombre, usuarioRol, children }) {
  return (
    <div className="ui-shell">
      <aside className="ui-sidebar">
        <div className="ui-brand">
          <span className="ui-brand-logo"><Activity size={18} /></span>
          <span>Portal <span className="ui-brand-accent">Clínico TT</span></span>
        </div>
        <nav className="ui-nav" aria-label="Navegación principal">
          {secciones.map((seccion) => (
            <div key={seccion.titulo}>
              <div className="ui-nav-section">{seccion.titulo}</div>
              {seccion.items.map(({ id, label, icon: Icon, onClick }) => (
                <button
                  key={id}
                  type="button"
                  className={`ui-nav-item${activa === id ? ' is-active' : ''}`}
                  aria-current={activa === id ? 'page' : undefined}
                  onClick={onClick || (() => onNavegar(id))}
                >
                  {Icon && <Icon size={18} />}
                  {label}
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
