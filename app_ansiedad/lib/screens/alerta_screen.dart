import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_config.dart';
import '../logger.dart';
import '../providers/alerta_provider.dart';
import '../repositories/perfil_repository.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

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

/// Encabezado del Monitor: "Buenos días / Buenas tardes / Buenas noches" +
/// nombre del paciente.
///
/// El nombre vive en la tabla `usuarios` (no en Firebase), así que se lee una
/// vez con el PerfilRepository existente (mismo `GET /api/usuarios/:id` que
/// usa Perfil). No pasa por AlertaProvider: es solo texto de presentación.
/// Mientras carga, o si falla, se muestra la parte del correo antes de la @
/// (lo que se veía antes).
class _EncabezadoMonitor extends StatefulWidget {
  final Widget inferior;
  const _EncabezadoMonitor({required this.inferior});

  @override
  State<_EncabezadoMonitor> createState() => _EncabezadoMonitorState();
}

class _EncabezadoMonitorState extends State<_EncabezadoMonitor> {
  String? _nombre;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  Future<void> _cargarNombre() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final perfil = await PerfilRepository().obtenerPerfil(uid);
      final nombre = perfil.nombre.trim();
      if (mounted && nombre.isNotEmpty) setState(() => _nombre = nombre);
    } catch (e) {
      // No es crítico: se queda el respaldo del correo.
      AppLogger.warning('No se pudo cargar el nombre para el saludo', tag: 'monitor', error: e);
    }
  }

  String get _respaldoCorreo =>
      FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? "Paciente";

  /// Solo el primer nombre, para que el saludo quepa en una línea.
  String get _primerNombre => (_nombre ?? _respaldoCorreo).split(RegExp(r'\s+')).first;

  static String _saludo(DateTime ahora) {
    final h = ahora.hour;
    if (h >= 5 && h < 12) return 'Buenos días';
    if (h >= 12 && h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return EncabezadoGradiente(
      icono: Icons.monitor_heart,
      titulo: '${_saludo(DateTime.now())}, $_primerNombre',
      subtitulo: 'Monitor de indicadores fisiológicos',
      inferior: widget.inferior,
    );
  }
}

class _AlertaView extends StatelessWidget {
  const _AlertaView();

  void _mostrarSnack(BuildContext context, String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _conectar(BuildContext context, AlertaProvider p) async {
    final mensaje = await p.escanearYConectar();
    if (mensaje == null || !context.mounted) return;
    _mostrarSnack(context, mensaje.texto, mensaje.advertencia ? AppColors.elevados : AppColors.altos);
  }

  Future<void> _sincronizar(BuildContext context, AlertaProvider p) async {
    if (!p.tieneDatosPendientes) return;
    _mostrarSnack(context, "Enviando resumen...", AppColors.textoAyuda);

    final r = await p.enviarResumen();
    if (!context.mounted) return;

    switch (r.resultado) {
      case ResultadoSync.sinDatos:
        break;
      case ResultadoSync.exito:
        _mostrarSnack(context, "✅ Resumen guardado en historial", AppColors.normal);
        break;
      case ResultadoSync.error:
        _mostrarSnack(context, "❌ ${r.mensajeError}", AppColors.altos);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AlertaProvider>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EncabezadoMonitor(
              inferior: Row(
                children: [
                  Expanded(child: _buildEstadoConexion(p)),
                  const SizedBox(width: 8),
                  _buildBotonSimulacion(p),
                ],
              ),
            ),
            Padding(
              // Padding inferior amplio para que el FAB "Conectar Sensor" no
              // tape el botón de sincronizar al final del scroll.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIndicadores(p),
                  const SizedBox(height: 8),
                  const DisclaimerNota(Disclaimers.monitor),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildMetrica(p, 'BPM', p.bpmActual, 'lat/min', Icons.favorite, AppColors.metricaBpm)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMetrica(p, 'SpO2', p.spo2Actual, '%', Icons.water_drop, AppColors.metricaSpo2)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMetrica(p, 'HRV', p.hrvActual, 'ms', Icons.timer, AppColors.metricaHrv)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTrendChart(p),
                  const SizedBox(height: 20),
                  BotonPrimario(
                    texto: 'Sincronizar resumen de datos',
                    icono: Icons.cloud_upload_outlined,
                    onPressed: p.sensorConectado ? () => _sincronizar(context, p) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFabConectar(context, p),
    );
  }

  // --- WIDGETS DE DISEÑO ---

  /// Chip translúcido con el estado del enlace ("En vivo (Serial)", etc.).
  Widget _buildEstadoConexion(AlertaProvider p) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(p.sensorConectado ? Icons.sensors : Icons.sensors_off, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                p.lastSyncTime,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonSimulacion(AlertaProvider p) {
    return TextButton.icon(
      onPressed: p.isScanning ? null : p.toggleSimulacion,
      icon: Icon(
        p.modoSimulacion ? Icons.stop_circle_outlined : Icons.science_outlined,
        color: Colors.white,
        size: 16,
      ),
      label: Text(
        p.modoSimulacion ? "Detener simulación" : "Simular datos (sin sensor)",
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// Tarjeta "Indicadores fisiológicos" con el badge Normal / Elevados / Altos.
  /// Sin score ni barra (GUIA_ESTILO_APP.md): el sistema no emite diagnósticos.
  /// El provider sigue calculando el score por dentro para el semáforo.
  Widget _buildIndicadores(AlertaProvider p) {
    return Tarjeta(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarioSuave,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.monitor_heart_outlined, color: AppColors.primario, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Indicadores fisiológicos",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.texto),
                ),
                const SizedBox(height: 2),
                Text(
                  p.tieneLectura ? "Según la lectura actual del sensor" : p.estadoAnsiedadTexto,
                  style: const TextStyle(fontSize: 12, color: AppColors.textoAyuda),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Por dentro el provider maneja el valor de BD ("Baja" / "Moderada" /
          // "Alta"); el badge muestra Normal / Elevados / Altos.
          BadgeEstado(p.tieneLectura ? p.estadoAnsiedadTexto : null),
        ],
      ),
    );
  }

  Widget _buildMetrica(AlertaProvider p, String etiqueta, int valor, String unidad, IconData icono, Color colorIcono) {
    return TarjetaMetrica(
      etiqueta: etiqueta,
      valor: p.tieneLectura ? '$valor' : '--',
      unidad: unidad,
      icono: icono,
      colorIcono: colorIcono,
    );
  }

  Widget _buildFabConectar(BuildContext context, AlertaProvider p) {
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
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),

      backgroundColor: p.sensorConectado ? AppColors.normal : AppColors.primario,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radio)),
    );
  }

  Widget _buildTrendChart(AlertaProvider p) {
    final puntos = p.tendenciaBpm;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion("Tendencia en tiempo real · BPM"),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: puntos.isEmpty
                ? const Center(child: Text("Esperando datos...", style: TextStyle(color: AppColors.textoSecundario)))
                : LineChart(
                    LineChartData(
                      minY: 40,
                      maxY: 140,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borde, strokeWidth: 1),
                      ),
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
                          color: AppColors.primario,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: AppColors.primario.withValues(alpha: 0.08)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
