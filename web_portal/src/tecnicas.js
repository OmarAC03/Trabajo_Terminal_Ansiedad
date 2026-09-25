// Técnicas de relajación que existen en la app, identificadas por un slug
// fijo. Los ids deben coincidir EXACTAMENTE con `Tecnica.id` en
// app_ansiedad/lib/screens/tecnicas_screen.dart y con TECNICAS_EJERCICIO en
// backend/validation.js (el backend rechaza cualquier otro).
export const TECNICAS = [
  { id: 'respiracion_478', titulo: 'Respiración 4-7-8' },
  { id: 'relajacion_muscular', titulo: 'Relajación muscular progresiva' },
  { id: 'grounding_54321', titulo: 'Grounding 5-4-3-2-1' },
  { id: 'visualizacion_guiada', titulo: 'Visualización guiada' },
];

export const tituloTecnica = (id) => TECNICAS.find((t) => t.id === id)?.titulo || id;
