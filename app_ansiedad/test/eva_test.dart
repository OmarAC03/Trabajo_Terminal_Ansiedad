import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/app_config.dart';
import 'package:app_ansiedad/models/calibracion.dart';
import 'package:app_ansiedad/models/eva_respuesta.dart';
import 'package:app_ansiedad/models/lectura_cruda.dart';
import 'package:app_ansiedad/models/sesion_detalle.dart';
import 'package:app_ansiedad/models/sesion_medicion.dart';
import 'package:app_ansiedad/models/sesion_resumen.dart';
import 'package:app_ansiedad/providers/medicion_provider.dart';
import 'package:app_ansiedad/repositories/sesion_repository.dart';
import 'package:app_ansiedad/screens/medicion_screen.dart' show etiquetaEva;

/// Repositorio falso. Cada envío de sesión consume la siguiente respuesta de
/// su cola: un id, un Completer (para decidir cuándo "llega" el id) o una
/// excepción. Las EVA igual: null = guardada, o una excepción.
class RepoFalso implements SesionRepository {
  final List<Object> sesiones;
  final List<Object?> evas;
  final enviadas = <(String, EvaRespuesta)>[];

  RepoFalso({required this.sesiones, this.evas = const []});

  late final _sesiones = [...sesiones];
  late final _evas = [...evas];

  @override
  Future<SesionGuardada> enviarSesion(SesionMedicion sesion) async {
    final r = _sesiones.removeAt(0);
    if (r is Exception) throw r;
    if (r is Completer<String>) return SesionGuardada(id: await r.future);
    if (r is SesionGuardada) return r;
    return SesionGuardada(id: r as String);
  }

  @override
  Future<void> enviarEva(String sesionId, EvaRespuesta eva) async {
    final r = _evas.isEmpty ? null : _evas.removeAt(0);
    if (r is Exception) throw r;
    enviadas.add((sesionId, eva));
  }

  @override
  Future<List<SesionResumen>> obtenerSesiones(String pacienteId, {int limite = 200}) => throw UnimplementedError();

  @override
  Future<SesionResumen?> obtenerUltimaSesion(String pacienteId) => throw UnimplementedError();

  @override
  Future<SesionDetalle> obtenerDetalle(String pacienteId, String sesionId) => throw UnimplementedError();

  @override
  Future<Map<String, Calibracion>> obtenerCalibraciones(String pacienteId) => throw UnimplementedError();
}

/// Lleva una medición hasta "completada" con lecturas válidas (sin esperar
/// 3 min reales) y devuelve el provider. La sesión ya se está enviando.
Future<MedicionProvider> medicionCompleta(RepoFalso repo) async {
  final fuente = StreamController<LecturaCruda>.broadcast(sync: true);
  final p = MedicionProvider(
    fuente: fuente.stream,
    origen: OrigenSesion.simulacion,
    repo: repo,
    pantallaEncendida: (_) async {},
  );
  p.comenzar();
  for (var i = 0; i < ConfigMedicion.objetivoValidoSeg; i++) {
    fuente.add(LecturaCruda(bpm: 75, spo2: 97, hrv: 0, rr: [i.isEven ? 800 : 820]));
  }
  await Future<void>.delayed(Duration.zero);
  expect(p.fase, FaseMedicion.completada);
  return p;
}

Future<void> esperar() => Future<void>.delayed(Duration.zero);

void main() {
  group('EvaRespuesta', () {
    test('toJson sin contexto: solo valor (lista cerrada)', () {
      expect(EvaRespuesta(valor: 63).toJson(), {'valor': 63});
    });

    test('toJson con contexto: el valor interno que acepta el backend', () {
      expect(
        EvaRespuesta(valor: 63, contexto: ContextoEva.antesExamen).toJson(),
        {'valor': 63, 'contexto': 'antes_examen'},
      );
    });

    test('los contextos coinciden con la lista cerrada del backend (chk_eva_contexto)', () {
      expect(ContextoEva.values.map((c) => c.valor).toList(),
          ['reposo', 'estudiando', 'antes_examen', 'despues_estresor', 'otro']);
    });

    test('desde el deslizador: 0–1 → entero 0–100, sin salirse del rango', () {
      expect(EvaRespuesta.desdeDeslizador(0.634).valor, 63);
      expect(EvaRespuesta.desdeDeslizador(0).valor, 0);
      expect(EvaRespuesta.desdeDeslizador(1).valor, 100);
      expect(EvaRespuesta.desdeDeslizador(1.2).valor, 100);
    });

    test('etiqueta en vivo del deslizador: descriptiva, por tramos, sin números', () {
      expect(etiquetaEva(0), 'Nada');
      expect(etiquetaEva(0.04), 'Nada');
      expect(etiquetaEva(0.05), 'Un poco');
      expect(etiquetaEva(0.29), 'Un poco');
      expect(etiquetaEva(0.30), 'Algo');
      expect(etiquetaEva(0.54), 'Algo');
      expect(etiquetaEva(0.55), 'Bastante');
      expect(etiquetaEva(0.79), 'Bastante');
      expect(etiquetaEva(0.80), 'Mucha');
      expect(etiquetaEva(1), 'Mucha');
    });
  });

  group('EVA en MedicionProvider', () {
    test('respondida antes de que llegue el id: espera en memoria y se manda al llegar', () async {
      final idSesion = Completer<String>();
      final repo = RepoFalso(sesiones: [idSesion]);
      final p = await medicionCompleta(repo);
      expect(p.estadoEnvio, EstadoEnvio.enviando);

      p.responderEva(EvaRespuesta(valor: 63, contexto: ContextoEva.reposo));
      expect(p.estadoEva, EstadoEva.esperandoSesion);
      expect(repo.enviadas, isEmpty);
      expect(p.puedeSalirSinConfirmar, isFalse);

      idSesion.complete('id-1');
      await esperar();
      expect(repo.enviadas.single.$1, 'id-1');
      expect(repo.enviadas.single.$2.valor, 63);
      expect(p.estadoEva, EstadoEva.guardada);
      expect(p.puedeTerminar, isTrue);
      p.dispose();
    });

    test('con la sesión ya guardada, la EVA se manda de inmediato', () async {
      final repo = RepoFalso(sesiones: ['id-2']);
      final p = await medicionCompleta(repo);
      expect(p.estadoEnvio, EstadoEnvio.enviada);
      expect(p.puedeTerminar, isFalse); // falta guardar u omitir la EVA

      p.responderEva(EvaRespuesta(valor: 20));
      await esperar();
      expect(repo.enviadas.single.$1, 'id-2');
      expect(p.estadoEva, EstadoEva.guardada);
      expect(p.puedeTerminar, isTrue);
      p.dispose();
    });

    test('omitir no envía nada y habilita "Listo"', () async {
      final repo = RepoFalso(sesiones: ['id-3']);
      final p = await medicionCompleta(repo);
      p.omitirEva();
      await esperar();
      expect(repo.enviadas, isEmpty);
      expect(p.estadoEva, EstadoEva.omitida);
      expect(p.puedeTerminar, isTrue);
      expect(p.puedeSalirSinConfirmar, isTrue);
      p.dispose();
    });

    test('si la sesión falla, la EVA sigue esperando y se manda cuando el reintento de la sesión funciona', () async {
      final repo = RepoFalso(sesiones: [RepositoryException('Sin conexión'), 'id-4']);
      final p = await medicionCompleta(repo);
      expect(p.estadoEnvio, EstadoEnvio.error);

      p.responderEva(EvaRespuesta(valor: 80));
      expect(p.estadoEva, EstadoEva.esperandoSesion);

      await p.enviar(); // "Reintentar envío" de la sesión
      await esperar();
      expect(repo.enviadas.single.$1, 'id-4');
      expect(p.estadoEva, EstadoEva.guardada);
      p.dispose();
    });

    test('error al guardar la EVA: "Reintentar" la guarda; o se puede continuar sin guardarla', () async {
      final repo = RepoFalso(sesiones: ['id-5'], evas: [RepositoryException('Sin conexión'), null]);
      final p = await medicionCompleta(repo);
      p.responderEva(EvaRespuesta(valor: 50));
      await esperar();
      expect(p.estadoEva, EstadoEva.error);
      expect(p.errorEva, 'Sin conexión');
      expect(p.puedeTerminar, isFalse);

      p.reintentarEva();
      await esperar();
      expect(p.estadoEva, EstadoEva.guardada);
      expect(repo.enviadas.single.$2.valor, 50);
      p.dispose();

      final repo2 = RepoFalso(sesiones: ['id-6'], evas: [RepositoryException('Sin conexión')]);
      final p2 = await medicionCompleta(repo2);
      p2.responderEva(EvaRespuesta(valor: 50));
      await esperar();
      p2.omitirEva();
      expect(p2.estadoEva, EstadoEva.omitida);
      expect(p2.puedeTerminar, isTrue);
      p2.dispose();
    });

    test('M3: guarda la etapa y la calibración que devuelve el backend al subir la sesión', () async {
      final guardada = SesionGuardada.fromData({
        'id': 's1',
        'evaluacion': {'etapa': 'preliminar', 'motivo_sin_estado': null},
        'calibracion': {'origen': 'simulacion', 'etapa': 'preliminar', 'dia_calibracion': 4, 'medido_hoy': true},
      });
      final p = await medicionCompleta(RepoFalso(sesiones: [guardada]));
      await esperar();
      expect(p.estadoEnvio, EstadoEnvio.enviada);
      expect(p.evaluacion!.etapa, EtapaBase.preliminar);
      expect(p.calibracion!.diaCalibracion, 4);
    });

    test('una vez respondida no se puede responder otra vez (no editable)', () async {
      final repo = RepoFalso(sesiones: ['id-7']);
      final p = await medicionCompleta(repo);
      p.responderEva(EvaRespuesta(valor: 10));
      await esperar();
      p.responderEva(EvaRespuesta(valor: 90));
      await esperar();
      expect(repo.enviadas.length, 1);
      expect(repo.enviadas.single.$2.valor, 10);
      p.dispose();
    });
  });
}
