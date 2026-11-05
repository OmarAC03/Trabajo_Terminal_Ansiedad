// Solicitudes de eliminación de cuenta en el portal del admin (Bloque 1,
// paso 3: RF-19 / RF-34). Funciones puras, sin React ni red: se prueban con
// Jest (solicitudes.test.js). Las filas vienen de
// GET /api/admin/solicitudes-eliminacion (pendientes primero).

// Lo mismo que hace el backend al atender (backend/eliminacion.js). Se muestra
// antes de confirmar.
export const SE_BORRA = [
  'Sus sesiones de medición, respuestas EVA y GAD-7 y lecturas.',
  'Su conversación con el especialista, los ejercicios asignados, y las notas clínicas y marcadores del especialista.',
  'Su cuenta de acceso (ya no podrá iniciar sesión y su correo queda libre) y el registro de notificaciones de su teléfono.',
];
export const SE_CONSERVA = [
  'Una fila anónima ("Cuenta eliminada", sin nombre ni correo) con la fecha de registro.',
  'El registro de su consentimiento y de esta solicitud, como evidencia.',
  'Las entradas de la bitácora sobre la cuenta (quién, qué acción y cuándo; sin datos clínicos).',
];

export const contarPendientes = (lista) => (lista || []).filter((s) => s.estado === 'pendiente').length;

/** Solo se atienden solicitudes pendientes de cuentas de paciente. */
export const puedeAtender = (solicitud) => solicitud.estado === 'pendiente' && solicitud.rol === 'paciente';

/**
 * Confirmación escribiendo el correo de la cuenta (sin importar mayúsculas
 * ni espacios a los lados). Un correo vacío nunca confirma.
 */
export function confirmacionValida(escrito, email) {
  const a = (escrito || '').trim().toLowerCase();
  const b = (email || '').trim().toLowerCase();
  return a !== '' && a === b;
}

export function textoEstado(solicitud) {
  return solicitud.estado === 'pendiente' ? 'Pendiente' : 'Atendida';
}
