import 'package:flutter/material.dart';
import '../app_config.dart';
import 'app_colors.dart';
import 'widgets.dart';

/// Estructura común de Login / Registro (equivalente a `ui/AuthLayout.js` del
/// portal): banda de marca con gradiente, tarjeta blanca con el formulario
/// montada encima y el aviso de alcance al pie.
class EstructuraAcceso extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget formulario;

  /// Contenido bajo la tarjeta (ej. "¿No tienes cuenta? Regístrate aquí").
  final Widget? pie;

  /// Muestra la flecha de regreso en la banda (pantallas abiertas con push).
  final bool conRegreso;

  const EstructuraAcceso({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.formulario,
    this.pie,
    this.conRegreso = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMarca(context),
            // La tarjeta sube sobre la banda azul para que se lean como una sola pieza.
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Tarjeta(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.texto),
                          ),
                          const SizedBox(height: 4),
                          Text(subtitulo, style: const TextStyle(fontSize: 13, color: AppColors.textoAyuda)),
                          const SizedBox(height: 20),
                          formulario,
                        ],
                      ),
                    ),
                    if (pie != null) ...[
                      const SizedBox(height: 12),
                      pie!,
                    ],
                    const SizedBox(height: 16),
                    const DisclaimerNota(Disclaimers.acceso),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarca(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.gradienteEncabezado,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 64),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: conRegreso
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Regresar',
                        onPressed: () => Navigator.pop(context),
                      )
                    : const SizedBox(height: 48),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.monitor_heart, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sistema de Ansiedad',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Sistema de Monitoreo Biométrico',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
