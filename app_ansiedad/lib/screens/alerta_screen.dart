import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

// 🚨 LIBRERÍAS CRÍTICAS
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';

class AlertaScreen extends StatefulWidget {
  const AlertaScreen({super.key});

  @override
  State<AlertaScreen> createState() => _AlertaScreenState();
}

class _AlertaScreenState extends State<AlertaScreen> {
  // --- 1. VARIABLES DE ESTADO Y UI ---
  final String _nombreUsuario = FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? "Paciente";
  final String _miPacienteId = FirebaseAuth.instance.currentUser?.uid ?? "";
  String _lastSyncTime = "Sin conexión";
  bool _sensorConectado = false;
  bool _isScanning = false;

  // --- 2. VALORES BIOMÉTRICOS ACTUALES ---
  int _bpmActual = 0;
  int _spo2Actual = 0;
  int _hrvActual = 0;
  double _ansiedadScore = 0.0;
  String _estadoAnsiedadText = "Esperando sensor...";
  Color _estadoAnsiedadColor = Colors.grey;

  // --- 3. MEMORIA INTERNA (GRÁFICA Y BUFFERS) ---
  final List<FlSpot> _puntosGrafica = []; 
  int _ejeX = 0;
  final List<int> _bufferBpm = [];
  final List<int> _bufferSpo2 = [];
  final List<int> _bufferHrv = [];

  // --- 4. HARDWARE (BLUETOOTH SERIAL) ---
  BluetoothConnection? connection;
  String _bufferDatos = "";

  // --- 5. MODO SIMULACIÓN (sin hardware) ---
  Timer? _simTimer;
  bool _modoSimulacion = false;
  final Random _rng = Random(); 

  @override
  void dispose() {
    connection?.dispose();
    _simTimer?.cancel();
    super.dispose();
  }

  // --- LÓGICA DE CONEXIÓN Y PERMISOS ---
  Future<bool> _solicitarPermisosModernos() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses[Permission.bluetoothConnect]!.isGranted;
  }

  Future<void> _escanearYConectar() async {
    if (_isScanning) return;
    if (_modoSimulacion) _detenerSimulacion();

    bool permisosOk = await _solicitarPermisosModernos();
    if (!permisosOk) {
      _mostrarSnack("⚠️ Se requieren permisos de Bluetooth para el A56", Colors.red);
      return;
    }

    setState(() { _isScanning = true; _lastSyncTime = "Buscando vinculado..."; });

    try {
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? esp32;
      
      for (var d in bondedDevices) {
        if (d.name != null && d.name!.contains("TT_SENSOR_CLASICO")) {
          esp32 = d;
          break;
        }
      }

      if (esp32 == null) {
        setState(() { _isScanning = false; _lastSyncTime = "No vinculado"; });
        _mostrarSnack('⚠️ Vincula "TT_SENSOR_CLASICO" en los ajustes del celular', Colors.orange);
        return;
      }

      connection = await BluetoothConnection.toAddress(esp32.address);
      setState(() { _sensorConectado = true; _isScanning = false; _lastSyncTime = "En vivo (Serial)"; });

      connection!.input!.listen((Uint8List data) {
        _bufferDatos += ascii.decode(data);
        if (_bufferDatos.contains('\n')) {
          List<String> lineas = _bufferDatos.split('\n');
          String jsonValido = lineas[0].trim();
          _bufferDatos = lineas.length > 1 ? lineas[1] : ""; 
          if (jsonValido.isNotEmpty) _procesarJSON(jsonValido);
        }
      }).onDone(() {
        setState(() { _sensorConectado = false; _lastSyncTime = "Desconectado"; });
      });

    } catch (e) {
      setState(() { _isScanning = false; _lastSyncTime = "Error de enlace"; });
    }
  }

  // --- PROCESAMIENTO DE DATOS ---
  void _procesarJSON(String jsonString) {
    try {
      var datos = jsonDecode(jsonString);
      if (mounted) {
        setState(() {
          _bpmActual = datos['bpm'] ?? _bpmActual;
          _spo2Actual = datos['spo2'] ?? _spo2Actual;
          _hrvActual = datos['hrv'] ?? _hrvActual;

          // Alimentar Gráfica
          _puntosGrafica.add(FlSpot(_ejeX.toDouble(), _bpmActual.toDouble()));
          _ejeX++;
          if (_puntosGrafica.length > 20) _puntosGrafica.removeAt(0);

          // Alimentar Buffers para Promedios
          _bufferBpm.add(_bpmActual);
          _bufferSpo2.add(_spo2Actual);
          _bufferHrv.add(_hrvActual);

          // Semáforo de Ansiedad
          if (_bpmActual > 95 || _hrvActual < 25) {
            _ansiedadScore = 8.5; _estadoAnsiedadText = "Alta"; _estadoAnsiedadColor = Colors.red;
          } else if (_bpmActual > 85) {
            _ansiedadScore = 6.0; _estadoAnsiedadText = "Moderada"; _estadoAnsiedadColor = Colors.orange;
          } else {
            _ansiedadScore = 4.0; _estadoAnsiedadText = "Baja"; _estadoAnsiedadColor = Colors.teal;
          }
        });
      }
    } catch (e) { print("Error JSON: $e"); }
  }

  // --- MODO SIMULACIÓN (genera lecturas falsas realistas) ---
  void _toggleSimulacion() {
    if (_modoSimulacion) {
      _detenerSimulacion();
    } else {
      _iniciarSimulacion();
    }
  }

  void _iniciarSimulacion() {
    // No mezclar simulación con una conexión Bluetooth real activa
    connection?.dispose();
    connection = null;

    setState(() {
      _modoSimulacion = true;
      _sensorConectado = true;
      _lastSyncTime = "En vivo (Simulado)";
    });

    _simTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final jsonFalso = jsonEncode(_generarLecturaFalsa());
      _procesarJSON(jsonFalso);
    });
  }

  void _detenerSimulacion() {
    _simTimer?.cancel();
    _simTimer = null;
    setState(() {
      _modoSimulacion = false;
      _sensorConectado = false;
      _lastSyncTime = "Simulación detenida";
    });
  }

  // Genera valores biométricos plausibles, con variación gradual (no saltos
  // random puros) y una probabilidad ocasional de "pico de ansiedad" para
  // poder ver el semáforo cambiar a Moderada/Alta sin hardware real.
  Map<String, dynamic> _generarLecturaFalsa() {
    final bool picoAnsiedad = _rng.nextDouble() < 0.15; // 15% de probabilidad

    int bpmBase = picoAnsiedad ? 100 + _rng.nextInt(20) : 65 + _rng.nextInt(20);
    int spo2 = 95 + _rng.nextInt(5); // 95-99, siempre saludable
    int hrv = picoAnsiedad ? 10 + _rng.nextInt(15) : 30 + _rng.nextInt(30);

    return {
      "bpm": bpmBase,
      "spo2": spo2,
      "hrv": hrv,
    };
  }

  // --- SINCRONIZACIÓN CON BACKEND (REMITIR PROMEDIOS) ---
  Future<void> _enviarResumen() async {
    if (_bufferBpm.isEmpty) return;

    int promBpm = (_bufferBpm.reduce((a, b) => a + b) / _bufferBpm.length).round();
    int promSpo2 = (_bufferSpo2.reduce((a, b) => a + b) / _bufferSpo2.length).round();
    int promHrv = (_bufferHrv.reduce((a, b) => a + b) / _bufferHrv.length).round();

    final payload = {
      "paciente_id": _miPacienteId,
      "bpm": promBpm,
      "spo2": promSpo2,
      "hrv": promHrv,
      "score_ansiedad": _ansiedadScore,
      "estado_ansiedad": _estadoAnsiedadText
    };

    try {
      final res = await http.post(
        Uri.parse('https://tt-ansiedad-backend.onrender.com/api/lecturas'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      if (res.statusCode == 201) {
        _bufferBpm.clear(); _bufferSpo2.clear(); _bufferHrv.clear();
        _mostrarSnack("✅ Resumen guardado en historial", Colors.green);
      }
    } catch (e) { _mostrarSnack("❌ Error de red", Colors.red); }
  }

  void _mostrarSnack(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

@override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1E6AFB);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Stack(
        children: [
          _buildDisenoFondo(primaryBlue), // El fondo azul
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(), // Nombre y estado
                const SizedBox(height: 12),
                _buildBotonSimulacion(),
                const SizedBox(height: 25),
                _buildAnxietyIndicator(), // El semáforo visual
                const SizedBox(height: 20),
                
                // 🚨 CUADRÍCULA DE MÉTRICAS RESTAURADA
                Row(
                  children: [
                    Expanded(child: _buildMetricCard("CORAZÓN", "$_bpmActual", "BPM", Colors.blueAccent, Icons.favorite)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildMetricCard("OXÍGENO", "$_spo2Actual", "%", Colors.green, Icons.opacity)),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard("VARIABILIDAD", "$_hrvActual", "ms", Colors.orange, Icons.timer)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildMetricCard("ESTRÉS", _ansiedadScore.toStringAsFixed(1), "/10", _estadoAnsiedadColor, Icons.psychology)),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Text("Tendencia en tiempo real", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 10),
                _buildTrendChart(), // La gráfica de fl_chart
                
                const SizedBox(height: 30),
                _buildBotonSincronizar(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFabConectar(primaryBlue),
    );
  }

  // --- Botón de Sincronización ---
  Widget _buildBotonSincronizar() {
    return ElevatedButton.icon(
      onPressed: _sensorConectado ? _enviarResumen : null,
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
  Widget _buildDisenoFondo(Color color) {
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
  Widget _buildFabConectar(Color color) {
    return FloatingActionButton.extended(
      // Si está escaneando, desactivamos el botón para evitar múltiples clics
      onPressed: _isScanning ? null : _escanearYConectar,
      
      icon: _isScanning 
        ? const SizedBox(
            width: 18, 
            height: 18, 
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          ) 
        : Icon(_sensorConectado ? Icons.bluetooth_connected : Icons.bluetooth),
      
      label: Text(
        _isScanning 
          ? "Conectando..." 
          : (_sensorConectado ? "Conectado" : "Conectar Sensor")
      ),
      
      backgroundColor: _sensorConectado ? Colors.green : color,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildBotonSimulacion() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _isScanning ? null : _toggleSimulacion,
        icon: Icon(
          _modoSimulacion ? Icons.stop_circle : Icons.science_outlined,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          _modoSimulacion ? "Detener simulación" : "Simular datos (sin sensor)",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Monitor Biométrico", style: TextStyle(color: Colors.white70, fontSize: 16)),
          Text(_nombreUsuario, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text("📡 $_lastSyncTime", style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
        const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
      ],
    );
  }

  Widget _buildSensorStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _sensorConectado ? Colors.greenAccent : Colors.redAccent, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(_sensorConectado ? "Hardware en línea" : "Esperando conexión serial...", style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]),
    );
  }

  Widget _buildAnxietyIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Nivel de Ansiedad", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(_estadoAnsiedadText.toUpperCase(), style: TextStyle(color: _estadoAnsiedadColor, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: _ansiedadScore / 10, minHeight: 10, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(_estadoAnsiedadColor)),
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

  Widget _buildTrendChart() {
    return Container(
      height: 180, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: _puntosGrafica.isEmpty ? const Center(child: Text("Esperando datos...", style: TextStyle(color: Colors.grey))) : LineChart(
        LineChartData(
          minY: 40, maxY: 140,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
          borderData: FlBorderData(show: false),
          lineBarsData: [LineChartBarData(spots: _puntosGrafica, isCurved: true, color: Colors.blueAccent, barWidth: 3, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)))],
        ),
      ),
    );
  }
}