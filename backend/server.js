const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const { Pool } = require('pg'); // Importamos el conector de PostgreSQL
require('dotenv').config();

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
    return console.error('❌ Error al conectar con la base de datos:', err.stack);
  }
  console.log('✅ Conexión exitosa a la base de datos en Supabase (PostgreSQL)');
  release();
});
// ----------------------------------------------

// Ruta para recibir lecturas biométricas de la App / ESP32
app.post('/api/lecturas', async (req, res) => {
  try {
    const { paciente_id, bpm, spo2, hrv, score_ansiedad, estado_ansiedad } = req.body;

    // Insertar en la tabla lecturas_biometricas de Supabase
    const query = `
      INSERT INTO lecturas_biometricas (paciente_id, bpm, spo2, hrv, score_ansiedad, estado_ansiedad) 
      VALUES ($1, $2, $3, $4, $5, $6) 
      RETURNING *;
    `;
    const values = [paciente_id, bpm, spo2, hrv, score_ansiedad, estado_ansiedad];
    
    const result = await pool.query(query, values);

    console.log('✅ Nueva lectura guardada para el paciente:', paciente_id);
    res.status(201).json({ mensaje: 'Lectura guardada con éxito', data: result.rows[0] });

  } catch (error) {
    console.error('❌ Error al guardar la lectura:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});
// Escuchando conexiones en tiempo real (WebSockets)
io.on('connection', (socket) => {
  console.log('🟢 Un cliente se ha conectado:', socket.id);

  // Escuchar cuando el paciente o especialista envía un mensaje
  socket.on('enviar_mensaje', async (data) => {
    console.log('📩 Nuevo mensaje recibido:', data.texto);

    try {
      // 1. Guardar el mensaje en la base de datos (Supabase)
      const query = `
        INSERT INTO mensajes_chat (paciente_id, texto, tipo_mensaje) 
        VALUES ($1, $2, $3) 
        RETURNING *;
      `;
      // Usamos tu UUID y el texto que venga del celular
      const values = [data.paciente_id, data.texto, data.tipo_mensaje || 'texto'];
      const result = await pool.query(query, values);

      // 2. Rebotar el mensaje a todos los dispositivos conectados
      // Emitimos el mensaje ya guardado (con su ID y fecha de la base de datos)
      io.emit('recibir_mensaje', result.rows[0]);

    } catch (error) {
      console.error('❌ Error al guardar el mensaje:', error);
    }
  });

  socket.on('disconnect', () => {
    console.log('🔴 Cliente desconectado:', socket.id);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Servidor corriendo en el puerto ${PORT}`);
});