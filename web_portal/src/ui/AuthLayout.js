import { Activity, Info } from 'lucide-react';
import './ui.css';

// Estructura de las pantallas sin sesión (Fase A, paso 7): Login, Registro y
// Recuperar contraseña. Panel de marca con el alcance del sistema a la
// izquierda y la tarjeta del formulario a la derecha; en pantallas angostas
// queda en una sola columna.
function AuthLayout({ title, subtitle, children, footer }) {
  return (
    <div className="ui-auth">
      <aside className="ui-auth-brand">
        <div className="ui-auth-logo">
          <span className="ui-brand-logo"><Activity size={18} /></span>
          <span>Portal <span className="ui-auth-accent">Clínico TT</span></span>
        </div>
        <div className="ui-auth-pitch">
          <h2 className="ui-auth-pitch-title">Monitoreo de indicadores fisiológicos</h2>
          <p className="ui-auth-pitch-text">
            Consulta la frecuencia cardiaca, SpO2 y HRV de tus pacientes vinculados, asigna ejercicios
            de apoyo y mantén la conversación con ellos desde un solo lugar.
          </p>
        </div>
        <p className="ui-auth-scope">
          <Info size={16} style={{ flexShrink: 0, marginTop: 1 }} />
          <span>
            Herramienta de apoyo al especialista. No emite diagnósticos: la interpretación clínica de los
            datos corresponde al profesional de salud.
          </span>
        </p>
      </aside>

      <main className="ui-auth-main">
        <div className="ui-card ui-auth-card">
          <h1 className="ui-auth-title">{title}</h1>
          {subtitle && <p className="ui-auth-subtitle">{subtitle}</p>}
          {children}
          {footer && <div className="ui-auth-footer">{footer}</div>}
        </div>
      </main>
    </div>
  );
}

export default AuthLayout;
