/// Textos del cuestionario GAD-7 (Fase M5a, DESARROLLO_FUNDAMENTADO.md §4.2).
///
/// **El instrumento (versión `gad7-es-v1`) se usa EXACTO**: encabezado, ítems,
/// opciones y pregunta de dificultad no se reescriben ni se "pasan a tú" (el
/// instrumento habla de usted). Lo protege test/gad7_textos_test.dart.
/// Fuente: validación en español de García-Campayo et al. (2010) — FUENTE POR
/// VERIFICAR contra la versión oficial antes de la entrega final (en
/// particular la opción "De nada", que en otras versiones es "Nunca" o
/// "Ningún día"). Corrección de Omar al ítem 1: "o muy tenso".
///
/// Los textos propios de la app (introducción, tarjeta, agradecimiento, apoyo)
/// van en "tú" y NUNCA hablan del resultado: el paciente no ve su puntaje ni
/// su severidad (regla de oro, como en M3).
library;

class OpcionGad7 {
  final String texto;
  final int valor;
  const OpcionGad7(this.texto, this.valor);
}

class TextosGad7 {
  TextosGad7._();

  /// Debe coincidir con `CONFIG_GAD7.version` del backend.
  static const String version = 'gad7-es-v1';

  // --- El instrumento, exacto ---

  static const String encabezado =
      'Durante las últimas 2 semanas, ¿con qué frecuencia le han molestado los siguientes problemas?';

  static const List<String> items = [
    'Sentirse nervioso, ansioso o muy tenso',
    'No poder detenerse o controlar la preocupación',
    'Preocuparse demasiado por cosas diferentes',
    'Dificultad para relajarse',
    'Ser tan inquieto que es difícil quedarse quieto',
    'Molestarse o irritarse con facilidad',
    'Sentir miedo, como si algo horrible pudiera suceder',
  ];

  static const List<OpcionGad7> opciones = [
    OpcionGad7('De nada', 0),
    OpcionGad7('Varios días', 1),
    OpcionGad7('Más de la mitad de los días', 2),
    OpcionGad7('Casi todos los días', 3),
  ];

  /// Opcional y NO suma al puntaje. Solo se pregunta si marcó algún problema.
  static const String preguntaDificultad =
      'Si marcó cualquier problema, ¿qué tan difícil le han hecho estos problemas para hacer su trabajo, '
      'ocuparse de las cosas en casa, o llevarse bien con otras personas?';

  static const List<OpcionGad7> opcionesDificultad = [
    OpcionGad7('No es nada difícil', 0),
    OpcionGad7('Algo difícil', 1),
    OpcionGad7('Muy difícil', 2),
    OpcionGad7('Extremadamente difícil', 3),
  ];

  // --- Textos de la app (tú), sin resultado ---

  static const String titulo = 'Cuestionario quincenal';

  static const String tarjetaTitulo = 'Cuestionario quincenal';
  static const String tarjetaDetalle = 'Cómo te has sentido las últimas 2 semanas · unos 2 minutos';
  static const String tarjetaBoton = 'Responder';

  static const String introTitulo = 'Unas preguntas sobre cómo te has sentido';
  static const List<String> introPuntos = [
    'Son 7 preguntas sobre las últimas 2 semanas. Toma unos 2 minutos.',
    'Tus respuestas las ve tu especialista.',
    'No hay respuestas buenas ni malas: elige la que más se parezca a lo que has vivido.',
  ];
  static const String comenzar = 'Comenzar';

  static const String omitirDificultad = 'Prefiero no responder esta';
  static const String enviar = 'Enviar';
  static const String enviando = 'Guardando tus respuestas…';

  static const String salirTitulo = '¿Salir del cuestionario?';
  static const String salirTexto = 'Tus respuestas no se guardarán.';

  static const String graciasTitulo = '¡Gracias por responder!';
  static const String graciasTexto = 'Tus respuestas ya le llegaron a tu especialista.';
  static const String yaGuardadoTexto = 'Tus respuestas ya estaban guardadas. Tu especialista ya puede verlas.';
  static const String listo = 'Listo';

  /// Igual para todos (no depende de las respuestas, para no delatarlas).
  ///
  /// VERIFICAR: cuando Omar confirme el número oficial de la Línea de la Vida,
  /// agregarlo aquí (y en `apoyoLinea`). NO publicar un número sin verificar.
  static const String apoyo =
      'Si en algún momento te sientes muy mal, habla con tu especialista o busca ayuda profesional.';

  /// VERIFICAR: texto con el número oficial de la Línea de la Vida. Mientras
  /// sea null no se muestra nada.
  static const String? apoyoLinea = null;
}

/// Aviso de alcance del cuestionario (no es diagnóstico).
const String disclaimerGad7 =
    'Este cuestionario es una herramienta de apoyo para tu especialista; no es un diagnóstico.';
