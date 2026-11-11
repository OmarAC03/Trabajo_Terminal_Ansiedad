'use strict';

// Seguridad mínima de la versión final (Fase S): orígenes permitidos (CORS
// de HTTP y Socket.io) y límites de peticiones. Lógica pura y configurable
// para poder probarla sin levantar el servidor (seguridad.test.js).

const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

// --- CORS ---

// El portal publicado en Render. Ningún otro sitio web puede usar la API
// desde un navegador.
const ORIGEN_PORTAL = 'https://monitor-ansiedad-escom.onrender.com';
// Solo fuera de producción: el portal en `npm start`.
const ORIGENES_DESARROLLO = Object.freeze(['http://localhost:3000']);

function origenesPermitidos(entorno = process.env.NODE_ENV) {
  return entorno === 'production' ? [ORIGEN_PORTAL] : [ORIGEN_PORTAL, ...ORIGENES_DESARROLLO];
}

// Sin cabecera Origin = no es un navegador (la app nativa, los scripts de
// prueba, el sensor): CORS no aplica y la autenticación por token decide.
function origenPermitido(origen, lista) {
  return !origen || lista.includes(origen);
}

// Opciones para `cors()`: con un origen no permitido no se mandan las
// cabeceras CORS y el navegador bloquea la respuesta.
function opcionesCors(lista) {
  return {
    origin: (origen, cb) => cb(null, origenPermitido(origen, lista)),
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 600,
  };
}

// Socket.io: el WebSocket no pasa por el CORS del navegador, así que además
// se rechaza el handshake de un origen no permitido (`allowRequest`).
function opcionesSocket(lista) {
  return {
    cors: { origin: lista, methods: ['GET', 'POST'] },
    allowRequest: (req, cb) => cb(null, origenPermitido(req.headers.origin, lista)),
  };
}

// --- Límites de peticiones ---

const LIMITES = Object.freeze({
  // Por IP, antes de autenticar. Alto a propósito: muchos participantes
  // pueden salir por la misma IP de la red de la escuela.
  ip: { ventanaMs: 15 * 60 * 1000, maximo: 1000 },
  // Por cuenta (uid del token), para todo /api.
  usuario: { ventanaMs: 15 * 60 * 1000, maximo: 600 },
  // Por cuenta, en registro, consentimiento y GAD-7.
  estricto: { ventanaMs: 60 * 60 * 1000, maximo: 10 },
});

const MENSAJE_429 = 'Demasiadas peticiones. Espera unos minutos e inténtalo de nuevo.';
const CODIGO_429 = 'demasiadas_peticiones';

// Mismo formato de error que el manejador central: { error, codigo }.
function responder429(req, res) {
  res.status(429).json({ error: MENSAJE_429, codigo: CODIGO_429 });
}

const clavePorIp = (req) => ipKeyGenerator(req.ip || '');
// Tras requiereAuth hay req.uid; sin él (no debería pasar) se usa la IP.
const clavePorUsuario = (req) => (req.uid ? `uid:${req.uid}` : clavePorIp(req));

function crearLimite({ ventanaMs, maximo }, claveDe) {
  return rateLimit({
    windowMs: ventanaMs,
    limit: maximo,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    keyGenerator: claveDe,
    handler: responder429,
  });
}

function crearLimites(limites = LIMITES) {
  return {
    porIp: crearLimite(limites.ip, clavePorIp),
    porUsuario: crearLimite(limites.usuario, clavePorUsuario),
    estricto: crearLimite(limites.estricto, clavePorUsuario),
  };
}

// Rutas con el límite estricto (método + ruta exacta).
const RUTAS_ESTRICTAS = Object.freeze([
  ['POST', '/api/usuarios'],
  ['POST', '/api/especialistas'],
  ['POST', '/api/consentimiento'],
  ['POST', '/api/gad7'],
]);

module.exports = {
  ORIGEN_PORTAL,
  ORIGENES_DESARROLLO,
  origenesPermitidos,
  origenPermitido,
  opcionesCors,
  opcionesSocket,
  LIMITES,
  MENSAJE_429,
  CODIGO_429,
  crearLimites,
  RUTAS_ESTRICTAS,
};
