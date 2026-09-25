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

/** POST /api/especialistas — registro de especialista con código de institución. */
function validarEspecialistaNuevo(body) {
  return {
    nombre: requerirString(body.nombre, 'nombre'),
    email: requerirString(body.email, 'email'),
    codigo_institucion: requerirString(body.codigo_institucion, 'codigo_institucion'),
  };
}

/** PUT /api/usuarios/:id — único campo editable desde la app. */
function validarNombre(body) {
  return requerirString(body.nombre, 'nombre');
}

/** POST /api/vinculacion — código que el paciente ingresa para vincularse a
 * su especialista. Se normaliza a mayúsculas porque así se generan los
 * códigos (ver ALFABETO_CODIGO en server.js) y el paciente puede tipearlo en
 * minúsculas sin que falle por eso. */
function validarCodigoVinculacion(body) {
  return {
    codigo_vinculacion: requerirString(body.codigo_vinculacion, 'codigo_vinculacion').toUpperCase(),
  };
}

/** Evento de socket `enviar_mensaje`. */
const MAX_LARGO_MENSAJE = 2000;

function validarMensajeChat(data) {
  const texto = requerirString(data && data.texto, 'texto');
  if (texto.length > MAX_LARGO_MENSAJE) {
    throw new ValidationError(`El mensaje no puede superar ${MAX_LARGO_MENSAJE} caracteres.`);
  }
  return {
    paciente_id: requerirString(data && data.paciente_id, 'paciente_id'),
    texto,
    tipo_mensaje: esStringNoVacio(data && data.tipo_mensaje) ? data.tipo_mensaje.trim() : 'texto',
  };
}

/** POST /api/ejercicios — ejercicio que el especialista asigna a un paciente.
 * Es una técnica de la app (por su slug) O un texto libre, nunca ambos ni
 * ninguno (mismo criterio que el CHECK chk_ejercicio_origen de la tabla).
 * Los slugs deben coincidir EXACTAMENTE con `Tecnica.id` en
 * app_ansiedad/lib/screens/tecnicas_screen.dart y con web_portal/src/tecnicas.js. */
const TECNICAS_EJERCICIO = ['respiracion_478', 'relajacion_muscular', 'grounding_54321', 'visualizacion_guiada'];
const MAX_LARGO_EJERCICIO = 500;
const MAX_LARGO_NOTA = 1000;

function textoOpcional(valor, campo, maxLargo) {
  if (valor === undefined || valor === null) return null;
  if (typeof valor !== 'string') {
    throw new ValidationError(`El campo "${campo}" debe ser texto.`);
  }
  const limpio = valor.trim();
  if (limpio.length > maxLargo) {
    throw new ValidationError(`El campo "${campo}" no puede superar ${maxLargo} caracteres.`);
  }
  return limpio.length > 0 ? limpio : null;
}

function validarEjercicioAsignado(body) {
  const tecnicaId = textoOpcional(body.tecnica_id, 'tecnica_id', 50);
  const textoPersonalizado = textoOpcional(body.texto_personalizado, 'texto_personalizado', MAX_LARGO_EJERCICIO);

  if ((tecnicaId === null) === (textoPersonalizado === null)) {
    throw new ValidationError('Indica una técnica de la lista o un ejercicio personalizado (solo uno de los dos).');
  }
  if (tecnicaId !== null && !TECNICAS_EJERCICIO.includes(tecnicaId)) {
    throw new ValidationError(`El campo "tecnica_id" debe ser uno de: ${TECNICAS_EJERCICIO.join(', ')}.`);
  }

  return {
    paciente_id: requerirString(body.paciente_id, 'paciente_id'),
    tecnica_id: tecnicaId,
    texto_personalizado: textoPersonalizado,
    nota: textoOpcional(body.nota, 'nota', MAX_LARGO_NOTA),
  };
}

module.exports = {
  validarLectura,
  validarUsuarioNuevo,
  validarEspecialistaNuevo,
  validarNombre,
  validarCodigoVinculacion,
  validarMensajeChat,
  validarEjercicioAsignado,
};
