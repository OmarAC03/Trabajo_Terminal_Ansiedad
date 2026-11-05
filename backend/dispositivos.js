const { ValidationError } = require('./errors');

// Tokens de FCM de la app del paciente (Bloque 3). Lógica pura, sin base:
// server.js la usa y dispositivos.test.js la prueba. Tabla
// `dispositivos_push` (token PK, usuario_id, plataforma, fechas).

const LARGO_MINIMO = 20;
const LARGO_MAXIMO = 4096;
const MAXIMO_POR_CUENTA = 5;

/** `{ token }` de PUT y DELETE /api/dispositivos. Lanza ValidationError (400). */
function validarToken(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new ValidationError('El cuerpo debe ser un objeto con "token".');
  }
  const extra = Object.keys(body).filter((k) => k !== 'token');
  if (extra.length > 0) throw new ValidationError(`Campo no reconocido: ${extra.join(', ')}.`);
  const { token } = body;
  if (typeof token !== 'string' || token.length < LARGO_MINIMO || token.length > LARGO_MAXIMO || /\s/.test(token)) {
    throw new ValidationError(`"token" debe ser texto sin espacios de ${LARGO_MINIMO} a ${LARGO_MAXIMO} caracteres.`);
  }
  return token;
}

// El token es del aparato: si ya estaba con otra cuenta (otra persona inició
// sesión en ese teléfono), pasa a esta.
const REGISTRAR_TOKEN = `
  INSERT INTO dispositivos_push (token, usuario_id)
  VALUES ($1, $2)
  ON CONFLICT (token) DO UPDATE SET usuario_id = EXCLUDED.usuario_id, actualizado_en = now();`;

// Deja solo los MAXIMO_POR_CUENTA más recientes de la cuenta.
const RECORTAR_TOKENS = `
  DELETE FROM dispositivos_push
  WHERE usuario_id = $1 AND token NOT IN (
    SELECT token FROM dispositivos_push WHERE usuario_id = $1
    ORDER BY actualizado_en DESC LIMIT ${MAXIMO_POR_CUENTA}
  );`;

// Solo un token propio: el de otra cuenta no se toca.
const BORRAR_TOKEN_PROPIO = 'DELETE FROM dispositivos_push WHERE token = $1 AND usuario_id = $2;';

const CONTAR_TOKENS = 'SELECT count(*)::int AS registrados FROM dispositivos_push WHERE usuario_id = $1;';

// Al suspender (admin.js) y al eliminar (eliminacion.js): todos los de la cuenta.
const BORRAR_TOKENS_DE_CUENTA = 'DELETE FROM dispositivos_push WHERE usuario_id = $1';

module.exports = {
  MAXIMO_POR_CUENTA,
  validarToken,
  REGISTRAR_TOKEN,
  RECORTAR_TOKENS,
  BORRAR_TOKEN_PROPIO,
  CONTAR_TOKENS,
  BORRAR_TOKENS_DE_CUENTA,
};
