import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../contenido/textos_educativos.dart';
import '../models/sesion_detalle.dart';
import '../models/sesion_medicion.dart';
import '../models/sesion_resumen.dart';
import '../providers/sesion_detalle_provider.dart';
import '../ui/app_colors.dart';
import '../ui/fila_indicador.dart';
import '../ui/formato_fecha.dart';
import '../ui/widgets.dart';

/// Detalle de una sesión del Historial (Fase M1c): sus indicadores con mínimo y
/// máximo, y la evolución de FC y HRV durante la medición.
///
/// Las gráficas unen los puntos con una línea CONTINUA aunque haya huecos de
/// mala señal en la serie (los puntos quedan en su `t` real): el paciente no
/// ve rastros de "medición imperfecta" (DISENO_FLUJO_MEDICION.md §10). En el
/// portal, el especialista sí verá la línea cortada en los huecos.
class SesionDetalleScreen extends StatelessWidget {
  /// La sesión de la lista: su fecha y duración se muestran mientras carga el detalle.
  final SesionResumen sesion;
  const SesionDetalleScreen({super.key, required this.sesion});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return ChangeNotifierProvider(
      create: (_) => SesionDetalleProvider(pacienteId: uid, sesionId: sesion.id)..cargar(),
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: appBarGradiente('Detalle de la medición'),
        body: _DetalleView(sesion),
      ),
    );
  }
}

class _DetalleView extends StatelessWidget {
  final SesionResumen sesion;
  const _DetalleView(this.sesion);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SesionDetalleProvider>();
    final ahora = DateTime.now();
    final f = sesion.fechaInicio;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          '${etiquetaDia(f, ahora: ahora)} · ${horaCorta(f)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        Text(
          'Duración: ${duracionCorta(sesion.duracionTotalSeg)}',
          style: const TextStyle(fontSize: 13, color: AppColors.textoAyuda),
        ),
        const SizedBox(height: 16),
        ...switch (p.estado) {
          EstadoDetalle.cargando => [
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator()),
            ],
          EstadoDetalle.noEncontrada => [
              const SizedBox(height: 40),
              const Icon(Icons.search_off, size: 56, color: AppColors.borde),
              const SizedBox(height: 12),
              Text(
                p.errorMsg ?? 'Esta medición ya no está disponible.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoAyuda),
              ),
            ],
          EstadoDetalle.error => [
              const SizedBox(height: 40),
              const Icon(Icons.cloud_off, size: 56, color: AppColors.borde),
              const SizedBox(height: 12),
              const Text(
                'No pudimos cargar esta medición.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textoAyuda),
              ),
              const SizedBox(height: 12),
              Center(child: ElevatedButton(onPressed: p.cargar, child: const Text('Reintentar'))),
            ],
          EstadoDetalle.listo => _contenido(p.detalle!),
        },
        const SizedBox(height: 16),
        const DisclaimerNota(Disclaimers.historial),
      ],
    );
  }

  List<Widget> _contenido(SesionDetalle d) {
    final r = d.resumen;
    return [
      Tarjeta(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            FilaIndicador(
              info: TextosEducativos.hrv,
              icono: Icons.timer,
              color: AppColors.metricaHrv,
              valor: '${r.hrvRmssd.round()}',
              subtitulo: 'Mín ${d.hrvMin.round()} · Máx ${d.hrvMax.round()} ms',
            ),
            const Divider(height: 1, color: AppColors.borde),
            FilaIndicador(
              info: TextosEducativos.frecuencia,
              icono: Icons.favorite,
              color: AppColors.metricaBpm,
              valor: '${r.bpmPromedio.round()}',
              subtitulo: 'Mín ${d.bpmMin} · Máx ${d.bpmMax} lat/min',
            ),
            const Divider(height: 1, color: AppColors.borde),
            FilaIndicador(
              info: TextosEducativos.spo2,
              icono: Icons.water_drop,
              color: AppColors.metricaSpo2,
              valor: '${r.spo2Promedio.round()}',
              subtitulo: 'Mín ${d.spo2Min} · Máx ${d.spo2Max} %',
            ),
          ],
        ),
      ),
      if (r.spo2Promedio < ConfigMedicion.spo2UmbralSeguridad) ...[
        const SizedBox(height: 12),
        const Aviso(
          TextosEducativos.avisoSpo2Bajo,
          icono: Icons.health_and_safety_outlined,
          color: AppColors.guia,
          fondo: AppColors.guiaFondo,
        ),
      ],
      const SizedBox(height: 20),
      const EtiquetaSeccion('Durante la medición'),
      const SizedBox(height: 8),
      if (d.serie.length < 2)
        const Tarjeta(
          child: Text('No hay suficientes datos para graficar.', style: TextStyle(color: AppColors.textoAyuda)),
        )
      else ...[
        _GraficaSerie(
          titulo: 'Frecuencia cardiaca (lat/min)',
          serie: d.serie,
          valor: (p) => p.bpm,
          color: AppColors.metricaBpm,
        ),
        const SizedBox(height: 12),
        _GraficaSerie(
          titulo: 'Variabilidad, HRV (ms)',
          serie: d.serie,
          valor: (p) => p.hrv,
          color: AppColors.metricaHrv,
        ),
      ],
    ];
  }
}

/// Un parámetro de la serie contra el tiempo de la sesión (eje en m:ss).
/// Línea continua: los huecos de la serie no cortan la línea.
class _GraficaSerie extends StatelessWidget {
  final String titulo;
  final List<PuntoSerie> serie;
  final double Function(PuntoSerie) valor;
  final Color color;

  const _GraficaSerie({required this.titulo, required this.serie, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    final valores = serie.map(valor).toList();
    final minV = valores.reduce(min);
    final maxV = valores.reduce(max);
    final margen = max((maxV - minV) * 0.2, 5.0);
    final ultimoT = serie.last.t.toDouble();
    final intervaloX = ultimoT > 300 ? 120.0 : 60.0;
    const estiloEje = TextStyle(fontSize: 10, color: AppColors.textoSecundario);

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.texto)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: ultimoT,
                minY: (minV - margen).floorToDouble(),
                maxY: (maxV + margen).ceilToDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borde, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: estiloEje),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: intervaloX,
                      getTitlesWidget: (value, meta) {
                        // Solo en múltiplos exactos del intervalo (no en el borde final).
                        if (value % intervaloX != 0) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(minSeg(value.toInt()), style: estiloEje),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (final p in serie) FlSpot(p.t.toDouble(), valor(p))],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
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
