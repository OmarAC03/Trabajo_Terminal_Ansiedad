import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_config.dart';
import '../models/lectura.dart';
import '../models/resumen_dia.dart';
import '../providers/historial_provider.dart';

/// Pantalla de Historial — capa de UI.
///
/// Tras el refactor del Incremento 3, esta pantalla NO llama a la red, NO parsea
/// JSON y NO calcula KPIs. Solo crea el HistorialProvider, escucha sus cambios y
/// dibuja. Toda la lógica vive en el provider y el repositorio.
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return ChangeNotifierProvider(
      create: (_) => HistorialProvider(pacienteId: uid)..cargar(),
      child: const _HistorialView(),
    );
  }
}

class _HistorialView extends StatelessWidget {
  const _HistorialView();

  static const Color headerColor = Color(0xFF1E6AFB);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistorialProvider>();

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
            onPressed: () => provider.cargar(),
            tooltip: "Actualizar datos",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.cargar(),
        child: Column(
          children: [
            _buildSelectorPeriodo(context, provider),
            Expanded(
              child: _buildCuerpo(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuerpo(BuildContext context, HistorialProvider p) {
    switch (p.estado) {
      case EstadoCarga.inicial:
      case EstadoCarga.cargando:
        return const Center(child: CircularProgressIndicator(color: headerColor));
      case EstadoCarga.error:
        return _buildErrorState(context, p);
      case EstadoCarga.listo:
        return p.periodo == 'dia' ? _buildVistaDia(p) : _buildVistaAgregada(p);
    }
  }

  // --- SELECTOR DÍA / SEMANA / MES ---
  Widget _buildSelectorPeriodo(BuildContext context, HistorialProvider p) {
    Widget chip(String valor, String label) {
      final seleccionado = p.periodo == valor;
      return Expanded(
        child: GestureDetector(
          onTap: () => p.cambiarPeriodo(valor),
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

  Widget _buildErrorState(BuildContext context, HistorialProvider p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text(p.errorMsg ?? "Error", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            ElevatedButton(onPressed: () => p.cargar(), child: const Text("Reintentar")),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // VISTA: DÍA (lecturas individuales de hoy)
  // =========================================================
  Widget _buildVistaDia(HistorialProvider p) {
    final lecturas = p.lecturasHoy;
    if (lecturas.isEmpty) {
      return ListView(
        children: [_buildEmptyState("Aún no hay lecturas hoy",
            "Sincroniza desde el Monitor para verlas aquí.")],
      );
    }

    final bpms = lecturas.map((e) => e.bpm.toDouble()).toList();
    final bpmProm = bpms.reduce((a, b) => a + b) / bpms.length;
    final bpmMax = bpms.reduce((a, b) => a > b ? a : b);

    final conteo = <String, int>{};
    for (final l in lecturas) {
      conteo[l.estadoAnsiedadTexto] = (conteo[l.estadoAnsiedadTexto] ?? 0) + 1;
    }
    final estadoPredominante =
        conteo.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      children: [
        _buildKpiRow([
          _KpiData("BPM promedio", bpmProm.round().toString(), Icons.favorite, Colors.blueAccent),
          _KpiData("BPM máximo", bpmMax.round().toString(), Icons.trending_up, Colors.redAccent),
          _KpiData("Lecturas hoy", lecturas.length.toString(), Icons.list_alt, headerColor),
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
                  spots: List.generate(bpms.length, (i) => FlSpot(i.toDouble(), bpms[i])),
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text("Lecturas recientes",
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ...lecturas.reversed.map(_buildRegistroCard),
      ],
    );
  }

  // =========================================================
  // VISTA: SEMANA / MES (resúmenes diarios agregados)
  // =========================================================
  Widget _buildVistaAgregada(HistorialProvider p) {
    final actual = p.periodoActual;
    if (actual.isEmpty) {
      return ListView(
        children: [
          _buildEmptyState(
            "Sin datos en este periodo",
            p.periodo == 'semana'
                ? "No hay resúmenes de los últimos 7 días."
                : "No hay resúmenes de los últimos 30 días.",
          ),
        ],
      );
    }

    final bpmProm = p.promedioPonderado((r) => r.bpmPromedio);
    final hrvProm = p.promedioPonderado((r) => r.hrvPromedio);
    final scoreProm = p.promedioPonderado((r) => r.scorePromedio);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      children: [
        _buildKpiRow([
          _KpiData("BPM promedio", bpmProm.round().toString(), Icons.favorite, Colors.blueAccent),
          _KpiData("HRV promedio", hrvProm.round().toString(), Icons.timer, Colors.orange),
          _KpiData("Episodios altos", p.episodiosAltosTotales.toString(), Icons.warning_amber_rounded, Colors.red),
          _KpiData("Días sin episodios altos", p.rachaSinEpisodiosAltos.toString(), Icons.emoji_events, Colors.teal),
        ]),
        const SizedBox(height: 10),
        _buildTendenciaCard(scoreProm, p.tendenciaScore),
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
                    interval: p.periodo == 'mes' ? 5 : 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= actual.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_etiquetaDia(actual[idx].dia, p.periodo),
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(actual.length,
                      (i) => FlSpot(i.toDouble(), actual[i].scorePromedio)),
                  isCurved: true,
                  color: headerColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: headerColor.withValues(alpha: 0.1)),
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
        ...actual.reversed.map(_buildResumenDiaCard),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 12.5)),
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

  Widget _buildRegistroCard(Lectura registro) {
    final color = _colorEstado(registro.estadoAnsiedadTexto);
    final fecha = registro.fechaMedicion;
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
            _buildMiniDato("BPM", "${registro.bpm}"),
            const SizedBox(width: 14),
            _buildMiniDato("SpO2", "${registro.spo2}%"),
            const SizedBox(width: 14),
            _buildMiniDato("HRV", "${registro.hrv}"),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(registro.estadoAnsiedadTexto.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenDiaCard(ResumenDia r) {
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

  Color _colorEstado(String estado) => EstadoAnsiedadInfo.colorDesdeTexto(estado);

  static const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  String _etiquetaDia(DateTime dia, String periodo) {
    if (periodo == 'semana') {
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