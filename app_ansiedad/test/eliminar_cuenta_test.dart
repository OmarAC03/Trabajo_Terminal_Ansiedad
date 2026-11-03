import 'package:app_ansiedad/models/solicitud_eliminacion.dart';
import 'package:app_ansiedad/providers/eliminar_cuenta_provider.dart';
import 'package:app_ansiedad/repositories/eliminacion_repository.dart';
import 'package:app_ansiedad/screens/eliminar_cuenta_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio falso: cada llamada responde lo siguiente de su lista
/// (una solicitud, null o una excepción) y cuenta los envíos.
class RepoFalso implements EliminacionRepository {
  final List<Object?> obtenciones;
  final List<Object?> envios;
  int vecesSolicitar = 0;
  RepoFalso({List<Object?>? obtenciones, List<Object?>? envios})
      : obtenciones = obtenciones ?? [null],
        envios = envios ?? [];

  @override
  Future<SolicitudEliminacion?> obtener() async {
    final r = obtenciones.removeAt(0);
    if (r is Exception) throw r;
    return r as SolicitudEliminacion?;
  }

  @override
  Future<SolicitudEliminacion?> solicitar() async {
    vecesSolicitar++;
    final r = envios.removeAt(0);
    if (r is Exception) throw r;
    return r as SolicitudEliminacion?;
  }
}

final pendiente = SolicitudEliminacion(estado: 'pendiente', fechaSolicitud: DateTime(2026, 11, 3, 10));
final atendida = SolicitudEliminacion(estado: 'atendida', fechaSolicitud: DateTime(2026, 10, 1, 10));

void main() {
  group('SolicitudEliminacion.fromJson', () {
    test('lee la solicitud del backend', () {
      final s = SolicitudEliminacion.fromJson({
        'estado': 'pendiente',
        'fecha_solicitud': '2026-11-03T16:00:00.000Z',
        'atendida_en': null,
      });
      expect(s, isNotNull);
      expect(s!.pendiente, isTrue);
    });

    test('null o JSON incompleto → sin solicitud', () {
      expect(SolicitudEliminacion.fromJson(null), isNull);
      expect(SolicitudEliminacion.fromJson({'estado': 'pendiente'}), isNull);
      expect(SolicitudEliminacion.fromJson({'fecha_solicitud': '2026-11-03T16:00:00Z'}), isNull);
      expect(SolicitudEliminacion.fromJson('pendiente'), isNull);
    });
  });

  group('EliminarCuentaProvider', () {
    test('sin solicitud: se puede enviar solo marcando "Entiendo"', () async {
      final repo = RepoFalso(envios: [pendiente]);
      final p = EliminarCuentaProvider(repo: repo);
      await p.cargar();
      expect(p.yaSolicitada, isFalse);
      expect(p.puedeEnviar, isFalse);
      expect(await p.solicitar(), isFalse);
      expect(repo.vecesSolicitar, 0);
      p.marcarEntiende(true);
      expect(p.puedeEnviar, isTrue);
    });

    test('enviar → queda pendiente y ya no se puede enviar otra', () async {
      final repo = RepoFalso(envios: [pendiente]);
      final p = EliminarCuentaProvider(repo: repo)..marcarEntiende(true);
      await p.cargar();
      expect(await p.solicitar(), isTrue);
      expect(p.yaSolicitada, isTrue);
      expect(p.puedeEnviar, isFalse);
      expect(repo.vecesSolicitar, 1);
    });

    test('con una pendiente al abrir: no se ofrece enviar (no se puede cancelar)', () async {
      final p = EliminarCuentaProvider(repo: RepoFalso(obtenciones: [pendiente]))..marcarEntiende(true);
      await p.cargar();
      expect(p.yaSolicitada, isTrue);
      expect(p.puedeEnviar, isFalse);
    });

    test('una atendida antigua no bloquea una nueva solicitud', () async {
      final p = EliminarCuentaProvider(repo: RepoFalso(obtenciones: [atendida]))..marcarEntiende(true);
      await p.cargar();
      expect(p.yaSolicitada, isFalse);
      expect(p.puedeEnviar, isTrue);
    });

    test('si el envío falla, muestra el error y se puede reintentar', () async {
      final repo = RepoFalso(envios: [RepositoryException('Sin conexión'), pendiente]);
      final p = EliminarCuentaProvider(repo: repo)..marcarEntiende(true);
      await p.cargar();
      expect(await p.solicitar(), isFalse);
      expect(p.error, 'Sin conexión');
      expect(p.puedeEnviar, isTrue);
      expect(await p.solicitar(), isTrue);
      expect(p.error, isNull);
    });

    test('si la consulta falla, muestra el error', () async {
      final p = EliminarCuentaProvider(repo: RepoFalso(obtenciones: [RepositoryException('Sin conexión')]));
      await p.cargar();
      expect(p.cargando, isFalse);
      expect(p.error, 'Sin conexión');
    });
  });

  test('los textos dicen qué se borra, qué se conserva y que no se puede cancelar', () {
    final borra = TextosEliminarCuenta.seBorra.join(' ');
    expect(borra, contains('mediciones'));
    expect(borra, contains('cuestionarios'));
    expect(borra, contains('mensajes'));
    expect(borra, contains('ya no podrás iniciar sesión'));
    expect(TextosEliminarCuenta.seConserva, contains('sin tu nombre ni tu correo'));
    expect(TextosEliminarCuenta.irreversible, contains('no se puede cancelar'));
  });
}
