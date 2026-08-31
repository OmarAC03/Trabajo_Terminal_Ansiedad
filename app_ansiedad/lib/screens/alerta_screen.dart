import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_config.dart';
import '../providers/alerta_provider.dart';

/// Pantalla de Alerta (Monitor) — capa de UI.
///
/// Tras el refactor a capas, esta pantalla NO toca Bluetooth, NO llama a la
/// red y NO calcula el semáforo de ansiedad. Solo crea el AlertaProvider,
/// escucha sus cambios y dibuja, igual que Historial y Perfil.
class AlertaScreen extends StatelessWidget {
  const AlertaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return ChangeNotifierProvider(
      create: (_) => AlertaProvider(pacienteId: uid),
      child: const _AlertaView(),
    );
  }
}

class _AlertaView extends StatelessWidget {
  const _AlertaView();

  static const Color primaryBlue = Color(0xFF1E6AFB);

  String get _nombreUsuario =>
      FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? "Paciente";

  void _mostrarSnack(BuildContext context, String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _conectar(BuildContext context, AlertaProvider p) async {
    final mensaje = await p.escanearYConectar();
    if (mensaje == null || !context.mounted) return;
    _mostrarSnack(context, mensaje.texto, mensaje.advertencia ? Colors.orange : Colors.red);
  }

  Future<void> _sincronizar(BuildContext context, AlertaProvider p) async {
    if (!p.tieneDatosPendientes) return;
    _mostrarSnack(context, "Enviando resumen...", Colors.blueGrey);

    final r = await p.enviarResumen();
    if (!context.mounted) return;

    switch (r.resultado) {
      case ResultadoSync.sinDatos:
        break;
      case ResultadoSync.exito:
        _mostrarSnack(context, "✅ Resumen guardado en historial", Colors.green);
        break;
      case ResultadoSync.error:
        _mostrarSnack(context, "❌ ${r.mensajeError}", Colors.red);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AlertaProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Stack(
        children: [
          _buildDisenoFondo(context, primaryBlue), // El fondo azul
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(p), // Nombre y estado
                const SizedBox(height: 12),
                _buildBotonSimulacion(context, p),
                const SizedBox(height: 25),
                _buildAnxietyIndicator(p), // El semáforo visual

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard("CORAZÓN", "${p.bpmActual}", "BPM", Colors.blueAccent, Icons.favorite)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildMetricCard("OXÍGENO", "${p.spo2Actual}", "%", Colors.green, Icons.opacity)),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard("VARIABILIDAD", "${p.hrvActual}", "ms", Colors.orange, Icons.timer)),
                    Expanded(
                      child: _buildMetricCard("ESTRÉS", p.ansiedadScore.toStringAsFixed(1), "/10", _colorEstado(p), Icons.psychology),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Text("Tendencia en tiempo real", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 10),
                _buildTrendChart(p), // La gráfica de fl_chart

                const SizedBox(height: 30),
                _buildBotonSincronizar(context, p),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFabConectar(context, p, primaryBlue),
    );
  }

  Color _colorEstado(AlertaProvider p) =>
      p.tieneLectura ? EstadoAnsiedadInfo.colorDesdeTexto(p.estadoAnsiedadTexto) : Colors.grey;

  // --- Botón de Sincronización ---
  Widget _buildBotonSincronizar(BuildContext context, AlertaProvider p) {
    return ElevatedButton.icon(
      onPressed: p.sensorConectado ? () => _sincronizar(context, p) : null,
      icon: const Icon(Icons.cloud_upload),
      label: const Text("Sincronizar Resumen Clínico"),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // --- WIDGETS DE DISEÑO ---
  Widget _buildDisenoFondo(BuildContext context, Color color) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.35,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, const Color(0xFF0C52CE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
    );
  }

  Widget _buildFabConectar(BuildContext context, AlertaProvider p, Color color) {
    return FloatingActionButton.extended(
      // Si está escaneando, desactivamos el botón para evitar múltiples clics
      onPressed: p.isScanning ? null : () => _conectar(context, p),

      icon: p.isScanning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Icon(p.sensorConectado ? Icons.bluetooth_connected : Icons.bluetooth),

      label: Text(
        p.isScanning ? "Conectando..." : (p.sensorConectado ? "Conectado" : "Conectar Sensor"),
      ),

      backgroundColor: p.sensorConectado ? Colors.green : color,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildBotonSimulacion(BuildContext context, AlertaProvider p) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: p.isScanning ? null : p.toggleSimulacion,
        icon: Icon(
          p.modoSimulacion ? Icons.stop_circle : Icons.science_outlined,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          p.modoSimulacion ? "Detener simulación" : "Simular datos (sin sensor)",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
      ),
    );
  }

  Widget _buildHeader(AlertaProvider p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Monitor Biométrico", style: TextStyle(color: Colors.white70, fontSize: 16)),
          Text(_nombreUsuario, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text("📡 ${p.lastSyncTime}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
        const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
      ],
    );
  }

  Widget _buildAnxietyIndicator(AlertaProvider p) {
    final color = _colorEstado(p);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Nivel de Ansiedad", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(p.estadoAnsiedadTexto.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: p.ansiedadScore / 10, minHeight: 10, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
      ]),
    );
  }

  Widget _buildMetricCard(String t, String v, String u, Color c, IconData i) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(i, color: c, size: 20),
        const SizedBox(height: 8),
        Text(t, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(u, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _buildTrendChart(AlertaProvider p) {
    final puntos = p.tendenciaBpm;
    return Container(
      height: 180,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: puntos.isEmpty
          ? const Center(child: Text("Esperando datos...", style: TextStyle(color: Colors.grey)))
          : LineChart(
              LineChartData(
                minY: 40,
                maxY: 140,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(puntos.length, (i) => FlSpot(i.toDouble(), puntos[i].toDouble())),
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
    );
  }
}
