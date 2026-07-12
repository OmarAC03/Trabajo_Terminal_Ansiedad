import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

// Modelo simple para un resumen diario ya agregado desde el backend.
class _ResumenDia {
  final DateTime dia;
  final int bpmPromedio;
  final int spo2Promedio;
  final int hrvPromedio;
  final double scorePromedio;
  final int episodiosAltos;
  final int episodiosModerados;
  final int episodiosBajos;
  final int totalRegistros;

  _ResumenDia({
    required this.dia,
    required this.bpmPromedio,
    required this.spo2Promedio,
    required this.hrvPromedio,
    required this.scorePromedio,
    required this.episodiosAltos,
    required this.episodiosModerados,
    required this.episodiosBajos,
    required this.totalRegistros,
  });

  factory _ResumenDia.fromJson(Map<String, dynamic> json) {
    return _ResumenDia(
      dia: DateTime.parse(json['dia']).toLocal(),
      bpmPromedio: _asInt(json['bpm_promedio']),
      spo2Promedio: _asInt(json['spo2_promedio']),
      hrvPromedio: _asInt(json['hrv_promedio']),
      scorePromedio: _asDouble(json['score_promedio']),
      episodiosAltos: _asInt(json['episodios_altos']),
      episodiosModerados: _asInt(json['episodios_moderados']),
      episodiosBajos: _asInt(json['episodios_bajos']),
      totalRegistros: _asInt(json['total_registros']),
    );
  }

  static int _asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _asDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
}

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  static const Color headerColor = Color(0xFF1E6AFB);
  final String _baseUrl = 'https://tt-ansiedad-backend.onrender.com';
  final String _miPacienteId = FirebaseAuth.instance.currentUser?.uid ?? "";

  // 'dia' | 'semana' | 'mes'
  String _periodo = 'dia';
  bool _isLoading = true;
  String? _errorMsg;

  // Datos para la vista "Día": lecturas individuales de hoy
  List<dynamic> _lecturasHoy = [];

  // Datos para "Semana"/"Mes": resúmenes diarios agregados
  List<_ResumenDia> _periodoActual = [];
  List<_ResumenDia> _periodoAnterior = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    if (_miPacienteId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = "No se detectó una sesión activa.";
      });
      return;
    }

    try {
      if (_periodo == 'dia') {
        await _cargarLecturasDeHoy();
      } else {
        await _cargarResumen(_periodo);
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "No se pudo conectar con el servidor. Desliza hacia abajo para reintentar.";
      });
    }
  }

  Future<void> _cargarLecturasDeHoy() async {
    final url = Uri.parse('$_baseUrl/api/lecturas/$_miPacienteId?limite=200');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error del servidor: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    final hoy = DateTime.now();

    final soloHoy = data.where((item) {
      final fecha = DateTime.tryParse(item['fecha_medicion'] ?? '')?.toLocal();
      if (fecha == null) return false;
      return fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
    }).toList();

    // Ascendente por hora, para graficar la evolución del día en orden.
    soloHoy.sort((a, b) => (a['fecha_medicion'] as String).compareTo(b['fecha_medicion'] as String));

    _lecturasHoy = soloHoy;
  }

  Future<void> _cargarResumen(String periodo) async {
    final url = Uri.parse('$_baseUrl/api/lecturas/$_miPacienteId/resumen?periodo=$periodo');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error del servidor: ${response.statusCode}');
    }

    final Map<String, dynamic> body = jsonDecode(response.body);
    final int diasPorPeriodo = body['dias_por_periodo'] ?? (periodo == 'mes' ? 30 : 7);
    final List<dynamic> serieCompleta = body['serie_completa'] ?? [];

    final resumenes = serieCompleta
        .map((e) => _ResumenDia.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.dia.compareTo(b.dia));

    final corte = DateTime.now().subtract(Duration(days: diasPorPeriodo));

    _periodoActual = resumenes.where((r) => r.dia.isAfter(corte)).toList();
    _periodoAnterior = resumenes.where((r) => !r.dia.isAfter(corte)).toList();
  }

  // --- CÁLCULO DE KPIs ---

  double _promedio(List<_ResumenDia> lista, num Function(_ResumenDia) selector) {
    if (lista.isEmpty) return 0;
    final totalRegistros = lista.fold<int>(0, (acc, r) => acc + r.totalRegistros);
    if (totalRegistros == 0) return 0;
    // Promedio ponderado por número de registros de cada día
    final suma = lista.fold<double>(0, (acc, r) => acc + selector(r) * r.totalRegistros);
    return suma / totalRegistros;
  }

  int _sumaEpisodiosAltos(List<_ResumenDia> lista) =>
      lista.fold<int>(0, (acc, r) => acc + r.episodiosAltos);

  /// Retorna el % de cambio de [actual] respecto a [anterior], o null si no
  /// hay suficiente dato en el periodo anterior para comparar.
  double? _tendencia(double actual, double anterior) {
    if (anterior == 0) return null;
    return ((actual - anterior) / anterior) * 100;
  }

  int _rachaSinEpisodiosAltos() {
    final ordenDesc = [..._periodoActual, ..._periodoAnterior]
      ..sort((a, b) => b.dia.compareTo(a.dia));
    int racha = 0;
    for (final r in ordenDesc) {
      if (r.episodiosAltos == 0 && r.totalRegistros > 0) {
        racha++;
      } else if (r.totalRegistros > 0) {
        break;
      }
    }
    return racha;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Historial y Tendencias",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarDatos,
            tooltip: "Actualizar datos",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: Column(
          children: [
            _buildSelectorPeriodo(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: headerColor))
                  : _errorMsg != null
                      ? _buildErrorState()
                      : _periodo == 'dia'
                          ? _buildVistaDia()
                          : _buildVistaAgregada(),
            ),
          ],
        ),
      ),
    );
  }

  // --- SELECTOR DÍA / SEMANA / MES ---
  Widget _buildSelectorPeriodo() {
    Widget chip(String valor, String label) {
      final seleccionado = _periodo == valor;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_periodo == valor) return;
            setState(() => _periodo = valor);
            _cargarDatos();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: seleccionado ? headerColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: seleccionado ? headerColor : Colors.grey.shade300),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: seleccionado ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          chip('dia', 'Día'),
          chip('semana', 'Semana'),
          chip('mes', 'Mes'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text(_errorMsg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            ElevatedButton(onPressed: _cargarDatos, child: const Text("Reintentar")),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // VISTA: DÍA (lecturas individuales de hoy)
  // =========================================================
  Widget _buildVistaDia() {
    if (_lecturasHoy.isEmpty) {
      return ListView(
        // ListView para que RefreshIndicator funcione aunque esté vacío
        children: [_buildEmptyState("Aún no hay lecturas hoy",
            "Sincroniza desde el Monitor para verlas aquí.")],
      );
    }

    final bpms = _lecturasHoy.map((e) => (e['bpm'] as num).toDouble()).toList();
    final bpmProm = bpms.reduce((a, b) => a + b) / bpms.length;
    final bpmMax = bpms.reduce((a, b) => a > b ? a : b);

    // Estado predominante del día (moda simple)
    final conteo = <String, int>{};
    for (final e in _lecturasHoy) {
      final estado = (e['estado_ansiedad'] ?? 'Baja').toString();
      conteo[estado] = (conteo[estado] ?? 0) + 1;
    }
    final estadoPredominante =
        conteo.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      children: [
        _buildKpiRow([
          _KpiData("BPM promedio", bpmProm.round().toString(), Icons.favorite, Colors.blueAccent),
          _KpiData("BPM máximo", bpmMax.round().toString(), Icons.trending_up, Colors.redAccent),
          _KpiData("Lecturas hoy", _lecturasHoy.length.toString(), Icons.list_alt, headerColor),
          _KpiData("Estado predominante", estadoPredominante, Icons.psychology,
              _colorEstado(estadoPredominante)),
        ]),
        const SizedBox(height: 20),
        _buildCardChart(
          "Evolución de BPM hoy",
          LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                      bpms.length, (i) => FlSpot(i.toDouble(), bpms[i])),
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text("Lecturas recientes",
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ..._lecturasHoy.reversed.map(_buildRegistroCard),
      ],
    );
  }

  // =========================================================
  // VISTA: SEMANA / MES (resúmenes diarios agregados)
  // =========================================================
  Widget _buildVistaAgregada() {
    if (_periodoActual.isEmpty) {
      return ListView(
        children: [
          _buildEmptyState(
            "Sin datos en este periodo",
            _periodo == 'semana'
                ? "No hay resúmenes de los últimos 7 días."
                : "No hay resúmenes de los últimos 30 días.",
          ),
        ],
      );
    }

    final bpmProm = _promedio(_periodoActual, (r) => r.bpmPromedio);
    final hrvProm = _promedio(_periodoActual, (r) => r.hrvPromedio);
    final scoreProm = _promedio(_periodoActual, (r) => r.scorePromedio);
    final episodiosAltos = _sumaEpisodiosAltos(_periodoActual);

    final scorePromAnterior = _promedio(_periodoAnterior, (r) => r.scorePromedio);
    final tendenciaScore = _tendencia(scoreProm, scorePromAnterior);
    final racha = _rachaSinEpisodiosAltos();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      children: [
        _buildKpiRow([
          _KpiData("BPM promedio", bpmProm.round().toString(), Icons.favorite, Colors.blueAccent),
          _KpiData("HRV promedio", hrvProm.round().toString(), Icons.timer, Colors.orange),
          _KpiData("Episodios altos", episodiosAltos.toString(), Icons.warning_amber_rounded, Colors.red),
          _KpiData("Días sin episodios altos", racha.toString(), Icons.emoji_events, Colors.teal),
        ]),
        const SizedBox(height: 10),
        _buildTendenciaCard(scoreProm, tendenciaScore),
        const SizedBox(height: 20),
        _buildCardChart(
          "Tendencia de ansiedad (score promedio/día)",
          LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: _periodo == 'mes' ? 5 : 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= _periodoActual.length) return const SizedBox();
                      final dia = _periodoActual[idx].dia;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_etiquetaDia(dia),
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(_periodoActual.length,
                      (i) => FlSpot(i.toDouble(), _periodoActual[i].scorePromedio)),
                  isCurved: true,
                  color: headerColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: headerColor.withOpacity(0.1)),
                ),
              ],
              minY: 0,
              maxY: 10,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text("Resumen por día",
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ..._periodoActual.reversed.map(_buildResumenDiaCard),
      ],
    );
  }

  // --- WIDGETS REUTILIZABLES ---

  Widget _buildKpiRow(List<_KpiData> kpis) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: kpis.map((k) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(k.icon, color: k.color, size: 20),
              const SizedBox(height: 8),
              Text(k.valor,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              Text(k.label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTendenciaCard(double scoreProm, double? tendencia) {
    String texto;
    Color color;
    IconData icono;

    if (tendencia == null) {
      texto = "Aún no hay suficiente historial para comparar contra el periodo anterior.";
      color = Colors.grey;
      icono = Icons.info_outline;
    } else if (tendencia <= -5) {
      texto = "Tu nivel de ansiedad promedio bajó ${tendencia.abs().toStringAsFixed(0)}% vs el periodo anterior.";
      color = Colors.green;
      icono = Icons.trending_down;
    } else if (tendencia >= 5) {
      texto = "Tu nivel de ansiedad promedio subió ${tendencia.toStringAsFixed(0)}% vs el periodo anterior.";
      color = Colors.red;
      icono = Icons.trending_up;
    } else {
      texto = "Tu nivel de ansiedad se mantiene estable respecto al periodo anterior.";
      color = Colors.blueGrey;
      icono = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(color: color.withOpacity(0.9), fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardChart(String titulo, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  Widget _buildRegistroCard(dynamic registro) {
    final estado = (registro['estado_ansiedad'] ?? 'Baja').toString();
    final color = _colorEstado(estado);
    final fecha = DateTime.tryParse(registro['fecha_medicion'] ?? '')?.toLocal();
    final hora = fecha != null
        ? "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}"
        : "--:--";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.monitor_heart, color: color, size: 20),
            const SizedBox(width: 10),
            Text(hora, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            _buildMiniDato("BPM", "${registro['bpm']}"),
            const SizedBox(width: 14),
            _buildMiniDato("SpO2", "${registro['spo2']}%"),
            const SizedBox(width: 14),
            _buildMiniDato("HRV", "${registro['hrv']}"),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(estado.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenDiaCard(_ResumenDia r) {
    final colorPredominante = r.episodiosAltos > 0
        ? Colors.red
        : r.episodiosModerados > 0
            ? Colors.orange
            : Colors.teal;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(width: 6, height: 40, decoration: BoxDecoration(color: colorPredominante, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_etiquetaFechaCompleta(r.dia),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("${r.totalRegistros} lecturas · ${r.episodiosAltos} episodios altos",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            _buildMiniDato("BPM", r.bpmPromedio.toString()),
            const SizedBox(width: 14),
            _buildMiniDato("HRV", r.hrvPromedio.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniDato(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState(String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(subtitulo, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    if (estado == 'Alta') return Colors.red;
    if (estado == 'Moderada') return Colors.orange;
    return Colors.teal; // 'Baja' u otro
  }

  static const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  String _etiquetaDia(DateTime dia) {
    if (_periodo == 'semana') {
      return _diasSemana[dia.weekday - 1];
    }
    return dia.day.toString();
  }

  String _etiquetaFechaCompleta(DateTime dia) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return "${dia.day} de ${meses[dia.month - 1]}";
  }
}

class _KpiData {
  final String label;
  final String valor;
  final IconData icon;
  final Color color;
  _KpiData(this.label, this.valor, this.icon, this.color);
}