'use strict';

// GET /api/salud (versión final, punto 6). Pública y sin base de datos: solo
// dice que el servidor responde, para el "Conectado / Sin conexión" de la app.
// No devuelve versión, entorno, hora ni ningún otro dato técnico.
function rutaSalud(req, res) {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ ok: true });
}

module.exports = { rutaSalud };
