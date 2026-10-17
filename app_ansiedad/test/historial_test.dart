import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/models/calibracion.dart';
import 'package:app_ansiedad/models/eva_respuesta.dart';
import 'package:app_ansiedad/models/sesion_detalle.dart';
import 'package:app_ansiedad/models/sesion_medicion.dart';
import 'package:app_ansiedad/models/sesion_resumen.dart';
import 'package:app_ansiedad/providers/historial_sesiones_provider.dart';
import 'package:app_ansiedad/providers/sesion_detalle_provider.dart';
import 'package:app_ansiedad/repositories/sesion_repository.dart';
import 'package:app_ansiedad/ui/formato_fecha.dart';

/// Fila de la lista tal como la manda el backend al paciente (numeric como texto).
Map<String, dynamic> fila(String id, String fechaUtc) => {
      'id': id,
      'fecha_inicio': fechaUtc,
      'fecha_registro': fechaUtc,
      'duracion_total_seg': 214,
      'duracion_valida_seg': 180,
      'hrv_rmssd': '42.46',
      'hrv_min': '38.50',
      'hrv_max': '49.10',
      'bpm_promedio': '73.2',
      'bpm_min': 70,
      'bpm_max': 76,
      'spo2_promedio': '97.4',
      'spo2_min': 96,
      'spo2_max': 99,
      'origen': 'simulacion',
    };

SesionResumen sesionLocal(String id, DateTime local) =>
    SesionResumen.fromJson(fila(id, local.toUtc().toIso8601String()));

/// Repositorio falso: cada llamada consume la siguiente respuesta de su cola
/// (un valor o una excepción) y cuenta cuántas veces se llamó.
class RepoFalso implements SesionRepository {
  final List<Object> listas;
  final List<Object> detalles;
  int llamadasLista = 0;
  RepoFalso({this.listas = const [], this.detalles = const []});

  late final _listas = [...listas];
  late final _detalles = [...detalles];

  @override
  Future<List<SesionResumen>> obtenerSesiones(String pacienteId, {int limite = 200}) async {
    llamadasLista++;
    final r = _listas.removeAt(0);
    if (r is Exception) throw r;
    return r as List<SesionResumen>;
  }

  @override
  Future<SesionDetalle> obtenerDetalle(String pacienteId, String sesionId) async {
    final r = _detalles.removeAt(0);
    if (r is Exception) throw r;
    return r as SesionDetalle;
  }

  @override
  Future<SesionResumen?> obtenerUltimaSesion(String pacienteId) => throw UnimplementedError();

  @override
  Future<SesionGuardada> enviarSesion(SesionMedicion sesion) => throw UnimplementedError();

  @override
  Future<void> enviarEva(String sesionId, EvaRespuesta eva) => throw UnimplementedError();

  @override
  Future<Map<String, Calibracion>> obtenerCalibraciones(String pacienteId) => throw UnimplementedError();
}

void main() {
  group('Modelos', () {
    test('SesionResumen lee la duración', () {
      expect(SesionResumen.fromJson(fila('a', '2026-10-13T15:30:00Z')).duracionTotalSeg, 214);
    });

    test('SesionDetalle.fromJson: numeric como texto, mín/máx enteros y serie ordenada', () {
      final d = SesionDetalle.fromJson({
        ...fila('a', '2026-10-13T15:30:00Z'),
        'serie': [
          {'t': 10, 'bpm': 74.2, 'spo2': 97, 'hrv': 41.5},
          {'t': 0, 'bpm': 73, 'spo2': 97.4, 'hrv': '40.25'},
          {'t': 30, 'bpm': 75, 'spo2': 98, 'hrv': 44}, // hueco de 10 a 30
        ],
      });
      expect(d.resumen.hrvRmssd, 42.46);
      expect(d.hrvMin, 38.5);
      expect(d.hrvMax, 49.1);
      expect(d.bpmMin, 70);
      expect(d.spo2Max, 99);
      expect(d.serie.map((p) => p.t).toList(), [0, 10, 30]);
      expect(d.serie.first.hrv, 40.25);
      expect(d.serie[1].bpm, 74.2);
    });

    test('el detalle tolera una serie ausente', () {
      expect(SesionDetalle.fromJson(fila('a', '2026-10-13T15:30:00Z')).serie, isEmpty);
    });
  });

  group('Formato de fechas del Historial', () {
    final ahora = DateTime(2026, 10, 13, 18, 0);

    test('etiquetaDia: Hoy, Ayer, día de la semana y año si es otro', () {
      expect(etiquetaDia(DateTime(2026, 10, 13), ahora: ahora), 'Hoy');
      expect(etiquetaDia(DateTime(2026, 10, 12), ahora: ahora), 'Ayer');
      expect(etiquetaDia(DateTime(2026, 10, 9), ahora: ahora), 'vie 9 oct');
      expect(etiquetaDia(DateTime(2025, 12, 31), ahora: ahora), 'mié 31 dic 2025');
    });

    test('duracionCorta y minSeg', () {
      expect(duracionCorta(45), '45 s');
      expect(duracionCorta(180), '3 min');
      expect(duracionCorta(214), '3 min 34 s');
      expect(minSeg(0), '0:00');
      expect(minSeg(125), '2:05');
    });
  });

  group('agruparPorDia', () {
    test('agrupa por día local respetando el orden (más reciente primero)', () {
      final grupos = agruparPorDia([
        sesionLocal('h2', DateTime(2026, 10, 13, 20, 0)),
        sesionLocal('h1', DateTime(2026, 10, 13, 9, 30)),
        sesionLocal('a1', DateTime(2026, 10, 12, 23, 59)),
        sesionLocal('v1', DateTime(2026, 10, 9, 0, 1)),
      ]);
      expect(grupos.map((g) => g.dia).toList(), [
        DateTime(2026, 10, 13),
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 9),
      ]);
      expect(grupos.first.sesiones.map((s) => s.id).toList(), ['h2', 'h1']);
      expect(grupos[1].sesiones.single.id, 'a1');
    });

    test('lista vacía → sin grupos', () {
      expect(agruparPorDia(const []), isEmpty);
    });
  });

  group('HistorialSesionesProvider', () {
    final s1 = sesionLocal('s1', DateTime(2026, 10, 13, 9, 30));
    final s2 = sesionLocal('s2', DateTime(2026, 10, 12, 9, 30));

    test('con sesiones: listo y agrupadas', () async {
      final p = HistorialSesionesProvider(pacienteId: 'p', repo: RepoFalso(listas: [[s1, s2]]));
      expect(p.estado, EstadoHistorial.cargando);
      await p.cargar();
      expect(p.estado, EstadoHistorial.listo);
      expect(p.grupos.length, 2);
      expect(p.sinMediciones, isFalse);
    });

    test('lista vacía: sin mediciones, no error', () async {
      final p = HistorialSesionesProvider(pacienteId: 'p', repo: RepoFalso(listas: [<SesionResumen>[]]));
      await p.cargar();
      expect(p.estado, EstadoHistorial.listo);
      expect(p.sinMediciones, isTrue);
    });

    test('un error NUNCA se muestra como "sin mediciones"', () async {
      final p = HistorialSesionesProvider(pacienteId: 'p', repo: RepoFalso(listas: [RepositoryException('Sin conexión')]));
      await p.cargar();
      expect(p.estado, EstadoHistorial.error);
      expect(p.sinMediciones, isFalse);
      expect(p.errorMsg, 'Sin conexión');
    });

    test('si una recarga falla, conserva la lista ya cargada y avisa', () async {
      final p = HistorialSesionesProvider(
        pacienteId: 'p',
        repo: RepoFalso(listas: [[s1, s2], RepositoryException('Sin conexión')]),
      );
      await p.cargar();
      await p.cargar();
      expect(p.estado, EstadoHistorial.listo);
      expect(p.grupos.length, 2);
      expect(p.errorMsg, 'Sin conexión');
    });

    test('se recarga con el aviso de sesión guardada y deja de escucharlo al desecharse', () async {
      final aviso = ValueNotifier<int>(0);
      final repo = RepoFalso(listas: [[s2], [s1, s2]]);
      final p = HistorialSesionesProvider(pacienteId: 'p', repo: repo, aviso: aviso);
      await p.cargar();
      aviso.value++;
      await Future<void>.delayed(Duration.zero);
      expect(repo.llamadasLista, 2);
      expect(p.grupos.first.sesiones.first.id, 's1');

      p.dispose();
      aviso.value++; // ya no debe pedir otra vez
      await Future<void>.delayed(Duration.zero);
      expect(repo.llamadasLista, 2);
    });
  });

  group('SesionDetalleProvider', () {
    final detalle = SesionDetalle.fromJson({
      ...fila('d', '2026-10-13T15:30:00Z'),
      'serie': [
        {'t': 0, 'bpm': 73, 'spo2': 97, 'hrv': 40},
      ],
    });

    test('listo con el detalle', () async {
      final p = SesionDetalleProvider(pacienteId: 'p', sesionId: 'd', repo: RepoFalso(detalles: [detalle]));
      await p.cargar();
      expect(p.estado, EstadoDetalle.listo);
      expect(p.detalle, same(detalle));
    });

    test('404 → noEncontrada (distinto de un error de red)', () async {
      final p = SesionDetalleProvider(pacienteId: 'p', sesionId: 'x', repo: RepoFalso(detalles: [SesionNoEncontrada()]));
      await p.cargar();
      expect(p.estado, EstadoDetalle.noEncontrada);
      expect(p.errorMsg, 'Esta medición ya no está disponible.');
    });

    test('error de red → error, y reintentar con éxito lo resuelve', () async {
      final p = SesionDetalleProvider(
        pacienteId: 'p',
        sesionId: 'd',
        repo: RepoFalso(detalles: [RepositoryException('Sin conexión'), detalle]),
      );
      await p.cargar();
      expect(p.estado, EstadoDetalle.error);
      await p.cargar();
      expect(p.estado, EstadoDetalle.listo);
      expect(p.errorMsg, isNull);
    });
  });
}
