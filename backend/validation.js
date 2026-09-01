const { ValidationError } = require('./errors');

const ESTADOS_ANSIEDAD = ['Alta', 'Moderada', 'Baja'];
const ROLES = ['paciente', 'especialista'];

function esStringNoVacio(valor) {
  return typeof valor === 'string' && valor.trim().length > 0;
}

function esNumeroFinito(valor) {
  return typeof valor === 'number' && Number.isFinite(valor);
}

function requerirString(valor, campo) {
  if (!esStringNoVacio(valor)) {
    throw new ValidationError(`El campo "${campo}" es obligatorio y debe ser texto no vacío.`);
  }
  return valor.trim();
}

function requerirNumeroEnRango(valor, campo, { min, max }) {
  if (!esNumeroFinito(valor)) {
    throw new ValidationError(`El campo "${campo}" es obligatorio y debe ser un número.`);
  }
  if (valor < min || valor > max) {
    throw new ValidationError(`El campo "${campo}" debe estar entre ${min} y ${max}.`);
  }
  return valor;
}

/** POST /api/lecturas — lectura biométrica individual o resumen de sesión. */
function validarLectura(body) {
  return {
    paciente_id: requerirString(body.paciente_id, 'paciente_id'),
    bpm: requerirNumeroEnRango(body.bpm, 'bpm', { min: 0, max: 300 }),
    spo2: requerirNumeroEnRango(body.spo2, 'spo2', { min: 0, max: 100 }),
    hrv: requerirNumeroEnRango(body.hrv, 'hrv', { min: 0, max: 300 }),
    score_ansiedad: requerirNumeroEnRango(body.score_ansiedad, 'score_ansiedad', { min: 0, max: 100 }),
    estado_ansiedad: (() => {
      if (!ESTADOS_ANSIEDAD.includes(body.estado_ansiedad)) {
        throw new ValidationError(`El campo "estado_ansiedad" debe ser uno de: ${ESTADOS_ANSIEDAD.join(', ')}.`);
      }
      return body.estado_ansiedad;
    })(),
  };
}

/** POST /api/usuarios — registro tras crear la cuenta en Firebase. */
function validarUsuarioNuevo(body) {
  const rol = body.rol === undefined || body.rol === null ? 'paciente' : body.rol;
  if (!ROLES.includes(rol)) {
    throw new ValidationError(`El campo "rol" debe ser uno de: ${ROLES.join(', ')}.`);
  }
  return {
    id: requerirString(body.id, 'id'),
    nombre: requerirString(body.nombre, 'nombre'),
    email: requerirString(body.email, 'email'),
    rol,
  };
}

/** PUT /api/usuarios/:id — único campo editable desde la app. */
function validarNombre(body) {
  return requerirString(body.nombre, 'nombre');
}

/** Evento de socket `enviar_mensaje`. */
function validarMensajeChat(data) {
  return {
    paciente_id: requerirString(data && data.paciente_id, 'paciente_id'),
    texto: requerirString(data && data.texto, 'texto'),
    tipo_mensaje: esStringNoVacio(data && data.tipo_mensaje) ? data.tipo_mensaje.trim() : 'texto',
  };
}

module.exports = {
  validarLectura,
  validarUsuarioNuevo,
  validarNombre,
  validarMensajeChat,
};
