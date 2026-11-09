import 'package:app_ansiedad/screens/mensajes_screen.dart';
import 'package:app_ansiedad/ui/fechas_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Instante UTC (la Ciudad de México es UTC-6 todo el año desde 2022).
DateTime utc(int y, int m, int d, int h, [int min = 0]) => DateTime.utc(y, m, d, h, min);

void main() {
  group('hora de la Ciudad de México', () {
    test('convierte desde UTC sin importar la zona del teléfono', () {
      expect(enHoraMexico(utc(2026, 11, 9, 20, 5)), DateTime(2026, 11, 9, 14, 5));
      // 02:30 UTC del 10 todavía es el 9 en México.
      expect(enHoraMexico(utc(2026, 11, 10, 2, 30)), DateTime(2026, 11, 9, 20, 30));
    });

    test('hora con dos dígitos: 14:05 y 09:07', () {
      expect(horaChat(DateTime(2026, 11, 9, 14, 5)), '14:05');
      expect(horaChat(DateTime(2026, 11, 9, 9, 7)), '09:07');
    });
  });

  group('etiqueta del día', () {
    final hoy = DateTime(2026, 11, 11, 12);
    test('Hoy, Ayer y fecha larga', () {
      expect(etiquetaDiaChat(DateTime(2026, 11, 11, 8), hoy: hoy), 'Hoy');
      expect(etiquetaDiaChat(DateTime(2026, 11, 10, 23), hoy: hoy), 'Ayer');
      expect(etiquetaDiaChat(DateTime(2026, 11, 9, 9), hoy: hoy), 'lunes 9 de noviembre');
      expect(etiquetaDiaChat(DateTime(2026, 11, 8), hoy: hoy), 'domingo 8 de noviembre');
    });

    test('otro año lleva el año; "Ayer" cruza meses y años', () {
      expect(etiquetaDiaChat(DateTime(2025, 12, 31), hoy: DateTime(2026, 1, 1)), 'Ayer');
      expect(etiquetaDiaChat(DateTime(2025, 12, 30), hoy: DateTime(2026, 1, 1)), 'martes 30 de diciembre de 2025');
      expect(etiquetaDiaChat(DateTime(2026, 10, 31), hoy: DateTime(2026, 11, 1)), 'Ayer');
    });
  });

  group('separadores', () {
    // Mensajes de prueba: (texto, instante UTC).
    final mensajes = <(String, DateTime?)>[
      ('a', utc(2026, 11, 9, 15)), // lunes 9, 09:00 MX
      ('b', utc(2026, 11, 9, 16)),
      ('c', utc(2026, 11, 11, 3)), // martes 10, 21:00 MX (ya es 11 en UTC)
      ('d', null), // sin fecha: se queda en el día anterior
      ('e', utc(2026, 11, 11, 18, 5)), // miércoles 11, 12:05 MX
    ];
    final ahora = utc(2026, 11, 11, 20); // miércoles 11, 14:00 MX

    test('un separador al cambiar de día, en hora de México', () {
      final e = conSeparadores(mensajes, ((String, DateTime?) m) => m.$2, ahora: ahora);
      expect(
        e.map((x) => x.esSeparador ? '[${x.separador}]' : '${x.mensaje!.$1} ${x.hora}').toList(),
        ['[lunes 9 de noviembre]', 'a 09:00', 'b 10:00', '[Ayer]', 'c 21:00', 'd ', '[Hoy]', 'e 12:05'],
      );
    });

    test('sin mensajes no hay separadores', () {
      expect(conSeparadores(<(String, DateTime?)>[], ((String, DateTime?) m) => m.$2, ahora: ahora), isEmpty);
    });

    testWidgets('el separador se dibuja como píldora con su texto', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SeparadorDia('Hoy'))));
      expect(find.text('Hoy'), findsOneWidget);
    });
  });
}
