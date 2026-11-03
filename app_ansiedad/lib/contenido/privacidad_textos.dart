/// Aviso de privacidad y consentimiento informado (Bloque 1, paso 2: RN-01,
/// RN-02, RNF-06). El paciente los acepta al registrarse o, si su cuenta ya
/// existía, en la puerta de consentimiento al entrar.
///
/// ⚠️ VERIFICAR: estos textos son un BORRADOR para probar el flujo. La
/// redacción final (datos personales sensibles de salud, LFPDPPP) la revisa y
/// la entrega Omar. Al reemplazarlos:
///   1. quitar "-borrador" de [versionAviso] y [versionConsentimiento];
///   2. poner las MISMAS versiones en `backend/consentimiento.js`;
///   3. poner [esBorrador] en false.
/// Cada paciente volverá a aceptar la versión nueva (por eso existe la versión).
class TextosPrivacidad {
  TextosPrivacidad._();

  /// Mientras sea true, una prueba exige que las versiones digan "borrador":
  /// así no se publica un texto provisional con una versión que parezca final.
  static const bool esBorrador = true;

  static const String versionAviso = 'privacidad-v0-borrador';
  static const String versionConsentimiento = 'consentimiento-v0-borrador';

  // --- Pantalla de la puerta (cuentas existentes) ---
  static const String titulo = 'Antes de continuar';
  static const String introduccion =
      'Para usar la app necesitamos que leas y aceptes el aviso de privacidad y el consentimiento informado. '
      'Sin tu aceptación no se pueden registrar mediciones ni cuestionarios.';
  static const String marcaBorrador = 'BORRADOR — texto pendiente de revisión';

  static const String casillaAviso = 'Leí y acepto el aviso de privacidad.';
  static const String casillaConsentimiento =
      'Doy mi consentimiento para el tratamiento de mis datos de salud como se describe.';
  static const String aceptar = 'Aceptar y continuar';
  static const String salir = 'Cerrar sesión';
  static const String errorCarga = 'No se pudo comprobar tu consentimiento.';
  static const String reintentar = 'Reintentar';

  // --- Registro ---
  static const String casillaRegistro = 'Leí y acepto el aviso de privacidad y el consentimiento informado.';
  static const String leerTextos = 'Leer aviso y consentimiento';
  static const String faltaAceptarRegistro = 'Para crear tu cuenta acepta el aviso de privacidad y el consentimiento.';

  // --- Textos (BORRADOR, VERIFICAR) ---
  static const String tituloAviso = 'Aviso de privacidad';
  static const List<String> aviso = [
    'Responsable. [VERIFICAR: nombre del responsable del tratamiento, domicilio y medio de contacto.]',
    'Datos que se recaban. Nombre y correo electrónico; mediciones fisiológicas (frecuencia cardíaca, '
        'saturación de oxígeno y variabilidad de la frecuencia cardíaca); tus respuestas a cuestionarios '
        '(EVA y GAD-7); los mensajes con tu especialista y los ejercicios que te asigne. Los datos de salud '
        'son datos personales sensibles.',
    'Finalidades. Mostrar tus indicadores fisiológicos a ti y a tu especialista vinculado como apoyo a su '
        'seguimiento. El sistema no emite diagnósticos.',
    'Quién ve tus datos. Solo tu especialista vinculado. El administrador gestiona cuentas y no tiene acceso '
        'a tus datos de salud. [VERIFICAR: transferencias y encargados (servidores de Render, Supabase y '
        'Firebase).]',
    'Tus derechos. Puedes acceder a tus datos, rectificarlos, cancelarlos u oponerte a su uso (derechos ARCO), '
        'y solicitar la eliminación de tu cuenta y tus datos. [VERIFICAR: medio y plazos de respuesta.]',
    'Cambios al aviso. Si el aviso cambia, la app te pedirá aceptarlo de nuevo.',
  ];

  static const String tituloConsentimiento = 'Consentimiento informado';
  static const List<String> consentimiento = [
    'Acepto de forma libre y voluntaria que el sistema registre y trate mis datos de salud con las '
        'finalidades del aviso de privacidad.',
    'Entiendo que los indicadores son de apoyo para mi especialista y no son un diagnóstico.',
    'Sé que puedo dejar de usar la app y solicitar la eliminación de mi cuenta y mis datos.',
    '[VERIFICAR: redacción final del consentimiento expreso para datos sensibles (LFPDPPP) y, si aplica, '
        'del protocolo de investigación.]',
  ];
}
