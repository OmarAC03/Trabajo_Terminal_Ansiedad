// Qué parte de la línea base ve cada rol (Fase M3, paso 2). Lógica pura sobre
// los resultados de linea_base.js, para probarla con `node --test`
// (linea_base_vista.test.js) sin base de datos.
//
// Negar por defecto, igual que `indice_calidad`: el paciente NUNCA recibe la
// etiqueta (normal/elevados/altos) ni nada que la delate (z, banda, FC por
// encima de lo habitual). Le llega solo lo que necesita el mensaje de la
// mascota: la etapa de calibración y por qué una sesión no se comparó. Los
// objetos del paciente se arman campo por campo (sin `...resultado`), así un
// campo nuevo en linea_base.js no se filtra solo.

const {
  CONFIG_LINEA_BASE,
  ETAPAS,
  diaLocal,
  lineaBaseAntesDe,
  evaluarSesion,
  progresoCalibracion,
} = require('./linea_base');

const redondear = (v, decimales) => (v == null ? null : Number(v.toFixed(decimales)));

/** Banda de una línea base (null mientras se calibra). Solo especialista. */
function bandaEspecialista(base) {
  if (base.etapa === ETAPAS.calibrando) return null;
  return {
    n: base.n,
    dias: base.dias,
    media_ln: redondear(base.media_ln, 4), // μ
    de_ln: redondear(base.de_ln, 4),
    de_ln_usada: redondear(base.de_ln_usada, 4), // σ* (con piso)
    k1: redondear(base.k1, 3),
    k2: redondear(base.k2, 3),
    rango_hrv_ms: {
      min: redondear(base.rango_hrv_ms.min, 1),
      max: redondear(base.rango_hrv_ms.max, 1),
    },
    fc_media: redondear(base.fc.media, 1),
    fc_limite_superior: redondear(base.fc.limite_superior, 1),
  };
}

/** Evaluación de una sesión (resultado de evaluarSesion) según el rol. */
function evaluacionPara(resultado, esEspecialista) {
  const paciente = {
    etapa: resultado.linea_base.etapa,
    motivo_sin_estado: resultado.motivo_sin_estado, // null | 'calibrando' | 'calidad_baja'
  };
  if (!esEspecialista) return paciente;
  return {
    ...paciente,
    estado: resultado.estado,
    z: redondear(resultado.z, 2),
    fc_por_encima: resultado.fc_por_encima,
    n: resultado.linea_base.n,
    banda: bandaEspecialista(resultado.linea_base),
    version: resultado.version,
  };
}

/** Evalúa cada fila de `filas` (por id) contra `sesionesBase`, que debe
 * traer las columnas de la base (incluida `indice_calidad`) de esas sesiones
 * y de los días previos. Devuelve un Map id → evaluación para el rol. */
function evaluarFilas(filas, sesionesBase, esEspecialista, config = CONFIG_LINEA_BASE) {
  const porId = new Map(sesionesBase.map((s) => [s.id, s]));
  const evaluaciones = new Map();
  for (const fila of filas) {
    const completa = porId.get(fila.id);
    if (!completa) continue;
    evaluaciones.set(fila.id, evaluacionPara(evaluarSesion(completa, sesionesBase, config), esEspecialista));
  }
  return evaluaciones;
}

/** Calibración de un origen hoy: "día X de 7" para la mascota y, al
 * especialista, la banda con la que se compararía una medición hecha hoy. */
function calibracionPara(sesiones, origen, esEspecialista, ahora = new Date(), config = CONFIG_LINEA_BASE) {
  const progreso = progresoCalibracion(sesiones, origen, ahora, config);
  const baseHoy = lineaBaseAntesDe(sesiones, diaLocal(ahora, config.zonaHoraria), origen, config);
  const medidoHoy = progreso.sesiones_validas_hoy > 0;
  // Si ya midió hoy, hoy es su día X; si no, la próxima medición lo será.
  const dia = medidoHoy ? progreso.dias_con_medicion : progreso.dias_con_medicion + 1;

  const paciente = {
    origen,
    hoy: progreso.hoy,
    etapa: baseHoy.etapa, // la de una medición hecha hoy
    etapa_manana: progreso.etapa, // la de la próxima medición de otro día
    dias_con_medicion: progreso.dias_con_medicion,
    medido_hoy: medidoHoy,
    dia_calibracion: Math.min(dia, config.diasVentana),
    dias_objetivo: config.diasVentana,
    dias_minimos: config.diasMinimos,
    hay_historial_vencido: progreso.hay_historial_vencido,
  };
  if (!esEspecialista) return paciente;
  return {
    ...paciente,
    sesiones_validas_hoy: progreso.sesiones_validas_hoy,
    n: baseHoy.n,
    banda: bandaEspecialista(baseHoy),
    version: config.version,
  };
}

module.exports = {
  evaluacionPara,
  evaluarFilas,
  calibracionPara,
};
