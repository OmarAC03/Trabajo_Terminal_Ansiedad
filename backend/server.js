const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const { Pool } = require('pg'); // Importamos el conector de PostgreSQL
require('dotenv').config();

const logger = require('./logger');
const { validarLectura, validarUsuarioNuevo, validarNombre, validarMensajeChat } = require('./validation');

const app = express();
const server = http.createServer(app);

// Configuración de WebSockets
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// --- CONEXIÓN A LA BASE DE DATOS (Supabase) ---
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false } // Obligatorio para conexiones seguras en la nube
});

pool.connect((err, client, release) => {
  if (err) {
    logger.error('Error al conectar con la base de datos', { detalle: err.message });
    return;
  }
  logger.info('Conexión exitosa a la base de datos en Supabase (PostgreSQL)');
  release();
});
// ----------------------------------------------

// Nota sobre manejo de errores: Express 5 reenvía automáticamente a
// next(err) cualquier excepción síncrona o promesa rechazada dentro de un
// handler `async`. Por eso las rutas de abajo ya no llevan try/catch propio:
// un validador que lanza ValidationError, o un fallo real de `pool.query`,
// terminan en el middleware de error centralizado al final del archivo.

// Ruta para recibir lecturas biométricas de la App / ESP32
app.post('/api/lecturas', async (req, res) => {
  const datos = validarLectura(req.body);

  const query = `
    INSERT INTO lecturas_biometricas (paciente_id, bpm, spo2, hrv, score_ansiedad, estado_ansiedad)
    VALUES ($1, $2, $3, $4, $5, $6)
    RETURNING *;
  `;
  const values = [datos.paciente_id, datos.bpm, datos.spo2, datos.hrv, datos.score_ansiedad, datos.estado_ansiedad];

  const result = await pool.query(query, values);

  logger.info('Nueva lectura guardada', { paciente_id: datos.paciente_id });
  res.status(201).json({ mensaje: 'Lectura guardada con éxito', data: result.rows[0] });
});

// --- NUEVA RUTA PARA CONSULTAR EL HISTORIAL ---
app.get('/api/lecturas', async (req, res) => {
  // "ORDER BY 1" ordena por la primera columna (normalmente el ID o la fecha)
  const query = 'SELECT * FROM lecturas_biometricas ORDER BY 1 DESC';
  const result = await pool.query(query);
  logger.info('Registros recuperados', { total: result.rows.length });
  res.status(200).json(result.rows);
});

// --- HISTORIAL DE UN PACIENTE ESPECÍFICO (registros recientes, sin exponer a otros pacientes) ---
// Usado por la app móvil. GET /api/lecturas/:pacienteId?limite=50
app.get('/api/lecturas/:pacienteId', async (req, res) => {
  const { pacienteId } = req.params;
  const limite = parseInt(req.query.limite) || 50;

  const query = `
    SELECT * FROM lecturas_biometricas
    WHERE paciente_id = $1
    ORDER BY fecha_medicion DESC
    LIMIT $2;
  `;
  const result = await pool.query(query, [pacienteId, limite]);
  res.status(200).json(result.rows);
});

// --- RESUMEN AGREGADO POR DÍA (para gráficas de semana/mes y KPIs) ---
// GET /api/lecturas/:pacienteId/resumen?periodo=semana|mes
// Devuelve el DOBLE del rango pedido (ej. 14 días si pides "semana") para que
// el cliente pueda comparar el periodo actual contra el inmediato anterior
// (tendencias, rachas, etc.) sin tener que hacer una segunda llamada.
app.get('/api/lecturas/:pacienteId/resumen', async (req, res) => {
  const { pacienteId } = req.params;
  const periodo = req.query.periodo === 'mes' ? 'mes' : 'semana';
  const diasPorPeriodo = periodo === 'mes' ? 30 : 7;
  const rangoConsulta = diasPorPeriodo * 2; // periodo actual + periodo anterior

  const query = `
    SELECT
      DATE_TRUNC('day', fecha_medicion) AS dia,
      ROUND(AVG(bpm))::int AS bpm_promedio,
      ROUND(AVG(spo2))::int AS spo2_promedio,
      ROUND(AVG(hrv))::int AS hrv_promedio,
      ROUND(AVG(score_ansiedad), 1) AS score_promedio,
      COUNT(*) FILTER (WHERE estado_ansiedad = 'Alta') AS episodios_altos,
      COUNT(*) FILTER (WHERE estado_ansiedad = 'Moderada') AS episodios_moderados,
      COUNT(*) FILTER (WHERE estado_ansiedad = 'Baja') AS episodios_bajos,
      COUNT(*) AS total_registros
    FROM lecturas_biometricas
    WHERE paciente_id = $1
      AND fecha_medicion >= NOW() - ($2 || ' days')::interval
    GROUP BY DATE_TRUNC('day', fecha_medicion)
    ORDER BY dia ASC;
  `;
  const result = await pool.query(query, [pacienteId, rangoConsulta.toString()]);

  res.status(200).json({
    periodo,
    dias_por_periodo: diasPorPeriodo,
    serie_completa: result.rows, // el cliente separa "actual" vs "anterior" por fecha
  });
});

// Ruta para registrar un nuevo usuario en Supabase (después de Firebase)
app.post('/api/usuarios', async (req, res) => {
  const datos = validarUsuarioNuevo(req.body);

  const query = `
    INSERT INTO usuarios (id, nombre, email, rol)
    VALUES ($1, $2, $3, $4)
    RETURNING *;
  `;
  const values = [datos.id, datos.nombre, datos.email, datos.rol];

  const result = await pool.query(query, values);

  logger.info('Nuevo usuario registrado', { nombre: datos.nombre });
  res.status(201).json({ mensaje: 'Usuario guardado con éxito', data: result.rows[0] });
});

// Obtener el perfil de un usuario (usado por PerfilScreen en la app)
app.get('/api/usuarios/:id', async (req, res) => {
  const { id } = req.params;
  const result = await pool.query('SELECT id, nombre, email, rol FROM usuarios WHERE id = $1', [id]);

  if (result.rows.length === 0) {
    return res.status(404).json({ error: 'Usuario no encontrado' });
  }

  res.status(200).json(result.rows[0]);
});

// Editar el nombre del perfil (único campo que el paciente puede cambiar
// desde la app; email/rol quedan fuera por ahora para no complicar Firebase)
app.put('/api/usuarios/:id', async (req, res) => {
  const { id } = req.params;
  const nombre = validarNombre(req.body);

  const result = await pool.query(
    'UPDATE usuarios SET nombre = $1 WHERE id = $2 RETURNING id, nombre, email, rol',
    [nombre, id]
  );

  if (result.rows.length === 0) {
    return res.status(404).json({ error: 'Usuario no encontrado' });
  }

  logger.info('Perfil actualizado', { nombre });
  res.status(200).json(result.rows[0]);
});

// Middleware de error centralizado: TODA ruta Express que arriba lance (un
// ValidationError de validation.js) o cuyo await rechace (un fallo real de
// pool.query) termina aquí. Evita repetir try/catch + console.error +
// res.status(500) en cada ruta.
app.use((err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  logger.error(err.message, { statusCode, path: req.path, stack: err.stack });
  res.status(statusCode).json({
    error: statusCode === 500 ? 'Error interno del servidor' : err.message,
  });
});

// Escuchando conexiones en tiempo real (WebSockets)
io.on('connection', (socket) => {
  logger.info('Cliente conectado', { socketId: socket.id });

  // Escuchar cuando el paciente o especialista envía un mensaje
  socket.on('enviar_mensaje', async (data) => {
    try {
      const datos = validarMensajeChat(data);

      // 1. Guardar el mensaje en la base de datos (Supabase)
      const query = `
        INSERT INTO mensajes_chat (paciente_id, texto, tipo_mensaje)
        VALUES ($1, $2, $3)
        RETURNING *;
      `;
      const values = [datos.paciente_id, datos.texto, datos.tipo_mensaje];
      const result = await pool.query(query, values);

      // 2. Rebotar el mensaje a todos los dispositivos conectados
      // Emitimos el mensaje ya guardado (con su ID y fecha de la base de datos)
      io.emit('recibir_mensaje', result.rows[0]);
    } catch (error) {
      logger.error('Error al guardar el mensaje', { detalle: error.message, socketId: socket.id });
    }
  });

  socket.on('disconnect', () => {
    logger.info('Cliente desconectado', { socketId: socket.id });
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logger.info(`Servidor corriendo en el puerto ${PORT}`);
});
