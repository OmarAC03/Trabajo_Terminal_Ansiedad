import 'dart:async';
import 'package:flutter/material.dart';
import '../contenido/marca.dart';
import 'app_colors.dart';

/// Pantalla de espera del arranque (versión final, punto 7). El servidor
/// gratuito tarda 30–50 s en despertar; en vez de un círculo que parece
/// congelado, la mascota "respira" y, si tarda, se explica por qué.
class PantallaCargando extends StatefulWidget {
  /// Tras este tiempo aparece la explicación de la espera.
  final Duration avisoTras;
  const PantallaCargando({super.key, this.avisoTras = const Duration(seconds: 8)});

  static const String texto = '${Marca.nombreMascota} está preparando todo…';
  static const String textoEspera = 'El servidor está despertando; puede tardar hasta un minuto.';

  @override
  State<PantallaCargando> createState() => _PantallaCargandoState();
}

class _PantallaCargandoState extends State<PantallaCargando> with SingleTickerProviderStateMixin {
  late final AnimationController _respiracion =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  late final Animation<double> _escala =
      Tween<double>(begin: 0.92, end: 1.04).animate(CurvedAnimation(parent: _respiracion, curve: Curves.easeInOut));
  Timer? _timer;
  bool _tarda = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.avisoTras, () {
      if (mounted) setState(() => _tarda = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _respiracion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _escala,
                  child: Image.asset('assets/mascota/mascota_respirando.png', width: 150, height: 150),
                ),
                const SizedBox(height: 20),
                const Text(
                  Marca.nombreApp,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primarioOscuro),
                ),
                const SizedBox(height: 2),
                const Text(
                  Marca.lema,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textoAyuda),
                ),
                const SizedBox(height: 20),
                const Text(
                  PantallaCargando.texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.texto),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      color: AppColors.primario,
                      backgroundColor: AppColors.primarioSuave,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _tarda ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      PantallaCargando.textoEspera,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
