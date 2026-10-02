const express = require('express');
const logger = require('./logger');

// Rutas del rol Admin (Fase C, ver PLAN_FASE_C_ADMIN.md). server.js monta este
// router detrás de `requiereAdmin`, así que aquí todo request ya es de un
// admin. El admin gestiona CUENTAS: ninguna ruta devuelve datos clínicos
// (lecturas, mensajes ni ejercicios).
function crearAdminRouter(pool) {
  const router = express.Router();

  // GET /api/admin/usuarios — todas las cuentas con su estado. Para pacientes
  // trae el especialista vinculado; para especialistas, cuántos pacientes
  // tienen vinculados. El estado sale de `eliminado_en` (borrado lógico) y
  // `suspendido`; la eliminada gana si tuviera ambas.
  router.get('/usuarios', async (req, res) => {
    const query = `
      SELECT
        u.id, u.nombre, u.email, u.rol, u.fecha_registro,
        CASE
          WHEN u.eliminado_en IS NOT NULL THEN 'eliminada'
          WHEN u.suspendido THEN 'suspendida'
          ELSE 'activa'
        END AS estado,
        u.especialista_id,
        e.nombre AS especialista_nombre,
        CASE WHEN u.rol = 'especialista' THEN (
          SELECT COUNT(*) FROM usuarios p
          WHERE p.rol = 'paciente' AND p.especialista_id = u.id
        )::int END AS pacientes_vinculados
      FROM usuarios u
      LEFT JOIN usuarios e ON e.id = u.especialista_id
      ORDER BY lower(u.nombre) ASC;
    `;
    const result = await pool.query(query);

    logger.info('Admin consultó la lista de usuarios', { admin_uid: req.uid, total: result.rows.length });
    res.status(200).json(result.rows);
  });

  return router;
}

module.exports = { crearAdminRouter };
