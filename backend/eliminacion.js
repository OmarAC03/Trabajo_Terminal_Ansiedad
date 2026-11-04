const { ValidationError, HttpError } = require('./errors');

// Solicitud de eliminación de cuenta (Bloque 1, paso 3: RF-19 / RF-34).
// Lógica pura, sin base ni Firebase: admin.js y server.js la usan y
// eliminacion.test.js la prueba.
//
// Qué pasa al ATENDER una solicitud (decisión aprobada):
//   - se BORRAN los datos clínicos y la comunicación del paciente
//     (BORRADO_PACIENTE, en ese orden por las FK);
//   - la fila de `usuarios` se conserva como "lápida" anonimizada
//     (ANONIMIZAR_USUARIO): la necesitan las FK de `consentimientos` y
//     `solicitudes_eliminacion`, que se CONSERVAN como evidencia;
//   - al final se borra la cuenta de Firebase (lo hace admin.js).
// Solo cuentas de paciente.

// Orden por las FK (C3 del plan, todas sin cascada efectiva porque la fila de
// usuarios no se borra): la EVA apunta a la sesión, así que va primero.
// `mensajes_chat` por paciente_id cubre los dos sentidos de su conversación.
const BORRADO_PACIENTE = Object.freeze([
  {
    tabla: 'respuestas_eva',
    sql: 'DELETE FROM respuestas_eva WHERE sesion_id IN (SELECT id FROM sesiones_medicion WHERE paciente_id = $1)',
  },
  { tabla: 'sesiones_medicion', sql: 'DELETE FROM sesiones_medicion WHERE paciente_id = $1' },
  { tabla: 'respuestas_gad7', sql: 'DELETE FROM respuestas_gad7 WHERE paciente_id = $1' },
  { tabla: 'lecturas_biometricas', sql: 'DELETE FROM lecturas_biometricas WHERE paciente_id = $1' },
  { tabla: 'mensajes_chat', sql: 'DELETE FROM mensajes_chat WHERE paciente_id = $1' },
  { tabla: 'ejercicios_asignados', sql: 'DELETE FROM ejercicios_asignados WHERE paciente_id = $1' },
  // Notas y marcadores del especialista sobre el paciente (Bloque 2): las
  // versiones de las notas se van en cascada (FK ON DELETE CASCADE; el
  // trigger solo impide el UPDATE).
  { tabla: 'notas_clinicas', sql: 'DELETE FROM notas_clinicas WHERE paciente_id = $1' },
  { tabla: 'marcadores_clinicos', sql: 'DELETE FROM marcadores_clinicos WHERE paciente_id = $1' },
]);

// Lo que se conserva de la cuenta: id, rol y fecha_registro. `email` es NOT
// NULL y UNIQUE (C1/C4), por eso un valor único no enrutable en vez de NULL.
const NOMBRE_ELIMINADA = 'Cuenta eliminada';
const emailAnonimo = (id) => `eliminada-${id}@invalid`;

const ANONIMIZAR_USUARIO = `
  UPDATE usuarios
  SET nombre = $2, email = $3, codigo_vinculacion = NULL, especialista_id = NULL, eliminado_en = now()
  WHERE id = $1`;

/** Parámetros de ANONIMIZAR_USUARIO para el paciente `id`. */
function parametrosAnonimizar(id) {
  return [id, NOMBRE_ELIMINADA, emailAnonimo(id)];
}

/** POST /api/solicitud-eliminacion: sin cuerpo (o `{}`). Cualquier campo → 400. */
function validarSolicitudNueva(body) {
  if (body === undefined || body === null) return;
  if (typeof body !== 'object' || Array.isArray(body) || Object.keys(body).length > 0) {
    throw new ValidationError('La solicitud de eliminación no lleva datos.');
  }
}

/**
 * Candados para atender. `usuario` es la fila de la cuenta ({ rol }).
 * Solo pacientes: un especialista (o admin) tiene mensajes y ejercicios de
 * otros pacientes como autor y no se elimina por esta vía.
 */
function verificarAtencion(usuario) {
  if (!usuario) {
    throw new HttpError('La cuenta de la solicitud ya no existe.', 409);
  }
  if (usuario.rol !== 'paciente') {
    throw new HttpError('Solo se pueden eliminar cuentas de paciente por esta vía.', 409);
  }
}

/** Lo que ve el paciente de su solicitud más reciente (o null). */
function vistaSolicitudPaciente(fila) {
  if (!fila) return null;
  return { estado: fila.estado, fecha_solicitud: fila.fecha_solicitud, atendida_en: fila.atendida_en ?? null };
}

module.exports = {
  BORRADO_PACIENTE,
  NOMBRE_ELIMINADA,
  ANONIMIZAR_USUARIO,
  emailAnonimo,
  parametrosAnonimizar,
  validarSolicitudNueva,
  verificarAtencion,
  vistaSolicitudPaciente,
};
