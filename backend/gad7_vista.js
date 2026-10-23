// Qué parte del GAD-7 ve cada rol (Fase M5a). Lógica pura sobre gad7.js,
// para probarla con `node --test` (gad7_vista.test.js) sin base de datos.
//
// Negar por defecto, igual que linea_base_vista.js: el paciente NUNCA recibe
// su puntaje, su severidad, sus respuestas ni nada que los delate (la marca de
// valorar, la dificultad). Le llega solo lo que necesita la tarjeta de Inicio:
// si le toca responder, desde cuándo y cuándo respondió por última vez. Los
// objetos se arman campo por campo (sin `...fila`), así una columna nueva en
// la tabla no se filtra sola.

const {
  CONFIG_GAD7,
  itemsDeFila,
  puntaje,
  severidad,
  valorar,
  estadoGad7,
  ultimaFechaDe,
} = require('./gad7');

/** Estado "¿le toca?" a partir de las respuestas del paciente. Igual para
 * ambos roles (no delata nada del resultado). `vinculado`: si tiene
 * especialista; sin él no puede responder (la app no muestra la tarjeta). */
function estadoPara(filas, vinculado, ahora = new Date(), config = CONFIG_GAD7) {
  const ultima = ultimaFechaDe(filas);
  const estado = estadoGad7(ultima, ahora, config);
  return {
    toca: estado.toca,
    proxima_fecha: estado.proxima_fecha,
    dias_restantes: estado.dias_restantes,
    ultima_respuesta: ultima,
    intervalo_dias: config.intervaloDias,
    vinculado: Boolean(vinculado),
  };
}

/** Una respuesta completa, solo para el especialista. */
function respuestaEspecialista(fila) {
  const items = itemsDeFila(fila);
  const p = puntaje(items);
  return {
    id: fila.id,
    fecha_respuesta: fila.fecha_respuesta,
    version: fila.version,
    items,
    dificultad: fila.dificultad == null ? null : Number(fila.dificultad),
    puntaje: p,
    severidad: severidad(p),
    valorar: valorar(p),
  };
}

/** `GET /api/gad7/:pacienteId`. Paciente: solo el estado. Especialista: el
 * estado y el historial, de la más reciente a la más vieja. */
function vistaGad7(filas, esEspecialista, vinculado, ahora = new Date()) {
  const estado = estadoPara(filas, vinculado, ahora);
  if (!esEspecialista) return { estado };
  const respuestas = [...filas]
    .sort((a, b) => new Date(b.fecha_respuesta) - new Date(a.fecha_respuesta))
    .map(respuestaEspecialista);
  return { estado, respuestas };
}

/** `POST /api/gad7` (solo lo hace el paciente, y solo vinculado): la
 * confirmación de que se guardó y su nuevo estado. Nada del resultado. */
function guardadaParaPaciente(fila, filasDelPaciente, ahora = new Date()) {
  return {
    id: fila.id,
    fecha_respuesta: fila.fecha_respuesta,
    estado: estadoPara(filasDelPaciente, true, ahora),
  };
}

module.exports = {
  estadoPara,
  respuestaEspecialista,
  vistaGad7,
  guardadaParaPaciente,
};
