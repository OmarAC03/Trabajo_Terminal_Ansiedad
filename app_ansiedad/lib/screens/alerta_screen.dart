import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AlertaScreen extends StatefulWidget {
  const AlertaScreen({super.key});

  @override
  State<AlertaScreen> createState() => _AlertaScreenState();
}

class _AlertaScreenState extends State<AlertaScreen> {
  // --- VARIABLES DE DATOS ---
  String _nombreUsuario = "Omar Ángeles"; 
  int _bpmActual = 0;
  int _spo2Actual = 0;
  int _hrvActual = 0;
  double _ansiedadScore = 0.0;
  String _estadoAnsiedadText = "Normal";
  Color _estadoAnsiedadColor = Colors.green;
  String _lastSyncTime = "Hace 2 min";
  bool _sensorConectado = false;

  // --- FUNCIÓN DE SIMULACIÓN ---
  void _simularDatos() {
    setState(() {
      _bpmActual = 65 + Random().nextInt(40); 
      _spo2Actual = 95 + Random().nextInt(5);  
      _hrvActual = 15 + Random().nextInt(20);  

      if (_bpmActual > 98) {
        _ansiedadScore = 7.1;
        _estadoAnsiedadText = "Alta";
        _estadoAnsiedadColor = Colors.redAccent;
      } else if (_bpmActual > 85) {
        _ansiedadScore = 6.2;
        _estadoAnsiedadText = "Moderada";
        _estadoAnsiedadColor = Colors.orange;
      } else {
        _ansiedadScore = 4.8;
        _estadoAnsiedadText = "Baja";
        _estadoAnsiedadColor = Colors.teal;
      }
      _lastSyncTime = "Ahora";
      _sensorConectado = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _simularDatos();
  }

  @override
  Widget build(BuildContext context) {
    const Color headerColor = Color(0xFF1E6AFB); 

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB), 
      body: Stack(
        children: [
          // 1. Capa de Fondo (Header Azul con degradado)
          Container(
            height: MediaQuery.of(context).size.height * 0.35, 
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [headerColor, Color(0xFF0C52CE)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          // 2. Capa de Contenido (Scroll)
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Buenos días,",
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                        ),
                        Text(
                          _nombreUsuario,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Último sync: $_lastSyncTime",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 30, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                _buildSensorStatusChip(_sensorConectado),
                const SizedBox(height: 30),

                // GRID DE MÉTRICAS
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "FREC. CARDÍACA",
                        value: "$_bpmActual",
                        unit: "BPM",
                        subtext: "+8 vs. base",
                        color: Colors.blueAccent,
                        icon: Icons.favorite,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildMetricCard(
                        title: "SPO2",
                        value: "$_spo2Actual",
                        unit: "%",
                        subtext: "✓ Normal",
                        color: Colors.green,
                        icon: Icons.opacity,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "HRV - RMSSD",
                        value: "$_hrvActual",
                        unit: "ms",
                        subtext: "▼ Baja",
                        color: Colors.orange,
                        icon: Icons.timer,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildMetricCard(
                        title: "ANSIEDAD",
                        value: _ansiedadScore.toStringAsFixed(1),
                        unit: "/ 10",
                        subtext: "▲ $_estadoAnsiedadText",
                        color: _estadoAnsiedadColor,
                        icon: Icons.warning_amber_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildGraphPlaceholderCard(),
                const SizedBox(height: 20),

                _buildScoreGradientCard(),
                const SizedBox(height: 30),

                // --- BOTONES DE ACCIÓN ---
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.history),
                  label: const Text("Ver historial completo"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.self_improvement),
                  label: const Text("Técnicas de relajación"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.notification_important),
                  label: const Text("Alerta al especialista"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),

                // --- NUEVO BOTÓN: ENVIAR A LA NUBE ---
                ElevatedButton.icon(
                  onPressed: () async {
                    // 1. URL usando tu IP local apuntando al puerto de Node.js
                    final url = Uri.parse('https://tt-ansiedad-backend.onrender.com');
                    
                    // 2. Preparamos el paquete JSON con tu UUID
                    final payload = {
                      "paciente_id": "890e9e28-59f8-43a2-9d67-08a387311d68", 
                      "bpm": _bpmActual,
                      "spo2": _spo2Actual,
                      "hrv": _hrvActual,
                      "score_ansiedad": _ansiedadScore,
                      "estado_ansiedad": _estadoAnsiedadText
                    };

                    try {
                      // 3. Disparamos la petición
                      final response = await http.post(
                        url,
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode(payload),
                      );

                      // Regla de Flutter: Validar que la pantalla siga activa antes de mostrar el mensaje
                      if (!mounted) return;

                      if (response.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Datos biométricos enviados a la Nube"),
                            backgroundColor: Colors.green,
                          )
                        );
                      } else {
                        throw Exception("Error del servidor: ${response.statusCode}");
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("❌ Error de red: $e"),
                          backgroundColor: Colors.red,
                        )
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("Subir lectura de prueba"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Botón flotante para cambiar los valores
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _simularDatos,
        icon: const Icon(Icons.sync),
        label: const Text("Generar nuevos datos"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtext,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: (title == "SPO2" && value == "97") ? color : Colors.black87,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtext,
              style: TextStyle(
                color: (subtext.contains("▲") || subtext.contains("▼")) ? color : Colors.teal,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorStatusChip(bool conectado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            conectado ? Icons.check_circle : Icons.error,
            color: conectado ? Colors.greenAccent : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            conectado ? "Sensor conectado · ESP32" : "Sensor desconectado",
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphPlaceholderCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "Frecuencia cardíaca · últimos 10 min",
                    style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text("En vivo", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 100,
              color: Colors.blue.withOpacity(0.05),
              child: const Center(
                child: Icon(Icons.show_chart, size: 60, color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreGradientCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Score de ansiedad · ahora",
                  style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${_ansiedadScore.toStringAsFixed(1)} / 10",
                  style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  colors: [Colors.teal, Colors.yellow, Colors.orange, Colors.redAccent],
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Sin ansiedad", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                Text("Moderada", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                Text("Alta", style: TextStyle(color: Colors.redAccent, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}