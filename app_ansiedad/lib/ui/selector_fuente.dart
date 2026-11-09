import 'package:flutter/material.dart';
import '../app_config.dart';
import '../medicion/estado_sensor.dart';
import '../providers/alerta_provider.dart';
import 'app_colors.dart';

/// Texto bajo el botón de medir cuando todavía no hay fuente.
String textoSinFuente([Sabor? sabor]) => AppConfig.conSimulador(sabor)
    ? 'Elige "Simulación" o "Sensor" (arriba) para iniciar una medición.'
    : 'Conectando con el sensor…';

/// Chip translúcido del encabezado de Inicio con la fuente de lecturas (Fase
/// M7a). En DEMO se elige Simulación o Sensor; en PILOTO solo existe el
/// sensor y el chip muestra su conexión (tocarlo reintenta). Mientras se busca
/// el sensor no se puede cambiar.
class SelectorFuente extends StatelessWidget {
  final AlertaProvider alerta;

  /// Para las pruebas; por defecto, el de la compilación.
  final Sabor? sabor;
  const SelectorFuente(this.alerta, {super.key, this.sabor});

  @override
  Widget build(BuildContext context) {
    final bloqueado = alerta.ocupado;
    final sensorListo = alerta.fuente == FuenteLecturas.sensor && alerta.estadoSensor == EstadoSensor.listo;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (AppConfig.conSimulador(sabor))
            _OpcionFuente(
              texto: 'Simulación',
              icono: Icons.science,
              activa: alerta.fuente == FuenteLecturas.simulacion,
              onTap: bloqueado ? null : alerta.elegirSimulacion,
            ),
          _OpcionFuente(
            texto: 'Sensor',
            icono: sensorListo ? Icons.sensors : Icons.sensors_off,
            activa: alerta.fuente == FuenteLecturas.sensor,
            onTap: bloqueado ? null : alerta.elegirSensor,
          ),
        ],
      ),
    );
  }
}

class _OpcionFuente extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool activa;
  final VoidCallback? onTap;
  const _OpcionFuente({required this.texto, required this.icono, required this.activa, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.primarioOscuro : Colors.white;
    return Material(
      color: activa ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: color, size: 14),
              const SizedBox(width: 5),
              Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
