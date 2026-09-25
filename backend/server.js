const express = require('express');
const http = require('http');
const crypto = require('crypto');
const cors = require('cors');
const { Server } = require('socket.io');
const { Pool } = require('pg'); // Importamos el conector de PostgreSQL
require('dotenv').config();

const logger = require('./logger');
const { AuthError, ValidationError } = require('./errors');
const { inicializarFirebaseAdmin, requiereAuth, requiereAuthSocket } = require('./auth');
const {
  validarLectura,
  validarUsuarioNuevo,
  validarEspecialistaNuevo,
  validarNombre,
  validarCodigoVinculacion,
  validarMensajeChat,
  validarEjercicioAsignado,
} = require('./validation');

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

// --- CÓDIGO DE INSTITUCIÓN (registro de especialistas) ---
// Sin este código nadie puede crear una cuenta de especialista. Si falta,
// el servidor arranca igual (para no tirar el resto de la API) pero el
// registro de especialistas responde 500 hasta que se configure.
if (!process.env.CODIGO_INSTITUCION) {
  logger.warn('Falta la variable de entorno CODIGO_INSTITUCION: el registro de especialistas estará deshabilitado.');
}
// ----------------------------------------------

// --- AUTENTICACIÓN (Firebase Admin) ---
// Falla rápido al arrancar si falta la credencial, en vez de servir 500 en
// cada request que llegue después.
try {
  inicializarFirebaseAdmin();
} catch (error) {
  logger.error('No se pudo inicializar Firebase Admin', { detalle: error.message });
  process.exit(1);
}

// Todas las rutas /api/* requieren un token Firebase válido. Adjunta
// req.uid (uid del token) y req.rol ('paciente' | 'especialista' | null si
// el token es válido pero aún no hay fila en `usuarios`). La autorización
// específica de cada ruta (dueño vs. especialista, etc.) se decide abajo,
// al inicio de cada handler.
app.use('/api', requiereAuth(pool));
// ----------------------------------------------

// Nota sobre manejo de errores: Express 5 reenvía automáticamente a
// next(err) cualquier excepción síncrona o promesa rechazada dentro de un
// handler `async`. Por eso las rutas de abajo ya no llevan try/catch propio:
// un validador que lanza ValidationError, un chequeo de autorización que
// lanza AuthError, o un fallo real de `pool.query`, terminan en el
// middleware de error centralizado al final del archivo.

// Ruta para recibir lecturas biométricas de la App / ESP32
app.post('/api/lecturas', async (req, res) => {
  if (req.body?.paciente_id !== req.uid) {
    throw new AuthError('Solo puedes reportar tus propias lecturas.', 403);
  }
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
  if (req.rol !== 'especialista') {
    throw new AuthError('Solo un especialista puede ver las lecturas de todos los pacientes.', 403);
  }
  // "ORDER BY 1" ordena por la primera columna (normalmente el ID o la fecha)
  const query = 'SELECT * FROM lecturas_biometricas ORDER BY 1 DESC';
  const result = await pool.query(query);
  logger.info('Registros recuperados', { total: result.rows.length });
  res.status(200).json(result.rows);
});

// Autorización para leer datos de UN paciente: el propio paciente, o un
// especialista al que ese paciente esté vinculado (`usuarios.especialista_id`).
// Antes bastaba con `rol === 'especialista'`, así que cualquier especialista
// podía ver a cualquier paciente poniendo su id en la URL.
async function autorizarLecturaPaciente(req, pacienteId, mensaje) {
  if (pacienteId === req.uid) return;
  if (req.rol === 'especialista' && (await esPacienteVinculado(pacienteId, req.uid))) return;
  throw new AuthError(mensaje, 403);
}

// ¿El paciente está vinculado a ese especialista? Usado por las lecturas, el
// historial de mensajes y el chat por Socket.io.
async function esPacienteVinculado(pacienteId, especialistaId) {
  const vinculo = await pool.query(
    "SELECT 1 FROM usuarios WHERE id = $1 AND rol = 'paciente' AND especialista_id = $2",
    [pacienteId, especialistaId]
  );
  return vinculo.rowCount > 0;
}

// Especialista vinculado ACTUALMENTE al paciente (o null). Una conversación
// es el par paciente ↔ este especialista: si el paciente se vincula con otro,
// el nuevo no ve los mensajes anteriores.
async function especialistaDePaciente(pacienteId) {
  const result = await pool.query(
    "SELECT especialista_id FROM usuarios WHERE id = $1 AND rol = 'paciente'",
    [pacienteId]
  );
  return result.rows[0]?.especialista_id || null;
}

// --- HISTORIAL DE UN PACIENTE ESPECÍFICO (registros recientes, sin exponer a otros pacientes) ---
// Usado por la app móvil. GET /api/lecturas/:pacienteId?limite=50
app.get('/api/lecturas/:pacienteId', async (req, res) => {
  const { pacienteId } = req.params;
  await autorizarLecturaPaciente(req, pacienteId, 'No autorizado para ver las lecturas de este paciente.');
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
  await autorizarLecturaPaciente(req, pacienteId, 'No autorizado para ver el resumen de este paciente.');
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

// --- HISTORIAL DEL CHAT DE UN PACIENTE (Fase 2b) ---
// GET /api/mensajes/:pacienteId — el propio paciente o su especialista
// vinculado. Solo devuelve la conversación con el especialista vinculado
// ACTUAL (filtra por `mensajes_chat.especialista_id`). Últimos 200, en orden
// cronológico.
app.get('/api/mensajes/:pacienteId', async (req, res) => {
  const { pacienteId } = req.params;
  await autorizarLecturaPaciente(req, pacienteId, 'No autorizado para ver los mensajes de este paciente.');

  const especialistaId = await especialistaDePaciente(pacienteId);
  if (!especialistaId) {
    return res.status(200).json([]);
  }

  const query = `
    SELECT * FROM (
      SELECT * FROM mensajes_chat
      WHERE paciente_id = $1 AND especialista_id = $2
      ORDER BY fecha_envio DESC
      LIMIT 200
    ) ultimos
    ORDER BY fecha_envio ASC;
  `;
  const result = await pool.query(query, [pacienteId, especialistaId]);
  res.status(200).json(result.rows);
});

// --- EJERCICIOS ASIGNADOS (Fase 2c) ---
// Tabla `ejercicios_asignados`: una técnica de la app (tecnica_id, slug) O un
// texto libre del especialista (texto_personalizado), más una nota opcional.
// `visto` no se guarda: se deriva de `usuarios.ultima_apertura_ejercicios`.

// POST /api/ejercicios — solo el especialista, solo a SUS pacientes
// vinculados. especialista_id lo pone el servidor desde el token.
app.post('/api/ejercicios', async (req, res) => {
  if (req.rol !== 'especialista') {
    throw new AuthError('Solo un especialista puede asignar ejercicios.', 403);
  }
  const datos = validarEjercicioAsignado(req.body);
  if (!(await esPacienteVinculado(datos.paciente_id, req.uid))) {
    throw new AuthError('Este paciente no está vinculado a tu cuenta.', 403);
  }

  const query = `
    INSERT INTO ejercicios_asignados (paciente_id, especialista_id, tecnica_id, texto_personalizado, nota)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING *, false AS visto;
  `;
  const values = [datos.paciente_id, req.uid, datos.tecnica_id, datos.texto_personalizado, datos.nota];
  const result = await pool.query(query, values);

  logger.info('Ejercicio asignado', { paciente_id: datos.paciente_id, especialista_id: req.uid });
  res.status(201).json({ mensaje: 'Ejercicio asignado con éxito', data: result.rows[0] });
});

// GET /api/ejercicios/:pacienteId — el propio paciente o su especialista
// vinculado. Igual que el chat, solo los del especialista vinculado ACTUAL:
// si el paciente cambia de especialista, el nuevo no ve las asignaciones del
// anterior. Más recientes primero.
app.get('/api/ejercicios/:pacienteId', async (req, res) => {
  const { pacienteId } = req.params;
  await autorizarLecturaPaciente(req, pacienteId, 'No autorizado para ver los ejercicios de este paciente.');

  const especialistaId = await especialistaDePaciente(pacienteId);
  if (!especialistaId) {
    return res.status(200).json([]);
  }

  const query = `
    SELECT e.*, (e.fecha_asignacion <= u.ultima_apertura_ejercicios) AS visto
    FROM ejercicios_asignados e
    JOIN usuarios u ON u.id = e.paciente_id
    WHERE e.paciente_id = $1 AND e.especialista_id = $2
    ORDER BY e.fecha_asignacion DESC
    LIMIT 200;
  `;
  const result = await pool.query(query, [pacienteId, especialistaId]);
  res.status(200).json(result.rows);
});

// --- INDICADORES DE PENDIENTE (badges de la app, Fase 2c) ---
// Una marca de "última apertura" por sección en `usuarios`. Pendiente =
// lo que llegó después de esa marca, siempre dentro de la conversación con el
// especialista vinculado ACTUAL (mismo criterio que GET /api/mensajes).
const SECCIONES_PENDIENTES = {
  mensajes: 'ultima_apertura_mensajes',
  ejercicios: 'ultima_apertura_ejercicios',
};

// GET /api/pendientes — conteo para el paciente autenticado. Los mensajes
// cuentan solo si los escribió el especialista (remitente_id distinto del
// paciente; los antiguos con remitente_id null eran del paciente).
app.get('/api/pendientes', async (req, res) => {
  if (req.rol !== 'paciente') {
    throw new AuthError('Solo un paciente tiene indicadores de pendiente.', 403);
  }

  const query = `
    SELECT
      (SELECT COUNT(*) FROM mensajes_chat m
        WHERE m.paciente_id = u.id
          AND m.especialista_id = u.especialista_id
          AND m.remitente_id IS NOT NULL AND m.remitente_id <> u.id
          AND m.fecha_envio > u.ultima_apertura_mensajes)::int AS mensajes,
      (SELECT COUNT(*) FROM ejercicios_asignados e
        WHERE e.paciente_id = u.id
          AND e.especialista_id = u.especialista_id
          AND e.fecha_asignacion > u.ultima_apertura_ejercicios)::int AS ejercicios
    FROM usuarios u
    WHERE u.id = $1;
  `;
  const result = await pool.query(query, [req.uid]);
  res.status(200).json(result.rows[0] ?? { mensajes: 0, ejercicios: 0 });
});

// POST /api/pendientes/:seccion/visto — el paciente abrió la sección: mueve
// su marca a "ahora" y devuelve la marca ANTERIOR, para que la app resalte
// como "nuevo" lo que llegó desde entonces sin carrera entre marcar y listar.
app.post('/api/pendientes/:seccion/visto', async (req, res) => {
  if (req.rol !== 'paciente') {
    throw new AuthError('Solo un paciente tiene indicadores de pendiente.', 403);
  }
  // El nombre de columna sale de la lista fija de arriba, nunca del cliente.
  const columna = SECCIONES_PENDIENTES[req.params.seccion];
  if (!columna) {
    throw new ValidationError(`Sección inválida. Debe ser una de: ${Object.keys(SECCIONES_PENDIENTES).join(', ')}.`);
  }

  const query = `
    UPDATE usuarios u SET ${columna} = now()
    FROM (SELECT ${columna} AS anterior FROM usuarios WHERE id = $1) previo
    WHERE u.id = $1
    RETURNING previo.anterior, u.${columna} AS actual;
  `;
  const result = await pool.query(query, [req.uid]);
  if (result.rows.length === 0) {
    return res.status(404).json({ error: 'Usuario no encontrado' });
  }
  res.status(200).json(result.rows[0]);
});

// Ruta para registrar un nuevo usuario en Supabase (después de Firebase)
app.post('/api/usuarios', async (req, res) => {
  if (req.body?.id !== req.uid) {
    throw new AuthError('Solo puedes registrar tu propio usuario.', 403);
  }
  const datos = validarUsuarioNuevo(req.body);
  // Ser especialista exige el código de institución: se registra únicamente
  // por POST /api/especialistas, nunca por esta ruta.
  if (datos.rol !== 'paciente') {
    throw new AuthError('Este endpoint solo registra pacientes.', 403);
  }

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

// Alfabeto sin caracteres ambiguos (0/O, 1/I/L) para que el código sea fácil
// de dictar o copiar. 31^6 ≈ 887 millones de combinaciones.
const ALFABETO_CODIGO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const LONGITUD_CODIGO = 6;
const MAX_INTENTOS_CODIGO = 5;

function generarCodigoVinculacion() {
  let codigo = '';
  for (let i = 0; i < LONGITUD_CODIGO; i++) {
    codigo += ALFABETO_CODIGO[crypto.randomInt(ALFABETO_CODIGO.length)];
  }
  return codigo;
}

// Comparación en tiempo constante para no filtrar el código por timing.
function codigoInstitucionValido(recibido) {
  const esperado = process.env.CODIGO_INSTITUCION;
  const a = crypto.createHash('sha256').update(recibido).digest();
  const b = crypto.createHash('sha256').update(esperado).digest();
  return crypto.timingSafeEqual(a, b);
}

// Registro de especialista (después de crear su cuenta en Firebase, igual que
// POST /api/usuarios). Exige el código de institución y le asigna su código de
// vinculación único, el que luego compartirá con sus pacientes.
app.post('/api/especialistas', async (req, res) => {
  if (!process.env.CODIGO_INSTITUCION) {
    throw new Error('CODIGO_INSTITUCION no está configurada en el servidor.');
  }
  const datos = validarEspecialistaNuevo(req.body);
  if (!codigoInstitucionValido(datos.codigo_institucion)) {
    logger.warn('Registro de especialista rechazado: código de institución incorrecto', { uid: req.uid });
    throw new AuthError('Código de institución incorrecto.', 403);
  }

  // ON CONFLICT (codigo_vinculacion) DO NOTHING: si el código generado ya
  // existe no hay fila nueva y reintentamos con otro. Un conflicto en `id`
  // (la cuenta ya está registrada) sí lanza error y se responde 409 abajo.
  const query = `
    INSERT INTO usuarios (id, nombre, email, rol, codigo_vinculacion)
    VALUES ($1, $2, $3, 'especialista', $4)
    ON CONFLICT (codigo_vinculacion) DO NOTHING
    RETURNING id, nombre, email, rol, codigo_vinculacion;
  `;

  let fila = null;
  try {
    for (let intento = 0; intento < MAX_INTENTOS_CODIGO && !fila; intento++) {
      const result = await pool.query(query, [req.uid, datos.nombre, datos.email, generarCodigoVinculacion()]);
      fila = result.rows[0] ?? null;
    }
  } catch (error) {
    if (error.code === '23505') {
      throw new AuthError('Esta cuenta ya está registrada.', 409);
    }
    throw error;
  }
  if (!fila) {
    throw new Error('No se pudo generar un código de vinculación único.');
  }

  logger.info('Nuevo especialista registrado', { nombre: fila.nombre });
  res.status(201).json({ mensaje: 'Especialista registrado con éxito', data: fila });
});

// --- VINCULACIÓN PACIENTE–ESPECIALISTA (tipo Classroom, ver CONTEXTO_PROYECTO.md 4ter) ---
// El paciente ingresa el codigo_vinculacion fijo de su especialista; si existe,
// se guarda el id del especialista en su propia fila (`usuarios.especialista_id`).
// Requiere la columna `especialista_id` en `usuarios` (varchar, referencia a
// usuarios.id) — agregarla a mano en Supabase si todavía no existe.
app.post('/api/vinculacion', async (req, res) => {
  if (req.rol !== 'paciente') {
    throw new AuthError('Solo un paciente puede vincularse a un especialista.', 403);
  }
  const datos = validarCodigoVinculacion(req.body);

  const especialista = await pool.query(
    "SELECT id, nombre FROM usuarios WHERE rol = 'especialista' AND codigo_vinculacion = $1",
    [datos.codigo_vinculacion]
  );
  if (especialista.rows.length === 0) {
    throw new ValidationError('Código de vinculación inválido.');
  }
  const { id: especialistaId, nombre: especialistaNombre } = especialista.rows[0];

  await pool.query('UPDATE usuarios SET especialista_id = $1 WHERE id = $2', [especialistaId, req.uid]);

  logger.info('Paciente vinculado a especialista', { paciente_id: req.uid, especialista_id: especialistaId });
  res.status(200).json({
    mensaje: 'Vinculación exitosa',
    data: { especialista_id: especialistaId, especialista_nombre: especialistaNombre },
  });
});

// Consulta el estado de vinculación del paciente autenticado (y el nombre del
// especialista, si ya está vinculado). Usado por VinculacionScreen en la app.
app.get('/api/vinculacion', async (req, res) => {
  if (req.rol !== 'paciente') {
    throw new AuthError('Solo un paciente puede consultar su vinculación.', 403);
  }

  const result = await pool.query(
    `SELECT e.id AS especialista_id, e.nombre AS especialista_nombre
     FROM usuarios u
     LEFT JOIN usuarios e ON e.id = u.especialista_id
     WHERE u.id = $1`,
    [req.uid]
  );
  const fila = result.rows[0];

  res.status(200).json({
    vinculado: Boolean(fila?.especialista_id),
    especialista_id: fila?.especialista_id ?? null,
    especialista_nombre: fila?.especialista_nombre ?? null,
  });
});

// Obtener el perfil de un usuario (usado por PerfilScreen en la app y por el
// Portal Web para leer su propio codigo_vinculacion; en pacientes ese campo
// simplemente viene null).
app.get('/api/usuarios/:id', async (req, res) => {
  const { id } = req.params;
  if (id !== req.uid && req.rol !== 'especialista') {
    throw new AuthError('No autorizado para ver este perfil.', 403);
  }
  const result = await pool.query('SELECT id, nombre, email, rol, codigo_vinculacion FROM usuarios WHERE id = $1', [id]);

  if (result.rows.length === 0) {
    return res.status(404).json({ error: 'Usuario no encontrado' });
  }

  res.status(200).json(result.rows[0]);
});

// Lista de pacientes para el Portal Web (con su última lectura, si tiene).
// Solo un especialista puede ver la lista, y SOLO la de sus propios pacientes
// (los vinculados a él vía `especialista_id`, Fase D — antes traía a todos).
app.get('/api/pacientes', async (req, res) => {
  if (req.rol !== 'especialista') {
    throw new AuthError('Solo un especialista puede ver la lista de pacientes.', 403);
  }

  const query = `
    SELECT
      u.id, u.nombre, u.email,
      lu.estado_ansiedad AS ultimo_estado,
      lu.fecha_medicion AS ultima_lectura
    FROM usuarios u
    LEFT JOIN LATERAL (
      SELECT estado_ansiedad, fecha_medicion
      FROM lecturas_biometricas l
      WHERE l.paciente_id = u.id
      ORDER BY fecha_medicion DESC
      LIMIT 1
    ) lu ON true
    WHERE u.rol = 'paciente' AND u.especialista_id = $1
    ORDER BY u.nombre ASC;
  `;
  const result = await pool.query(query, [req.uid]);
  res.status(200).json(result.rows);
});

// Editar el nombre del perfil (único campo que el paciente puede cambiar
// desde la app; email/rol quedan fuera por ahora para no complicar Firebase)
app.put('/api/usuarios/:id', async (req, res) => {
  const { id } = req.params;
  if (id !== req.uid && req.rol !== 'especialista') {
    throw new AuthError('No autorizado para editar este perfil.', 403);
  }
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

// Todo socket debe traer un token Firebase válido en el handshake
// (`io(url, { auth: { token } })` del lado del cliente).
io.use(requiereAuthSocket(pool));

// Salas privadas: cada usuario escucha solo la suya. Antes el servidor hacía
// io.emit a TODOS los sockets conectados, así que cada paciente recibía los
// mensajes de los demás. Ahora cada mensaje va solo al paciente y a su
// especialista vinculado ACTUAL (calculado en el momento del envío, así que
// si el paciente cambia de especialista el anterior deja de recibir).
const salaUsuario = (uid) => `usuario:${uid}`;

// Responde al emisor por el callback de acknowledgement de Socket.io, si lo
// mandó (los clientes viejos emiten sin callback).
const responder = (ack, respuesta) => {
  if (typeof ack === 'function') ack(respuesta);
};

// Escuchando conexiones en tiempo real (WebSockets)
io.on('connection', (socket) => {
  logger.info('Cliente conectado', { socketId: socket.id, uid: socket.data.uid });

  // Cada socket escucha solo su propia sala. El portal filtra por paciente
  // en el cliente (al especialista solo le llegan mensajes de SUS pacientes).
  socket.join(salaUsuario(socket.data.uid));

  // Escuchar cuando el paciente o especialista envía un mensaje
  socket.on('enviar_mensaje', async (data, ack) => {
    try {
      const datos = validarMensajeChat(data);
      const { uid, rol } = socket.data;

      // Autorización: el paciente solo escribe en SU conversación (y debe
      // tener especialista vinculado); el especialista solo a SUS pacientes.
      let especialistaId;
      if (rol === 'paciente' && datos.paciente_id === uid) {
        especialistaId = await especialistaDePaciente(uid);
        if (!especialistaId) {
          return responder(ack, { ok: false, error: 'Aún no tienes un especialista vinculado.' });
        }
      } else if (rol === 'especialista' && (await esPacienteVinculado(datos.paciente_id, uid))) {
        especialistaId = uid;
      } else {
        logger.warn('Mensaje rechazado: emisor sin acceso a la conversación', { socketId: socket.id, uid });
        return responder(ack, { ok: false, error: 'No autorizado para escribir en esta conversación.' });
      }

      // 1. Guardar el mensaje en la base de datos (Supabase). remitente_id y
      // especialista_id los pone el servidor, nunca el cliente.
      const query = `
        INSERT INTO mensajes_chat (remitente_id, paciente_id, especialista_id, texto, tipo_mensaje)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *;
      `;
      const values = [uid, datos.paciente_id, especialistaId, datos.texto, datos.tipo_mensaje];
      const result = await pool.query(query, values);

      // 2. Enviar el mensaje ya guardado (con su id y fecha) SOLO a los dos
      // participantes de la conversación.
      io.to(salaUsuario(datos.paciente_id)).to(salaUsuario(especialistaId)).emit('recibir_mensaje', result.rows[0]);
      responder(ack, { ok: true });
    } catch (error) {
      logger.error('Error al guardar el mensaje', { detalle: error.message, socketId: socket.id });
      responder(ack, {
        ok: false,
        error: error instanceof ValidationError ? error.message : 'No se pudo enviar el mensaje.',
      });
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
