import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../providers/pendientes_provider.dart';
import 'ejercicios_asignados_screen.dart';

// --- MODELO DE DATOS ---
class Tecnica {
  /// Slug fijo de la técnica. Es lo que guarda `ejercicios_asignados.tecnica_id`
  /// cuando el especialista asigna una técnica. Debe coincidir EXACTAMENTE con
  /// TECNICAS_EJERCICIO en backend/validation.js y con web_portal/src/tecnicas.js;
  /// no cambiarlo sin migrar las filas existentes.
  final String id;
  final String titulo;
  final String descripcionCorta;
  final IconData icono;
  final Color color;
  final String tipo; // 'respiracion' | 'pasos'
  final String? introduccion;
  final List<String>? pasos;
  final String? tipoAnimacion; // 'tension' | 'grounding' | 'visualizacion'

  Tecnica({
    required this.id,
    required this.titulo,
    required this.descripcionCorta,
    required this.icono,
    required this.color,
    required this.tipo,
    this.introduccion,
    this.pasos,
    this.tipoAnimacion,
  });
}

// --- CATÁLOGO DE TÉCNICAS ---
final List<Tecnica> _catalogoTecnicas = [
  Tecnica(
    id: 'respiracion_478',
    titulo: "Respiración 4-7-8",
    descripcionCorta: "Calma tu sistema nervioso en un par de minutos",
    icono: Icons.air,
    color: const Color(0xFF1E6AFB),
    tipo: 'respiracion',
  ),
  Tecnica(
    id: 'relajacion_muscular',
    titulo: "Relajación muscular progresiva",
    descripcionCorta: "Libera la tensión física, grupo muscular por grupo",
    icono: Icons.self_improvement,
    color: Colors.deepPurple,
    tipo: 'pasos',
    tipoAnimacion: 'tension',
    introduccion: "Siéntate o recuéstate en un lugar cómodo. Ve tensando y "
        "soltando cada grupo muscular durante unos 5 segundos antes de pasar "
        "al siguiente paso.",
    pasos: [
      "Cierra los ojos si te sientes seguro haciéndolo. Respira profundo dos veces.",
      "Tensa los dedos de los pies y las plantas. Sostén 5 segundos... y suelta lentamente.",
      "Tensa las pantorrillas. Sostén 5 segundos... y relaja, notando la diferencia.",
      "Tensa muslos y glúteos. Sostén 5 segundos... y libera.",
      "Tensa el abdomen. Sostén 5 segundos... y suelta el aire despacio.",
      "Cierra los puños y tensa los brazos. Sostén 5 segundos... y deja caer los brazos.",
      "Sube los hombros hacia las orejas. Sostén 5 segundos... y déjalos caer por completo.",
      "Arruga la frente, cierra los ojos con fuerza, aprieta la mandíbula. Sostén... y relaja el rostro.",
      "Recorre mentalmente todo tu cuerpo una vez más, notando la calma después de la tensión.",
    ],
  ),
  Tecnica(
    id: 'grounding_54321',
    titulo: "Grounding 5-4-3-2-1",
    descripcionCorta: "Reconecta con el presente a través de tus sentidos",
    icono: Icons.spa,
    color: Colors.teal,
    tipo: 'pasos',
    tipoAnimacion: 'grounding',
    introduccion: "Esta técnica te ayuda a salir de un pico de ansiedad "
        "anclándote al momento presente. Ve a tu ritmo, un paso a la vez.",
    pasos: [
      "Nombra 5 cosas que puedas VER a tu alrededor ahora mismo.",
      "Nombra 4 cosas que puedas TOCAR o sentir (tu ropa, una silla, el suelo).",
      "Nombra 3 cosas que puedas ESCUCHAR en este momento.",
      "Nombra 2 cosas que puedas OLER (o que recuerdes con claridad).",
      "Nombra 1 cosa que puedas SABOREAR, o cuyo sabor te guste recordar.",
    ],
  ),
  Tecnica(
    id: 'visualizacion_guiada',
    titulo: "Visualización guiada",
    descripcionCorta: "Imagina un lugar seguro y tranquilo",
    icono: Icons.landscape,
    color: Colors.orange,
    tipo: 'pasos',
    tipoAnimacion: 'visualizacion',
    introduccion: "Busca un lugar tranquilo, cierra los ojos si puedes, "
        "y deja que cada paso te guíe.",
    pasos: [
      "Respira profundamente tres veces, despacio.",
      "Imagina un lugar donde te sientas completamente seguro y en calma. Puede ser real o inventado.",
      "Observa los detalles: los colores, la luz, las formas a tu alrededor.",
      "Nota los sonidos de ese lugar — ¿hay viento, agua, silencio?",
      "Siente la temperatura y las texturas: el suelo bajo tus pies, el aire en tu piel.",
      "Permanece ahí unos momentos, dejando que la calma de ese lugar te acompañe.",
      "Cuando estés listo, abre los ojos lentamente, trayendo esa sensación contigo.",
    ],
  ),
];

/// Técnica del catálogo por su slug (`ejercicios_asignados.tecnica_id`), o
/// null si la app no la conoce (p. ej. una versión vieja de la app).
Tecnica? tecnicaPorId(String id) {
  for (final t in _catalogoTecnicas) {
    if (t.id == id) return t;
  }
  return null;
}

/// Abre la pantalla de ejercicio de una técnica (lista de técnicas y
/// ejercicios asignados usan la misma navegación).
void abrirTecnica(BuildContext context, Tecnica t) {
  if (t.tipo == 'respiracion') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RespiracionGuiadaScreen()));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TecnicaPasosScreen(tecnica: t)));
  }
}

// =============================================================
// PANTALLA PRINCIPAL: lista de técnicas
// =============================================================
class TecnicasScreen extends StatelessWidget {
  const TecnicasScreen({super.key});

  static const Color headerColor = Color(0xFF1E6AFB);

  /// Las rutas que se abren con Navigator.push quedan fuera del árbol de
  /// MainLayout, así que el PendientesProvider se le pasa a la pantalla de
  /// ejercicios de forma explícita.
  void _abrirEjercicios(BuildContext context) {
    final pendientes = context.read<PendientesProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: pendientes,
          child: const EjerciciosAsignadosScreen(),
        ),
      ),
    ).then((_) => pendientes.refrescar());
  }

  Widget _buildTarjetaEjercicios(BuildContext context) {
    final nuevos = context.watch<PendientesProvider>().ejercicios;
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      color: headerColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: headerColor.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Badge(
          isLabelVisible: nuevos > 0,
          label: Text('$nuevos'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_outlined, color: headerColor),
          ),
        ),
        title: const Text("Ejercicios asignados por tu especialista",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            nuevos > 0
                ? (nuevos == 1 ? "Tienes 1 ejercicio nuevo" : "Tienes $nuevos ejercicios nuevos")
                : "Consulta lo que tu especialista te sugirió practicar",
            style: TextStyle(
              color: nuevos > 0 ? headerColor : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: nuevos > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () => _abrirEjercicios(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Técnicas de relajación",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        // +1: la tarjeta de ejercicios asignados va antes del catálogo.
        itemCount: _catalogoTecnicas.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _buildTarjetaEjercicios(context);
          final t = _catalogoTecnicas[i - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(t.icono, color: t.color),
              ),
              title: Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.descripcionCorta,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
              onTap: () => abrirTecnica(context, t),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// EJERCICIO INTERACTIVO: Respiración 4-7-8
// =============================================================
class RespiracionGuiadaScreen extends StatefulWidget {
  const RespiracionGuiadaScreen({super.key});

  @override
  State<RespiracionGuiadaScreen> createState() => _RespiracionGuiadaScreenState();
}

class _RespiracionGuiadaScreenState extends State<RespiracionGuiadaScreen>
    with TickerProviderStateMixin {
  static const int _inhalaSeg = 4;
  static const int _sostenSeg = 7;
  static const int _exhalaSeg = 8;
  static const int _totalSeg = _inhalaSeg + _sostenSeg + _exhalaSeg;

  // Colores ancla del ciclo: Inhala -> Sostén -> Exhala -> (vuelve a Inhala)
  static const Color _colorInhala = Color(0xFF1E6AFB); // azul
  static const Color _colorSosten = Color(0xFF7C4DFF); // morado
  static const Color _colorExhala = Color(0xFF14C7B4); // verde-azulado

  late final AnimationController _controller; // ciclo de respiración (19s)
  late final AnimationController _rotController; // rotación continua de partículas
  late final FlutterTts _tts;
  late final AudioPlayer _audioPlayer;

  bool _activo = false;
  int _ciclos = 0;
  String _faseAnterior = "";
  bool _vozActiva = true;
  bool _musicaActiva = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeg),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _activo) {
          setState(() => _ciclos++);
          _controller.forward(from: 0);
        }
      });

    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );

    _tts = FlutterTts();
    _tts.setLanguage("es-MX");
    _tts.setSpeechRate(0.4);

    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _controller.dispose();
    _rotController.dispose();
    _tts.stop();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _activo = !_activo);
    if (_activo) {
      HapticFeedback.mediumImpact();
      _controller.forward(from: 0);
      _rotController.repeat();
      if (_musicaActiva) {
        _audioPlayer.play(AssetSource('audio/musica_relajante.mp3'), volume: 0.3);
      }
    } else {
      _controller.stop();
      _rotController.stop();
      _faseAnterior = "";
      _audioPlayer.pause();
      _tts.stop();
    }
  }

  void _toggleVoz() {
    setState(() => _vozActiva = !_vozActiva);
    if (!_vozActiva) _tts.stop();
  }

  void _toggleMusica() {
    setState(() => _musicaActiva = !_musicaActiva);
    if (!_activo) return;
    if (_musicaActiva) {
      _audioPlayer.resume();
    } else {
      _audioPlayer.pause();
    }
  }

  String _faseActual(double progreso) {
    final seg = progreso * _totalSeg;
    if (seg < _inhalaSeg) return "Inhala";
    if (seg < _inhalaSeg + _sostenSeg) return "Sostén";
    return "Exhala";
  }

  double _escalaActual(double progreso) {
    final seg = progreso * _totalSeg;
    if (seg < _inhalaSeg) {
      return 0.55 + 0.45 * (seg / _inhalaSeg);
    } else if (seg < _inhalaSeg + _sostenSeg) {
      return 1.0;
    } else {
      final segExhala = seg - _inhalaSeg - _sostenSeg;
      return 1.0 - 0.45 * (segExhala / _exhalaSeg);
    }
  }

  // Interpola el color de forma continua a lo largo de todo el ciclo,
  // pasando suavemente de Inhala -> Sostén -> Exhala -> Inhala otra vez.
  Color _colorActual(double progreso) {
    final seg = progreso * _totalSeg;
    if (seg < _inhalaSeg) {
      final t = seg / _inhalaSeg;
      return Color.lerp(_colorInhala, _colorSosten, t)!;
    } else if (seg < _inhalaSeg + _sostenSeg) {
      final t = (seg - _inhalaSeg) / _sostenSeg;
      return Color.lerp(_colorSosten, _colorExhala, t)!;
    } else {
      final t = (seg - _inhalaSeg - _sostenSeg) / _exhalaSeg;
      return Color.lerp(_colorExhala, _colorInhala, t)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color colorBase = _colorInhala;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Respiración 4-7-8",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: colorBase,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_vozActiva ? Icons.record_voice_over : Icons.voice_over_off),
            color: Colors.white,
            tooltip: _vozActiva ? "Voz activada" : "Voz desactivada",
            onPressed: _toggleVoz,
          ),
          IconButton(
            icon: Icon(_musicaActiva ? Icons.music_note : Icons.music_off),
            color: Colors.white,
            tooltip: _musicaActiva ? "Música activada" : "Música desactivada",
            onPressed: _toggleMusica,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_controller, _rotController]),
                builder: (context, child) {
                  final escala = _activo ? _escalaActual(_controller.value) : 0.55;
                  final fase = _activo ? _faseActual(_controller.value) : "Presiona iniciar";
                  final color = _activo ? _colorActual(_controller.value) : colorBase;

                  // Retroalimentación háptica al cambiar de fase
                  if (_activo && fase != _faseAnterior) {
                    _faseAnterior = fase;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      HapticFeedback.lightImpact();
                      if (_vozActiva) {
                        _tts.stop();
                        _tts.speak(fase);
                      }
                    });
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: CustomPaint(
                          painter: _RespiracionPainter(
                            escala: escala,
                            color: color,
                            anguloParticulas: _rotController.value * 2 * pi,
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: Text(
                                fase,
                                key: ValueKey(fase),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text("Ciclos completados: $_ciclos",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggle,
                icon: Icon(_activo ? Icons.pause : Icons.play_arrow),
                label: Text(_activo ? "Pausar" : "Iniciar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorBase,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dibuja el círculo de respiración con anillos de resonancia y partículas
// orbitando alrededor. Todo hecho a mano con Canvas, sin assets externos.
class _RespiracionPainter extends CustomPainter {
  final double escala; // 0.55 - 1.0, tamaño de "respiración" actual
  final Color color;
  final double anguloParticulas; // radianes, rotación continua

  _RespiracionPainter({
    required this.escala,
    required this.color,
    required this.anguloParticulas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radioBase = size.width / 2 * 0.5;

    // 1. Anillos de resonancia (ondas hacia afuera)
    for (int i = 2; i >= 0; i--) {
      final radio = radioBase * escala * (1 + i * 0.24);
      final opacidad = (0.16 - i * 0.045).clamp(0.0, 1.0);
      final paintAnillo = Paint()
        ..color = color.withOpacity(opacidad)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radio, paintAnillo);
    }

    // 2. Círculo principal con gradiente radial
    final radioPrincipal = radioBase * escala;
    final paintCirculo = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(0.85), color.withOpacity(0.25)],
      ).createShader(Rect.fromCircle(center: center, radius: radioPrincipal));
    canvas.drawCircle(center, radioPrincipal, paintCirculo);

    // 3. Partículas orbitando alrededor del círculo
    const int numParticulas = 8;
    final radioOrbita = radioBase * escala * 1.4;
    for (int i = 0; i < numParticulas; i++) {
      final anguloBase = (2 * pi / numParticulas) * i;
      final angulo = anguloBase + anguloParticulas;
      final dx = center.dx + radioOrbita * cos(angulo);
      final dy = center.dy + radioOrbita * sin(angulo);
      final paintParticula = Paint()..color = color.withOpacity(0.55);
      canvas.drawCircle(Offset(dx, dy), 4, paintParticula);
    }
  }

  @override
  bool shouldRepaint(covariant _RespiracionPainter oldDelegate) => true;
}


// =============================================================
// GUÍA PASO A PASO: reutilizable para técnicas basadas en texto
// =============================================================
class TecnicaPasosScreen extends StatefulWidget {
  final Tecnica tecnica;
  const TecnicaPasosScreen({super.key, required this.tecnica});

  @override
  State<TecnicaPasosScreen> createState() => _TecnicaPasosScreenState();
}

class _TecnicaPasosScreenState extends State<TecnicaPasosScreen> with TickerProviderStateMixin {
  static const List<IconData> _iconosGrounding = [
    Icons.visibility,
    Icons.back_hand,
    Icons.hearing,
    Icons.local_florist,
    Icons.restaurant,
  ];
  static const List<String> _numerosGrounding = ['5', '4', '3', '2', '1'];

  int _pasoActual = -1; // -1 = pantalla de introducción
  late final FlutterTts _tts;
  late final AudioPlayer _audioPlayer;
  bool _vozActiva = true;
  bool _musicaActiva = true;
  bool _modoAutomatico = false;

  AnimationController? _tensionController;
  AnimationController? _groundingController;
  AnimationController? _ambientController;

  @override
  void initState() {
    super.initState();
    switch (widget.tecnica.tipoAnimacion) {
      case 'tension':
        _tensionController = AnimationController(vsync: this, duration: const Duration(seconds: 8));
        break;
      case 'grounding':
        _groundingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
        break;
      case 'visualizacion':
        _ambientController = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
        break;
    }

    _tts = FlutterTts();
    _tts.setLanguage("es-MX");
    _tts.setSpeechRate(0.4);
    _tts.setCompletionHandler(() => _programarAvanceAutomatico(fallback: false));

    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    if (_musicaActiva) {
      _audioPlayer.play(AssetSource('audio/musica_relajante.mp3'), volume: 0.3);
    }

    _hablarActual();
  }

  @override
  void dispose() {
    _tts.stop();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _tensionController?.dispose();
    _groundingController?.dispose();
    _ambientController?.dispose();
    super.dispose();
  }

  void _hablarActual() {
    final t = widget.tecnica;
    final pasos = t.pasos ?? [];
    final texto = _pasoActual < 0 ? (t.introduccion ?? "") : pasos[_pasoActual];

    if (_vozActiva && texto.isNotEmpty) {
      _tts.stop();
      _tts.speak(texto);
    } else if (_modoAutomatico) {
      _programarAvanceAutomatico(fallback: true);
    }
  }

  // En modo automático, avanza solo al terminar de leer el paso (o tras una
  // pausa fija si la voz está apagada). Compara contra el paso que originó
  // la espera para no avanzar de más si el usuario ya navegó manualmente.
  void _programarAvanceAutomatico({required bool fallback}) {
    if (!_modoAutomatico || !mounted) return;
    final pasoQueInicioEspera = _pasoActual;
    final pasos = widget.tecnica.pasos ?? [];
    final enUltimoPaso = pasoQueInicioEspera == pasos.length - 1;
    if (enUltimoPaso) return;
    Future.delayed(Duration(milliseconds: fallback ? 4000 : 900), () {
      if (!mounted || !_modoAutomatico) return;
      if (_pasoActual != pasoQueInicioEspera) return;
      _irAPaso(pasoQueInicioEspera + 1);
    });
  }

  void _irAPaso(int nuevoPaso) {
    setState(() => _pasoActual = nuevoPaso);
    _hablarActual();
    if (nuevoPaso >= 0) {
      _tensionController?.forward(from: 0);
      _groundingController?.forward(from: 0);
    }
  }

  void _finalizar() {
    _tts.stop();
    _audioPlayer.stop();
    Navigator.pop(context);
  }

  void _toggleVoz() {
    setState(() => _vozActiva = !_vozActiva);
    if (_vozActiva) {
      _hablarActual();
    } else {
      _tts.stop();
      if (_modoAutomatico) _programarAvanceAutomatico(fallback: true);
    }
  }

  void _toggleMusica() {
    setState(() => _musicaActiva = !_musicaActiva);
    if (_musicaActiva) {
      _audioPlayer.resume();
    } else {
      _audioPlayer.pause();
    }
  }

  void _toggleModoAutomatico() {
    setState(() => _modoAutomatico = !_modoAutomatico);
    if (_modoAutomatico) {
      if (_vozActiva) {
        _hablarActual();
      } else {
        _programarAvanceAutomatico(fallback: true);
      }
    }
  }

  Widget _buildVisual(Tecnica t) {
    if (_pasoActual < 0) {
      if (t.tipoAnimacion == 'visualizacion' && _ambientController != null) {
        return SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _ambientController!,
            builder: (context, _) =>
                CustomPaint(painter: _EscenaAmbientalPainter(t: _ambientController!.value, color: t.color)),
          ),
        );
      }
      return Icon(t.icono, color: t.color, size: 60);
    }

    switch (t.tipoAnimacion) {
      case 'tension':
        return SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _tensionController!,
            builder: (context, _) =>
                CustomPaint(painter: _TensionPainter(progreso: _tensionController!.value, color: t.color)),
          ),
        );
      case 'grounding':
        final idx = _pasoActual.clamp(0, _iconosGrounding.length - 1);
        return AnimatedBuilder(
          animation: _groundingController!,
          builder: (context, _) {
            final escala = 0.6 + 0.4 * Curves.elasticOut.transform(_groundingController!.value);
            return Transform.scale(
              scale: escala,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: t.color.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(_iconosGrounding[idx], color: t.color, size: 52),
                  ),
                  const SizedBox(height: 12),
                  Text(_numerosGrounding[idx],
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: t.color)),
                ],
              ),
            );
          },
        );
      case 'visualizacion':
        return SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _ambientController!,
            builder: (context, _) =>
                CustomPaint(painter: _EscenaAmbientalPainter(t: _ambientController!.value, color: t.color)),
          ),
        );
      default:
        return Icon(t.icono, color: t.color, size: 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tecnica;
    final pasos = t.pasos ?? [];
    final enIntroduccion = _pasoActual < 0;
    final enUltimoPaso = _pasoActual == pasos.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(t.titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: t.color,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_vozActiva ? Icons.record_voice_over : Icons.voice_over_off),
            color: Colors.white,
            tooltip: _vozActiva ? "Voz activada" : "Voz desactivada",
            onPressed: _toggleVoz,
          ),
          IconButton(
            icon: Icon(_musicaActiva ? Icons.music_note : Icons.music_off),
            color: Colors.white,
            tooltip: _musicaActiva ? "Música activada" : "Música desactivada",
            onPressed: _toggleMusica,
          ),
          IconButton(
            icon: Icon(_modoAutomatico ? Icons.timer : Icons.touch_app),
            color: Colors.white,
            tooltip: _modoAutomatico ? "Avance automático" : "Avance manual",
            onPressed: _toggleModoAutomatico,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!enIntroduccion) ...[
              LinearProgressIndicator(
                value: (_pasoActual + 1) / pasos.length,
                color: t.color,
                backgroundColor: t.color.withOpacity(0.15),
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 10),
              Text("Paso ${_pasoActual + 1} de ${pasos.length}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
            Expanded(
              child: Center(
                child: enIntroduccion
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildVisual(t),
                          const SizedBox(height: 20),
                          Text(t.introduccion ?? "",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, height: 1.5)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildVisual(t),
                          const SizedBox(height: 24),
                          Text(
                            pasos[_pasoActual],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: enIntroduccion ? null : () => _irAPaso(_pasoActual - 1),
                  child: const Text("Anterior"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (enIntroduccion) {
                      _irAPaso(0);
                    } else if (enUltimoPaso) {
                      _finalizar();
                    } else {
                      _irAPaso(_pasoActual + 1);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enUltimoPaso ? Colors.green : t.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(enIntroduccion ? "Comenzar" : (enUltimoPaso ? "Terminar" : "Siguiente")),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Círculo que se contrae y vibra sutilmente al "tensar" (0.0-0.35), se
// sostiene tenso (0.35-0.65) y se expande suavemente al "soltar" (0.65-1.0).
class _TensionPainter extends CustomPainter {
  final double progreso; // 0..1 a lo largo del ciclo tensa->sostén->suelta
  final Color color;

  _TensionPainter({required this.progreso, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radioBase = size.width / 2 * 0.55;

    double escala;
    double jitter;
    if (progreso < 0.35) {
      final t = progreso / 0.35;
      escala = 1.0 - 0.3 * t;
      jitter = 3.0 * t;
    } else if (progreso < 0.65) {
      escala = 0.7;
      jitter = 3.0;
    } else {
      final t = (progreso - 0.65) / 0.35;
      escala = 0.7 + 0.3 * t;
      jitter = 3.0 * (1 - t);
    }

    final centro = center.translate(sin(progreso * 120) * jitter, cos(progreso * 130) * jitter);

    for (int i = 2; i >= 0; i--) {
      final radio = radioBase * escala * (1 + i * 0.22);
      final opacidad = (0.14 - i * 0.04).clamp(0.0, 1.0);
      canvas.drawCircle(centro, radio, Paint()..color = color.withOpacity(opacidad));
    }

    final radioPrincipal = radioBase * escala;
    canvas.drawCircle(
      centro,
      radioPrincipal,
      Paint()
        ..shader = RadialGradient(colors: [color.withOpacity(0.85), color.withOpacity(0.3)])
            .createShader(Rect.fromCircle(center: centro, radius: radioPrincipal)),
    );
  }

  @override
  bool shouldRepaint(covariant _TensionPainter oldDelegate) => true;
}

// Escena ambiental: un resplandor que "respira" lentamente con partículas
// flotando alrededor, para la Visualización guiada.
class _EscenaAmbientalPainter extends CustomPainter {
  final double t; // 0..1, progreso del loop continuo
  final Color color;

  _EscenaAmbientalPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radioBase = size.width / 2 * 0.6;
    final respiro = 0.9 + 0.1 * sin(t * 2 * pi);

    canvas.drawCircle(
      center,
      radioBase * respiro,
      Paint()
        ..shader = RadialGradient(colors: [color.withOpacity(0.35), color.withOpacity(0.0)])
            .createShader(Rect.fromCircle(center: center, radius: radioBase * respiro)),
    );

    const int numParticulas = 6;
    for (int i = 0; i < numParticulas; i++) {
      final anguloBase = (2 * pi / numParticulas) * i;
      final angulo = anguloBase + t * 2 * pi * 0.3;
      final radioOrbita = radioBase * (0.9 + 0.15 * sin(t * 2 * pi + i));
      final dx = center.dx + radioOrbita * cos(angulo);
      final dy = center.dy + radioOrbita * sin(angulo) * 0.6;
      canvas.drawCircle(Offset(dx, dy), 5, Paint()..color = color.withOpacity(0.45));
    }
  }

  @override
  bool shouldRepaint(covariant _EscenaAmbientalPainter oldDelegate) => true;
}
