const express = require('express');
const { AuthError } = require('./errors');

// Secciones del portal que son del especialista y no de un paciente (versión
// final, Fase 2): la bandeja de Mensajes, el historial de exportaciones de
// Reportes y el resumen de su perfil. server.js monta el router en
// /api/especialista. Sin DDL: todo sale de tablas que ya existen.
//
// Solo el rol especialista entra (403 a pacientes y admins), y cada consulta
// se filtra por `req.uid`: nadie ve la bandeja ni las exportaciones de otro.

const ZONA_HORARIA = 'America/Mexico_City';
const LIMITE_EXPORTACIONES = 100;

// --- Bandeja de Mensajes (decisión D1, opción b) ---
// Sin tabla de "leídos": una conversación está PENDIENTE DE RESPONDER cuando
// su último mensaje es del paciente. `sin_responder` = mensajes del paciente
// después de la última respuesta del especialista. No se manda el texto de
// ningún mensaje (eso se lee al abrir la conversación, con su registro de
// acceso en la bitácora); solo quién escribió al último y cuándo.
//
// Como GET /api/mensajes, la conversación es el par paciente ↔ especialista
// vinculado ACTUAL (`especialista_id = $1`). Un mensaje sin remitente_id es del
// paciente (antes solo la app podía escribir).
const CONVERSACIONES = `
  SELECT u.id AS paciente_id, u.nombre,
         um.fecha_envio AS ultima_fecha,
         CASE WHEN um.fecha_envio IS NULL THEN NULL
              WHEN COALESCE(um.remitente_id, um.paciente_id) = u.id THEN 'paciente'
              ELSE 'especialista' END AS ultimo_de,
         COALESCE(sr.total, 0)::int AS sin_responder
  FROM usuarios u
  LEFT JOIN LATERAL (
    SELECT m.fecha_envio, m.remitente_id, m.paciente_id
    FROM mensajes_chat m
    WHERE m.paciente_id = u.id AND m.especialista_id = $1
    ORDER BY m.fecha_envio DESC, m.id DESC
    LIMIT 1
  ) um ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*) AS total
    FROM mensajes_chat m
    WHERE m.paciente_id = u.id AND m.especialista_id = $1
      AND COALESCE(m.remitente_id, m.paciente_id) = u.id
      AND m.fecha_envio > COALESCE((
        SELECT max(r.fecha_envio) FROM mensajes_chat r
        WHERE r.paciente_id = u.id AND r.especialista_id = $1 AND r.remitente_id = $1
      ), '-infinity'::timestamptz)
  ) sr ON true
  WHERE u.rol = 'paciente' AND u.especialista_id = $1`;

const fechaMs = (f) => (f ? new Date(f).getTime() : null);

/**
 * Filas de CONVERSACIONES → bandeja. Orden: primero las pendientes de
 * responder, luego las demás con mensajes, y al final los pacientes sin
 * mensajes (por nombre). Dentro de cada grupo, la más reciente primero.
 */
function vistaConversaciones(filas) {
  const vista = filas.map((f) => {
    const pendiente = f.ultimo_de === 'paciente';
    return {
      paciente_id: f.paciente_id,
      nombre: f.nombre,
      ultima_fecha: f.ultima_fecha ? new Date(f.ultima_fecha).toISOString() : null,
      ultimo_de: f.ultimo_de || null,
      pendiente,
      sin_responder: pendiente ? Math.max(1, Number(f.sin_responder) || 0) : 0,
    };
  });
  const grupo = (c) => (c.pendiente ? 0 : c.ultima_fecha ? 1 : 2);
  return vista.sort((a, b) =>
    grupo(a) - grupo(b)
    || (fechaMs(b.ultima_fecha) || 0) - (fechaMs(a.ultima_fecha) || 0)
    || String(a.nombre).localeCompare(String(b.nombre), 'es'));
}

// --- Historial de exportaciones (Reportes) ---
// Lo que el propio especialista exportó, leído de la bitácora (acción
// `exportacion`, que el backend registra en la misma transacción que arma el
// reporte). El nombre del paciente solo se muestra si SIGUE vinculado a este
// especialista; si no, la fila dice "ya no vinculado" sin nombre ni id.
const EXPORTACIONES = `
  SELECT b.id, b.fecha, b.objetivo_id, b.detalle, u.nombre,
         COALESCE(u.rol = 'paciente' AND u.especialista_id = $1 AND u.eliminado_en IS NULL, false) AS vinculado
  FROM bitacora b
  LEFT JOIN usuarios u ON u.id = b.objetivo_id
  WHERE b.actor_id = $1 AND b.accion = 'exportacion'
  ORDER BY b.fecha DESC, b.id DESC
  LIMIT $2`;

function vistaExportaciones(filas) {
  return filas.map((f) => {
    const d = f.detalle || {};
    const vinculado = f.vinculado === true;
    return {
      id: String(f.id),
      fecha: new Date(f.fecha).toISOString(),
      paciente_id: vinculado ? f.objetivo_id : null,
      paciente_nombre: vinculado ? f.nombre : null,
      vinculado,
      formato: d.formato === 'pdf' || d.formato === 'csv' ? d.formato : null,
      seudonimizado: d.seudonimizado === true,
      desde: typeof d.desde === 'string' ? d.desde : null,
      hasta: typeof d.hasta === 'string' ? d.hasta : null,
    };
  });
}

// --- Resumen del perfil ---
// Fecha de alta y cuatro conteos de la propia actividad. "Este mes" es el mes
// calendario en hora de México. No hay "último acceso": la base no lo guarda.
const RESUMEN_PERFIL = `
  SELECT
    (SELECT fecha_registro FROM usuarios WHERE id = $1) AS fecha_registro,
    (SELECT COUNT(*) FROM usuarios WHERE rol = 'paciente' AND especialista_id = $1)::int AS pacientes_vinculados,
    (SELECT COUNT(*) FROM mensajes_chat WHERE remitente_id = $1)::int AS mensajes_enviados,
    (SELECT COUNT(*) FROM notas_clinicas WHERE especialista_id = $1)::int AS notas_registradas,
    (SELECT COUNT(*) FROM bitacora
      WHERE actor_id = $1 AND accion = 'exportacion'
        AND fecha >= (date_trunc('month', now() AT TIME ZONE $2) AT TIME ZONE $2))::int AS exportaciones_mes`;

function vistaResumenPerfil(fila = {}) {
  const entero = (v) => Number(v) || 0;
  return {
    fecha_registro: fila.fecha_registro ? new Date(fila.fecha_registro).toISOString() : null,
    pacientes_vinculados: entero(fila.pacientes_vinculados),
    mensajes_enviados: entero(fila.mensajes_enviados),
    notas_registradas: entero(fila.notas_registradas),
    exportaciones_mes: entero(fila.exportaciones_mes),
  };
}

function soloEspecialista(req, res, next) {
  if (req.rol !== 'especialista') {
    throw new AuthError('Solo un especialista puede usar esta sección.', 403);
  }
  next();
}

function crearCuentaEspecialistaRouter(pool) {
  const router = express.Router();
  router.use(soloEspecialista);

  // GET /api/especialista/conversaciones
  router.get('/conversaciones', async (req, res) => {
    const result = await pool.query(CONVERSACIONES, [req.uid]);
    res.status(200).json(vistaConversaciones(result.rows));
  });

  // GET /api/especialista/exportaciones
  router.get('/exportaciones', async (req, res) => {
    const result = await pool.query(EXPORTACIONES, [req.uid, LIMITE_EXPORTACIONES]);
    res.set('Cache-Control', 'no-store');
    res.status(200).json({ filas: vistaExportaciones(result.rows), limite: LIMITE_EXPORTACIONES });
  });

  // GET /api/especialista/resumen
  router.get('/resumen', async (req, res) => {
    const result = await pool.query(RESUMEN_PERFIL, [req.uid, ZONA_HORARIA]);
    res.status(200).json(vistaResumenPerfil(result.rows[0]));
  });

  return router;
}

module.exports = {
  crearCuentaEspecialistaRouter,
  soloEspecialista,
  vistaConversaciones,
  vistaExportaciones,
  vistaResumenPerfil,
  CONVERSACIONES,
  EXPORTACIONES,
  RESUMEN_PERFIL,
  LIMITE_EXPORTACIONES,
  ZONA_HORARIA,
};
