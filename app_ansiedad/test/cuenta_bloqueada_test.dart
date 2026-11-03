import 'package:app_ansiedad/cuenta_bloqueada.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('codigoBloqueo (Bloque 1: cuenta suspendida o eliminada)', () {
    test('403 con cuenta_suspendida', () {
      expect(codigoBloqueo(403, '{"error":"x","codigo":"cuenta_suspendida"}'), 'cuenta_suspendida');
    });

    test('403 con cuenta_eliminada', () {
      expect(codigoBloqueo(403, '{"error":"x","codigo":"cuenta_eliminada"}'), 'cuenta_eliminada');
    });

    test('un 403 de autorización normal no cierra la sesión', () {
      expect(codigoBloqueo(403, '{"error":"No autorizado para ver este perfil"}'), isNull);
      expect(codigoBloqueo(403, '{"error":"x","codigo":"otro"}'), isNull);
    });

    test('otro status con el mismo código no cuenta', () {
      expect(codigoBloqueo(401, '{"codigo":"cuenta_suspendida"}'), isNull);
      expect(codigoBloqueo(200, '{"codigo":"cuenta_suspendida"}'), isNull);
      expect(codigoBloqueo(null, null), isNull);
    });

    test('cuerpo vacío, no JSON o no objeto no truena', () {
      expect(codigoBloqueo(403, null), isNull);
      expect(codigoBloqueo(403, ''), isNull);
      expect(codigoBloqueo(403, '<html>Forbidden</html>'), isNull);
      expect(codigoBloqueo(403, '["cuenta_suspendida"]'), isNull);
      expect(codigoBloqueo(403, '{"codigo":7}'), isNull);
    });

    test('cada código tiene su mensaje, sin nada clínico', () {
      expect(mensajesBloqueo['cuenta_suspendida'], contains('suspendida'));
      expect(mensajesBloqueo['cuenta_eliminada'], contains('eliminada'));
      for (final texto in mensajesBloqueo.values) {
        expect(texto, isNot(contains(RegExp(r'ansiedad|medici|lectura|gad', caseSensitive: false))));
      }
    });
  });
}
