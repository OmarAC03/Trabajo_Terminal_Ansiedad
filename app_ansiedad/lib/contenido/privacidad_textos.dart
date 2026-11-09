/// Aviso de privacidad y consentimiento informado (Bloque 1, paso 2: RN-01,
/// RN-02, RNF-06; versión final: docs/version_final/AVISO_PRIVACIDAD_Y_CONSENTIMIENTO.md).
/// El paciente los acepta al registrarse o, si su cuenta ya existía, en la
/// puerta de consentimiento al entrar.
///
/// Los textos son los aprobados por los directores (versión 1). Mientras
/// queden datos entre [corchetes], la versión lleva "-borrador" (una prueba lo
/// exige). Al completarlos:
///   1. quitar "-borrador" de [versionAviso] y [versionConsentimiento];
///   2. poner las MISMAS versiones en `backend/consentimiento.js`;
///   3. poner [esBorrador] en false.
/// Cada paciente volverá a aceptar la versión nueva (por eso existe la versión).
///
/// Las negritas se marcan con **asteriscos** (las dibuja [TextoConNegritas]).
library;

enum TipoBloque { subtitulo, parrafo, vineta }

class BloqueTexto {
  final TipoBloque tipo;
  final String texto;
  const BloqueTexto.subtitulo(this.texto) : tipo = TipoBloque.subtitulo;
  const BloqueTexto.parrafo(this.texto) : tipo = TipoBloque.parrafo;
  const BloqueTexto.vineta(this.texto) : tipo = TipoBloque.vineta;

  /// Sin las marcas de negrita.
  String get plano => texto.replaceAll('**', '');
}

class TextosPrivacidad {
  TextosPrivacidad._();

  /// Mientras sea true, una prueba exige que las versiones digan "borrador":
  /// así no se publica un texto incompleto con una versión que parezca final.
  static const bool esBorrador = true;

  static const String versionAviso = 'privacidad-v1-borrador';
  static const String versionConsentimiento = 'consentimiento-v1-borrador';

  // --- Pantalla de la puerta (cuentas existentes) ---
  static const String titulo = 'Antes de continuar';
  static const String introduccion =
      'Para usar la app necesitamos que leas y aceptes el aviso de privacidad y el consentimiento informado. '
      'Sin tu aceptación no se pueden registrar mediciones ni cuestionarios.';
  static const String marcaBorrador = 'BORRADOR — falta el correo de contacto del proyecto (entre corchetes).';

  static const String casillaAviso = 'Leí y acepto el aviso de privacidad.';
  static const String casillaConsentimiento =
      'Doy mi consentimiento expreso para participar y para el tratamiento de mis datos de salud.';
  static const String aceptar = 'Aceptar y continuar';
  static const String salir = 'Cerrar sesión';
  static const String errorCarga = 'No se pudo comprobar tu consentimiento.';
  static const String reintentar = 'Reintentar';
  static const String leerCompleto = 'Leer aviso completo';

  // --- Registro ---
  static const String casillaRegistro = 'Leí y acepto el aviso de privacidad y el consentimiento informado.';
  static const String leerTextos = 'Leer aviso y consentimiento';
  static const String faltaAceptarRegistro = 'Para crear tu cuenta acepta el aviso de privacidad y el consentimiento.';

  // --- A. Aviso simplificado (registro y puerta) ---
  static const String tituloAviso = 'Aviso de privacidad';
  static const List<BloqueTexto> avisoSimplificado = [
    BloqueTexto.parrafo(
        'Este prototipo forma parte del Trabajo Terminal 2026-B085 de la Escuela Superior de Cómputo (ESCOM) del '
        'Instituto Politécnico Nacional. La ESCOM es la responsable del tratamiento de tus datos personales.'),
    BloqueTexto.parrafo('Usamos tus datos para:'),
    BloqueTexto.vineta(
        'registrar tus mediciones de pulso (frecuencia cardiaca, variabilidad de la frecuencia cardiaca y '
        'oxigenación) y tus respuestas a los cuestionarios;'),
    BloqueTexto.vineta('compararlas con tu propio ritmo habitual;'),
    BloqueTexto.vineta('que el especialista con el que te vincules pueda darte seguimiento.'),
    BloqueTexto.parrafo(
        'Algunos de estos datos son **datos de salud** y por eso te pedimos tu consentimiento expreso.'),
    BloqueTexto.parrafo(
        'Con datos **agregados y sin identificarte** se evaluará el funcionamiento del prototipo dentro del '
        'Trabajo Terminal. Si no quieres que tus datos se usen para esto, escríbenos a [correo de contacto del '
        'proyecto].'),
    BloqueTexto.parrafo('No vendemos tus datos ni los compartimos con terceros para otros fines.'),
    BloqueTexto.parrafo('Puedes pedir la eliminación de tu cuenta en **Perfil → Privacidad**.'),
    BloqueTexto.parrafo(
        'Consulta el aviso completo en **Perfil → Privacidad → Aviso de privacidad**.'),
  ];

  // --- B. Aviso integral (Perfil → Privacidad) ---
  static const String tituloAvisoIntegral = 'Aviso de privacidad integral';
  static const List<BloqueTexto> avisoIntegral = [
    BloqueTexto.subtitulo('1. Responsable'),
    BloqueTexto.parrafo(
        'La Escuela Superior de Cómputo (ESCOM) del Instituto Politécnico Nacional, con domicilio en Av. Juan '
        'de Dios Bátiz s/n, esq. Miguel Othón de Mendizábal, Col. Lindavista, Alcaldía Gustavo A. Madero, C.P. '
        '07738, Ciudad de México, es la responsable del tratamiento de los datos personales que se recaben '
        'mediante este prototipo, conforme a la Ley General de Protección de Datos Personales en Posesión de '
        'Sujetos Obligados.'),
    BloqueTexto.parrafo(
        'El prototipo lo desarrollan Omar Alejandro Angeles Carcamo y Luis Enrique Lopez Marin como parte del '
        'Trabajo Terminal 2026-B085. Lo dirigen el Dr. José Alfredo Jiménez Benítez y la M. en C. Jacqueline Arzate '
        'Gordillo.'),
    BloqueTexto.subtitulo('2. Datos personales que se tratan'),
    BloqueTexto.parrafo('**Datos de identificación y de cuenta:**'),
    BloqueTexto.vineta('nombre;'),
    BloqueTexto.vineta('correo electrónico;'),
    BloqueTexto.vineta(
        'contraseña. La contraseña la administra el servicio de autenticación y el proyecto nunca la conoce.'),
    BloqueTexto.parrafo('**Datos de salud (sensibles):**'),
    BloqueTexto.vineta(
        'frecuencia cardiaca, variabilidad de la frecuencia cardiaca (RMSSD) y saturación de oxígeno (SpO2) de '
        'cada medición, con su fecha, hora y calidad de la señal;'),
    BloqueTexto.vineta('la escala de cómo te sientes que respondes después de cada medición;'),
    BloqueTexto.vineta('las respuestas al cuestionario GAD-7.'),
    BloqueTexto.parrafo('**Datos de comunicación:**'),
    BloqueTexto.vineta('los mensajes que intercambias con tu especialista;'),
    BloqueTexto.vineta('los ejercicios que te asigna.'),
    BloqueTexto.parrafo(
        '**Datos técnicos del dispositivo:** si activas las notificaciones, se guarda un identificador técnico '
        'de tu teléfono (token de notificaciones) para poder avisarte de mensajes y ejercicios nuevos. Se borra '
        'al cerrar sesión, si tu cuenta se suspende o al eliminarla. Las notificaciones **nunca muestran el '
        'contenido** de tus mensajes ni resultados; aun así, quien vea tu pantalla podría notar que usas la app. '
        'Puedes desactivarlas en cualquier momento en los ajustes de tu teléfono.'),
    BloqueTexto.parrafo(
        '**No recabamos** tu ubicación, tus contactos ni otros datos de tu teléfono. El permiso de Bluetooth se '
        'usa solo para conectar el sensor.'),
    BloqueTexto.subtitulo('3. Finalidades'),
    BloqueTexto.parrafo('**Necesarias para el servicio:**'),
    BloqueTexto.vineta('1. Crear y administrar tu cuenta.'),
    BloqueTexto.vineta(
        '2. Registrar tus mediciones y calcular tu línea base individual, es decir, tu propio ritmo habitual.'),
    BloqueTexto.vineta(
        '3. Que el especialista con el que te vincules consulte tus mediciones y tus cuestionarios para darte '
        'seguimiento.'),
    BloqueTexto.vineta('4. Permitir la comunicación entre tú y tu especialista.'),
    BloqueTexto.parrafo('**Adicional:**'),
    BloqueTexto.vineta(
        '5. Evaluar el funcionamiento del prototipo con datos **agregados y sin identificarte**, dentro del '
        'Trabajo Terminal y su documento. Puedes negarte escribiendo a [correo de contacto del proyecto]; tu '
        'negativa no afecta el uso de la app.'),
    BloqueTexto.parrafo(
        'La app **no emite diagnósticos** y no sustituye la atención de un profesional de la salud.'),
    BloqueTexto.subtitulo('4. Quién puede ver tus datos'),
    BloqueTexto.vineta('**Tú:** tus mediciones y tu historial.'),
    BloqueTexto.vineta(
        '**Tu especialista** (solo si te vinculas con él o ella): tus mediciones, cómo se comparan con tu línea '
        'base, la calidad de cada medición, tus cuestionarios, tus mensajes y tus ejercicios. También puede '
        'escribir notas de seguimiento y marcar fechas relevantes (por ejemplo, un periodo de exámenes), y '
        'exportar un reporte de tus datos para tu seguimiento.'),
    BloqueTexto.vineta(
        '**Administración del sistema:** tu nombre, correo, rol y estado de la cuenta, y la bitácora de '
        'seguridad (quién hizo qué acción y cuándo). **No ve** tus datos de salud ni las notas de tu '
        'especialista.'),
    BloqueTexto.subtitulo('5. Servicios que usa el sistema (encargados)'),
    BloqueTexto.parrafo(
        'Para funcionar, el sistema se apoya en proveedores que guardan o procesan los datos **por cuenta del '
        'proyecto** y solo para prestar el servicio:'),
    BloqueTexto.vineta('**Google Firebase:** autenticación de cuentas.'),
    BloqueTexto.vineta('**Supabase:** base de datos.'),
    BloqueTexto.vineta('**Render:** servidor de la aplicación y portal web.'),
    BloqueTexto.parrafo(
        'Estos servicios pueden almacenar la información en servidores fuera de México. La base de datos '
        '(Supabase) y el servidor (Render) están en la región East US, en Estados Unidos.'),
    BloqueTexto.parrafo(
        'No se hacen otras transferencias, salvo las que exija una autoridad competente conforme a la ley.'),
    BloqueTexto.subtitulo('6. Cuánto tiempo se conservan'),
    BloqueTexto.parrafo(
        'Tus datos se conservan mientras tu cuenta esté activa y dure el Trabajo Terminal, como máximo hasta el '
        '31 de enero de 2027.'),
    BloqueTexto.parrafo('Cuando el administrador atiende una solicitud de eliminación:'),
    BloqueTexto.vineta(
        '**se borran** tus mediciones, cuestionarios, mensajes y ejercicios, así como tu cuenta de acceso;'),
    BloqueTexto.vineta(
        '**se conserva** solo un registro seudonimizado (identificado solo con un código interno, sin tu nombre '
        'ni tu correo) que indica que la cuenta existió, que aceptaste este aviso y que pediste la eliminación.'),
    BloqueTexto.vineta(
        '**se conserva** la bitácora de seguridad del sistema: un registro de qué acciones se hicieron sobre la '
        'cuenta y cuándo (por ejemplo, que un especialista consultó tus datos o que se atendió tu solicitud). '
        'Solo guarda un identificador interno de la cuenta, **sin datos de salud** y sin contenido de mensajes '
        'ni de notas.'),
    BloqueTexto.parrafo(
        'El especialista también puede escribir **notas de seguimiento** sobre ti, que solo ve él o ella '
        'mientras estés vinculado. Estas notas se borran junto con tus demás datos al atender tu solicitud de '
        'eliminación.'),
    BloqueTexto.subtitulo('7. Tus derechos (ARCO y portabilidad)'),
    BloqueTexto.parrafo(
        'Tienes derecho a acceder a tus datos, rectificarlos, cancelarlos u oponerte a su tratamiento, y a '
        'solicitar su portabilidad.'),
    BloqueTexto.parrafo('**Dentro de la app:**'),
    BloqueTexto.vineta('consultar tus mediciones en Historial;'),
    BloqueTexto.vineta('corregir tu nombre en Perfil;'),
    BloqueTexto.vineta('pedir la eliminación de tu cuenta en Perfil → Privacidad → Eliminar mi cuenta.'),
    BloqueTexto.parrafo('**Por escrito:** a [correo de contacto del proyecto].'),
    BloqueTexto.parrafo(
        '**Ante la Unidad de Transparencia del IPN:** Av. Wilfrido Massieu s/n, Edificio «Adolfo Ruiz '
        'Cortines», planta baja, Unidad Profesional Adolfo López Mateos, Zacatenco, Alcaldía Gustavo A. Madero, '
        'C.P. 07738, Ciudad de México. Teléfono 55 5729 6000, extensiones 50128 y 51992. Correo: '
        'acceinfo@ipn.mx.'),
    BloqueTexto.parrafo(
        'Puedes **retirar tu consentimiento** en cualquier momento solicitando la eliminación de tu cuenta.'),
    BloqueTexto.subtitulo('8. Cambios a este aviso'),
    BloqueTexto.parrafo(
        'Si este aviso cambia, la app te mostrará la nueva versión y te pedirá aceptarla antes de seguir '
        'midiendo.'),
    BloqueTexto.parrafo('Versión: $versionAviso · Fecha: 10 de noviembre de 2026.'),
  ];

  // --- C. Consentimiento informado (segunda casilla) ---
  static const String tituloConsentimiento = 'Consentimiento para participar';
  static const List<BloqueTexto> consentimientoInformado = [
    BloqueTexto.parrafo('Al aceptar, confirmo que:'),
    BloqueTexto.vineta(
        '1. **Entiendo qué es la app.** Es un prototipo académico que mide señales de mi pulso con un sensor en '
        'el dedo durante unos minutos, en reposo, para conocer mi ritmo habitual. **No da diagnósticos** ni '
        'sustituye la atención de un profesional.'),
    BloqueTexto.vineta(
        '2. **Entiendo qué veré y qué no.** La app me muestra mis valores y mi progreso, pero **no me muestra '
        'interpretaciones** sobre mi estado. Si me vinculo con un especialista, él o ella revisará esta '
        'información para darme seguimiento.'),
    BloqueTexto.vineta(
        '3. **Mi participación es voluntaria.** Puedo dejar de usar la app y pedir la eliminación de mi cuenta '
        'en cualquier momento, sin ninguna consecuencia.'),
    BloqueTexto.vineta(
        '4. **Autorizo el tratamiento de mis datos de salud** (frecuencia cardiaca, variabilidad, oxigenación y '
        'respuestas a cuestionarios) para las finalidades descritas en el aviso de privacidad.'),
    BloqueTexto.vineta(
        '5. **Riesgos.** La medición no es invasiva: es la misma técnica de un oxímetro de dedo. Responder '
        'cuestionarios sobre cómo me siento puede resultar incómodo; puedo dejar de responder cuando quiera.'),
    BloqueTexto.vineta(
        '6. **Si necesito ayuda.** Esta app no atiende emergencias. Si me siento en crisis o en peligro, llamo '
        'al **911** o a la **Línea de la Vida 800 911 2000** (gratuita, 24 horas, todos los días).'),
    BloqueTexto.parrafo('Versión: $versionConsentimiento · Fecha: 10 de noviembre de 2026.'),
  ];

  /// Textos planos del aviso (simplificado + integral) y del consentimiento;
  /// los usan las pruebas de contenido.
  static List<String> get aviso => [...avisoSimplificado, ...avisoIntegral].map((b) => b.plano).toList();
  static List<String> get consentimiento => consentimientoInformado.map((b) => b.plano).toList();

  /// Si aún quedan datos por completar entre [corchetes].
  static bool get tieneCorchetes => [...aviso, ...consentimiento].any((t) => t.contains('['));
}
