import { Armchair, BookOpen, PenLine, CloudLightning, Tag } from 'lucide-react';
import { evaSobre10, nivelEva, etiquetaAccesibleEva, TITULO_EVA, textoContextoEva } from './sesiones';

// EVA del paciente en el portal: una cara (de neutro a ámbar, sin rojo) y el
// número sobre 10, y el contexto como ícono + texto (nunca solo el ícono).
// Ningún texto visible pone etiqueta a la ansiedad: la cara solo acompaña al
// número, que es lo que reportó el paciente.

// Boca y cejas de cada cara (viewBox 24×24, mismo trazo que lucide).
const CARAS = {
  tranquila: { boca: 'M8 14.5 Q12 18.5 16 14.5' },
  leve: { boca: 'M8.5 15 Q12 17 15.5 15' },
  moderada: { boca: 'M8.5 15.5 H15.5' },
  alta: { boca: 'M8.5 16.5 Q12 14.5 15.5 16.5' },
  muy_alta: { boca: 'M8 17.5 Q12 13.5 16 17.5', cejas: 'M7.5 8 L10 9 M16.5 8 L14 9' },
};

/** Cara SVG del nivel; decorativa (el valor accesible lo lleva quien la usa). */
export function CaraEva({ valor, size = 18 }) {
  const nivel = nivelEva(valor);
  if (!nivel) return null;
  const { boca, cejas } = CARAS[nivel];
  return (
    <svg
      className={`eva-cara eva-${nivel}`}
      data-nivel={nivel}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <circle cx="12" cy="12" r="10" className="eva-cara-fondo" />
      <line x1="9" y1="10.5" x2="9.01" y2="10.5" />
      <line x1="15" y1="10.5" x2="15.01" y2="10.5" />
      {cejas && <path d={cejas} />}
      <path d={boca} />
    </svg>
  );
}

/** Cara + "7.4/10", con tooltip y aria-label. Omitida → "—". */
export function ValorEva({ valor, grande = false }) {
  if (valor == null) return <span className="ui-muted">—</span>;
  const etiqueta = etiquetaAccesibleEva(valor);
  return (
    <span className={`eva-valor${grande ? ' eva-valor-grande' : ''}`} role="img" aria-label={etiqueta} title={TITULO_EVA}>
      <CaraEva valor={valor} size={grande ? 32 : 18} />
      <span><span className="ui-num">{evaSobre10(valor)}</span><span className="ui-unit">/10</span></span>
    </span>
  );
}

const ICONOS_CONTEXTO = {
  reposo: Armchair,
  estudiando: BookOpen,
  antes_examen: PenLine,
  despues_estresor: CloudLightning,
  otro: Tag,
};

/** Ícono + texto del contexto; sin contexto no se dibuja nada. */
export function ContextoEva({ clave }) {
  if (clave == null) return null;
  const Icono = ICONOS_CONTEXTO[clave] ?? Tag;
  return (
    <span className="eva-contexto">
      <Icono size={15} aria-hidden="true" focusable="false" />
      <span>{textoContextoEva(clave)}</span>
    </span>
  );
}
