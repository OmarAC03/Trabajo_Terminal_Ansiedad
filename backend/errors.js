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

module.exports = { ValidationError };
