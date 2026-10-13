import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../medicion/aviso_sesiones.dart';
import '../models/sesion_resumen.dart';
import '../providers/historial_sesiones_provider.dart';
import '../ui/app_colors.dart';
import '../ui/formato_fecha.dart';
import '../ui/widgets.dart';
import 'sesion_detalle_screen.dart';

/// Historial del paciente (Fase M1c): sus sesiones de medición agrupadas por
/// día. Reemplaza al historial de lecturas sueltas (`lecturas_biometricas`),
/// que sigue en la base y en el portal pero la app ya no muestra.
///
/// Sin semáforo ni tendencias: sin línea base (M4) no se interpreta.
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return ChangeNotifierProvider(
      // Se recarga sola al guardarse una sesión nueva (AvisoSesiones).
      create: (_) => HistorialSesionesProvider(pacienteId: uid, aviso: AvisoSesiones.guardadas)..cargar(),
      child: const _HistorialView(),
    );
  }
}

class _HistorialView extends StatelessWidget {
  const _HistorialView();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<HistorialSesionesProvider>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoGradiente(
            icono: Icons.bar_chart,
            titulo: 'Historial',
            subtitulo: 'Tus sesiones de medición',
            accion: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: p.recargando ? null : p.cargar,
              tooltip: 'Actualizar',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DisclaimerNota(Disclaimers.historial),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: p.cargar,
              child: _cuerpo(context, p),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo(BuildContext context, HistorialSesionesProvider p) {
    // ListView en todos los estados para que "deslizar para actualizar" funcione.
    switch (p.estado) {
      case EstadoHistorial.cargando:
        return ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
          ],
        );
      case EstadoHistorial.error:
        return ListView(
          padding: const EdgeInsets.all(30),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.cloud_off, size: 64, color: AppColors.borde),
            const SizedBox(height: 15),
            const Text(
              'No pudimos cargar tus mediciones.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoAyuda),
            ),
            const SizedBox(height: 15),
            Center(
              child: ElevatedButton(onPressed: p.recargando ? null : p.cargar, child: const Text('Reintentar')),
            ),
          ],
        );
      case EstadoHistorial.listo:
        return p.sinMediciones ? const _SinMediciones() : _Lista(p);
    }
  }
}

class _SinMediciones extends StatelessWidget {
  const _SinMediciones();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 24),
        Image.asset('assets/mascota/mascota_saludando.png', height: 110),
        const SizedBox(height: 16),
        const Text(
          'Aún no tienes mediciones',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ve a Inicio y toca "Iniciar medición" para hacer la primera.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textoAyuda),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  final HistorialSesionesProvider p;
  const _Lista(this.p);

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Recarga fallida: se avisa sin vaciar la lista que ya se ve.
        if (p.errorMsg != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 13, color: AppColors.textoSecundario),
                SizedBox(width: 4),
                Text('No se pudo actualizar', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ],
            ),
          ),
        for (final grupo in p.grupos) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: EtiquetaSeccion(etiquetaDia(grupo.dia, ahora: ahora)),
          ),
          for (final s in grupo.sesiones) ...[
            _TarjetaSesion(s),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

/// Una sesión de la lista: hora y duración, y sus tres valores (HRV · FC ·
/// SpO2) con el color de cada indicador. Sin semáforo.
class _TarjetaSesion extends StatelessWidget {
  final SesionResumen s;
  const _TarjetaSesion(this.s);

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SesionDetalleScreen(sesion: s))),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                horaCorta(s.fechaInicio),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.texto),
              ),
              Text(
                duracionCorta(s.duracionTotalSeg),
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
              ),
            ],
          ),
          const Spacer(),
          _MiniValor(Icons.timer, AppColors.metricaHrv, s.hrvRmssd, 'ms'),
          _MiniValor(Icons.favorite, AppColors.metricaBpm, s.bpmPromedio, 'lpm'),
          _MiniValor(Icons.water_drop, AppColors.metricaSpo2, s.spo2Promedio, '%'),
          const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
        ],
      ),
    );
  }
}

class _MiniValor extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double valor;
  final String unidad;
  const _MiniValor(this.icono, this.color, this.valor, this.unidad);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(height: 2),
          Text(
            '${valor.round()}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.texto),
          ),
          Text(unidad, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        ],
      ),
    );
  }
}
