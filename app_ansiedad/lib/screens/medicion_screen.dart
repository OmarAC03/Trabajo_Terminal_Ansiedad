import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../models/sesion_medicion.dart';
import '../providers/alerta_provider.dart';
import '../providers/medicion_provider.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

/// Medición guiada (Fase M1b): pantalla completa, encima de la barra inferior.
///
/// Principio de UX (DISENO_FLUJO_MEDICION.md §10): durante la captura el
/// paciente solo ve un anillo que avanza con señal buena y una guía positiva
/// en ámbar; nunca valores en vivo ni un índice de confiabilidad. Al terminar
/// ve sus promedios con el disclaimer, sin semáforo.
///
/// Recibe el [AlertaProvider] del Monitor porque ahí vive la fuente de
/// lecturas (sensor o simulación) y el botón de prueba "Forzar mala señal".
class MedicionScreen extends StatefulWidget {
  final AlertaProvider alerta;
  const MedicionScreen({super.key, required this.alerta});

  @override
  State<MedicionScreen> createState() => _MedicionScreenState();
}

class _MedicionScreenState extends State<MedicionScreen> with WidgetsBindingObserver {
  late final MedicionProvider _medicion;

  @override
  void initState() {
    super.initState();
    final simulacion = widget.alerta.modoSimulacion;
    _medicion = MedicionProvider(
      fuente: widget.alerta.lecturas,
      origen: simulacion ? OrigenSesion.simulacion : OrigenSesion.sensor,
      alComenzar: simulacion ? widget.alerta.simularColocacionDedo : null,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.alerta.setForzarMalaSenal(false, notificar: false);
    _medicion.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _medicion.setSegundoPlano(state == AppLifecycleState.paused || state == AppLifecycleState.hidden);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _medicion),
        ChangeNotifierProvider.value(value: widget.alerta),
      ],
      child: const _MedicionView(),
    );
  }
}

class _MedicionView extends StatelessWidget {
  const _MedicionView();

  Future<bool> _confirmarSalida(BuildContext context, MedicionProvider p) async {
    final midiendo = p.fase == FaseMedicion.midiendo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(midiendo ? '¿Cancelar la medición?' : '¿Salir sin guardar?'),
        content: Text(midiendo
            ? 'Se perderá el avance de esta medición.'
            : 'Tu medición todavía no se guarda. Si sales ahora, se perderá.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(midiendo ? 'Continuar midiendo' : 'Quedarme')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _salir(BuildContext context, MedicionProvider p) async {
    if (!p.puedeSalirSinConfirmar && !await _confirmarSalida(context, p)) return;
    p.cancelar();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MedicionProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir(context, p);
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoGradiente(
              icono: Icons.monitor_heart,
              titulo: 'Medición guiada',
              subtitulo: 'Indicadores fisiológicos en reposo',
              accion: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Salir',
                onPressed: () => _salir(context, p),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: switch (p.fase) {
                  FaseMedicion.preparacion => _Preparacion(p),
                  FaseMedicion.midiendo => _Captura(p),
                  FaseMedicion.completada => _Completada(p, onListo: () => _salir(context, p)),
                  FaseMedicion.noCompletada => _NoCompletada(p, onSalir: () => _salir(context, p)),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Preparación ---

class _Preparacion extends StatelessWidget {
  final MedicionProvider p;
  const _Preparacion(this.p);

  @override
  Widget build(BuildContext context) {
    const minutos = ConfigMedicion.objetivoValidoSeg ~/ 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Antes de empezar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        const SizedBox(height: 12),
        const Tarjeta(
          child: Column(
            children: [
              _Indicacion(Icons.event_seat_outlined, 'Siéntate cómodamente y apoya el brazo en una superficie.'),
              _Indicacion(Icons.touch_app_outlined, 'Coloca el dedo sobre el sensor, sin apretar.'),
              _Indicacion(Icons.air, 'Respira con normalidad y evita hablar.'),
              _Indicacion(Icons.timer_outlined, 'Toma unos $minutos minutos. La app te avisa cuando termine.', ultima: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BotonPrimario(texto: 'Comenzar', icono: Icons.play_arrow_rounded, onPressed: p.comenzar),
      ],
    );
  }
}

class _Indicacion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool ultima;
  const _Indicacion(this.icono, this.texto, {this.ultima = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultima ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 22, color: AppColors.primario),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 14, color: AppColors.texto, height: 1.35))),
        ],
      ),
    );
  }
}

// --- Captura ---

class _Captura extends StatelessWidget {
  final MedicionProvider p;
  const _Captura(this.p);

  static String _textoGuia(GuiaMedicion g) => switch (g) {
        GuiaMedicion.detectando => 'Detectando tu pulso…',
        GuiaMedicion.midiendo => 'Midiendo… respira con normalidad',
        GuiaMedicion.casiListo => 'Casi listo, un momento más',
        GuiaMedicion.acomodaDedo => 'Acomoda tu dedo en el sensor',
        GuiaMedicion.manoQuieta => 'Mantén la mano quieta un momento',
      };

  static String _restante(int segundos) {
    final s = segundos < 0 ? 0 : segundos;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final alerta = context.watch<AlertaProvider>();
    final guia = p.guia;
    final enGuia = guia == GuiaMedicion.acomodaDedo || guia == GuiaMedicion.manoQuieta;
    final colorAnillo = enGuia ? AppColors.guia : AppColors.primario;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: p.progreso),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, valor, _) => CircularProgressIndicator(
                      value: valor,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      color: colorAnillo,
                      backgroundColor: AppColors.borde,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Pulso(activo: p.senalBuena, color: colorAnillo),
                    const SizedBox(height: 8),
                    Text(
                      'Faltan ~${_restante(p.segundosRestantes)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textoAyuda),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: enGuia
              ? Aviso(
                  _textoGuia(guia),
                  key: ValueKey(guia),
                  icono: guia == GuiaMedicion.acomodaDedo ? Icons.touch_app_outlined : Icons.pan_tool_outlined,
                  color: AppColors.guia,
                  fondo: AppColors.guiaFondo,
                )
              : Text(
                  _textoGuia(guia),
                  key: ValueKey(guia),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.texto),
                ),
        ),
        if (alerta.modoSimulacion) ...[
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => alerta.setForzarMalaSenal(!alerta.forzandoMalaSenal),
            icon: Icon(alerta.forzandoMalaSenal ? Icons.restore : Icons.science_outlined, size: 18),
            label: Text(alerta.forzandoMalaSenal ? 'Simulación: restablecer señal' : 'Simulación: forzar mala señal'),
          ),
        ],
      ],
    );
  }
}

/// Corazón que late mientras la señal es buena; quieto si no.
class _Pulso extends StatefulWidget {
  final bool activo;
  final Color color;
  const _Pulso({required this.activo, required this.color});

  @override
  State<_Pulso> createState() => _PulsoState();
}

class _PulsoState extends State<_Pulso> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    lowerBound: 0.88,
    upperBound: 1.08,
  );

  @override
  void initState() {
    super.initState();
    _sincronizar();
  }

  @override
  void didUpdateWidget(covariant _Pulso old) {
    super.didUpdateWidget(old);
    if (old.activo != widget.activo) _sincronizar();
  }

  void _sincronizar() {
    if (widget.activo) {
      _c.repeat(reverse: true);
    } else {
      _c.animateTo(1.0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _c,
      child: Icon(Icons.favorite, size: 56, color: widget.color),
    );
  }
}

// --- Resultado ---

class _Completada extends StatelessWidget {
  final MedicionProvider p;
  final VoidCallback onListo;
  const _Completada(this.p, {required this.onListo});

  @override
  Widget build(BuildContext context) {
    final s = p.sesion!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.primario),
        const SizedBox(height: 12),
        const Text(
          'Medición completada',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TarjetaMetrica(
                etiqueta: 'FC promedio',
                valor: s.bpmPromedio.round().toString(),
                unidad: 'lat/min',
                icono: Icons.favorite,
                colorIcono: AppColors.metricaBpm,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TarjetaMetrica(
                etiqueta: 'HRV (RMSSD)',
                valor: s.hrvRmssd.round().toString(),
                unidad: 'ms',
                icono: Icons.timer,
                colorIcono: AppColors.metricaHrv,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TarjetaMetrica(
                etiqueta: 'SpO2 prom.',
                valor: s.spo2Promedio.round().toString(),
                unidad: '%',
                icono: Icons.water_drop,
                colorIcono: AppColors.metricaSpo2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const DisclaimerNota(Disclaimers.inicio),
        const SizedBox(height: 20),
        switch (p.estadoEnvio) {
          EstadoEnvio.enviada => const Aviso(
              'Medición guardada. Tu especialista podrá consultarla.',
              icono: Icons.cloud_done_outlined,
              color: AppColors.primario,
              fondo: AppColors.primarioSuave,
            ),
          EstadoEnvio.error => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Aviso.error(p.errorEnvio ?? 'No se pudo guardar la medición.'),
                const SizedBox(height: 12),
                BotonPrimario(texto: 'Reintentar envío', icono: Icons.refresh, onPressed: p.enviar),
              ],
            ),
          _ => const Aviso.info('Guardando tu medición…', icono: Icons.cloud_upload_outlined),
        },
        const SizedBox(height: 16),
        if (p.estadoEnvio == EstadoEnvio.enviada) BotonPrimario(texto: 'Listo', onPressed: onListo),
      ],
    );
  }
}

class _NoCompletada extends StatelessWidget {
  final MedicionProvider p;
  final VoidCallback onSalir;
  const _NoCompletada(this.p, {required this.onSalir});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.replay_circle_filled_rounded, size: 64, color: AppColors.guia),
        const SizedBox(height: 12),
        const Text(
          'Intentémoslo de nuevo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        const SizedBox(height: 8),
        const Text(
          'No logramos una lectura estable esta vez. Suele pasar si la mano se mueve '
          'o el dedo no queda bien apoyado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textoAyuda, height: 1.4),
        ),
        const SizedBox(height: 16),
        const Tarjeta(
          child: Column(
            children: [
              _Indicacion(Icons.pan_tool_outlined, 'Apoya la mano sobre una superficie firme.'),
              _Indicacion(Icons.touch_app_outlined, 'Cubre el sensor con la yema del dedo, sin apretar.'),
              _Indicacion(Icons.self_improvement, 'Evita moverte y hablar hasta que termine.', ultima: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BotonPrimario(texto: 'Intentar de nuevo', icono: Icons.refresh, onPressed: p.reiniciar),
        const SizedBox(height: 8),
        TextButton(onPressed: onSalir, child: const Text('Salir')),
      ],
    );
  }
}
