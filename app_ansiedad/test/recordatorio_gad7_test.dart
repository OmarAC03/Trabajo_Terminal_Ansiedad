import 'package:app_ansiedad/models/gad7.dart';
import 'package:app_ansiedad/notificaciones/recordatorio_gad7.dart';
import 'package:flutter_test/flutter_test.dart';

class ProgramadorFalso implements ProgramadorRecordatorios {
  DateTime ahora;
  String? vence;
  final Map<int, DateTime> programados = {};
  final List<String> pasos = [];
  ProgramadorFalso(this.ahora, {this.vence});

  @override
  DateTime ahoraMexico() => ahora;
  @override
  Future<void> programar(int id, DateTime relojMexico) async {
    pasos.add('programar $id');
    programados[id] = relojMexico;
  }

  @override
  Future<void> cancelar(int id) async {
    pasos.add('cancelar $id');
    programados.remove(id);
  }

  @override
  Future<String?> leerVence() async => vence;
  @override
  Future<void> guardarVence(String? v) async => vence = v;
}

const proximo = EstadoGad7(toca: false, vinculado: true, proximaFecha: '2026-11-20', diasRestantes: 15);

void main() {
  final ahora = DateTime(2026, 11, 5, 18, 30);

  test('textos fijos y neutros', () {
    expect(tituloRecordatorio, 'Mi Ritmo');
    expect(textoRecordatorio, 'Ya puedes responder tu cuestionario quincenal');
  });

  test('sumarDias cruza meses y años', () {
    expect(sumarDias('2026-11-29', 3), '2026-12-02');
    expect(sumarDias('2026-12-31', 1), '2027-01-01');
  });

  test('aún no le toca: a las 10:00 del día que le toca y 3 días después', () {
    final plan = planGad7(estado: proximo, venceGuardado: null, ahora: ahora);
    expect(plan.vence, '2026-11-20');
    expect(plan.fechas, [DateTime(2026, 11, 20, 10), DateTime(2026, 11, 23, 10)]);
  });

  test('ya le toca hoy por primera vez, después de las 10:00: solo el segundo aviso', () {
    const hoy = EstadoGad7(toca: true, vinculado: true, proximaFecha: '2026-11-05');
    final plan = planGad7(estado: hoy, venceGuardado: null, ahora: ahora);
    expect(plan.vence, '2026-11-05');
    expect(plan.fechas, [DateTime(2026, 11, 8, 10)]);
  });

  test('sigue vencido: el backend manda proxima=hoy, pero se usa el vencimiento guardado', () {
    // Le tocó el 1 de noviembre; el backend responde proxima_fecha = hoy (5).
    const vencido = EstadoGad7(toca: true, vinculado: true, proximaFecha: '2026-11-05');
    final plan = planGad7(estado: vencido, venceGuardado: '2026-11-01', ahora: ahora);
    expect(plan.vence, '2026-11-01');
    expect(plan.fechas, isEmpty, reason: 'el segundo aviso (día 4) ya pasó: después, nada (D2)');
  });

  test('sin especialista o sin estado: nada programado', () {
    const sinVinculo = EstadoGad7(toca: true, vinculado: false, proximaFecha: '2026-11-05');
    expect(planGad7(estado: sinVinculo, venceGuardado: '2026-11-01', ahora: ahora).fechas, isEmpty);
    expect(planGad7(estado: null, venceGuardado: null, ahora: ahora).vence, isNull);
  });

  test('actualizar cancela lo anterior antes de programar, y guarda el vencimiento', () async {
    final p = ProgramadorFalso(ahora);
    await RecordatorioGad7(p).actualizar(proximo);
    expect(p.pasos, ['cancelar 7001', 'cancelar 7002', 'programar 7001', 'programar 7002']);
    expect(p.programados[7001], DateTime(2026, 11, 20, 10));
    expect(p.vence, '2026-11-20');
  });

  test('tras responder: el siguiente toca en 14 días', () async {
    final p = ProgramadorFalso(ahora, vence: '2026-11-01');
    await RecordatorioGad7(p).trasResponder();
    expect(p.programados[7001], DateTime(2026, 11, 19, 10));
    expect(p.programados[7002], DateTime(2026, 11, 22, 10));
    expect(p.vence, '2026-11-19');
  });

  test('cerrar sesión cancela todo y olvida el vencimiento', () async {
    final p = ProgramadorFalso(ahora);
    final r = RecordatorioGad7(p);
    await r.actualizar(proximo);
    await r.cancelarTodo();
    expect(p.programados, isEmpty);
    expect(p.vence, isNull);
  });

  test('un fallo del sistema no lanza', () async {
    await expectLater(RecordatorioGad7(_ProgramadorRoto()).actualizar(proximo), completes);
    await expectLater(RecordatorioGad7(_ProgramadorRoto()).cancelarTodo(), completes);
  });
}

class _ProgramadorRoto extends ProgramadorFalso {
  _ProgramadorRoto() : super(DateTime(2026, 11, 5));
  @override
  Future<void> cancelar(int id) async => throw Exception('sin plugin');
}
