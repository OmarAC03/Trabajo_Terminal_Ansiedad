const express = require('express');
const logger = require('./logger');
const { AuthError, ValidationError, HttpError } = require('./errors');
const { registrar: registrarBitacora } = require('./bitacora');
const notas = require('./notas');
const marcadores = require('./marcadores');
const reporte = require('./reporte');

const FORMATO_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Herramientas del especialista sobre un paciente (Bloque 2): notas clínicas
// (paso 2), marcadores en la línea de tiempo (paso 3) y el reporte para
// exportar (paso 4). server.js monta este router en /api/pacientes.
//
// A diferencia de las lecturas (autorizarLecturaPaciente en server.js), aquí
// no hay rama del paciente: solo el especialista vinculado ACTUAL. El
// paciente y el admin reciben 403. Y todo se filtra además por
// `especialista_id = req.uid` (decisión D1: lo escrito es del par).
//
// `esPacienteVinculado` y `registrarAcceso` vienen de server.js: el mismo
// chequeo de vínculo y el mismo registro de lecturas (D2) que el resto.
// `evaluarSesiones(req, pacienteId, filas)` es conEvaluacion de server.js
// (estado contra la línea base, para el reporte).
function crearEspecialistaRouter(pool, { esPacienteVinculado, registrarAcceso, evaluarSesiones }) {
  const router = express.Router();

  async function autorizarEspecialistaVinculado(req, pacienteId) {
    if (req.rol !== 'especialista') {
      throw new AuthError('Solo el especialista del paciente puede usar esta función.', 403);
    }
    if (!(await esPacienteVinculado(pacienteId, req.uid))) {
      throw new AuthError('Este paciente no está vinculado a tu cuenta.', 403);
    }
  }

  // Una escritura y su registro en la bitácora van juntos (D2).
  async function enTransaccion(fn) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const resultado = await fn(client);
      await client.query('COMMIT');
      return resultado;
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  const bitacora = (db, req, accion, pacienteId, detalle) =>
    registrarBitacora(db, { actorId: req.uid, actorRol: req.rol, accion, objetivoId: pacienteId, detalle });

  function uuid(texto, que) {
    if (!FORMATO_UUID.test(texto)) throw new ValidationError(`El identificador ${que} no es válido.`);
    return texto;
  }
  const idNota = (texto) => uuid(texto, 'de la nota');

  // --- NOTAS CLÍNICAS (WEB-RF-27 / RN-15) ---

  // GET /api/pacientes/:pacienteId/notas — versión vigente de cada nota del
  // par, por fecha clínica (más reciente primero).
  router.get('/:pacienteId/notas', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    await registrarAcceso(req, pacienteId, 'notas');
    const result = await pool.query(notas.LISTAR_NOTAS, [pacienteId, req.uid]);
    res.status(200).json(result.rows);
  });

  // POST /api/pacientes/:pacienteId/notas { fecha, contenido }
  router.post('/:pacienteId/notas', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    const datos = notas.validarNotaNueva(req.body);

    const nota = await enTransaccion(async (client) => {
      const fila = (await client.query(notas.INSERTAR_NOTA, [pacienteId, req.uid, datos.fecha, datos.contenido])).rows[0];
      await bitacora(client, req, 'nota_creada', pacienteId, { nota_id: fila.id });
      return fila;
    });

    logger.info('Nota clínica creada', { paciente_id: pacienteId, especialista_id: req.uid });
    res.status(201).json(nota);
  });

  // PUT /api/pacientes/:pacienteId/notas/:notaId { fecha, contenido, version }
  // La versión vigente pasa a `notas_clinicas_versiones` y la nota sube de
  // versión. 409 si `version` no es la vigente; sin cambios → 200 sin versión
  // nueva.
  router.put('/:pacienteId/notas/:notaId', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    const notaId = idNota(req.params.notaId);
    const datos = notas.validarEdicionNota(req.body);

    const nota = await enTransaccion(async (client) => {
      const actual = (await client.query(notas.BLOQUEAR_NOTA, [notaId, pacienteId, req.uid])).rows[0];
      if (!actual) throw new HttpError('Nota no encontrada.', 404);
      if (!notas.decidirEdicion(actual, datos)) return actual;

      await client.query(notas.GUARDAR_VERSION_ANTERIOR, [notaId]);
      const editada = (await client.query(notas.ACTUALIZAR_NOTA, [notaId, datos.fecha, datos.contenido])).rows[0];
      await bitacora(client, req, 'nota_editada', pacienteId, { nota_id: notaId, version: editada.version });
      return editada;
    });

    res.status(200).json(nota);
  });

  // GET /api/pacientes/:pacienteId/notas/:notaId/versiones — las versiones
  // anteriores (la vigente es la nota misma), de la más nueva a la más vieja.
  router.get('/:pacienteId/notas/:notaId/versiones', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    const notaId = idNota(req.params.notaId);
    const existe = await pool.query(notas.EXISTE_NOTA, [notaId, pacienteId, req.uid]);
    if (existe.rowCount === 0) throw new HttpError('Nota no encontrada.', 404);
    await registrarAcceso(req, pacienteId, 'notas');
    const result = await pool.query(notas.LISTAR_VERSIONES, [notaId]);
    res.status(200).json(result.rows);
  });

  // --- MARCADORES (WEB-RF-28) ---

  // GET /api/pacientes/:pacienteId/marcadores — del par, por fecha (más
  // antiguo primero, como la gráfica).
  router.get('/:pacienteId/marcadores', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    await registrarAcceso(req, pacienteId, 'marcadores');
    const result = await pool.query(marcadores.LISTAR_MARCADORES, [pacienteId, req.uid]);
    res.status(200).json(result.rows);
  });

  // POST /api/pacientes/:pacienteId/marcadores { fecha, tipo, descripcion? }
  router.post('/:pacienteId/marcadores', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    const datos = marcadores.validarMarcadorNuevo(req.body);

    const marcador = await enTransaccion(async (client) => {
      const fila = (await client.query(marcadores.INSERTAR_MARCADOR, [
        pacienteId, req.uid, datos.fecha, datos.tipo, datos.descripcion,
      ])).rows[0];
      await bitacora(client, req, 'marcador_creado', pacienteId, { marcador_id: fila.id });
      return fila;
    });

    res.status(201).json(marcador);
  });

  // DELETE /api/pacientes/:pacienteId/marcadores/:marcadorId — solo su autor
  // (D6); el borrado y su registro van juntos.
  router.delete('/:pacienteId/marcadores/:marcadorId', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    const marcadorId = uuid(req.params.marcadorId, 'del marcador');

    await enTransaccion(async (client) => {
      const borrado = await client.query(marcadores.BORRAR_MARCADOR, [marcadorId, pacienteId, req.uid]);
      if (borrado.rowCount === 0) throw new HttpError('Marcador no encontrado.', 404);
      await bitacora(client, req, 'marcador_eliminado', pacienteId, { marcador_id: marcadorId });
    });

    res.status(204).end();
  });

  // --- REPORTE (WEB-RF-29 / RNF-WEB-08) ---

  // GET /api/pacientes/:pacienteId/reporte?desde&hasta&formato&seudonimizado
  // Datos del periodo para el CSV o la impresión (los arma el portal). La
  // exportación se registra en la bitácora en la misma transacción que las
  // lecturas, y se confirma ANTES de responder: si el registro falla, no
  // sale ningún dato (D2).
  router.get('/:pacienteId/reporte', async (req, res) => {
    const { pacienteId } = req.params;
    await autorizarEspecialistaVinculado(req, pacienteId);
    const filtros = reporte.validarReporte(req.query);
    const params = reporte.parametrosReporte(pacienteId, filtros);

    const datos = await enTransaccion(async (client) => {
      const [personas, sesiones, gad7, marcas] = await Promise.all([
        client.query('SELECT id, nombre, email FROM usuarios WHERE id = ANY($1::varchar[])', [[pacienteId, req.uid]]),
        client.query(reporte.SESIONES_REPORTE, params),
        client.query(reporte.GAD7_REPORTE, params),
        client.query(reporte.MARCADORES_REPORTE, [...params, req.uid]),
      ]);
      const porId = new Map(personas.rows.map((u) => [u.id, u]));
      const armado = reporte.armarReporte({
        pacienteId,
        paciente: porId.get(pacienteId),
        especialista: porId.get(req.uid),
        filtros,
        sesiones: await evaluarSesiones(req, pacienteId, sesiones.rows),
        gad7: gad7.rows,
        marcadores: marcas.rows,
      });
      await bitacora(client, req, 'exportacion', pacienteId, {
        formato: filtros.formato, seudonimizado: filtros.seudonimizado, desde: filtros.desde, hasta: filtros.hasta,
      });
      return armado;
    });

    logger.info('Reporte exportado', { paciente_id: pacienteId, especialista_id: req.uid, formato: filtros.formato });
    res.set('Cache-Control', 'no-store');
    res.status(200).json(datos);
  });

  return router;
}

module.exports = { crearEspecialistaRouter };
