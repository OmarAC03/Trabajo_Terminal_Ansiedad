const { ValidationError, AuthError } = require('./errors');

// Consentimiento informado y aviso de privacidad (Bloque 1, paso 2: RN-01,
// RN-02, RNF-06). Lógica pura, sin base: server.js y auth.js la usan y
// consentimiento.test.js la prueba.
//
// Versiones VIGENTES de los dos textos. Deben ser IDÉNTICAS a las de la app
// (`app_ansiedad/lib/contenido/privacidad_textos.dart`). Cambiar una palabra
// del texto = versión nueva aquí y en la app: cada paciente vuelve a aceptar
// (la tabla `consentimientos` guarda una fila por versión aceptada).
//
// Versión 1 publicada (docs/version_final/AVISO_PRIVACIDAD_Y_CONSENTIMIENTO.md).
// Cualquier cambio de versión va aquí y en la app AL MISMO TIEMPO (mismo
// despliegue): con versiones distintas nadie podría aceptar.
const CONFIG_CONSENTIMIENTO = Object.freeze({
  version_aviso: 'privacidad-v1',
  version_consentimiento: 'consentimiento-v1',
});

const CODIGO_CONSENTIMIENTO_REQUERIDO = 'consentimiento_requerido';
const CAMPOS_CONSENTIMIENTO = ['version_aviso', 'version_consentimiento'];

/** Solo el paciente da consentimiento (sus datos de salud son los que se capturan). */
function requiereConsentimiento(rol) {
  return rol === 'paciente';
}

/**
 * POST /api/consentimiento y el campo `consentimiento` de POST /api/usuarios:
 * exactamente las dos versiones, y deben ser las vigentes (aceptar un texto
 * viejo no cuenta: la app debe mostrar el actual).
 */
function validarConsentimiento(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new ValidationError('El consentimiento debe ser un objeto con version_aviso y version_consentimiento.');
  }
  const desconocidos = Object.keys(body).filter((campo) => !CAMPOS_CONSENTIMIENTO.includes(campo));
  if (desconocidos.length > 0) {
    throw new ValidationError(`Campos no permitidos en el consentimiento: ${desconocidos.join(', ')}.`);
  }
  for (const campo of CAMPOS_CONSENTIMIENTO) {
    if (typeof body[campo] !== 'string' || body[campo].trim() === '') {
      throw new ValidationError(`El campo "${campo}" es obligatorio.`);
    }
  }
  if (body.version_aviso !== CONFIG_CONSENTIMIENTO.version_aviso ||
      body.version_consentimiento !== CONFIG_CONSENTIMIENTO.version_consentimiento) {
    throw new ValidationError('El texto aceptado no es la versión vigente. Actualiza la app y vuelve a leerlo.');
  }
  return {
    version_aviso: CONFIG_CONSENTIMIENTO.version_aviso,
    version_consentimiento: CONFIG_CONSENTIMIENTO.version_consentimiento,
  };
}

/**
 * Rutas de captura (sesiones, EVA, GAD-7, lecturas): un paciente sin el
 * consentimiento vigente recibe 403 con `codigo`. `vigente` lo calcula
 * requiereAuth en la misma consulta del rol.
 */
function exigirConsentimiento(rol, vigente) {
  if (requiereConsentimiento(rol) && !vigente) {
    throw new AuthError(
      'Antes de registrar datos necesitas aceptar el aviso de privacidad y el consentimiento.',
      403,
      CODIGO_CONSENTIMIENTO_REQUERIDO
    );
  }
}

/**
 * Respuesta de GET /api/consentimiento. `aceptadoEn` es la fecha de la
 * aceptación de la versión vigente, o null si no la ha aceptado.
 */
function vistaConsentimiento(rol, aceptadoEn) {
  const requerido = requiereConsentimiento(rol);
  return {
    requerido,
    version_aviso: CONFIG_CONSENTIMIENTO.version_aviso,
    version_consentimiento: CONFIG_CONSENTIMIENTO.version_consentimiento,
    aceptado: requerido ? Boolean(aceptadoEn) : false,
    aceptado_en: requerido && aceptadoEn ? aceptadoEn : null,
  };
}

module.exports = {
  CONFIG_CONSENTIMIENTO,
  CODIGO_CONSENTIMIENTO_REQUERIDO,
  requiereConsentimiento,
  validarConsentimiento,
  exigirConsentimiento,
  vistaConsentimiento,
};
