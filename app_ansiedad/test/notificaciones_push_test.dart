import 'dart:async';
import 'package:app_ansiedad/notificaciones/servicio_push.dart';
import 'package:app_ansiedad/repositories/dispositivos_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registro de lo que pasó, en orden, para revisar la secuencia del cierre.
final List<String> bitacora = [];

class FuenteFalsa implements FuentePush {
  PermisoNotificaciones estado;
  PermisoNotificaciones alPedir;
  String? token;
  bool fallaToken = false;
  int vecesPedido = 0;
  final _renovados = StreamController<String>.broadcast();

  FuenteFalsa({this.estado = PermisoNotificaciones.concedido, this.alPedir = PermisoNotificaciones.concedido, this.token = 'tok-1'});

  void renovar(String nuevo) => _renovados.add(nuevo);

  @override
  Future<PermisoNotificaciones> estadoPermiso() async => estado;
  @override
  Future<PermisoNotificaciones> pedirPermiso() async {
    vecesPedido++;
    estado = alPedir;
    return alPedir;
  }

  @override
  Future<String?> obtenerToken() async {
    if (fallaToken) throw Exception('sin Play Services');
    return token;
  }

  @override
  Stream<String> get tokenRenovado => _renovados.stream;
  @override
  Future<void> borrarToken() async => bitacora.add('fcm.deleteToken');
  @override
  Future<String?> tipoDeArranque() async => null;
  @override
  Stream<String> get tiposAbiertos => const Stream.empty();
  @override
  Stream<void> get enPrimerPlano => const Stream.empty();
}

class RepoFalso implements DispositivosRepository {
  final List<String> registrados = [];
  final List<String> borrados = [];
  bool falla = false;

  @override
  Future<void> registrar(String token) async {
    if (falla) throw RepositoryException('sin red');
    registrados.add(token);
  }

  @override
  Future<void> borrar(String token) async {
    bitacora.add('backend.borrar($token)');
    if (falla) throw RepositoryException('sin red');
    borrados.add(token);
  }
}

class PrefsFalsas implements PreferenciasPush {
  bool pregunto;
  PrefsFalsas({this.pregunto = false});
  @override
  Future<bool> yaPregunto() async => pregunto;
  @override
  Future<void> marcarPregunto() async => pregunto = true;
}

ServicioPush servicio(FuenteFalsa f, RepoFalso r, [PrefsFalsas? p]) =>
    ServicioPush(fuente: f, repo: r, prefs: p ?? PrefsFalsas());

void main() {
  setUp(bitacora.clear);

  test('pestaña de cada tipo (D8)', () {
    expect(pestanaParaTipo('mensaje'), 2);
    expect(pestanaParaTipo('ejercicio'), 3);
    expect(pestanaParaTipo('gad7'), 0);
    expect(pestanaParaTipo('otro'), isNull);
    expect(pestanaParaTipo(null), isNull);
  });

  test('con permiso registra el token, y también cada token renovado', () async {
    final f = FuenteFalsa();
    final r = RepoFalso();
    final s = servicio(f, r);
    await s.registrar();
    expect(r.registrados, ['tok-1']);
    f.renovar('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(r.registrados, ['tok-1', 'tok-2']);
    // Llamarlo otra vez no duplica la escucha de renovaciones.
    await s.registrar();
    f.renovar('tok-3');
    await Future<void>.delayed(Duration.zero);
    expect(r.registrados.where((t) => t == 'tok-3').length, 1);
  });

  test('sin permiso no registra nada', () async {
    final r = RepoFalso();
    await servicio(FuenteFalsa(estado: PermisoNotificaciones.denegado), r).registrar();
    expect(r.registrados, isEmpty);
  });

  test('un fallo de red o de FCM no lanza (se reintenta al volver a abrir)', () async {
    final r = RepoFalso()..falla = true;
    await expectLater(servicio(FuenteFalsa(), r).registrar(), completes);
    final f = FuenteFalsa()..fallaToken = true;
    await expectLater(servicio(f, RepoFalso()).registrar(), completes);
  });

  test('la explicación se muestra una sola vez y solo sin permiso', () async {
    final prefs = PrefsFalsas();
    final f = FuenteFalsa(estado: PermisoNotificaciones.denegado, alPedir: PermisoNotificaciones.denegado);
    final s = servicio(f, RepoFalso(), prefs);
    expect(await s.debePreguntar(), isTrue);
    await s.posponer();
    expect(await s.debePreguntar(), isFalse);
    expect(await servicio(FuenteFalsa(), RepoFalso()).debePreguntar(), isFalse);
  });

  test('aceptar el permiso lo pide al sistema y registra el token', () async {
    final f = FuenteFalsa(estado: PermisoNotificaciones.denegado, alPedir: PermisoNotificaciones.concedido);
    final r = RepoFalso();
    final prefs = PrefsFalsas();
    expect(await servicio(f, r, prefs).pedirPermiso(), PermisoNotificaciones.concedido);
    expect(f.vecesPedido, 1);
    expect(prefs.pregunto, isTrue);
    expect(r.registrados, ['tok-1']);
  });

  test('cerrar sesión: primero se borra en el backend y después en FCM', () async {
    final r = RepoFalso();
    await servicio(FuenteFalsa(), r).cerrarSesion();
    expect(bitacora, ['backend.borrar(tok-1)', 'fcm.deleteToken']);
    expect(r.borrados, ['tok-1']);
  });

  test('cerrar sesión sin red: igual invalida el token local y no lanza', () async {
    final r = RepoFalso()..falla = true;
    await expectLater(servicio(FuenteFalsa(), r).cerrarSesion(), completes);
    expect(bitacora, ['backend.borrar(tok-1)', 'fcm.deleteToken']);
  });

  test('cuenta bloqueada: no llama al backend (ya borró los tokens), solo invalida el local', () async {
    final r = RepoFalso();
    await servicio(FuenteFalsa(), r).limpiarPorBloqueo();
    expect(bitacora, ['fcm.deleteToken']);
    expect(r.borrados, isEmpty);
  });
}
