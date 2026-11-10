import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Botón grande y circular de Inicio para empezar a medir (versión final).
/// Listo: azul, con un anillo que pulsa suave y la leyenda "Toca para medir".
/// No listo: gris, deshabilitado y con el [motivo] en texto. El pulso es
/// decorativo (no sigue ningún dato) y se apaga con
/// `MediaQuery.disableAnimations`.
class BotonMedir extends StatefulWidget {
  final bool habilitado;

  /// Texto bajo el botón cuando no está habilitado.
  final String motivo;
  final String detalle;
  final VoidCallback onTap;
  const BotonMedir({
    super.key,
    required this.habilitado,
    required this.motivo,
    required this.onTap,
    this.detalle = '',
  });

  static const String leyenda = 'Toca para medir';
  static const double diametro = 132;

  @override
  State<BotonMedir> createState() => _BotonMedirState();
}

class _BotonMedirState extends State<BotonMedir> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  bool _animar = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarPulso();
  }

  @override
  void didUpdateWidget(BotonMedir anterior) {
    super.didUpdateWidget(anterior);
    _actualizarPulso();
  }

  void _actualizarPulso() {
    _animar = widget.habilitado && !MediaQuery.of(context).disableAnimations;
    if (_animar) {
      if (!_pulso.isAnimating) _pulso.repeat();
    } else {
      _pulso.stop();
      _pulso.value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const d = BotonMedir.diametro;
    final h = widget.habilitado;
    final circulo = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: h ? AppColors.gradienteEncabezado : null,
        color: h ? null : AppColors.sinLecturasFondo,
        border: h ? null : Border.all(color: AppColors.borde, width: 2),
        boxShadow: h
            ? [BoxShadow(color: AppColors.primario.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: h ? widget.onTap : null,
          child: Icon(Icons.play_arrow_rounded, size: 72, color: h ? Colors.white : AppColors.textoAyuda),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: h,
          label: h ? BotonMedir.leyenda : widget.motivo,
          excludeSemantics: true,
          child: SizedBox(
            width: d + 44,
            height: d + 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_animar)
                  AnimatedBuilder(
                    animation: _pulso,
                    builder: (context, _) {
                      final t = Curves.easeOut.transform(_pulso.value);
                      return Container(
                        width: d + 44 * t,
                        height: d + 44 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primario.withValues(alpha: 0.45 * (1 - t)), width: 4),
                        ),
                      );
                    },
                  ),
                circulo,
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          h ? BotonMedir.leyenda : widget.motivo,
          key: const ValueKey('leyenda_boton_medir'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: h ? AppColors.primarioMasOscuro : AppColors.textoAyuda,
          ),
        ),
        if (widget.detalle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(widget.detalle,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textoAyuda)),
        ],
      ],
    );
  }
}
