import 'dart:developer' as developer;

/// Logger estructurado central de la app.
///
/// Antes los errores inesperados (todo lo que no era un [RepositoryException]
/// ya traducido) se tragaban en silencio dentro de los `catch (_)` de cada
/// provider: el usuario veía un mensaje genérico y no quedaba ningún rastro
/// de qué había pasado. `dart:developer.log()` da niveles, nombre/tag, error
/// y stackTrace estructurados (visibles en la consola y en DevTools) sin
/// añadir una dependencia nueva al proyecto.
class AppLogger {
  AppLogger._();

  static const int _nivelDebug = 500;
  static const int _nivelInfo = 800;
  static const int _nivelWarning = 900;
  static const int _nivelError = 1000;

  static void debug(String mensaje, {String tag = 'app'}) {
    developer.log(mensaje, name: tag, level: _nivelDebug);
  }

  static void info(String mensaje, {String tag = 'app'}) {
    developer.log(mensaje, name: tag, level: _nivelInfo);
  }

  static void warning(String mensaje, {String tag = 'app', Object? error}) {
    developer.log(mensaje, name: tag, level: _nivelWarning, error: error);
  }

  static void error(
    String mensaje, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      mensaje,
      name: tag,
      level: _nivelError,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
