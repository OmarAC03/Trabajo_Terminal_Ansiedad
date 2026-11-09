import 'dart:io';
import 'package:app_ansiedad/avatar_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatares de la mascota', () {
    test('11 expresiones, sin avatar_preocupado', () {
      expect(TipoAvatar.values, hasLength(11));
      expect(TipoAvatar.values.map((t) => t.id), isNot(contains('preocupado')));
    });

    test('cada avatar tiene su imagen 1x, 2.0x y 3.0x', () {
      for (final t in TipoAvatar.values) {
        final nombre = t.ruta.split('/').last;
        for (final carpeta in ['assets/mascota', 'assets/mascota/2.0x', 'assets/mascota/3.0x']) {
          expect(File('$carpeta/$nombre').existsSync(), isTrue, reason: '$carpeta/$nombre');
        }
      }
    });

    test('ida y vuelta por photoURL', () {
      for (final t in TipoAvatar.values) {
        expect(avatarDesdePhotoUrl(avatarAPhotoUrl(t)), t);
      }
      expect(avatarDesdePhotoUrl(null), isNull);
      expect(avatarDesdePhotoUrl('https://foto'), isNull);
      expect(avatarDesdePhotoUrl('avatar:desconocido'), isNull);
      expect(avatarDesdePhotoUrl('avatar:preocupado'), isNull);
    });

    test('las cuentas con un animal de antes ven la mascota feliz', () {
      for (final viejo in ['zorro', 'gato', 'buho', 'panda', 'conejo', 'oso']) {
        expect(avatarDesdePhotoUrl('avatar:$viejo'), TipoAvatar.feliz, reason: viejo);
      }
    });

    testWidgets('el selector muestra las 11 imágenes sin nombres y devuelve la elegida', (tester) async {
      TipoAvatar? elegido;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SelectorAvatar(actual: TipoAvatar.feliz, onElegir: (t) => elegido = t)),
      ));
      expect(find.byType(MascotaAvatar), findsNWidgets(11));
      final textos = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(textos, ['Elige tu avatar']);
      await tester.tap(find.byType(MascotaAvatar).at(2));
      expect(elegido, TipoAvatar.values[2]);
    });
  });
}
