// Semáforo de indicadores fisiológicos, compartido por la lista y el detalle
// de pacientes (mismo criterio que backend/app_ansiedad).
//
// El backend sigue enviando estado_ansiedad = 'Alta' | 'Moderada' | 'Baja';
// aquí solo cambia el texto visible (ver MARCO_ALCANCE_Y_LENGUAJE.md, sección 2).

export const getStatusColor = (status) => {
  if (status === 'Alta') return '#ef4444';
  if (status === 'Moderada') return '#f59e0b';
  if (status === 'Baja') return '#10b981';
  return '#9ca3af'; // sin lecturas aún
};

export const getStatusLabel = (status) => {
  if (status === 'Alta') return 'Altos';
  if (status === 'Moderada') return 'Elevados';
  if (status === 'Baja') return 'Normal';
  return 'Sin datos';
};
