import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Resultado de una operación de red, para que las pantallas sepan qué mostrar
/// sin tener que interpretar códigos HTTP crudos ni excepciones sueltas.
enum EstadoRed {
  ok,
  errorServidor,    // el servidor respondió, pero con error (4xx/5xx)
  sinConexion,      // no hubo forma de contactar al servidor
  tiempoAgotado,    // el servidor no respondió a tiempo (posible cold start)
}

class RespuestaRed {
  final EstadoRed estado;
  final int? statusCode;
  final String? body;

  RespuestaRed(this.estado, {this.statusCode, this.body});

  bool get exito => estado == EstadoRed.ok;

  /// Mensaje amable y accionable para mostrarle al usuario según lo que pasó.
  String get mensajeUsuario {
    switch (estado) {
      case EstadoRed.ok:
        return "Listo.";
      case EstadoRed.errorServidor:
        return "El servidor respondió con un error (código $statusCode). Intenta de nuevo en un momento.";
      case EstadoRed.sinConexion:
        return "No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.";
      case EstadoRed.tiempoAgotado:
        return "El servidor está tardando en responder. Puede estar iniciándose; espera unos segundos y reintenta.";
    }
  }
}

/// Cliente HTTP central de la app.
///
/// Su razón de existir: el backend está en el plan gratuito de Render, que
/// "duerme" el servicio tras ~15 min de inactividad. La primera petición
/// después de eso puede tardar 30-50s en despertar el servidor (cold start).
/// Sin manejo, eso se ve como un error de red aunque todo esté bien.
///
/// Este cliente reintenta automáticamente con esperas crecientes antes de
/// rendirse, y traduce el resultado a algo que la UI entiende.
class ApiClient {
  ApiClient._();

  /// Tiempo máximo de espera por intento. Generoso a propósito por el cold start.
  static const Duration _timeoutPorIntento = Duration(seconds: 20);

  /// Número de reintentos ante timeout/sin conexión (además del intento inicial).
  static const int _maxReintentos = 2;

  static Future<RespuestaRed> get(Uri url) =>
      _ejecutar(() async => http.get(url, headers: await _conHeaderAuth(null)));

  static Future<RespuestaRed> post(Uri url, {Map<String, String>? headers, Object? body}) =>
      _ejecutar(() async => http.post(url, headers: await _conHeaderAuth(headers), body: body));

  static Future<RespuestaRed> put(Uri url, {Map<String, String>? headers, Object? body}) =>
      _ejecutar(() async => http.put(url, headers: await _conHeaderAuth(headers), body: body));

  /// Agrega `Authorization: Bearer <idToken>` a los headers si hay sesión
  /// Firebase activa. Centralizado aquí para que ningún repositorio tenga
  /// que acordarse de mandar el token: todo pasa por ApiClient.
  static Future<Map<String, String>> _conHeaderAuth(Map<String, String>? headers) async {
    final resultado = Map<String, String>.from(headers ?? {});
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) resultado['Authorization'] = 'Bearer $token';
    return resultado;
  }

  static Future<RespuestaRed> _ejecutar(Future<http.Response> Function() peticion) async {
    for (int intento = 0; intento <= _maxReintentos; intento++) {
      try {
        final res = await peticion().timeout(_timeoutPorIntento);

        // 2xx = éxito. Cualquier otra cosa es error del servidor (no reintentamos
        // 4xx/5xx: reintentar no arregla un dato mal formado ni un bug del server).
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return RespuestaRed(EstadoRed.ok, statusCode: res.statusCode, body: res.body);
        }
        return RespuestaRed(EstadoRed.errorServidor, statusCode: res.statusCode, body: res.body);
      } on TimeoutException {
        // Posible cold start: si quedan reintentos, esperamos y volvemos a probar.
        if (intento < _maxReintentos) {
          await Future.delayed(Duration(seconds: 2 * (intento + 1)));
          continue;
        }
        return RespuestaRed(EstadoRed.tiempoAgotado);
      } on SocketException {
        if (intento < _maxReintentos) {
          await Future.delayed(Duration(seconds: 2 * (intento + 1)));
          continue;
        }
        return RespuestaRed(EstadoRed.sinConexion);
      } catch (e) {
        // Cualquier otro error inesperado lo tratamos como sin conexión, pero
        // sin reintentar a ciegas.
        return RespuestaRed(EstadoRed.sinConexion);
      }
    }
    // Inalcanzable, pero el analizador lo pide.
    return RespuestaRed(EstadoRed.sinConexion);
  }
}
