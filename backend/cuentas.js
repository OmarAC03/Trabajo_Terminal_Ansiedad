const { HttpError } = require('./errors');

// Estado de acceso de las cuentas (Bloque 1, paso 1: suspender / reactivar).
// Lógica pura, sin base ni Firebase: auth.js y admin.js la usan y
// cuentas.test.js la prueba.

// Códigos estables que viajan en `{ error, codigo }`: la app y el portal
// cierran la sesión al recibirlos (no leen el texto).
const CODIGO_SUSPENDIDA = 'cuenta_suspendida';
const CODIGO_ELIMINADA = 'cuenta_eliminada';

/**
 * Motivo por el que una cuenta ya no puede usar la API, o null si puede.
 * `cuenta` es la fila de `usuarios` ({ suspendido, eliminado_en }) o null si
 * aún no existe (el registro la crea después del token): eso no bloquea.
 * La eliminada gana si tuviera ambas marcas, igual que en el panel del admin.
 */
function bloqueoDeCuenta(cuenta) {
  if (!cuenta) return null;
  if (cuenta.eliminado_en) {
    return { codigo: CODIGO_ELIMINADA, mensaje: 'Esta cuenta fue eliminada.' };
  }
  if (cuenta.suspendido) {
    return { codigo: CODIGO_SUSPENDIDA, mensaje: 'Tu cuenta está suspendida. Contacta al administrador.' };
  }
  return null;
}

/**
 * Candados para suspender (`suspender = true`) o reactivar una cuenta. Lanza
 * HttpError 409 si no se permite; si se permite no devuelve nada.
 *   - `adminUid`: quien hace la petición (ya pasó requiereAdmin).
 *   - `objetivo`: la fila de la cuenta ({ id, rol, eliminado_en }).
 *   - `otrosAdminsActivos`: admins activos SIN contar al objetivo (solo
 *     importa al suspender a un admin).
 */
function verificarCambioSuspension({ adminUid, objetivo, suspender, otrosAdminsActivos }) {
  if (objetivo.eliminado_en) {
    throw new HttpError('Esta cuenta está eliminada: no se puede suspender ni reactivar.', 409);
  }
  if (!suspender) return;
  if (objetivo.id === adminUid) {
    throw new HttpError('No puedes suspender tu propia cuenta.', 409);
  }
  // Con el candado de arriba siempre queda quien pide; esto es la defensa por
  // si alguna vez se llama desde otro lado.
  if (objetivo.rol === 'admin' && otrosAdminsActivos < 1) {
    throw new HttpError('No se puede suspender al último administrador activo.', 409);
  }
}

module.exports = { CODIGO_SUSPENDIDA, CODIGO_ELIMINADA, bloqueoDeCuenta, verificarCambioSuspension };
