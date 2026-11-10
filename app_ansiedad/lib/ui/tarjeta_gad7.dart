import 'package:flutter/material.dart';
import '../contenido/gad7_textos.dart';
import 'app_colors.dart';

/// Invitación a responder el GAD-7 en Inicio (diseño de la versión final; la
/// lógica de cuándo aparece sigue en `mostrarTarjetaGad7`). Morado de los
/// cuestionarios, sin rojo ni ámbar, con la etiqueta "Nuevo". Entra con un
/// fundido y deslizamiento (~400 ms) y la etiqueta pulsa leve; nada se anima
/// con `MediaQuery.disableAnimations`. Nunca habla del resultado.
class TarjetaGad7 extends StatefulWidget {
  final VoidCallback onTap;
  const TarjetaGad7({super.key, required this.onTap});

  static const String etiquetaNuevo = 'Nuevo';
  static const Duration entrada = Duration(milliseconds: 400);

  @override
  State<TarjetaGad7> createState() => _TarjetaGad7State();
}

class _TarjetaGad7State extends State<TarjetaGad7> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pulso.stop();
      _pulso.value = 0;
    } else if (!_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sinAnimar = MediaQuery.of(context).disableAnimations;
    final radio = BorderRadius.circular(AppColors.radio);

    final etiqueta = Container(
      key: const ValueKey('etiqueta_nuevo_gad7'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.acentoCuestionario, borderRadius: BorderRadius.circular(20)),
      child: const Text(
        TarjetaGad7.etiquetaNuevo,
        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );

    final tarjeta = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.cuestionarioFondo,
          shape: RoundedRectangleBorder(
            borderRadius: radio,
            side: BorderSide(color: AppColors.acentoCuestionario.withValues(alpha: 0.35)),
          ),
          child: InkWell(
            borderRadius: radio,
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.acentoCuestionario.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_outlined, color: AppColors.acentoCuestionario),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TextosGad7.tarjetaTitulo,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.cuestionarioTexto),
                        ),
                        SizedBox(height: 2),
                        Text(
                          TextosGad7.tarjetaDetalle,
                          style: TextStyle(fontSize: 12.5, color: AppColors.cuestionarioTextoSuave),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onTap,
                    style: TextButton.styleFrom(foregroundColor: AppColors.cuestionarioTexto),
                    child: const Text(TextosGad7.tarjetaBoton),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -9,
          right: 12,
          child: sinAnimar
              ? etiqueta
              : ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.08)
                      .animate(CurvedAnimation(parent: _pulso, curve: Curves.easeInOut)),
                  child: etiqueta,
                ),
        ),
      ],
    );

    if (sinAnimar) return tarjeta;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: TarjetaGad7.entrada,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: tarjeta,
    );
  }
}
