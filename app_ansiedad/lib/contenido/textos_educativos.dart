// Textos educativos de la pantalla de Inicio (Fase M1c).
//
// Todos viven aquí para revisarlos en un solo lugar. Cada uno indica de dónde
// sale: los que vienen de DESARROLLO_FUNDAMENTADO.md tienen su sección; los
// que aún no tienen fuente en el documento dicen "FUENTE POR VERIFICAR" y no
// deben citarse en la tesis hasta confirmarla. Lenguaje de indicadores
// fisiológicos, nunca de diagnóstico (MARCO_ALCANCE_Y_LENGUAJE.md).

/// Un indicador de la sesión, con su explicación para el paciente.
class InfoIndicador {
  final String nombre;

  /// Etiqueta corta visible con la fila cerrada.
  final String resumen;
  final String unidad;
  final String explicacion;

  const InfoIndicador({
    required this.nombre,
    required this.resumen,
    required this.unidad,
    required this.explicacion,
  });
}

/// Un consejo fijo de bienestar: no depende del resultado de la medición
/// (sin línea base no se interpreta).
class Consejo {
  final String titulo;
  final List<String> puntos;

  const Consejo({required this.titulo, required this.puntos});
}

class TextosEducativos {
  TextosEducativos._();

  // --- Indicadores, en el orden de la jerarquía de §1 (HRV > FC > SpO2) ---

  /// Fuente: DESARROLLO_FUNDAMENTADO.md §5.1 (textual).
  static const hrv = InfoIndicador(
    nombre: 'Variabilidad (HRV)',
    resumen: 'Regulación y calma',
    unidad: 'ms',
    explicacion: 'La variabilidad de tu ritmo cardíaco refleja cómo tu cuerpo regula la calma y la '
        'activación. Más variabilidad suele asociarse a mejor recuperación.',
  );

  /// Fuente: DESARROLLO_FUNDAMENTADO.md §1.2 (adaptado a lenguaje sencillo).
  static const frecuencia = InfoIndicador(
    nombre: 'Frecuencia cardiaca',
    resumen: 'Activación',
    unidad: 'lat/min',
    explicacion: 'Tu frecuencia cardiaca sube cuando el cuerpo se activa, por ejemplo ante una '
        'preocupación o un esfuerzo. También la cambian el café, el ejercicio, la postura o el '
        'sueño; por eso se mira junto con la variabilidad y nunca sola.',
  );

  /// Fuente: DESARROLLO_FUNDAMENTADO.md §1.3 (adaptado a lenguaje sencillo).
  static const spo2 = InfoIndicador(
    nombre: 'Oxígeno (SpO2)',
    resumen: 'Dato de seguridad',
    unidad: '%',
    explicacion: 'Es la cantidad de oxígeno en tu sangre. No mide ansiedad: aunque sientas falta '
        'de aire por nervios, suele mantenerse normal (95–100 %). La registramos como dato de '
        'seguridad.',
  );

  static const indicadores = [hrv, frecuencia, spo2];

  // --- Mensajes de la pantalla ---

  /// Fuente: DESARROLLO_FUNDAMENTADO.md §5.1 (textual).
  static const sobreLaMedicion =
      'Medimos en reposo unos minutos para obtener un dato confiable de tu estado fisiológico de hoy.';

  static const primerUso = 'Aún no has hecho tu primera medición. Toca el botón para empezar.';

  /// Fuente: DESARROLLO_FUNDAMENTADO.md §2.3 (regla de seguridad, textual).
  static const avisoSpo2Bajo =
      'Confirma con un oxímetro y consulta a tu especialista. No se relaciona con la ansiedad.';

  // --- Consejos fijos ---

  /// Fuente: DESARROLLO_FUNDAMENTADO.md §3 (protocolo de medición).
  static const cuandoMedir = Consejo(
    titulo: 'Cuándo medir',
    puntos: [
      'Mide a la misma hora cada día, de preferencia por la mañana, para comparar un día con otro.',
      'Evita café y ejercicio 1–2 horas antes.',
      'Siéntate, apoya la mano a la altura del corazón y no hables mientras mides.',
    ],
  );

  /// FUENTE POR VERIFICAR: Laborde S et al. (2022), Neurosci Biobehav Rev
  /// (metaanálisis respiración lenta y HRV); Zaccaro A et al. (2018), Front
  /// Hum Neurosci 12:353. Aún no están en DESARROLLO_FUNDAMENTADO.md §8.
  static const respiracion = Consejo(
    titulo: 'Respiración',
    puntos: [
      'Respirar despacio unos minutos (inhalar ~4 s y exhalar ~6 s, unas 6 respiraciones por '
          'minuto) ayuda a activar la respuesta de calma de tu cuerpo. Puedes practicar en Técnicas.',
    ],
  );

  /// Relación sueño–HRV: DESARROLLO_FUNDAMENTADO.md §4.3 (confusores).
  /// Recomendaciones de higiene del sueño: FUENTE POR VERIFICAR, Irish LA et
  /// al. (2015), Sleep Med Rev 22:23–36.
  static const sueno = Consejo(
    titulo: 'Sueño',
    puntos: [
      'Dormir mal puede cambiar tus indicadores del día siguiente. Procura horarios regulares para '
          'dormir y despertar, y deja las pantallas un rato antes de acostarte.',
    ],
  );

  static const consejos = [cuandoMedir, respiracion, sueno];
}
