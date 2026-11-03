import 'package:app_ansiedad/contenido/privacidad_textos.dart';
import 'package:app_ansiedad/models/consentimiento.dart';
import 'package:app_ansiedad/providers/consentimiento_provider.dart';
import 'package:app_ansiedad/repositories/consentimiento_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio falso: cada llamada responde lo siguiente de su lista
/// (un [EstadoConsentimiento] o una excepción) y cuenta las aceptaciones.
class RepoFalso implements ConsentimientoRepository {
  final List<Object> obtenciones;
  final List<Object> aceptaciones;
  int vecesAceptar = 0;
  RepoFalso({this.obtenciones = const [], this.aceptaciones = const []});

  @override
  Future<EstadoConsentimiento> obtener() async {
    final r = obtenciones.removeAt(0);
    if (r is Exception) throw r;
    return r as EstadoConsentimiento;
  }

  @override
  Future<EstadoConsentimiento> aceptar() async {
    vecesAceptar++;
    final r = aceptaciones.removeAt(0);
    if (r is Exception) throw r;
    return r as EstadoConsentimiento;
  }
}

const pendiente = EstadoConsentimiento(requerido: true, aceptado: false);
const aceptado = EstadoConsentimiento(requerido: true, aceptado: true);
const noRequerido = EstadoConsentimiento(requerido: false, aceptado: false);

void main() {
  group('EstadoConsentimiento.fromJson', () {
    test('lee la respuesta del backend', () {
      final c = EstadoConsentimiento.fromJson({
        'requerido': true,
        'version_aviso': 'privacidad-v0-borrador',
        'version_consentimiento': 'consentimiento-v0-borrador',
        'aceptado': true,
        'aceptado_en': '2026-11-03T18:00:00.000Z',
      });
      expect(c.requerido, isTrue);
      expect(c.aceptado, isTrue);
      expect(c.versionAviso, 'privacidad-v0-borrador');
      expect(c.puedeContinuar, isTrue);
    });

    test('si falta o viene mal, se pide de más (requerido y no aceptado)', () {
      final c = EstadoConsentimiento.fromJson({'requerido': 'si', 'aceptado': 1});
      expect(c.requerido, isTrue);
      expect(c.aceptado, isFalse);
      expect(c.puedeContinuar, isFalse);
      expect(EstadoConsentimiento.fromJson(const {}).puedeContinuar, isFalse);
    });

    test('quien no lo requiere (especialista, admin) continúa', () {
      expect(noRequerido.puedeContinuar, isTrue);
    });
  });

  group('ConsentimientoProvider (puerta)', () {
    test('paciente sin aceptar → pide consentimiento', () async {
      final p = ConsentimientoProvider(repo: RepoFalso(obtenciones: [pendiente]));
      await p.cargar();
      expect(p.estado, EstadoPuerta.pedirConsentimiento);
    });

    test('paciente que ya aceptó, o cuenta que no lo requiere → continúa', () async {
      for (final estado in [aceptado, noRequerido]) {
        final p = ConsentimientoProvider(repo: RepoFalso(obtenciones: [estado]));
        await p.cargar();
        expect(p.estado, EstadoPuerta.continuar);
      }
    });

    test('si falla la consulta NO deja pasar; Reintentar se recupera', () async {
      final p = ConsentimientoProvider(
        repo: RepoFalso(obtenciones: [RepositoryException('Sin conexión'), pendiente]),
      );
      await p.cargar();
      expect(p.estado, EstadoPuerta.error);
      expect(p.error, 'Sin conexión');
      await p.cargar();
      expect(p.estado, EstadoPuerta.pedirConsentimiento);
      expect(p.error, isNull);
    });

    test('"Aceptar" solo con las dos casillas', () async {
      final repo = RepoFalso(obtenciones: [pendiente], aceptaciones: [aceptado]);
      final p = ConsentimientoProvider(repo: repo);
      await p.cargar();
      expect(p.puedeAceptar, isFalse);
      p.marcarAviso(true);
      expect(p.puedeAceptar, isFalse);
      await p.aceptar(); // sin la segunda casilla no llama al backend
      expect(repo.vecesAceptar, 0);
      p.marcarConsentimiento(true);
      expect(p.puedeAceptar, isTrue);
    });

    test('aceptar con éxito → continúa a la app', () async {
      final repo = RepoFalso(obtenciones: [pendiente], aceptaciones: [aceptado]);
      final p = ConsentimientoProvider(repo: repo)
        ..marcarAviso(true)
        ..marcarConsentimiento(true);
      await p.cargar();
      await p.aceptar();
      expect(repo.vecesAceptar, 1);
      expect(p.estado, EstadoPuerta.continuar);
      expect(p.enviando, isFalse);
    });

    test('si aceptar falla, se queda en la pantalla con el error y puede reintentar', () async {
      final repo = RepoFalso(
        obtenciones: [pendiente],
        aceptaciones: [RepositoryException('Hay una versión nueva del aviso.'), aceptado],
      );
      final p = ConsentimientoProvider(repo: repo)
        ..marcarAviso(true)
        ..marcarConsentimiento(true);
      await p.cargar();
      await p.aceptar();
      expect(p.estado, EstadoPuerta.pedirConsentimiento);
      expect(p.error, contains('versión nueva'));
      expect(p.puedeAceptar, isTrue);
      await p.aceptar();
      expect(p.estado, EstadoPuerta.continuar);
    });
  });

  group('TextosPrivacidad (VERIFICAR: borrador)', () {
    test('las versiones son las mismas que en backend/consentimiento.js', () {
      expect(TextosPrivacidad.versionAviso, 'privacidad-v0-borrador');
      expect(TextosPrivacidad.versionConsentimiento, 'consentimiento-v0-borrador');
      expect(ConsentimientoRepository.versionesVigentes, {
        'version_aviso': 'privacidad-v0-borrador',
        'version_consentimiento': 'consentimiento-v0-borrador',
      });
    });

    test('mientras sea borrador, las versiones lo dicen (no se publica un provisional como final)', () {
      if (TextosPrivacidad.esBorrador) {
        expect(TextosPrivacidad.versionAviso, contains('borrador'));
        expect(TextosPrivacidad.versionConsentimiento, contains('borrador'));
      } else {
        expect(TextosPrivacidad.versionAviso, isNot(contains('borrador')));
        expect(TextosPrivacidad.versionConsentimiento, isNot(contains('borrador')));
        expect([...TextosPrivacidad.aviso, ...TextosPrivacidad.consentimiento].join(), isNot(contains('VERIFICAR')));
      }
    });

    test('el aviso dice que no es un diagnóstico y menciona la eliminación de la cuenta', () {
      final todo = [...TextosPrivacidad.aviso, ...TextosPrivacidad.consentimiento].join(' ');
      expect(todo, contains('no emite diagnósticos'));
      expect(todo, contains('eliminación de tu cuenta'));
      expect(todo, contains('datos personales sensibles'));
    });
  });
}
