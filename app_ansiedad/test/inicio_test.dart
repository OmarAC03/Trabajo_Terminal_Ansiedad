import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/contenido/textos_educativos.dart';
import 'package:app_ansiedad/medicion/aviso_sesiones.dart';
import 'package:app_ansiedad/models/calibracion.dart';
import 'package:app_ansiedad/models/eva_respuesta.dart';
import 'package:app_ansiedad/models/sesion_detalle.dart';
import 'package:app_ansiedad/models/sesion_medicion.dart';
import 'package:app_ansiedad/models/sesion_resumen.dart';
import 'package:app_ansiedad/providers/inicio_provider.dart';
import 'package:app_ansiedad/repositories/sesion_repository.dart';
import 'package:app_ansiedad/ui/formato_fecha.dart';

/// Fila tal como la manda el backend al paciente: numeric como texto.
Map<String, dynamic> filaBackend({String spo2 = '97.4'}) => {
      'id': 'b2f1c7a0-0000-4000-8000-000000000001',
      'fecha_inicio': '2026-10-13T15:30:00.000Z',
      'fecha_registro': '2026-10-13T15:34:10.000Z',
      'duracion_total_seg': 214,
      'duracion_valida_seg': 180,
      'hrv_rmssd': '42.46',
      'hrv_min': '38.50',
      'hrv_max': '49.10',
      'bpm_promedio': '73.2',
      'bpm_min': 70,
      'bpm_max': 76,
      'spo2_promedio': spo2,
      'spo2_min': 96,
      'spo2_max': 99,
      'origen': 'simulacion',
    };

/// Repositorio falso: responde lo que se le indique en cada llamada.
class RepoFalso implements SesionRepository {
  final List<Object?> respuestas; // SesionResumen, null o una excepción

  /// Lo que responde la línea base: un mapa o una excepción (por defecto, vacío).
  final Object calibraciones;
  RepoFalso(this.respuestas, {this.calibraciones = const <String, Calibracion>{}});

  @override
  Future<Map<String, Calibracion>> obtenerCalibraciones(String pacienteId) async {
    final r = calibraciones;
    if (r is Exception) throw r;
    return r as Map<String, Calibracion>;
  }

  @override
  Future<SesionResumen?> obtenerUltimaSesion(String pacienteId) async {
    final r = respuestas.removeAt(0);
    if (r is Exception) throw r;
    return r as SesionResumen?;
  }

  @override
  Future<SesionGuardada> enviarSesion(SesionMedicion sesion) => throw UnimplementedError();

  @override
  Future<void> enviarEva(String sesionId, EvaRespuesta eva) => throw UnimplementedError();

  @override
  Future<List<SesionResumen>> obtenerSesiones(String pacienteId, {int limite = 200}) =>
      throw UnimplementedError();

  @override
  Future<SesionDetalle> obtenerDetalle(String pacienteId, String sesionId) => throw UnimplementedError();
}

void main() {
  group('SesionResumen.fromJson', () {
    test('convierte los numeric que llegan como texto', () {
      final s = SesionResumen.fromJson(filaBackend());
      expect(s.hrvRmssd, 42.46);
      expect(s.bpmPromedio, 73.2);
      expect(s.spo2Promedio, 97.4);
    });

    test('acepta también números y pasa la fecha a hora local', () {
      final s = SesionResumen.fromJson({...filaBackend(), 'hrv_rmssd': 42.46, 'bpm_promedio': 73});
      expect(s.hrvRmssd, 42.46);
      expect(s.bpmPromedio, 73.0);
      expect(s.fechaInicio.isUtc, isFalse);
      expect(s.fechaInicio.toUtc(), DateTime.utc(2026, 10, 13, 15, 30));
    });
  });

  group('fechaRelativa', () {
    final ahora = DateTime(2026, 10, 13, 18, 0); // martes

    test('hoy, ayer y otro día', () {
      expect(fechaRelativa(DateTime(2026, 10, 13, 9, 30), ahora: ahora), 'hoy 9:30');
      expect(fechaRelativa(DateTime(2026, 10, 12, 20, 5), ahora: ahora), 'ayer 20:05');
      expect(fechaRelativa(DateTime(2026, 10, 10, 7, 0), ahora: ahora), 'sáb 10 oct, 7:00');
    });

    test('ayer funciona en cambio de mes', () {
      expect(fechaRelativa(DateTime(2026, 9, 30, 8, 15), ahora: DateTime(2026, 10, 1, 10, 0)), 'ayer 8:15');
    });
  });

  group('InicioProvider', () {
    final sesion = SesionResumen.fromJson(filaBackend());

    test('con sesión: listo y con la última sesión', () async {
      final p = InicioProvider(pacienteId: 'p', repo: RepoFalso([sesion]));
      expect(p.estado, EstadoInicio.cargando);
      await p.cargar();
      expect(p.estado, EstadoInicio.listo);
      expect(p.ultima, same(sesion));
      expect(p.sinMediciones, isFalse);
    });

    test('lista vacía: primer uso (sin mediciones), no error', () async {
      final p = InicioProvider(pacienteId: 'p', repo: RepoFalso([null]));
      await p.cargar();
      expect(p.estado, EstadoInicio.listo);
      expect(p.sinMediciones, isTrue);
    });

    test('M3: carga la calibración por origen junto con la última sesión', () async {
      final cal = Calibracion.fromJson({'origen': 'simulacion', 'etapa': 'preliminar', 'dia_calibracion': 5});
      final p = InicioProvider(pacienteId: 'p', repo: RepoFalso([sesion], calibraciones: {'simulacion': cal}));
      await p.cargar();
      expect(p.calibracionDe('simulacion'), same(cal));
      expect(p.calibracionDe('sensor'), isNull);
    });

    test('M3: si la línea base falla, Inicio sigue listo y sin error', () async {
      final p = InicioProvider(
        pacienteId: 'p',
        repo: RepoFalso([sesion], calibraciones: RepositoryException('Sin conexión')),
      );
      await p.cargar();
      expect(p.estado, EstadoInicio.listo);
      expect(p.errorMsg, isNull);
      expect(p.calibracionDe('simulacion'), isNull);
    });

    test('un error NUNCA se muestra como primer uso', () async {
      final p = InicioProvider(pacienteId: 'p', repo: RepoFalso([RepositoryException('Sin conexión')]));
      await p.cargar();
      expect(p.estado, EstadoInicio.error);
      expect(p.sinMediciones, isFalse);
      expect(p.errorMsg, 'Sin conexión');
    });

    test('si una recarga falla, conserva la sesión ya cargada y avisa', () async {
      final p = InicioProvider(pacienteId: 'p', repo: RepoFalso([sesion, RepositoryException('Sin conexión')]));
      await p.cargar();
      await p.cargar();
      expect(p.estado, EstadoInicio.listo);
      expect(p.ultima, same(sesion));
      expect(p.errorMsg, 'Sin conexión');
    });

    test('tras un error, reintentar con éxito limpia el error', () async {
      final p = InicioProvider(pacienteId: 'p', repo: RepoFalso([RepositoryException('x'), sesion]));
      await p.cargar();
      await p.cargar();
      expect(p.estado, EstadoInicio.listo);
      expect(p.errorMsg, isNull);
    });

    test('se recarga sola cuando se guarda una sesión nueva', () async {
      final nueva = SesionResumen.fromJson({...filaBackend(), 'id': 'nueva'});
      final p = InicioProvider(pacienteId: 'p', repo: RepoFalso([sesion, nueva]), aviso: AvisoSesiones.guardadas);
      await p.cargar();
      AvisoSesiones.notificarGuardada();
      await Future<void>.delayed(Duration.zero);
      expect(p.ultima?.id, 'nueva');
      p.dispose();
    });

    test('aviso de SpO2 solo por debajo de 94 % (regla §2.3)', () async {
      final bajo = InicioProvider(pacienteId: 'p', repo: RepoFalso([SesionResumen.fromJson(filaBackend(spo2: '93.6'))]));
      final limite = InicioProvider(pacienteId: 'p', repo: RepoFalso([SesionResumen.fromJson(filaBackend(spo2: '94.0'))]));
      final vacio = InicioProvider(pacienteId: 'p', repo: RepoFalso([null]));
      await bajo.cargar();
      await limite.cargar();
      await vacio.cargar();
      expect(bajo.spo2Bajo, isTrue);
      expect(limite.spo2Bajo, isFalse);
      expect(vacio.spo2Bajo, isFalse);
    });
  });

  test('textos: indicadores en orden HRV > FC > SpO2 y tres consejos', () {
    expect(TextosEducativos.indicadores.map((i) => i.nombre).toList(),
        ['Variabilidad (HRV)', 'Frecuencia cardiaca', 'Oxígeno (SpO2)']);
    expect(TextosEducativos.consejos.length, 3);
  });
}
