import 'package:flutter/material.dart';

/// Configuración central de la app.
///
/// Antes, la URL del backend y los estados de ansiedad estaban copiados a mano
/// en varios archivos. Cualquier cambio (ej. mover el backend a otro dominio)
/// obligaba a buscar y reemplazar en todos lados, con riesgo de olvidar alguno.
/// Ahora viven en un único lugar.
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
}

/// Los tres niveles de ansiedad que maneja el sistema.
///
/// Antes eran strings sueltos ("Alta", "Moderada", "Baja") repetidos en Alerta
/// e Historial, propensos a errores de tipeo y con los colores duplicados en
/// cada pantalla. Este enum los unifica: un solo lugar define el texto que se
/// guarda en la base de datos y el color con que se pinta.
enum EstadoAnsiedad {
  baja,
  moderada,
  alta,
}

extension EstadoAnsiedadInfo on EstadoAnsiedad {
  /// El texto EXACTO que viaja al backend y se guarda en Supabase.
  /// No cambiar sin migrar los datos existentes.
  String get textoDB {
    switch (this) {
      case EstadoAnsiedad.alta:
        return 'Alta';
      case EstadoAnsiedad.moderada:
        return 'Moderada';
      case EstadoAnsiedad.baja:
        return 'Baja';
    }
  }

  Color get color {
    switch (this) {
      case EstadoAnsiedad.alta:
        return Colors.red;
      case EstadoAnsiedad.moderada:
        return Colors.orange;
      case EstadoAnsiedad.baja:
        return Colors.teal;
    }
  }

  /// Score numérico representativo del estado (usado al enviar lecturas).
  double get scoreRepresentativo {
    switch (this) {
      case EstadoAnsiedad.alta:
        return 8.5;
      case EstadoAnsiedad.moderada:
        return 6.0;
      case EstadoAnsiedad.baja:
        return 4.0;
    }
  }

  /// Convierte el texto que viene de la base de datos al enum.
  /// Si el valor no coincide con ninguno conocido, asume 'baja' como default
  /// seguro (en vez de reventar).
  static EstadoAnsiedad desdeTexto(String? texto) {
    switch (texto) {
      case 'Alta':
        return EstadoAnsiedad.alta;
      case 'Moderada':
        return EstadoAnsiedad.moderada;
      case 'Baja':
      default:
        return EstadoAnsiedad.baja;
    }
  }

  /// Color a partir de un texto crudo de la BD, sin tener que instanciar el
  /// enum manualmente. Atajo cómodo para las pantallas.
  static Color colorDesdeTexto(String? texto) => desdeTexto(texto).color;
}
