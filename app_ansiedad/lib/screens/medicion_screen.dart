import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../medicion/mensajes_mascota.dart';
import '../models/eva_respuesta.dart';
import '../models/sesion_medicion.dart';
import '../providers/alerta_provider.dart';
import '../providers/medicion_provider.dart';
import '../ui/app_colors.dart';
import '../ui/progreso_calibracion.dart';
import '../ui/widgets.dart';

/// Medición guiada (Fase M1b): pantalla completa, encima de la barra inferior.
///
/// Principio de UX (DISENO_FLUJO_MEDICION.md §10): durante la captura el
/// paciente solo ve un anillo que avanza con señal buena y una guía positiva
/// en ámbar; nunca valores en vivo ni un índice de confiabilidad. Al terminar
/// ve sus promedios con el disclaimer, sin semáforo, y la mascota celebra el
/// hábito con el "día X de 7" de su línea base (Fase M3): nunca una etiqueta
/// del estado, ni banda, ni z (regla de oro).
///
/// Recibe el [AlertaProvider] del Monitor porque ahí vive la fuente de
/// lecturas (sensor o simulación) y el botón de prueba "Forzar mala señal".
class MedicionScreen extends StatefulWidget {
  final AlertaProvider alerta;

  /// Ver [MedicionProvider.yaHabiaMedidoHoy].
  final bool yaHabiaMedidoHoy;
  const MedicionScreen({super.key, required this.alerta, this.yaHabiaMedidoHoy = false});

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
      yaHabiaMedidoHoy: widget.yaHabiaMedidoHoy,
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
            : p.estadoEnvio == EstadoEnvio.enviada
                // La sesión ya está guardada: lo que falta es la EVA respondida.
                ? 'Tu respuesta todavía se está guardando. Si sales ahora, se perderá.'
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
        // Con mala señal, la mascota acompaña con calma (nunca un regaño).
        if (enGuia) ...[
          const SizedBox(height: 16),
          const MascotaConMensaje(mensajeMalaSenal, tamano: 56),
        ],
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

/// Resultado de la medición. La EVA va PRIMERO y los indicadores aparecen
/// solo después de guardarla u omitirla: si el paciente viera antes su FC y
/// su HRV, esos números podrían sesgar su respuesta subjetiva y contaminar la
/// correlación objetivo↔subjetivo (Fase M2). La EVA sigue siendo opcional:
/// "Omitir" está a un toque.
class _Completada extends StatelessWidget {
  final MedicionProvider p;
  final VoidCallback onListo;
  const _Completada(this.p, {required this.onListo});

  @override
  Widget build(BuildContext context) {
    final s = p.sesion!;
    final evaPendiente = p.estadoEva == EstadoEva.pendiente;
    final guardada = p.estadoEnvio == EstadoEnvio.enviada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EstadoEnvio(p),
        const SizedBox(height: 16),
        // Con la EVA pendiente (o la sesión aún subiéndose), la mascota grande
        // celebrando; ya con resultados y la sesión guardada, la expresión y el
        // mensaje de su etapa de calibración (Fase M3).
        if (evaPendiente || !guardada) ...[
          Image.asset('assets/mascota/mascota_celebrando.png', height: 110),
          const SizedBox(height: 12),
        ],
        const Text(
          'Medición completada',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        if (evaPendiente) ...[
          const SizedBox(height: 12),
          const _BurbujaMascota('¡Bien hecho! Antes de ver tus resultados, ¿me cuentas cómo te sientes?'),
        ],
        if (!evaPendiente && guardada) ...[
          const SizedBox(height: 16),
          MascotaConMensaje(
            mensajeResultado(
              evaluacion: p.evaluacion,
              calibracion: p.calibracion,
              yaHabiaMedidoHoy: p.yaHabiaMedidoHoy,
            ),
            tamano: 72,
          ),
          if (p.calibracion != null && mostrarProgreso(p.calibracion!)) ...[
            const SizedBox(height: 14),
            ProgresoCalibracion(p.calibracion!),
          ],
        ],
        const SizedBox(height: 20),
        _Eva(p),
        if (!evaPendiente) ...[
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
          const SizedBox(height: 16),
          if (p.puedeTerminar) BotonPrimario(texto: 'Listo', onPressed: onListo),
        ],
      ],
    );
  }
}

/// Estado del envío de la sesión, discreto arriba: el envío corre en segundo
/// plano mientras el paciente responde la EVA. Solo el error ocupa más espacio,
/// porque necesita el botón de reintento.
class _EstadoEnvio extends StatelessWidget {
  final MedicionProvider p;
  const _EstadoEnvio(this.p);

  @override
  Widget build(BuildContext context) {
    return switch (p.estadoEnvio) {
      EstadoEnvio.enviada => const _LineaEstado(
          'Medición guardada. Tu especialista podrá consultarla.',
          Icons.cloud_done_outlined,
        ),
      EstadoEnvio.error => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Aviso.error(p.errorEnvio ?? 'No se pudo guardar la medición.'),
            const SizedBox(height: 12),
            BotonPrimario(texto: 'Reintentar envío', icono: Icons.refresh, onPressed: p.enviar),
          ],
        ),
      _ => const _LineaEstado('Guardando tu medición…', Icons.cloud_upload_outlined),
    };
  }
}

class _LineaEstado extends StatelessWidget {
  final String texto;
  final IconData icono;
  const _LineaEstado(this.texto, this.icono);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, size: 16, color: AppColors.textoAyuda),
        const SizedBox(width: 6),
        Flexible(child: Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.textoAyuda))),
      ],
    );
  }
}

/// Lo que "dice" la mascota: una burbuja suave que invita a responder la EVA.
class _BurbujaMascota extends StatelessWidget {
  final String texto;
  const _BurbujaMascota(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarioSuave,
        borderRadius: BorderRadius.circular(AppColors.radio),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, color: AppColors.primarioMasOscuro, height: 1.35),
      ),
    );
  }
}

// --- EVA post-medición (Fase M2) ---

/// Etiqueta descriptiva de la posición del deslizador (0–1), que se muestra
/// como "Tu respuesta: …". Describe lo que el paciente marcó, nunca lo
/// interpreta, y no sustituye al valor: se guarda el valor continuo 0–100.
/// Pública solo para poder probarla.
String etiquetaEva(double posicion) {
  final v = (posicion * 100).round();
  if (v < 5) return 'Nada';
  if (v < 30) return 'Un poco';
  if (v < 55) return 'Algo';
  if (v < 80) return 'Bastante';
  return 'Mucha';
}

/// EVA según su estado: el cuestionario mientras está pendiente; después solo
/// un aviso. Nunca interpreta la respuesta ("estás muy ansioso"): solo
/// agradece (DESARROLLO_FUNDAMENTADO.md §4.1, MARCO_ALCANCE_Y_LENGUAJE.md).
class _Eva extends StatelessWidget {
  final MedicionProvider p;
  const _Eva(this.p);

  @override
  Widget build(BuildContext context) {
    return switch (p.estadoEva) {
      EstadoEva.pendiente => _CuestionarioEva(onGuardar: p.responderEva, onOmitir: p.omitirEva),
      EstadoEva.esperandoSesion || EstadoEva.enviando =>
        const Aviso.info('Guardando tu respuesta…', icono: Icons.cloud_upload_outlined),
      EstadoEva.guardada => const Aviso(
          'Gracias, tu respuesta se guardó.',
          icono: Icons.check_circle_outline,
          color: AppColors.primario,
          fondo: AppColors.primarioSuave,
        ),
      EstadoEva.omitida => const SizedBox.shrink(),
      EstadoEva.error => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Aviso.error(p.errorEva ?? 'No se pudo guardar tu respuesta.'),
            const SizedBox(height: 12),
            BotonPrimario(texto: 'Reintentar', icono: Icons.refresh, onPressed: p.reintentarEva),
            TextButton(onPressed: p.omitirEva, child: const Text('Continuar sin guardar la respuesta')),
          ],
        ),
    };
  }
}

/// Gradiente de la línea de la EVA: de un tono calmado a ámbar, sin rojo (no
/// debe leerse como alarma ni como el semáforo de los indicadores).
const _gradienteEva = [Color(0xFF5EC4B6), Color(0xFFA7D7A0), Color(0xFFFCD34D), Color(0xFFF59E0B)];

/// La pregunta de la EVA con un deslizador continuo SIN números visibles (como
/// la EVA de papel), anclado solo en los extremos ("Nada" y "La máxima
/// ansiedad imaginable") y sin marcas intermedias, para no agrupar las
/// respuestas en ellas. Como guía da un gradiente de color y la etiqueta en
/// vivo "Tu respuesta: …". No muestra posición hasta que el paciente lo toca,
/// para no sugerirle una respuesta de partida.
class _CuestionarioEva extends StatefulWidget {
  final void Function(EvaRespuesta) onGuardar;
  final VoidCallback onOmitir;
  const _CuestionarioEva({required this.onGuardar, required this.onOmitir});

  @override
  State<_CuestionarioEva> createState() => _CuestionarioEvaState();
}

class _CuestionarioEvaState extends State<_CuestionarioEva> {
  double? _posicion; // null hasta que el paciente toca el deslizador
  ContextoEva? _contexto;

  @override
  Widget build(BuildContext context) {
    final tocado = _posicion != null;
    const estiloAncla = TextStyle(fontSize: 12, color: AppColors.textoAyuda);

    return Tarjeta(
      colorBorde: AppColors.primario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Qué tan ansioso/a te sientes en este momento?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.texto),
          ),
          const SizedBox(height: 4),
          const Text('Desliza o toca la línea donde mejor te describa.', style: estiloAncla),
          const SizedBox(height: 14),
          Text(
            tocado ? 'Tu respuesta: ${etiquetaEva(_posicion!)}' : 'Toca la línea',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: tocado ? FontWeight.bold : FontWeight.normal,
              color: tocado ? AppColors.texto : AppColors.textoSecundario,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              trackShape: const _PistaGradiente(),
              thumbShape: _PulgarEva(visible: tocado),
              overlayColor: AppColors.primario.withValues(alpha: 0.12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: _posicion ?? 0.5,
              onChanged: (v) => setState(() => _posicion = v),
            ),
          ),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('Nada', style: estiloAncla)),
              Expanded(child: Text('La máxima ansiedad imaginable', textAlign: TextAlign.end, style: estiloAncla)),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Qué estabas haciendo? (opcional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.texto),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in ContextoEva.values)
                ChoiceChip(
                  label: Text(c.texto),
                  selected: _contexto == c,
                  // Tocar la opción elegida la quita (el contexto es opcional).
                  onSelected: (sel) => setState(() => _contexto = sel ? c : null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          BotonPrimario(
            texto: 'Guardar',
            onPressed: tocado
                ? () => widget.onGuardar(EvaRespuesta.desdeDeslizador(_posicion!, contexto: _contexto))
                : null,
          ),
          TextButton(onPressed: widget.onOmitir, child: const Text('Omitir')),
        ],
      ),
    );
  }
}

/// Línea de la EVA pintada entera con el gradiente: no hay parte "activa", así
/// la posición del dedo no se lee como una barra que se llena.
class _PistaGradiente extends RoundedRectSliderTrackShape {
  const _PistaGradiente();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final pintura = Paint()..shader = const LinearGradient(colors: _gradienteEva).createShader(rect);
    context.canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)), pintura);
  }
}

/// Pulgar blanco con aro del color del gradiente en esa posición. Invisible
/// hasta el primer toque.
class _PulgarEva extends SliderComponentShape {
  final bool visible;
  const _PulgarEva({required this.visible});

  static const _radio = 12.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(_radio);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    if (!visible) return;
    final canvas = context.canvas;
    canvas.drawCircle(center, _radio + 1, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(center, _radio, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      _radio - 2,
      Paint()
        ..color = _colorEnGradienteEva(value)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }
}

/// Color del gradiente de la EVA en la posición 0–1.
Color _colorEnGradienteEva(double t) {
  final tramos = _gradienteEva.length - 1;
  final x = t.clamp(0.0, 1.0) * tramos;
  final i = x.floor().clamp(0, tramos - 1);
  return Color.lerp(_gradienteEva[i], _gradienteEva[i + 1], x - i)!;
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
        const MascotaConMensaje(mensajeNoCompletada, tamano: 72),
        const SizedBox(height: 16),
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
