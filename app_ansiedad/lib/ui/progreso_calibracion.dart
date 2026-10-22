import 'package:flutter/material.dart';
import '../medicion/mensajes_mascota.dart';
import '../models/calibracion.dart';
import 'app_colors.dart';

/// "Día X de 7" con siete puntos (Fase M3): los rellenos son los días que ya
/// cuentan para la línea base. Mide el HÁBITO, no un valor: todos los puntos
/// son del mismo azul, sin colores de semáforo.
class ProgresoCalibracion extends StatelessWidget {
  final Calibracion calibracion;

  /// Texto bajo los puntos; por defecto "Día X de 7".
  final String? leyenda;

  const ProgresoCalibracion(this.calibracion, {super.key, this.leyenda});

  @override
  Widget build(BuildContext context) {
    final c = calibracion;
    final contados = diasContados(c);
    return Semantics(
      label: 'Línea base: $contados de ${c.diasObjetivo} días',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < c.diasObjetivo; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < contados ? AppColors.primario : AppColors.superficie,
                    border: Border.all(color: i < contados ? AppColors.primario : AppColors.borde, width: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            leyenda ?? 'Día ${c.diaCalibracion} de ${c.diasObjetivo}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoAyuda),
          ),
        ],
      ),
    );
  }
}

/// La mascota con su burbuja: la expresión a la izquierda y el texto en una
/// burbuja azul suave.
class MascotaConMensaje extends StatelessWidget {
  final MensajeMascota mensaje;
  final double tamano;

  /// En false solo se dibuja la burbuja: Inicio ya muestra esa misma
  /// expresión en su encabezado y no se repite la mascota.
  final bool mostrarAvatar;

  const MascotaConMensaje(this.mensaje, {super.key, this.tamano = 64, this.mostrarAvatar = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (mostrarAvatar) ...[
          Image.asset(mensaje.ruta, width: tamano, height: tamano, fit: BoxFit.contain),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarioSuave,
              borderRadius: BorderRadius.circular(AppColors.radio),
            ),
            child: Text(
              mensaje.texto,
              style: const TextStyle(fontSize: 14, color: AppColors.primarioMasOscuro, height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}
