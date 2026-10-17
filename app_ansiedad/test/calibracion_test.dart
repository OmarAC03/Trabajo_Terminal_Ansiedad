import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/models/calibracion.dart';

/// Lo que manda `GET /api/linea-base/:id` (y `data.calibracion` del POST) al
/// paciente. A propósito incluye campos que el paciente NO debe recibir, para
/// comprobar la segunda barrera de la regla de oro: el modelo los descarta.
Map<String, dynamic> calibracionJson({
  String etapa = 'preliminar',
  int dia = 5,
  int dias = 4,
  bool medidoHoy = false,
  bool vencido = false,
}) =>
    {
      'origen': 'simulacion',
      'hoy': '2026-10-17',
      'etapa': etapa,
      'etapa_manana': etapa,
      'dias_con_medicion': dias,
      'medido_hoy': medidoHoy,
      'dia_calibracion': dia,
      'dias_objetivo': 7,
      'dias_minimos': 3,
      'hay_historial_vencido': vencido,
    };

const camposProhibidos = {
  'estado': 'altos',
  'z': -3.21,
  'fc_por_encima': true,
  'n': 7,
  'banda': {'rango_hrv_ms': {'min': 41.8, 'max': 51.0}},
};

void main() {
  group('Calibracion.fromJson', () {
    test('lee la etapa y el "día X de 7"', () {
      final c = Calibracion.fromJson(calibracionJson());
      expect(c.origen, 'simulacion');
      expect(c.etapa, EtapaBase.preliminar);
      expect(c.diaCalibracion, 5);
      expect(c.diasObjetivo, 7);
      expect(c.diasConMedicion, 4);
      expect(c.medidoHoy, isFalse);
      expect(c.hayHistorialVencido, isFalse);
    });

    test('etapa desconocida → calibrando (el mensaje más neutro); día dentro de 1–7', () {
      final c = Calibracion.fromJson({...calibracionJson(), 'etapa': 'otra', 'dia_calibracion': 12});
      expect(c.etapa, EtapaBase.calibrando);
      expect(c.diaCalibracion, 7);
    });

    test('deOrigenes: un mapa por origen; ignora lo que no sea objeto', () {
      final m = Calibracion.deOrigenes({
        'simulacion': calibracionJson(),
        'sensor': {...calibracionJson(etapa: 'calibrando', dia: 2, dias: 1), 'origen': 'sensor'},
        'raro': 'texto',
      });
      expect(m.keys, unorderedEquals(['simulacion', 'sensor']));
      expect(m['sensor']!.etapa, EtapaBase.calibrando);
      expect(Calibracion.deOrigenes(null), isEmpty);
    });
  });

  group('Regla de oro, segunda barrera: el modelo no guarda estado, banda, z ni FC por encima', () {
    test('Calibracion: aunque el JSON trajera esos campos, el objeto no los tiene', () {
      final c = Calibracion.fromJson({...calibracionJson(), ...camposProhibidos});
      // Solo los campos de la lista cerrada (sin reflexión en Flutter: se
      // revisa el texto del objeto completo).
      final texto = '${c.origen} ${c.etapa} ${c.etapaManana} ${c.diaCalibracion} ${c.diasObjetivo} '
          '${c.diasConMedicion} ${c.medidoHoy} ${c.hayHistorialVencido}';
      for (final prohibido in ['altos', '-3.21', '41.8', '51.0']) {
        expect(texto.contains(prohibido), isFalse, reason: 'apareció "$prohibido"');
      }
    });

    test('EvaluacionSesion: solo etapa y motivo', () {
      final e = EvaluacionSesion.fromJson({'etapa': 'consolidada', 'motivo_sin_estado': null, ...camposProhibidos});
      expect(e.etapa, EtapaBase.consolidada);
      expect(e.motivo, isNull);
    });

    test('SesionGuardada: id, evaluación y calibración; null si el backend no las calculó', () {
      final g = SesionGuardada.fromData({
        'id': 's1',
        'fecha_inicio': '2026-10-17T14:00:00Z',
        'evaluacion': {'etapa': 'consolidada', 'motivo_sin_estado': 'calidad_baja', ...camposProhibidos},
        'calibracion': calibracionJson(etapa: 'consolidada', dia: 7, dias: 9, medidoHoy: true),
      });
      expect(g.id, 's1');
      expect(g.evaluacion!.motivo, MotivoSinComparar.calidadBaja);
      expect(g.calibracion!.medidoHoy, isTrue);

      final sinCalculo = SesionGuardada.fromData({'id': 's2', 'evaluacion': null, 'calibracion': null});
      expect(sinCalculo.evaluacion, isNull);
      expect(sinCalculo.calibracion, isNull);
    });
  });
}
