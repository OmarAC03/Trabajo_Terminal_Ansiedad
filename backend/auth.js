const admin = require('firebase-admin');
const { AuthError } = require('./errors');
const logger = require('./logger');

/**
 * Inicializa el Admin SDK de Firebase a partir de la variable de entorno
 * FIREBASE_SERVICE_ACCOUNT_JSON (el JSON completo de la clave de servicio,
 * generada en Firebase Console > Configuración del proyecto > Cuentas de
 * servicio). Se llama una sola vez al arrancar el servidor; si falta la
 * variable, preferimos que el proceso no arranque a que sirva 500 en cada
 * request.
 */
function inicializarFirebaseAdmin() {
  if (admin.apps.length) return;

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    throw new Error('Falta la variable de entorno FIREBASE_SERVICE_ACCOUNT_JSON.');
  }

  const credenciales = JSON.parse(raw);
  admin.initializeApp({ credential: admin.credential.cert(credenciales) });
}

/** Busca el rol ('paciente' | 'especialista') del uid en la tabla `usuarios`.
 * Devuelve null si el token es válido pero todavía no existe la fila (pasa
 * justo entre crear la cuenta en Firebase y el POST /api/usuarios que la
 * registra en Supabase). */
async function obtenerRol(pool, uid) {
  const result = await pool.query('SELECT rol FROM usuarios WHERE id = $1', [uid]);
  return result.rows[0]?.rol ?? null;
}

function extraerToken(headerAuthorization) {
  if (!headerAuthorization || !headerAuthorization.startsWith('Bearer ')) return null;
  return headerAuthorization.slice('Bearer '.length).trim();
}

/**
 * Middleware Express: exige un token Firebase válido en el header
 * `Authorization: Bearer <token>` y adjunta `req.uid` / `req.rol`.
 * No decide autorización por ruta (eso vive en cada handler de server.js);
 * solo resuelve "quién es" antes de que la ruta decida "puede o no puede".
 */
function requiereAuth(pool) {
  return async (req, res, next) => {
    const token = extraerToken(req.headers.authorization);
    if (!token) {
      return next(new AuthError('Falta el header Authorization: Bearer <token>.'));
    }

    try {
      const decoded = await admin.auth().verifyIdToken(token);
      req.uid = decoded.uid;
      req.rol = await obtenerRol(pool, req.uid);
      next();
    } catch (error) {
      logger.warn('Token inválido o expirado', { detalle: error.message });
      next(new AuthError('Token inválido o expirado.'));
    }
  };
}

/**
 * Middleware de Socket.io equivalente a requiereAuth: verifica el token en
 * `socket.handshake.auth.token` y adjunta `socket.data.uid` / `socket.data.rol`.
 */
function requiereAuthSocket(pool) {
  return async (socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('auth_required'));
    }

    try {
      const decoded = await admin.auth().verifyIdToken(token);
      socket.data.uid = decoded.uid;
      socket.data.rol = await obtenerRol(pool, decoded.uid);
      next();
    } catch (error) {
      logger.warn('Socket rechazado: token inválido', { detalle: error.message });
      next(new Error('auth_invalid'));
    }
  };
}

module.exports = { inicializarFirebaseAdmin, requiereAuth, requiereAuthSocket };
