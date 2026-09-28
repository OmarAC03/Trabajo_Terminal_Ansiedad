import './ui.css';

// Componentes base del portal (Fase 2e). Presentacionales, sin estado de red:
// cada pantalla decide qué datos mostrar. `tone` es una de
// 'primary' | 'normal' | 'elevados' | 'altos' | 'neutral' (ver tokens.css).

const clases = (...lista) => lista.filter(Boolean).join(' ');

export function PageHeader({ title, subtitle, actions }) {
  return (
    <div className="ui-page-header">
      <div>
        <h1 className="ui-page-title">{title}</h1>
        {subtitle && <p className="ui-page-subtitle">{subtitle}</p>}
      </div>
      {actions && <div style={{ display: 'flex', gap: 12 }}>{actions}</div>}
    </div>
  );
}

export function Card({ title, subtitle, icon: Icon, actions, children, className }) {
  const conEncabezado = title || subtitle || actions;
  return (
    <section className={clases('ui-card', className)}>
      {conEncabezado && (
        <div className="ui-card-header">
          <div>
            {title && (
              <h2 className="ui-card-title">
                {Icon && <Icon size={18} />}
                {title}
              </h2>
            )}
            {subtitle && <p className="ui-card-subtitle">{subtitle}</p>}
          </div>
          {actions}
        </div>
      )}
      <div className="ui-card-body">{children}</div>
    </section>
  );
}

// Tarjeta de KPI al estilo del mockup: etiqueta, valor grande, pista de color
// e icono en un chip suave.
export function KpiCard({ label, value, hint, hintTone, icon: Icon, tone = 'primary' }) {
  return (
    <section className="ui-card ui-kpi">
      <div className="ui-kpi-top">
        <span className="ui-kpi-label">{label}</span>
        {Icon && (
          <span className={clases('ui-icon-chip', `tone-${tone}`)}>
            <Icon size={20} />
          </span>
        )}
      </div>
      <div className="ui-kpi-value">{value}</div>
      {hint && <div className={clases('ui-kpi-hint', hintTone && `tone-${hintTone}`)}>{hint}</div>}
    </section>
  );
}

export function Button({ variant = 'primary', size, icon: Icon, children, className, ...props }) {
  return (
    <button
      type="button"
      className={clases('ui-btn', `ui-btn-${variant}`, size === 'sm' && 'ui-btn-sm', className)}
      {...props}
    >
      {Icon && <Icon size={size === 'sm' ? 14 : 18} />}
      {children}
    </button>
  );
}

// Badge de estado. Para el semáforo usar los tonos 'normal' | 'elevados' |
// 'altos' con las etiquetas Normal / Elevados / Altos (nunca diagnóstico).
export function Badge({ tone = 'neutral', dot = true, children }) {
  return (
    <span className={clases('ui-badge', `tone-${tone}`)}>
      {dot && <span className="ui-badge-dot" />}
      {children}
    </span>
  );
}

export function iniciales(nombre) {
  const partes = (nombre || '').trim().split(/\s+/).filter(Boolean);
  if (partes.length === 0) return '?';
  return partes
    .slice(0, 2)
    .map((p) => p[0].toUpperCase())
    .join('');
}

// `tone` opcional para teñirlo con el color de un estado (tabla de pacientes).
export function Avatar({ nombre, size = 36, tone }) {
  return (
    <span
      className={clases('ui-avatar', tone && `tone-${tone}`)}
      style={{ width: size, height: size, fontSize: size * 0.38 }}
    >
      {iniciales(nombre)}
    </span>
  );
}

export function Field({ label, help, id, ...inputProps }) {
  return (
    <div className="ui-field">
      <label className="ui-label" htmlFor={id}>{label}</label>
      <input id={id} className="ui-input" {...inputProps} />
      {help && <span className="ui-help">{help}</span>}
    </div>
  );
}

// Mensaje de éxito o error dentro de una tarjeta.
export function Alert({ tone = 'primary', icon: Icon, children }) {
  return (
    <div className={clases('ui-alert', `tone-${tone}`)} role={tone === 'altos' ? 'alert' : 'status'}>
      {Icon && <Icon size={16} style={{ flexShrink: 0, marginTop: 1 }} />}
      <span>{children}</span>
    </div>
  );
}

export function Disclaimer({ icon: Icon, children }) {
  return (
    <div className="ui-disclaimer">
      {Icon && <Icon size={16} style={{ flexShrink: 0, marginTop: 1 }} />}
      <span>{children}</span>
    </div>
  );
}
