import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_config.dart';
import '../models/lectura.dart';
import '../models/resumen_dia.dart';
import '../providers/historial_provider.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistorialProvider>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: RefreshIndicator(
        onRefresh: () => provider.cargar(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoGradiente(
              icono: Icons.bar_chart,
              titulo: "Historial y Tendencias",
              subtitulo: "Tus indicadores fisiológicos",
              accion: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => provider.cargar(),
                tooltip: "Actualizar datos",
              ),
              inferior: _buildSelectorPeriodo(provider),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DisclaimerNota(Disclaimers.historial),
            ),
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
        return const Center(child: CircularProgressIndicator(color: AppColors.primario));
      case EstadoCarga.error:
        return _buildErrorState(context, p);
      case EstadoCarga.listo:
        return p.periodo == 'dia' ? _buildVistaDia(p) : _buildVistaAgregada(p);
    }
  }

  // --- SELECTOR DÍA / SEMANA / MES (segmentado, dentro del gradiente) ---
  Widget _buildSelectorPeriodo(HistorialProvider p) {
    Widget segmento(String valor, String label) {
      final seleccionado = p.periodo == valor;
      return Expanded(
        child: GestureDetector(
          onTap: () => p.cambiarPeriodo(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: seleccionado ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: seleccionado ? AppColors.primario : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppColors.radio),
      ),
      child: Row(
        children: [
          segmento('dia', 'Día'),
          segmento('semana', 'Semana'),
          segmento('mes', 'Mes'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, HistorialProvider p) {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.cloud_off, size: 64, color: AppColors.borde),
        const SizedBox(height: 15),
        Text(
          p.errorMsg ?? "Error",
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textoAyuda),
        ),
        const SizedBox(height: 15),
        Center(
          child: ElevatedButton(onPressed: () => p.cargar(), child: const Text("Reintentar")),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        _buildKpis([
          _KpiData("BPM promedio", bpmProm.round().toString(), "lat/min", Icons.favorite, AppColors.metricaBpm),
          _KpiData("BPM máximo", bpmMax.round().toString(), "lat/min", Icons.trending_up, AppColors.metricaBpm),
          _KpiData("Lecturas hoy", lecturas.length.toString(), "lecturas", Icons.list_alt, AppColors.primario),
          _KpiData("Nivel predominante", EstadoAnsiedadInfo.textoUIDesdeTexto(estadoPredominante), "del día",
              Icons.monitor_heart_outlined, _colorEstado(estadoPredominante),
              colorValor: _colorEstado(estadoPredominante)),
        ]),
        const SizedBox(height: 16),
        _buildCardChart(
          "Evolución de BPM hoy",
          LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borde, strokeWidth: 1),
              ),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(bpms.length, (i) => FlSpot(i.toDouble(), bpms[i])),
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
        const SizedBox(height: 20),
        const EtiquetaSeccion("Lecturas recientes"),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        _buildKpis([
          _KpiData("BPM promedio", bpmProm.round().toString(), "lat/min", Icons.favorite, AppColors.metricaBpm),
          _KpiData("HRV promedio", hrvProm.round().toString(), "ms", Icons.timer, AppColors.metricaHrv),
          _KpiData("Lecturas altas", p.episodiosAltosTotales.toString(), "en el periodo",
              Icons.warning_amber_rounded, AppColors.altos, colorValor: AppColors.altos),
          _KpiData("Días sin lecturas altas", p.rachaSinEpisodiosAltos.toString(), "días seguidos",
              Icons.emoji_events_outlined, AppColors.normal, colorValor: AppColors.normal),
        ]),
        const SizedBox(height: 12),
        _buildTendenciaCard(scoreProm, p.tendenciaScore),
        const SizedBox(height: 16),
        _buildCardChart(
          "Tendencia de indicadores fisiológicos (índice promedio/día)",
          LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borde, strokeWidth: 1),
              ),
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
                            style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
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
                  color: AppColors.primario,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: AppColors.primario.withValues(alpha: 0.08)),
                ),
              ],
              minY: 0,
              maxY: 10,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const EtiquetaSeccion("Resumen por día"),
        const SizedBox(height: 10),
        ...actual.reversed.map(_buildResumenDiaCard),
      ],
    );
  }

  // --- WIDGETS REUTILIZABLES ---

  /// KPIs en 2 columnas. Filas con IntrinsicHeight para que ambas tarjetas
  /// midan lo mismo aunque una etiqueta ocupe dos líneas.
  Widget _buildKpis(List<_KpiData> kpis) {
    Widget tarjeta(int i) {
      final k = kpis[i];
      return TarjetaMetrica(
        etiqueta: k.label,
        valor: k.valor,
        unidad: k.unidad,
        icono: k.icon,
        colorIcono: k.color,
        color: k.colorValor ?? AppColors.primario,
      );
    }

    final filas = <Widget>[];
    for (var i = 0; i < kpis.length; i += 2) {
      if (filas.isNotEmpty) filas.add(const SizedBox(height: 10));
      filas.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tarjeta(i)),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < kpis.length ? tarjeta(i + 1) : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: filas);
  }

  Widget _buildTendenciaCard(double scoreProm, double? tendencia) {
    String texto;
    Color color;
    Color fondo;
    IconData icono;

    if (tendencia == null) {
      texto = "Aún no hay suficiente historial para comparar contra el periodo anterior.";
      color = AppColors.textoAyuda;
      fondo = AppColors.sinLecturasFondo;
      icono = Icons.info_outline;
    } else if (tendencia <= -5) {
      texto = "El índice promedio de tus indicadores fisiológicos bajó ${tendencia.abs().toStringAsFixed(0)}% vs el periodo anterior.";
      color = AppColors.normal;
      fondo = AppColors.normalFondo;
      icono = Icons.trending_down;
    } else if (tendencia >= 5) {
      texto = "El índice promedio de tus indicadores fisiológicos subió ${tendencia.toStringAsFixed(0)}% vs el periodo anterior.";
      color = AppColors.altos;
      fondo = AppColors.altosFondo;
      icono = Icons.trending_up;
    } else {
      texto = "Tus indicadores fisiológicos se mantienen estables respecto al periodo anterior.";
      color = AppColors.primario;
      fondo = AppColors.primarioSuave;
      icono = Icons.trending_flat;
    }

    return Aviso(texto, icono: icono, color: color, fondo: fondo);
  }

  Widget _buildCardChart(String titulo, Widget chart) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.texto, fontSize: 14)),
          const SizedBox(height: 14),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  Widget _buildRegistroCard(Lectura registro) {
    final fecha = registro.fechaMedicion;
    final hora = fecha != null
        ? "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}"
        : "--:--";

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tarjeta(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.textoSecundario),
                const SizedBox(width: 6),
                Text(hora, style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                BadgeEstado(registro.estadoAnsiedadTexto),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMiniDato("BPM", "${registro.bpm}", AppColors.metricaBpm)),
                Expanded(child: _buildMiniDato("SpO2", "${registro.spo2}%", AppColors.metricaSpo2)),
                Expanded(child: _buildMiniDato("HRV", "${registro.hrv} ms", AppColors.metricaHrv)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenDiaCard(ResumenDia r) {
    final colorPredominante = r.episodiosAltos > 0
        ? AppColors.altos
        : r.episodiosModerados > 0
            ? AppColors.elevados
            : AppColors.normal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tarjeta(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 40,
              decoration: BoxDecoration(color: colorPredominante, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_etiquetaFechaCompleta(r.dia),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.texto)),
                  const SizedBox(height: 2),
                  Text("${r.totalRegistros} lecturas · ${r.episodiosAltos} lecturas altas",
                      style: const TextStyle(fontSize: 11, color: AppColors.textoAyuda)),
                ],
              ),
            ),
            SizedBox(width: 56, child: _buildMiniDato("BPM", r.bpmPromedio.toString(), AppColors.metricaBpm)),
            SizedBox(width: 56, child: _buildMiniDato("HRV", r.hrvPromedio.toString(), AppColors.metricaHrv)),
          ],
        ),
      ),
    );
  }

  /// Valor + etiqueta pequeña; el puntito de color identifica la métrica
  /// igual que los íconos del Monitor.
  Widget _buildMiniDato(String label, String value, Color colorMetrica) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.texto)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: colorMetrica, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: AppColors.textoSecundario, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
              child: const Icon(Icons.insights, size: 36, color: AppColors.primario),
            ),
            const SizedBox(height: 15),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.texto, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoAyuda, fontSize: 12)),
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
  final String unidad;
  final IconData icon;

  /// Color del ícono.
  final Color color;

  /// Color del número (azul si es null; color del semáforo cuando aplica).
  final Color? colorValor;

  const _KpiData(this.label, this.valor, this.unidad, this.icon, this.color, {this.colorValor});
}
