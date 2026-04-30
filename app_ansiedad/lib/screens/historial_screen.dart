import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final String _miPacienteId = FirebaseAuth.instance.currentUser?.uid ?? "";
  List<dynamic> _registros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _obtenerHistorial();
  }

  Future<void> _obtenerHistorial() async {
    setState(() => _isLoading = true);
    
    final url = Uri.parse('https://tt-ansiedad-backend.onrender.com/api/lecturas');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        if (mounted) {
          setState(() {
            // Filtramos solo los registros de este paciente específico
            _registros = data.where((item) => item['paciente_id'] == _miPacienteId).toList();
            // Invertimos la lista para mostrar los más recientes arriba
            _registros = _registros.reversed.toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        print("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      print("Error obteniendo historial: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color headerColor = Color(0xFF1E6AFB);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Resúmenes Clínicos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white), 
            onPressed: _obtenerHistorial,
            tooltip: "Actualizar datos",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: headerColor))
          : _registros.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _registros.length,
                  itemBuilder: (context, index) {
                    final registro = _registros[index];
                    
                    // Definir el color de la tarjeta según el estado guardado
                    Color colorEstado = Colors.teal;
                    String estadoTexto = registro['estado_ansiedad'] ?? 'Desconocido';
                    if (estadoTexto == 'Alta') colorEstado = Colors.red;
                    if (estadoTexto == 'Moderada') colorEstado = Colors.orange;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20), 
                        side: BorderSide(color: Colors.grey.shade200)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.monitor_heart, color: colorEstado, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Reporte Sincronizado", 
                                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14)
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorEstado.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  child: Text(
                                    estadoTexto.toUpperCase(), 
                                    style: TextStyle(color: colorEstado, fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMiniDato("BPM", "${registro['bpm']}", Icons.favorite, Colors.blueAccent),
                                _buildMiniDato("SpO2", "${registro['spo2']}%", Icons.opacity, Colors.green),
                                _buildMiniDato("HRV", "${registro['hrv']}", Icons.timer, Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // Widget para diseño de métricas individuales
  Widget _buildMiniDato(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // Widget si la lista está vacía
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("No hay resúmenes guardados", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("Sincroniza desde el monitor para verlos aquí.", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }
}