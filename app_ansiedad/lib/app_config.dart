import 'package:flutter/material.dart';
import 'ui/app_colors.dart';

/// Configuración central de la app.
///
/// Antes, la URL del backend estaba copiada a mano en varios archivos.
/// Cualquier cambio (ej. mover el backend a otro dominio) obligaba a buscar y
/// reemplazar en todos lados, con riesgo de olvidar alguno. Ahora vive en un
/// único lugar.
class AppConfig {
  AppConfig._(); // no instanciable

  /// URL base del backend (Render). Si algún día cambia el dominio, se edita
  /// SOLO aquí.
  static const String backendUrl = 'https://tt-ansiedad-backend.onrender.com';

  // --- Endpoints derivados (para no repetir strings de rutas) ---
  static String get urlLecturas => '$backendUrl/api/lecturas';
  static String urlLecturasPaciente(String pacienteId) => '$backendUrl/api/lecturas/$pacienteId';
  static String urlResumenPaciente(String pacienteId) => '$backendUrl/api/lecturas/$pacienteId/resumen';
  static String get urlUsuarios => '$backendUrl/api/usuarios';
  static String urlUsuario(String id) => '$backendUrl/api/usuarios/$id';
  static String get urlVinculacion => '$backendUrl/api/vinculacion';
  static String urlMensajesPaciente(String pacienteId) => '$backendUrl/api/mensajes/$pacienteId';
  static String urlEjerciciosPaciente(String pacienteId) => '$backendUrl/api/ejercicios/$pacienteId';
  static String get urlPendientes => '$backendUrl/api/pendientes';
  static String urlPendienteVisto(String seccion) => '$backendUrl/api/pendientes/$seccion/visto';
  static String get urlSesiones => '$backendUrl/api/sesiones';
  static String urlSesionesPaciente(String pacienteId) => '$backendUrl/api/sesiones/$pacienteId';
  static String urlEvaSesion(String sesionId) => '$backendUrl/api/sesiones/$sesionId/eva';
  static String urlLineaBase(String pacienteId) => '$backendUrl/api/linea-base/$pacienteId';
  static const String urlGad7 = '$backendUrl/api/gad7';
  static String urlGad7Paciente(String pacienteId) => '$backendUrl/api/gad7/$pacienteId';
}

/// Parámetros de la sesión de medición (Fase M1b, DISENO_FLUJO_MEDICION.md §3).
/// Son constantes para poder ajustarlas con los directores sin tocar la lógica.
class ConfigMedicion {
  ConfigMedicion._();

  /// Segundos de señal VÁLIDA para dar la medición por completada (3 min).
  /// El backend exige al menos 120 s (MIN_SENAL_VALIDA_SEG en validation.js).
  static const int objetivoValidoSeg = 180;

  /// Tope de duración total: si no se junta el objetivo antes, la medición no
  /// se completa y no se sube nada.
  static const int topeTotalSeg = 600;

  /// Malla de la serie: un punto cada 5 s (1800 s / 5 = 360 puntos máx.).
  static const int intervaloSerieSeg = 5;

  /// Segundos válidos mínimos de un tramo de la malla para emitir su punto.
  static const int minValidosPorTramo = 4;

  /// Ventana móvil del RMSSD de cada punto de la serie.
  static const int ventanaHrvSeg = 30;

  // Rangos de plausibilidad de cada segundo de señal.
  static const int bpmMin = 40;
  static const int bpmMax = 180;
  static const int spo2Min = 80;
  static const int rrMinMs = 300;
  static const int rrMaxMs = 2000;

  /// Máxima diferencia relativa entre un RR y el anterior (filtro de
  /// artefactos habitual en HRV de corto plazo).
  static const double rrMaxVariacion = 0.20;

  /// Regla de seguridad (DESARROLLO_FUNDAMENTADO.md §2.3): SpO2 por debajo de
  /// este valor en una sesión con buena señal → aviso de confirmar con un
  /// oxímetro. No es una interpretación de ansiedad.
  static const double spo2UmbralSeguridad = 94;
}

/// Avisos de alcance mostrados en las pantallas con datos del paciente
/// (MARCO_ALCANCE_Y_LENGUAJE.md, sección 3).
class Disclaimers {
  Disclaimers._();

  /// Inicio y resultado de la medición (DESARROLLO_FUNDAMENTADO.md §5.1, textual).
  static const String inicio =
      'Estos son indicadores fisiológicos de apoyo, no un diagnóstico. Tu especialista los interpreta.';
  static const String historial =
      'Datos de apoyo. La interpretación corresponde a tu especialista.';
  static const String alcance =
      'Esta app monitorea parámetros fisiológicos (frecuencia cardiaca, SpO2 y HRV) '
      'asociados a la ansiedad como apoyo a tu especialista. No emite diagnósticos '
      'ni reemplaza la atención de un profesional de salud.';
  static const String acceso =
      'Herramienta de apoyo para tu especialista: muestra parámetros fisiológicos '
      'y no emite diagnósticos.';
  static const String ejercicios =
      'Estos ejercicios son una herramienta de apoyo sugerida por tu especialista; '
      'no son un tratamiento ni sustituyen la atención profesional. Si tienes dudas '
      'o no te sientes bien, consulta a tu especialista.';
}

/// Aviso discreto (texto gris con ícono) para acompañar los datos.
class DisclaimerNota extends StatelessWidget {
  final String texto;
  const DisclaimerNota(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 14, color: AppColors.textoSecundario),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texto, style: const TextStyle(fontSize: 11, color: AppColors.textoAyuda, height: 1.3)),
        ),
      ],
    );
  }
}
