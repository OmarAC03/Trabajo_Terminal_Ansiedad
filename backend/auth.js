const admin = require('firebase-admin');
const { AuthError } = require('./errors');
const logger = require('./logger');
const { bloqueoDeCuenta } = require('./cuentas');

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

/** Busca la cuenta del uid en `usuarios`: rol ('paciente' | 'especialista' |
 * 'admin') y su estado (`suspendido`, `eliminado_en`), en UNA consulta.
 * Devuelve null si el token es válido pero todavía no existe la fila (pasa
 * justo entre crear la cuenta en Firebase y el POST /api/usuarios que la
 * registra en Supabase). */
async function obtenerCuenta(pool, uid) {
  const result = await pool.query('SELECT rol, suspendido, eliminado_en FROM usuarios WHERE id = $1', [uid]);
  return result.rows[0] ?? null;
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
 *
 * Una cuenta suspendida o eliminada recibe 403 con `codigo` aunque su token
 * siga vigente: Firebase solo deja de emitir tokens nuevos, y uno ya emitido
 * vale ~1 h. Así la suspensión corta el acceso al instante.
 */
function requiereAuth(pool) {
  return async (req, res, next) => {
    const token = extraerToken(req.headers.authorization);
    if (!token) {
      return next(new AuthError('Falta el header Authorization: Bearer <token>.'));
    }

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(token);
    } catch (error) {
      logger.warn('Token inválido o expirado', { detalle: error.message });
      return next(new AuthError('Token inválido o expirado.'));
    }

    // Un fallo de la base aquí es un 500, no un "token inválido".
    let cuenta;
    try {
      cuenta = await obtenerCuenta(pool, decoded.uid);
    } catch (error) {
      return next(error);
    }
    const bloqueo = bloqueoDeCuenta(cuenta);
    if (bloqueo) {
      logger.warn('Acceso rechazado: cuenta bloqueada', { uid: decoded.uid, codigo: bloqueo.codigo, path: req.originalUrl });
      return next(new AuthError(bloqueo.mensaje, 403, bloqueo.codigo));
    }

    req.uid = decoded.uid;
    req.rol = cuenta?.rol ?? null;
    next();
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

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(token);
    } catch (error) {
      logger.warn('Socket rechazado: token inválido', { detalle: error.message });
      return next(new Error('auth_invalid'));
    }

    let cuenta;
    try {
      cuenta = await obtenerCuenta(pool, decoded.uid);
    } catch (error) {
      logger.error('Socket rechazado: no se pudo leer la cuenta', { detalle: error.message });
      return next(new Error('server_error'));
    }
    // El mensaje del error llega al cliente en `connect_error`.
    const bloqueo = bloqueoDeCuenta(cuenta);
    if (bloqueo) {
      logger.warn('Socket rechazado: cuenta bloqueada', { uid: decoded.uid, codigo: bloqueo.codigo });
      return next(new Error(bloqueo.codigo));
    }

    socket.data.uid = decoded.uid;
    socket.data.rol = cuenta?.rol ?? null;
    next();
  };
}

/**
 * Middleware Express de la Fase C: deja pasar solo a `rol === 'admin'`.
 * Se monta UNA vez delante de todo el router de admin
 * (`app.use('/api/admin', requiereAdmin, adminRouter)`), así ninguna ruta de
 * admin puede quedar sin este chequeo por olvido. Pacientes, especialistas y
 * cuentas sin fila en `usuarios` reciben 403. Va después de requiereAuth.
 */
function requiereAdmin(req, res, next) {
  if (req.rol !== 'admin') {
    logger.warn('Acceso a ruta de admin rechazado', { uid: req.uid, rol: req.rol, path: req.originalUrl });
    return next(new AuthError('Solo un administrador puede usar esta ruta.', 403));
  }
  next();
}

module.exports = { inicializarFirebaseAdmin, requiereAuth, requiereAuthSocket, requiereAdmin };
