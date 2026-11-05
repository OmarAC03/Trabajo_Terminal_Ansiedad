// Notificaciones push al paciente con Firebase Cloud Messaging (Bloque 3).
// server.js crea el notificador con `crearNotificador` y lo llama DESPUÉS de
// guardar un mensaje del especialista o un ejercicio; notificaciones.test.js
// lo prueba con un `messaging` falso.
//
// REGLA DE ORO: el texto de la notificación es SIEMPRE uno de TEXTOS, fijo.
// La función recibe solo el tipo, así que no hay forma de que lleguen el texto
// del mensaje, el nombre del especialista ni un dato clínico: la notificación
// se ve en la pantalla de bloqueo.
//
// El GAD-7 no pasa por aquí: es un recordatorio local programado en el
// teléfono (decisión D1 del Bloque 3; Render gratuito no tiene un proceso
// despierto para avisar a una hora).

const TITULO = 'Monitor ESCOM';
const TEXTOS = Object.freeze({
  mensaje: 'Tienes un mensaje nuevo de tu especialista',
  ejercicio: 'Tu especialista te asignó un ejercicio',
});
const TIPOS = Object.freeze(Object.keys(TEXTOS));

// Canal de Android que crea la app al arrancar (si no existe, Android usa el
// de respaldo de FCM y la notificación llega igual).
const CANAL_ANDROID = 'avisos';

// Solo estos dos códigos significan que el token ya no sirve y se borra.
// Cualquier otro error (red, cuota, invalid-argument, credenciales) puede
// ser pasajero o del servidor: no se borra nada, solo se registra.
const CODIGOS_TOKEN_INVALIDO = Object.freeze([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** Mensaje multicast de FCM para `tokens`. Lanza si el tipo no existe. */
function mensajeFcm(tipo, tokens) {
  const cuerpo = TEXTOS[tipo];
  if (!cuerpo) throw new Error(`Notificación: tipo desconocido '${tipo}'.`);
  return {
    tokens,
    notification: { title: TITULO, body: cuerpo },
    // `tipo` le dice a la app qué pestaña abrir al tocarla. Nada más.
    data: { tipo },
    android: {
      priority: 'high',
      // Mismo `tag`: diez mensajes seguidos quedan en UNA notificación.
      notification: { tag: tipo, channelId: CANAL_ANDROID },
    },
  };
}

/**
 * Tokens que FCM rechazó como inexistentes o inválidos, según la respuesta
 * de sendEachForMulticast (`responses[i]` corresponde a `tokens[i]`).
 */
function tokensAInvalidar(tokens, respuesta) {
  return tokens.filter((_, i) => {
    const r = respuesta?.responses?.[i];
    return r && !r.success && CODIGOS_TOKEN_INVALIDO.includes(r.error?.code);
  });
}

/** Errores que no invalidan el token, agrupados por código (para el log). */
function otrosErrores(tokens, respuesta) {
  const codigos = {};
  tokens.forEach((_, i) => {
    const r = respuesta?.responses?.[i];
    if (r && !r.success && !CODIGOS_TOKEN_INVALIDO.includes(r.error?.code)) {
      const codigo = r.error?.code || 'desconocido';
      codigos[codigo] = (codigos[codigo] || 0) + 1;
    }
  });
  return codigos;
}

// Para el log: nunca el token completo.
const colaToken = (token) => `…${String(token).slice(-6)}`;

// Tokens de un PACIENTE activo (ni suspendido ni eliminado).
const TOKENS_DE_PACIENTE = `
  SELECT d.token
  FROM dispositivos_push d
  JOIN usuarios u ON u.id = d.usuario_id
  WHERE d.usuario_id = $1 AND u.rol = 'paciente' AND NOT u.suspendido AND u.eliminado_en IS NULL
  ORDER BY d.actualizado_en DESC;`;

const BORRAR_TOKENS = 'DELETE FROM dispositivos_push WHERE token = ANY($1::text[])';

/**
 * `{ avisar(pacienteId, tipo) }`. `avisar` nunca lanza: un fallo de FCM o de
 * la base no debe romper la petición que ya guardó el mensaje o el
 * ejercicio. Devuelve un resumen (lo usan las pruebas).
 * `messaging` es una función que devuelve admin.messaging() (perezosa, para
 * no tocar Firebase al cargar el módulo).
 */
function crearNotificador({ pool, messaging, logger }) {
  async function avisar(pacienteId, tipo) {
    const resumen = { enviados: 0, fallidos: 0, invalidados: 0 };
    try {
      const tokens = (await pool.query(TOKENS_DE_PACIENTE, [pacienteId])).rows.map((f) => f.token);
      if (tokens.length === 0) return resumen;

      const respuesta = await messaging().sendEachForMulticast(mensajeFcm(tipo, tokens));
      resumen.enviados = respuesta.successCount;
      resumen.fallidos = respuesta.failureCount;

      const invalidos = tokensAInvalidar(tokens, respuesta);
      if (invalidos.length > 0) {
        await pool.query(BORRAR_TOKENS, [invalidos]);
        resumen.invalidados = invalidos.length;
        logger.info('Push: tokens rechazados por FCM, borrados', {
          paciente_id: pacienteId, tokens: invalidos.map(colaToken),
        });
      }
      const otros = otrosErrores(tokens, respuesta);
      if (Object.keys(otros).length > 0) {
        logger.error('Push: FCM no entregó (tokens conservados)', { paciente_id: pacienteId, tipo, codigos: otros });
      }
    } catch (error) {
      logger.error('Push: no se pudo enviar la notificación', {
        paciente_id: pacienteId, tipo, codigo: error.code, detalle: error.message,
      });
    }
    return resumen;
  }
  return { avisar };
}

module.exports = {
  TITULO,
  TEXTOS,
  TIPOS,
  CANAL_ANDROID,
  CODIGOS_TOKEN_INVALIDO,
  mensajeFcm,
  tokensAInvalidar,
  otrosErrores,
  colaToken,
  TOKENS_DE_PACIENTE,
  BORRAR_TOKENS,
  crearNotificador,
};
