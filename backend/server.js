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

// Ruta de prueba
// --- ENDPOINT PARA RECIBIR DATOS DEL ESP32 ---
app.post('/api/lecturas', async (req, res) => {
  // 1. Extraemos los datos que nos mandará el ESP32 (o la app móvil por ahora)
  const { paciente_id, bpm, spo2, hrv, score_ansiedad, estado_ansiedad } = req.body;

  try {
    // 2. Preparamos la instrucción SQL para insertar la lectura
    const query = `
      INSERT INTO lecturas_biometricas (paciente_id, bpm, spo2, hrv, score_ansiedad, estado_ansiedad)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *;
    `;
    
    // 3. Pasamos los valores de forma segura (evita inyecciones SQL)
    const values = [paciente_id, bpm, spo2, hrv, score_ansiedad, estado_ansiedad];

    // 4. Ejecutamos la consulta en Supabase
    const result = await pool.query(query, values);

    // 5. Respondemos con éxito
    res.status(201).json({
      mensaje: '✅ Lectura biométrica guardada exitosamente',
      datos_guardados: result.rows[0]
    });

  } catch (error) {
    console.error('❌ Error al guardar la lectura:', error);
    res.status(500).json({ error: 'Error interno del servidor al guardar datos' });
  }
});

// Escuchando conexiones en tiempo real
io.on('connection', (socket) => {
  console.log('Un cliente se ha conectado:', socket.id);

  socket.on('disconnect', () => {
    console.log('Cliente desconectado:', socket.id);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Servidor corriendo en el puerto ${PORT}`);
});