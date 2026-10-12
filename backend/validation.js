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

// --- Edición de cuentas por el admin (Fase C, paso 2) ---
// Largos según las columnas de `usuarios` (varchar(100)).
const MAX_LARGO_NOMBRE = 100;
const MAX_LARGO_EMAIL = 100;
const FORMATO_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// Rol, suspensión y eliminación tienen sus propias rutas: aquí no se aceptan.
const CAMPOS_EDICION_ADMIN = ['nombre', 'email', 'especialista_id'];

/** PUT /api/admin/usuarios/:id — cuerpo parcial: solo los campos que se
 * envían se editan. Devuelve un objeto con los campos presentes, ya
 * normalizados (email sin espacios y en minúsculas; especialista_id puede ser
 * null para desvincular). Las reglas que dependen de la base (cuenta
 * eliminada, especialista válido, correo repetido) viven en admin.js. */
function validarEdicionAdmin(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new ValidationError('El cuerpo debe ser un objeto con los campos a editar.');
  }
  const desconocidos = Object.keys(body).filter((campo) => !CAMPOS_EDICION_ADMIN.includes(campo));
  if (desconocidos.length > 0) {
    throw new ValidationError(
      `Campos no permitidos: ${desconocidos.join(', ')}. Solo se puede editar: ${CAMPOS_EDICION_ADMIN.join(', ')}.`
    );
  }

  const cambios = {};
  if (body.nombre !== undefined) {
    const nombre = requerirString(body.nombre, 'nombre');
    if (nombre.length > MAX_LARGO_NOMBRE) {
      throw new ValidationError(`El nombre no puede pasar de ${MAX_LARGO_NOMBRE} caracteres.`);
    }
    cambios.nombre = nombre;
  }
  if (body.email !== undefined) {
    const email = requerirString(body.email, 'email').toLowerCase();
    if (email.length > MAX_LARGO_EMAIL) {
      throw new ValidationError(`El correo no puede pasar de ${MAX_LARGO_EMAIL} caracteres.`);
    }
    if (!FORMATO_EMAIL.test(email)) {
      throw new ValidationError('El correo no tiene un formato válido.');
    }
    cambios.email = email;
  }
  if (body.especialista_id !== undefined) {
    cambios.especialista_id =
      body.especialista_id === null ? null : requerirString(body.especialista_id, 'especialista_id');
  }

  if (Object.keys(cambios).length === 0) {
    throw new ValidationError('Indica al menos un campo para editar: nombre, email o especialista_id.');
  }
  return cambios;
}

// --- Sesiones de medición (Fase M1) ---
// Los rangos replican los CHECK chk_sesion_* de la tabla `sesiones_medicion`,
// para que un dato malo dé 400 aquí y nunca un error de Postgres (500). El
// mínimo de señal válida vive SOLO aquí (no en la base): puede ajustarse con
// criterio clínico sin migración. El backend valida coherencia, no recalcula
// el RMSSD ni cruza el resumen con la serie (eso queda para la validación, M7).
const CAMPOS_SESION = [
  'fecha_inicio',
  'duracion_total_seg', 'duracion_valida_seg',
  'hrv_rmssd', 'hrv_min', 'hrv_max',
  'bpm_promedio', 'bpm_min', 'bpm_max',
  'spo2_promedio', 'spo2_min', 'spo2_max',
  'indice_calidad', 'serie', 'origen',
];
const CAMPOS_PUNTO_SERIE = ['t', 'bpm', 'spo2', 'hrv'];
const ORIGENES_SESION = ['simulacion', 'sensor'];
const MAX_DURACION_SESION_SEG = 1800;
const MIN_SENAL_VALIDA_SEG = 120; // protocolo: mínimo 2 min de señal limpia
const MAX_PUNTOS_SERIE = 360; // 1800 s / 5 s
const MARGEN_FUTURO_MS = 5 * 60 * 1000; // reloj del celular adelantado
const MAX_ANTIGUEDAD_MS = 7 * 24 * 60 * 60 * 1000; // reenvío offline (M1b)
// ISO 8601 con zona horaria explícita (Z u ±hh:mm): sin zona, la hora se
// interpretaría con la del servidor y la sesión quedaría corrida.
const FORMATO_FECHA_ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/;

function esObjetoPlano(valor) {
  return valor !== null && typeof valor === 'object' && !Array.isArray(valor);
}

function requerirEnteroEnRango(valor, campo, rango) {
  requerirNumeroEnRango(valor, campo, rango);
  if (!Number.isInteger(valor)) {
    throw new ValidationError(`El campo "${campo}" debe ser un número entero.`);
  }
  return valor;
}

// Redondea a la escala de la columna numeric ANTES de comparar, para validar
// exactamente lo que se va a guardar.
function redondear(valor, decimales) {
  const factor = 10 ** decimales;
  return Math.round(valor * factor) / factor;
}

function requerirDecimalEnRango(valor, campo, rango, decimales) {
  requerirNumeroEnRango(valor, campo, rango);
  const redondeado = redondear(valor, decimales);
  if (redondeado < rango.min || redondeado > rango.max) {
    throw new ValidationError(`El campo "${campo}" debe estar entre ${rango.min} y ${rango.max}.`);
  }
  return redondeado;
}

function validarFechaInicio(valor) {
  if (typeof valor !== 'string' || !FORMATO_FECHA_ISO.test(valor)) {
    throw new ValidationError('El campo "fecha_inicio" debe ser una fecha ISO 8601 con zona horaria (ej. 2026-10-11T14:30:00Z).');
  }
  const ms = Date.parse(valor);
  if (Number.isNaN(ms)) {
    throw new ValidationError('El campo "fecha_inicio" no es una fecha válida.');
  }
  const ahora = Date.now();
  if (ms > ahora + MARGEN_FUTURO_MS) {
    throw new ValidationError('El campo "fecha_inicio" no puede estar en el futuro.');
  }
  if (ms < ahora - MAX_ANTIGUEDAD_MS) {
    throw new ValidationError('El campo "fecha_inicio" no puede tener más de 7 días de antigüedad.');
  }
  return new Date(ms).toISOString();
}

function validarSerie(serie, duracionTotal) {
  if (!Array.isArray(serie) || serie.length === 0 || serie.length > MAX_PUNTOS_SERIE) {
    throw new ValidationError(`El campo "serie" debe ser un arreglo de 1 a ${MAX_PUNTOS_SERIE} puntos.`);
  }
  let tAnterior = -1;
  return serie.map((punto, i) => {
    const campo = `serie[${i}]`;
    if (!esObjetoPlano(punto)) {
      throw new ValidationError(`El punto "${campo}" debe ser un objeto con ${CAMPOS_PUNTO_SERIE.join(', ')}.`);
    }
    const claves = Object.keys(punto);
    if (claves.length !== CAMPOS_PUNTO_SERIE.length || !CAMPOS_PUNTO_SERIE.every((c) => claves.includes(c))) {
      throw new ValidationError(`El punto "${campo}" debe tener exactamente: ${CAMPOS_PUNTO_SERIE.join(', ')}.`);
    }
    const t = requerirEnteroEnRango(punto.t, `${campo}.t`, { min: 0, max: duracionTotal });
    if (t <= tAnterior) {
      throw new ValidationError(`Los tiempos de "serie" deben ser estrictamente crecientes (falla en ${campo}).`);
    }
    tAnterior = t;
    return {
      t,
      bpm: requerirNumeroEnRango(punto.bpm, `${campo}.bpm`, { min: 0, max: 300 }),
      spo2: requerirNumeroEnRango(punto.spo2, `${campo}.spo2`, { min: 0, max: 100 }),
      hrv: requerirNumeroEnRango(punto.hrv, `${campo}.hrv`, { min: 0, max: 300 }),
    };
  });
}

/** POST /api/sesiones — sesión de medición completa. Lista cerrada de
 * campos: `paciente_id` NO se acepta (lo pone el servidor desde el token), ni
 * `id`/`fecha_registro`/estado. Devuelve los datos normalizados (decimales
 * redondeados a la escala de cada columna, fecha en ISO UTC). */
function validarSesion(body) {
  if (!esObjetoPlano(body)) {
    throw new ValidationError('El cuerpo debe ser un objeto con los datos de la sesión.');
  }
  const desconocidos = Object.keys(body).filter((campo) => !CAMPOS_SESION.includes(campo));
  if (desconocidos.length > 0) {
    throw new ValidationError(`Campos no permitidos: ${desconocidos.join(', ')}.`);
  }

  const duracionTotal = requerirEnteroEnRango(body.duracion_total_seg, 'duracion_total_seg', {
    min: 1,
    max: MAX_DURACION_SESION_SEG,
  });
  const duracionValida = requerirEnteroEnRango(body.duracion_valida_seg, 'duracion_valida_seg', {
    min: 0,
    max: duracionTotal,
  });
  if (duracionValida < MIN_SENAL_VALIDA_SEG) {
    throw new ValidationError(`La sesión necesita al menos ${MIN_SENAL_VALIDA_SEG} s de señal válida.`);
  }

  const hrvRmssd = requerirDecimalEnRango(body.hrv_rmssd, 'hrv_rmssd', { min: 0, max: 300 }, 2);
  if (hrvRmssd <= 0) {
    throw new ValidationError('El campo "hrv_rmssd" debe ser mayor que 0.');
  }
  const hrvMin = requerirDecimalEnRango(body.hrv_min, 'hrv_min', { min: 0, max: 300 }, 2);
  const hrvMax = requerirDecimalEnRango(body.hrv_max, 'hrv_max', { min: 0, max: 300 }, 2);
  if (hrvMin > hrvMax) {
    throw new ValidationError('"hrv_min" no puede ser mayor que "hrv_max".');
  }

  const bpmMin = requerirEnteroEnRango(body.bpm_min, 'bpm_min', { min: 1, max: 300 });
  const bpmMax = requerirEnteroEnRango(body.bpm_max, 'bpm_max', { min: 1, max: 300 });
  const bpmPromedio = requerirDecimalEnRango(body.bpm_promedio, 'bpm_promedio', { min: 1, max: 300 }, 1);
  if (!(bpmMin <= bpmPromedio && bpmPromedio <= bpmMax)) {
    throw new ValidationError('Debe cumplirse bpm_min ≤ bpm_promedio ≤ bpm_max.');
  }

  const spo2Min = requerirEnteroEnRango(body.spo2_min, 'spo2_min', { min: 0, max: 100 });
  const spo2Max = requerirEnteroEnRango(body.spo2_max, 'spo2_max', { min: 0, max: 100 });
  const spo2Promedio = requerirDecimalEnRango(body.spo2_promedio, 'spo2_promedio', { min: 0, max: 100 }, 1);
  if (!(spo2Min <= spo2Promedio && spo2Promedio <= spo2Max)) {
    throw new ValidationError('Debe cumplirse spo2_min ≤ spo2_promedio ≤ spo2_max.');
  }

  if (!ORIGENES_SESION.includes(body.origen)) {
    throw new ValidationError(`El campo "origen" debe ser uno de: ${ORIGENES_SESION.join(', ')}.`);
  }

  return {
    fecha_inicio: validarFechaInicio(body.fecha_inicio),
    duracion_total_seg: duracionTotal,
    duracion_valida_seg: duracionValida,
    hrv_rmssd: hrvRmssd,
    hrv_min: hrvMin,
    hrv_max: hrvMax,
    bpm_promedio: bpmPromedio,
    bpm_min: bpmMin,
    bpm_max: bpmMax,
    spo2_promedio: spo2Promedio,
    spo2_min: spo2Min,
    spo2_max: spo2Max,
    indice_calidad: requerirDecimalEnRango(body.indice_calidad, 'indice_calidad', { min: 0, max: 1 }, 3),
    serie: validarSerie(body.serie, duracionTotal),
    origen: body.origen,
  };
}

module.exports = {
  validarSesion,
  validarEdicionAdmin,
  validarLectura,
  validarUsuarioNuevo,
  validarEspecialistaNuevo,
  validarNombre,
  validarCodigoVinculacion,
  validarMensajeChat,
  validarEjercicioAsignado,
};
