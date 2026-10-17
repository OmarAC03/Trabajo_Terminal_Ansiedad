import '../models/calibracion.dart';

/// Lo que "dice" la mascota según la etapa de la línea base (Fase M3).
/// Lógica pura, sin Flutter: se prueba con `flutter test`
/// (test/mensajes_mascota_test.dart).
///
/// Acompañamiento, no veredicto: los mensajes celebran el HÁBITO de medir y
/// el avance de la calibración ("día X de 7"), nunca el valor. Ningún texto
/// lleva HRV, FC ni una etiqueta del estado (normal / elevados / altos): esa
/// es la regla de oro, y la prueba lo revisa sobre todas las situaciones.

/// Un mensaje: la expresión de la mascota (archivo en assets/mascota/, con
/// sus variantes 2.0x/3.0x) y el texto de la burbuja.
class MensajeMascota {
  final String avatar;
  final String texto;
  const MensajeMascota(this.avatar, this.texto);

  String get ruta => 'assets/mascota/$avatar';

  @override
  String toString() => '$avatar: $texto';
}

/// Inicio. [calibracion] es la del origen activo (simulación o sensor); null
/// si no se pudo cargar. Devuelve null solo cuando hay mediciones pero no
/// hay calibración: la pantalla queda como antes de M3, sin mensaje.
MensajeMascota? mensajeInicio({required bool sinMediciones, Calibracion? calibracion}) {
  if (sinMediciones) {
    return const MensajeMascota(
      'avatar_saludando.png',
      '¡Hola! Voy a acompañarte en tus mediciones. Con unos minutos al día empiezo a conocer tu ritmo.',
    );
  }
  final c = calibracion;
  if (c == null) return null;
  final dia = 'día ${c.diaCalibracion} de ${c.diasObjetivo}';

  switch (c.etapa) {
    case EtapaBase.calibrando:
      if (c.medidoHoy) {
        return MensajeMascota('avatar_feliz.png', '¡Medición de hoy lista! Vamos en el $dia. Mañana seguimos.');
      }
      if (c.hayHistorialVencido) {
        return MensajeMascota(
          'avatar_guinando.png',
          '¡Qué gusto verte de nuevo! Como pasó un tiempo, vuelvo a conocer tu ritmo: $dia.',
        );
      }
      return MensajeMascota('avatar_pensativo.png', 'Estoy aprendiendo cómo es tu ritmo. Hoy sería tu $dia.');
    case EtapaBase.preliminar:
      if (c.medidoHoy) {
        return MensajeMascota(
          'avatar_feliz.png',
          '¡${_mayuscula(dia)} completado! Cada día me ayuda a conocerte mejor.',
        );
      }
      return MensajeMascota('avatar_concentrado.png', 'Ya te voy conociendo. Hoy sería tu $dia.');
    case EtapaBase.consolidada:
      if (c.medidoHoy) {
        return const MensajeMascota('avatar_genial.png', '¡Hábito de hoy cumplido! Gracias por darte este momento.');
      }
      return const MensajeMascota('avatar_sereno.png', 'Ya conozco tu ritmo. Medir hoy me ayuda a seguir acompañándote.');
  }
}

/// Resultado de la medición, después de la EVA. [evaluacion] y
/// [calibracion] vienen de la respuesta de `POST /api/sesiones` (null si el
/// backend no pudo calcularlas). [yaHabiaMedidoHoy]: el día ya contaba antes
/// de esta medición (evita llamar "primera" a la segunda del día 1).
MensajeMascota mensajeResultado({
  EvaluacionSesion? evaluacion,
  Calibracion? calibracion,
  bool yaHabiaMedidoHoy = false,
}) {
  if (evaluacion?.motivo == MotivoSinComparar.calidadBaja) {
    return const MensajeMascota(
      'avatar_sereno.png',
      '¡Gracias por medir! Tu medición quedó guardada. Esta vez la señal tuvo varias pausas, así que no '
          'la usaré para conocer tu ritmo. La próxima, con la mano bien apoyada, sí cuenta.',
    );
  }
  final c = calibracion;
  if (c == null) {
    return const MensajeMascota('avatar_celebrando.png', '¡Bien hecho! Tu medición quedó guardada.');
  }
  final dia = 'día ${c.diaCalibracion} de ${c.diasObjetivo}';

  switch (evaluacion?.etapa ?? c.etapa) {
    case EtapaBase.calibrando:
      if (c.diaCalibracion == 1 && !c.hayHistorialVencido && !yaHabiaMedidoHoy) {
        return MensajeMascota('avatar_celebrando.png', '¡Tu primera medición! Hoy empiezo a conocer tu ritmo: $dia.');
      }
      return MensajeMascota('avatar_celebrando.png', '¡Bien hecho! ${_mayuscula(dia)}: sigo aprendiendo cómo es tu ritmo.');
    case EtapaBase.preliminar:
      return MensajeMascota('avatar_feliz.png', '¡Una medición más! ${_mayuscula(dia)}: ya te voy conociendo.');
    case EtapaBase.consolidada:
      return const MensajeMascota('avatar_genial.png', '¡Hábito cumplido! Cada medición me ayuda a acompañarte mejor.');
  }
}

/// Durante la captura, mientras se muestra la guía de mala señal.
const mensajeMalaSenal = MensajeMascota(
  'avatar_meditando.png',
  'Con calma, aquí espero. Respira despacio mientras acomodas la mano.',
);

/// Cuando la medición no se completó (no se subió nada).
const mensajeNoCompletada = MensajeMascota(
  'avatar_sereno.png',
  'No pasa nada, a veces la señal se escapa. ¿Lo intentamos otra vez?',
);

/// Los 7 puntos de progreso se muestran mientras la base no está consolidada.
bool mostrarProgreso(Calibracion c) => c.etapa != EtapaBase.consolidada;

/// Puntos rellenos: días que ya cuentan para la base (incluye hoy si ya
/// midió con buena señal). Una medición con calidad baja no los avanza.
int diasContados(Calibracion c) => c.diasConMedicion.clamp(0, c.diasObjetivo);

String _mayuscula(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
