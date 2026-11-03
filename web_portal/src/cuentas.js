// Estado de las cuentas en el portal (Bloque 1, paso 1: suspender / reactivar).
// Funciones puras, sin React ni red: se prueban con Jest (cuentas.test.js).

// Mismos códigos que backend/cuentas.js. Llegan en `{ error, codigo }` con un
// 403 cuando la cuenta de la sesión ya no puede usar la API.
export const MENSAJES_BLOQUEO = {
  cuenta_suspendida: 'Tu cuenta está suspendida. Contacta al administrador.',
  cuenta_eliminada: 'Esta cuenta fue eliminada.',
};

/** Código de bloqueo de un error de axios, o null si es otro error. */
export function codigoBloqueo(error) {
  const respuesta = error?.response;
  if (respuesta?.status !== 403) return null;
  const codigo = respuesta.data?.codigo;
  return Object.prototype.hasOwnProperty.call(MENSAJES_BLOQUEO, codigo) ? codigo : null;
}

// Aviso para la pantalla de login después de cerrar la sesión a la fuerza.
// Vive en el módulo (no en React) porque al cerrar la sesión App desmonta todo
// y monta Login desde cero; Login lo toma una vez y lo borra.
let avisoCierre = '';
export function guardarAvisoCierre(texto) {
  avisoCierre = texto || '';
}
export function tomarAvisoCierre() {
  const texto = avisoCierre;
  avisoCierre = '';
  return texto;
}

/**
 * Qué puede hacer el admin con el estado de una cuenta (fila de
 * GET /api/admin/usuarios): `accion` = 'suspender' | 'reactivar' | null y,
 * si no se permite, `motivo`. Los candados reales están en el backend; aquí
 * solo se evita ofrecer un botón que el servidor rechazaría.
 */
export function accionEstado(usuario, uidPropio) {
  if (usuario.estado === 'eliminada') {
    return { accion: null, motivo: 'Una cuenta eliminada no se puede suspender ni reactivar.' };
  }
  if (usuario.estado === 'suspendida') {
    return { accion: 'reactivar', motivo: null };
  }
  if (usuario.id === uidPropio) {
    return { accion: null, motivo: 'No puedes suspender tu propia cuenta.' };
  }
  return { accion: 'suspender', motivo: null };
}

/** Consecuencias que se muestran antes de confirmar. */
export function consecuencias(accion, usuario) {
  if (accion === 'suspender') {
    const lista = [
      'No podrá iniciar sesión y sus sesiones abiertas se cerrarán de inmediato, en la app y en el portal.',
      'No se borra ningún dato. Puedes reactivarla cuando quieras.',
    ];
    if (usuario.rol === 'especialista') {
      lista.splice(1, 0, 'Sus pacientes siguen vinculados pero no recibirán respuestas, y su código de vinculación deja de funcionar. Puedes reasignarlos desde "Editar".');
    }
    return lista;
  }
  if (accion === 'reactivar') {
    return ['Podrá volver a iniciar sesión con su misma contraseña.'];
  }
  return [];
}
