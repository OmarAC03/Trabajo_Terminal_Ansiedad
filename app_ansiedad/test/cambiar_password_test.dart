import 'package:app_ansiedad/providers/cambiar_password_provider.dart';
import 'package:app_ansiedad/screens/cambiar_password_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CuentaFalsa implements CuentaPassword {
  String? codigoError;
  final List<List<String>> llamadas = [];
  CuentaFalsa({this.codigoError});

  @override
  Future<void> cambiar(String actual, String nueva) async {
    llamadas.add([actual, nueva]);
    if (codigoError != null) throw FirebaseAuthException(code: codigoError!);
  }
}

void main() {
  test('validación igual que el portal', () {
    expect(errorCampos('', 'nueva1', 'nueva1'), 'Completa los tres campos.');
    expect(errorCampos('actual', '12345', '12345'), contains('al menos 6'));
    expect(errorCampos('actual', 'nueva12', 'nueva13'), contains('no coincide'));
    expect(errorCampos('igual12', 'igual12', 'igual12'), contains('distinta'));
    expect(errorCampos('actual', 'nueva12', 'nueva12'), isNull);
  });

  test('mensajes de los errores de Firebase', () {
    expect(mensajeErrorPassword('wrong-password'), 'La contraseña actual no es correcta.');
    expect(mensajeErrorPassword('invalid-credential'), 'La contraseña actual no es correcta.');
    expect(mensajeErrorPassword('too-many-requests'), contains('Demasiados intentos'));
    expect(mensajeErrorPassword('network-request-failed'), contains('Sin conexión'));
    expect(mensajeErrorPassword('requires-recent-login'), contains('vuelve a entrar'));
    expect(mensajeErrorPassword('otro'), contains('No se pudo'));
  });

  test('campos inválidos no llaman a Firebase', () async {
    final cuenta = CuentaFalsa();
    final p = CambiarPasswordProvider(cuenta: cuenta);
    expect(await p.cambiar('actual', 'corta', 'corta'), isFalse);
    expect(cuenta.llamadas, isEmpty);
    expect(p.error, contains('al menos 6'));
  });

  test('cambio correcto', () async {
    final cuenta = CuentaFalsa();
    final p = CambiarPasswordProvider(cuenta: cuenta);
    expect(await p.cambiar('actual1', 'nueva12', 'nueva12'), isTrue);
    expect(cuenta.llamadas, [['actual1', 'nueva12']]);
    expect(p.listo, isTrue);
    expect(p.error, isNull);
    expect(p.guardando, isFalse);
  });

  test('contraseña actual incorrecta: mensaje claro', () async {
    final p = CambiarPasswordProvider(cuenta: CuentaFalsa(codigoError: 'invalid-credential'));
    expect(await p.cambiar('mala12', 'nueva12', 'nueva12'), isFalse);
    expect(p.error, 'La contraseña actual no es correcta.');
    expect(p.listo, isFalse);
  });

  testWidgets('la pantalla muestra el error y, al cambiar, limpia los campos', (tester) async {
    final cuenta = CuentaFalsa();
    await tester.pumpWidget(MaterialApp(home: CambiarPasswordScreen(cuenta: cuenta)));
    final campos = find.byType(TextField);
    expect(campos, findsNWidgets(3));

    await tester.enterText(campos.at(0), 'actual1');
    await tester.enterText(campos.at(1), 'nueva12');
    await tester.enterText(campos.at(2), 'otra123');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no coincide'), findsOneWidget);

    await tester.enterText(campos.at(2), 'nueva12');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Contraseña actualizada'), findsOneWidget);
    expect(cuenta.llamadas, [['actual1', 'nueva12']]);
    expect(tester.widget<TextField>(campos.at(0)).controller!.text, isEmpty);
  });
}
