import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tarjeta de acción de Inicio para empezar a medir (versión final). Solo es
/// apariencia: quien la usa decide [habilitado] y el [motivo].
///
/// - Listo: fondo blanco, borde de 2.5 dp con el degradado azul → verde
///   azulado y un brillo lento que recorre el contorno (~3 s por vuelta);
///   escala 0.98 al tocar.
/// - No listo: fondo gris claro, borde gris, ícono gris y el [motivo] en una
///   pastilla; no responde al toque.
///
/// El brillo es decorativo (no sigue ningún dato). Con
/// `MediaQuery.disableAnimations` no hay brillo ni escala.
class BotonMedir extends StatefulWidget {
  final bool habilitado;

  /// Por qué no se puede medir (va en la pastilla cuando no está habilitado).
  final String motivo;

  /// Línea bajo el título cuando está habilitado ("Unos 3 minutos · sensor listo").
  final String detalle;
  final VoidCallback onTap;
  const BotonMedir({
    super.key,
    required this.habilitado,
    required this.motivo,
    required this.onTap,
    this.detalle = '',
  });

  static const String titulo = 'Iniciar medición';
  static const double alto = 96;
  static const double radio = 20;
  static const double grosorBorde = 2.5;
  static const Duration vuelta = Duration(seconds: 3);

  // Colores propios de la tarjeta (contraste AA comprobado en las pruebas).
  static const Color degradadoInicio = Color(0xFF2563EB);
  static const Color degradadoFin = Color(0xFF0F766E);
  static const Color textoDetalle = Color(0xFF475569);
  static const Color fondoNoListo = Color(0xFFF1F5F9);
  static const Color bordeNoListo = Color(0xFFCBD5E1);
  static const Color pastillaFondo = Color(0xFFE2E8F0);
  static const Color pastillaTexto = Color(0xFF334155);

  @override
  State<BotonMedir> createState() => _BotonMedirState();
}

class _BotonMedirState extends State<BotonMedir> with SingleTickerProviderStateMixin {
  late final AnimationController _brillo = AnimationController(vsync: this, duration: BotonMedir.vuelta);
  bool _animar = false;
  bool _presionado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarBrillo();
  }

  @override
  void didUpdateWidget(BotonMedir anterior) {
    super.didUpdateWidget(anterior);
    _actualizarBrillo();
  }

  void _actualizarBrillo() {
    _animar = widget.habilitado && !MediaQuery.of(context).disableAnimations;
    if (_animar) {
      if (!_brillo.isAnimating) _brillo.repeat();
    } else {
      _brillo.stop();
      _brillo.value = 0;
      _presionado = false;
    }
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  void _presion(bool valor) {
    if (_animar && _presionado != valor) setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habilitado;
    const radioExterno = BorderRadius.all(Radius.circular(BotonMedir.radio));
    const radioInterno = BorderRadius.all(Radius.circular(BotonMedir.radio - BotonMedir.grosorBorde));

    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Icono(habilitado: h),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BotonMedir.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: h ? AppColors.texto : BotonMedir.textoDetalle,
                  ),
                ),
                const SizedBox(height: 4),
                if (h)
                  Text(
                    widget.detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: BotonMedir.textoDetalle),
                  )
                else
                  _Pastilla(widget.motivo),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 28, color: h ? AppColors.primario : BotonMedir.bordeNoListo),
        ],
      ),
    );

    // Interior: blanco si está lista, gris si no.
    final interior = Material(
      color: h ? AppColors.superficie : BotonMedir.fondoNoListo,
      borderRadius: radioInterno,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: h ? widget.onTap : null,
        onHighlightChanged: _presion,
        child: contenido,
      ),
    );

    final Widget tarjeta;
    if (!h) {
      tarjeta = Container(
        height: BotonMedir.alto,
        padding: const EdgeInsets.all(BotonMedir.grosorBorde),
        decoration: const BoxDecoration(color: BotonMedir.bordeNoListo, borderRadius: radioExterno),
        child: interior,
      );
    } else if (!_animar) {
      // Sin animaciones: el mismo degradado, quieto y sin brillo.
      tarjeta = Container(
        height: BotonMedir.alto,
        padding: const EdgeInsets.all(BotonMedir.grosorBorde),
        decoration: const BoxDecoration(
          borderRadius: radioExterno,
          gradient: LinearGradient(colors: [BotonMedir.degradadoInicio, BotonMedir.degradadoFin]),
        ),
        child: interior,
      );
    } else {
      tarjeta = AnimatedBuilder(
        animation: _brillo,
        child: interior,
        builder: (context, child) => Container(
          height: BotonMedir.alto,
          padding: const EdgeInsets.all(BotonMedir.grosorBorde),
          decoration: BoxDecoration(
            borderRadius: radioExterno,
            boxShadow: [
              BoxShadow(
                color: BotonMedir.degradadoInicio.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            // El degradado da la vuelta al contorno con un tramo claro (el brillo).
            gradient: SweepGradient(
              colors: const [
                BotonMedir.degradadoInicio,
                BotonMedir.degradadoFin,
                Color(0xFFBAE6FD),
                BotonMedir.degradadoFin,
                BotonMedir.degradadoInicio,
              ],
              stops: const [0, 0.42, 0.5, 0.58, 1],
              transform: GradientRotation(2 * math.pi * _brillo.value),
            ),
          ),
          child: child,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: h,
      label: h ? '${BotonMedir.titulo}. ${widget.detalle}' : '${BotonMedir.titulo}. ${widget.motivo}',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _presionado ? 0.98 : 1,
        duration: _animar ? const Duration(milliseconds: 120) : Duration.zero,
        child: tarjeta,
      ),
    );
  }
}

class _Icono extends StatelessWidget {
  final bool habilitado;
  const _Icono({required this.habilitado});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: habilitado ? null : BotonMedir.bordeNoListo,
        gradient: habilitado
            ? const LinearGradient(
                colors: [BotonMedir.degradadoInicio, BotonMedir.degradadoFin],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Icon(
        Icons.monitor_heart_outlined,
        size: 30,
        color: habilitado ? Colors.white : BotonMedir.textoDetalle,
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final String texto;
  const _Pastilla(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('motivo_boton_medir'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: BotonMedir.pastillaFondo, borderRadius: BorderRadius.circular(20)),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: BotonMedir.pastillaTexto),
      ),
    );
  }
}
