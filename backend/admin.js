const express = require('express');
const admin = require('firebase-admin');
const logger = require('./logger');
const { ValidationError, HttpError } = require('./errors');
const { validarEdicionAdmin } = require('./validation');

// Rutas del rol Admin (Fase C, ver PLAN_FASE_C_ADMIN.md). server.js monta este
// router detrás de `requiereAdmin`, así que aquí todo request ya es de un
// admin. El admin gestiona CUENTAS: ninguna ruta devuelve datos clínicos
// (lecturas, mensajes ni ejercicios).

// Una fila por cuenta, con el mismo formato en la lista y en la respuesta de
// la edición. Para pacientes trae el especialista vinculado; para
// especialistas, cuántos pacientes tienen vinculados. El estado sale de
// `eliminado_en` (borrado lógico) y `suspendido`; la eliminada gana si
// tuviera ambas.
const SELECT_USUARIOS = `
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
`;

const CORREO_EN_USO = 'Ese correo ya está en uso por otra cuenta.';

// uid de la cuenta de Firebase con ese correo, o null si no hay ninguna.
async function uidFirebasePorEmail(email) {
  try {
    return (await admin.auth().getUserByEmail(email)).uid;
  } catch (error) {
    if (error.code === 'auth/user-not-found') return null;
    throw error;
  }
}

// Traduce un fallo de Firebase al cambiar el correo. En todos estos casos la
// transacción de la base todavía no se confirmó, así que se revierte y no
// queda nada a medias.
function errorFirebaseEmail(error) {
  switch (error.code) {
    case 'auth/email-already-exists':
      return new HttpError(CORREO_EN_USO, 409);
    case 'auth/invalid-email':
      return new ValidationError('Firebase rechazó el correo por formato inválido.');
    case 'auth/user-not-found':
      return new HttpError('Esta cuenta no existe en Firebase Authentication; no se cambió nada.', 409);
    default:
      logger.error('Firebase no pudo cambiar el correo', { codigo: error.code, detalle: error.message });
      return new HttpError('No se pudo actualizar el correo en Firebase. No se guardó ningún cambio; inténtalo de nuevo.', 502);
  }
}

function crearAdminRouter(pool) {
  const router = express.Router();

  // GET /api/admin/usuarios — todas las cuentas con su estado.
  router.get('/usuarios', async (req, res) => {
    const result = await pool.query(`${SELECT_USUARIOS} ORDER BY lower(u.nombre) ASC;`);

    logger.info('Admin consultó la lista de usuarios', { admin_uid: req.uid, total: result.rows.length });
    res.status(200).json(result.rows);
  });

  // PUT /api/admin/usuarios/:id — edita nombre, email y (solo pacientes) el
  // especialista vinculado (null = desvincular). Cuerpo parcial.
  //
  // Consistencia Firebase ↔ base (el correo vive en los dos): no hay una
  // transacción que abarque ambos, así que la base se cambia DENTRO de una
  // transacción y Firebase se cambia ANTES de confirmarla:
  //   - si algo falla antes o durante el cambio en Firebase → ROLLBACK, y
  //     ninguno de los dos cambió;
  //   - si Firebase cambió pero el COMMIT falla → se COMPENSA devolviendo en
  //     Firebase el correo que tenía. Si eso también falla, se registra como
  //     INCONSISTENCIA con ambos correos para corregirlo a mano.
  // La fila se bloquea (FOR UPDATE) para que dos admins no la editen a la vez.
  router.put('/usuarios/:id', async (req, res) => {
    const { id } = req.params;
    const cambios = validarEdicionAdmin(req.body);

    const client = await pool.connect();
    let enTransaccion = false;
    let errorConexion; // si se pasa a release(), el pool descarta la conexión
    try {
      await client.query('BEGIN');
      enTransaccion = true;

      const actual = (
        await client.query(
          'SELECT id, nombre, email, rol, especialista_id, eliminado_en FROM usuarios WHERE id = $1 FOR UPDATE',
          [id]
        )
      ).rows[0];
      if (!actual) {
        throw new HttpError('Usuario no encontrado.', 404);
      }
      if (actual.eliminado_en) {
        throw new HttpError('No se puede editar una cuenta eliminada.', 409);
      }

      // Solo lo que cambia de verdad. Las claves salen de la lista fija de
      // validarEdicionAdmin, nunca del cliente, así que van seguras al SQL.
      const set = {};
      if (cambios.nombre !== undefined && cambios.nombre !== actual.nombre) {
        set.nombre = cambios.nombre;
      }
      if (cambios.email !== undefined && cambios.email !== (actual.email || '').toLowerCase()) {
        set.email = cambios.email;
      }
      if (cambios.especialista_id !== undefined) {
        if (actual.rol !== 'paciente') {
          throw new ValidationError('Solo se puede asignar especialista a una cuenta de paciente.');
        }
        if (cambios.especialista_id !== actual.especialista_id) {
          set.especialista_id = cambios.especialista_id;
        }
      }

      const columnas = Object.keys(set);
      if (columnas.length > 0) {
        if (set.especialista_id) {
          const especialista = await client.query(
            "SELECT 1 FROM usuarios WHERE id = $1 AND rol = 'especialista' AND NOT suspendido AND eliminado_en IS NULL",
            [set.especialista_id]
          );
          if (especialista.rowCount === 0) {
            throw new ValidationError('Especialista no válido: debe ser una cuenta de especialista activa.');
          }
        }

        if (set.email) {
          const repetido = await client.query(
            'SELECT 1 FROM usuarios WHERE lower(email) = $1 AND id <> $2',
            [set.email, id]
          );
          const otroUid = repetido.rowCount === 0 ? await uidFirebasePorEmail(set.email) : null;
          if (repetido.rowCount > 0 || (otroUid && otroUid !== id)) {
            throw new HttpError(CORREO_EN_USO, 409);
          }
        }

        const asignaciones = columnas.map((columna, i) => `${columna} = $${i + 2}`).join(', ');
        try {
          await client.query(`UPDATE usuarios SET ${asignaciones} WHERE id = $1`, [id, ...columnas.map((c) => set[c])]);
        } catch (error) {
          if (error.code === '23505') throw new HttpError(CORREO_EN_USO, 409);
          throw error;
        }
      }

      // Firebase al final, con la base todavía sin confirmar.
      let emailFirebaseAnterior;
      if (set.email) {
        try {
          emailFirebaseAnterior = (await admin.auth().getUser(id)).email;
          await admin.auth().updateUser(id, { email: set.email });
        } catch (error) {
          throw errorFirebaseEmail(error);
        }
      }

      try {
        await client.query('COMMIT');
        enTransaccion = false;
      } catch (errorCommit) {
        // La transacción ya no existe (falló el COMMIT): no hay ROLLBACK que hacer.
        enTransaccion = false;
        errorConexion = errorCommit;
        logger.error('Falló el COMMIT al editar un usuario', { admin_uid: req.uid, usuario_id: id, detalle: errorCommit.message });
        if (set.email) {
          try {
            await admin.auth().updateUser(id, { email: emailFirebaseAnterior });
            logger.warn('Cambio de correo revertido en Firebase tras fallar el COMMIT', { admin_uid: req.uid, usuario_id: id });
          } catch (errorCompensacion) {
            logger.error('INCONSISTENCIA email admin: Firebase quedó con el correo nuevo y la base con el anterior', {
              admin_uid: req.uid,
              usuario_id: id,
              email_firebase: set.email,
              email_bd: actual.email,
              detalle: errorCompensacion.message,
            });
            throw new HttpError(
              'El correo quedó distinto entre Firebase y la base de datos. Revisa los logs del servidor y corrígelo a mano.',
              502
            );
          }
        }
        throw new HttpError('No se pudo guardar el cambio. No se modificó nada; inténtalo de nuevo.', 503);
      }

      if (columnas.length > 0) {
        logger.info('Admin editó usuario', { admin_uid: req.uid, usuario_id: id, campos: columnas });
      }
    } catch (error) {
      if (enTransaccion) {
        try {
          await client.query('ROLLBACK');
        } catch (errorRollback) {
          errorConexion = errorRollback;
          logger.error('Falló el ROLLBACK al editar un usuario', { usuario_id: id, detalle: errorRollback.message });
        }
      }
      throw error;
    } finally {
      client.release(errorConexion);
    }

    const fila = (await pool.query(`${SELECT_USUARIOS} WHERE u.id = $1;`, [id])).rows[0];
    res.status(200).json(fila);
  });

  return router;
}

module.exports = { crearAdminRouter };
