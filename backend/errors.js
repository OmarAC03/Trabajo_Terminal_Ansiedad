/**
 * Error de validación: se distingue de un fallo interno real (DB caída, bug)
 * porque el problema es el dato que llegó, no el servidor. El middleware de
 * error de server.js usa `statusCode` para decidir 400 vs 500 y qué tan
 * detallado puede ser el mensaje que ve el cliente.
 */
class ValidationError extends Error {
  constructor(mensaje) {
    super(mensaje);
    this.name = 'ValidationError';
    this.statusCode = 400;
  }
}

/**
 * Error de autenticación/autorización: token ausente/inválido (401) o token
 * válido pero sin permiso para el recurso pedido (403). Mismo mecanismo que
 * ValidationError: el middleware de error de server.js lee `statusCode`.
 */
class AuthError extends Error {
  constructor(mensaje, statusCode = 401) {
    super(mensaje);
    this.name = 'AuthError';
    this.statusCode = statusCode;
  }
}

module.exports = { ValidationError, AuthError };
