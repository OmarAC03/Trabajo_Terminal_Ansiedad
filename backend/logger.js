/**
 * Logger estructurado del backend: una línea JSON por evento (timestamp,
 * nivel, mensaje, metadata) en vez de console.log/console.error sueltos.
 * Sin dependencia nueva; el formato JSON es fácil de buscar/filtrar en los
 * logs de Render.
 */
function registrar(nivel, mensaje, meta = {}) {
  const linea = { timestamp: new Date().toISOString(), nivel, mensaje, ...meta };
  const salida = nivel === 'error' ? console.error : console.log;
  salida(JSON.stringify(linea));
}

module.exports = {
  info: (mensaje, meta) => registrar('info', mensaje, meta),
  warn: (mensaje, meta) => registrar('warn', mensaje, meta),
  error: (mensaje, meta) => registrar('error', mensaje, meta),
};
