// Semáforo de indicadores fisiológicos, compartido por la lista y el detalle
// de pacientes (mismo criterio que backend/app_ansiedad).
//
// El backend sigue enviando estado_ansiedad = 'Alta' | 'Moderada' | 'Baja';
// aquí solo cambia el texto visible (ver MARCO_ALCANCE_Y_LENGUAJE.md, sección 2).
// Colores iguales a los tokens de src/ui/tokens.css (GUIA_ESTILO_PORTAL.md).

export const getStatusColor = (status) => {
  if (status === 'Alta') return '#dc2626';
  if (status === 'Moderada') return '#d97706';
  if (status === 'Baja') return '#16a34a';
  return '#94a3b8'; // sin lecturas aún
};

export const getStatusLabel = (status) => {
  if (status === 'Alta') return 'Altos';
  if (status === 'Moderada') return 'Elevados';
  if (status === 'Baja') return 'Normal';
  return 'Sin lecturas';
};

// Tono de los componentes de src/ui/ (Badge, KpiCard, Avatar...).
export const getStatusTone = (status) => {
  if (status === 'Alta') return 'altos';
  if (status === 'Moderada') return 'elevados';
  if (status === 'Baja') return 'normal';
  return 'sin-datos';
};

// Orden para listar pacientes: Altos → Elevados → Normal → Sin lecturas.
export const getStatusOrden = (status) => {
  if (status === 'Alta') return 0;
  if (status === 'Moderada') return 1;
  if (status === 'Baja') return 2;
  return 3;
};
