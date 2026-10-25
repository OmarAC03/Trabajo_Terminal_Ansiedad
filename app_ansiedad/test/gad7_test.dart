import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/models/gad7.dart';
import 'package:app_ansiedad/providers/cuestionario_gad7_provider.dart';
import 'package:app_ansiedad/repositories/gad7_repository.dart';

/// Repositorio falso: responde lo que se le indique y guarda lo enviado.
class Gad7Falso implements Gad7Repository {
  final List<Object> respuestasEnvio; // EnvioGad7 o una excepción, en orden
  Object estado; // EstadoGad7 o una excepción
  final List<RespuestaGad7> enviadas = [];

  Gad7Falso({List<Object>? envios, Object? estado})
      : respuestasEnvio = envios ?? [EnvioGad7.guardado],
        estado = estado ?? const EstadoGad7(toca: true, vinculado: true);

  @override
  Future<EstadoGad7> obtenerEstado(String pacienteId) async {
    final e = estado;
    if (e is Exception) throw e;
    return e as EstadoGad7;
  }

  @override
  Future<EnvioGad7> enviar(RespuestaGad7 respuesta) async {
    enviadas.add(respuesta);
    final r = respuestasEnvio.removeAt(0);
    if (r is Exception) throw r;
    return r as EnvioGad7;
  }
}

/// Responde las 7 preguntas con [valores], avanzando como lo hace la pantalla.
void responder(CuestionarioGad7Provider p, List<int> valores) {
  for (var i = 0; i < valores.length; i++) {
    p.elegir(valores[i]);
    p.siguienteDesde(i);
  }
}

void main() {
  group('EstadoGad7 (lista cerrada)', () {
    test('lee los campos del estado', () {
      final e = EstadoGad7.fromJson({
        'toca': false,
        'vinculado': true,
        'proxima_fecha': '2026-11-06',
        'dias_restantes': 14,
        'ultima_respuesta': '2026-10-23T18:00:00.000Z',
        'intervalo_dias': 14,
      });
      expect((e.toca, e.vinculado, e.proximaFecha, e.diasRestantes), (false, true, '2026-11-06', 14));
      expect(e.ultimaRespuesta, isNotNull);
    });

    test('ignora cualquier campo de más (no hay dónde guardar un puntaje)', () {
      final e = EstadoGad7.fromJson({'toca': true, 'vinculado': true, 'puntaje': 18, 'severidad': 'grave'});
      // El modelo no tiene esos campos: si llegaran, simplemente se pierden.
      expect((e.toca, e.vinculado), (true, true));
    });

    test('datos faltantes o raros → valores seguros (sin tarjeta)', () {
      final e = EstadoGad7.fromJson({});
      expect((e.toca, e.vinculado, e.proximaFecha, e.diasRestantes), (false, false, null, 0));
    });
  });

  group('mostrarTarjetaGad7', () {
    test('solo si se cargó, le toca y tiene especialista', () {
      expect(mostrarTarjetaGad7(null), isFalse);
      expect(mostrarTarjetaGad7(const EstadoGad7(toca: true, vinculado: false)), isFalse);
      expect(mostrarTarjetaGad7(const EstadoGad7(toca: false, vinculado: true)), isFalse);
      expect(mostrarTarjetaGad7(const EstadoGad7(toca: true, vinculado: true)), isTrue);
    });
  });

  group('RespuestaGad7', () {
    test('toJson lleva solo items y dificultad', () {
      final r = RespuestaGad7(items: [0, 1, 2, 3, 0, 1, 2], dificultad: 1);
      expect(r.toJson(), {'items': [0, 1, 2, 3, 0, 1, 2], 'dificultad': 1});
      expect(RespuestaGad7(items: [0, 0, 0, 0, 0, 0, 0]).toJson().keys, ['items', 'dificultad']);
    });

    test('rechaza 6 u 8 ítems, valores fuera de 0–3 y dificultad fuera de rango', () {
      expect(() => RespuestaGad7(items: [0, 1, 2, 3, 0, 1]), throwsArgumentError);
      expect(() => RespuestaGad7(items: [0, 1, 2, 3, 0, 1, 2, 3]), throwsArgumentError);
      expect(() => RespuestaGad7(items: [0, 1, 2, 4, 0, 1, 2]), throwsArgumentError);
      expect(() => RespuestaGad7(items: [0, 1, 2, -1, 0, 1, 2]), throwsArgumentError);
      expect(() => RespuestaGad7(items: [0, 0, 0, 0, 0, 0, 0], dificultad: 4), throwsArgumentError);
    });
  });

  group('CuestionarioGad7Provider', () {
    test('intro → 7 preguntas → dificultad → envío → gracias', () async {
      final repo = Gad7Falso();
      final p = CuestionarioGad7Provider(repo: repo);
      expect(p.fase, FaseGad7.intro);
      p.comenzar();
      expect((p.fase, p.indice), (FaseGad7.pregunta, 0));

      responder(p, [1, 0, 2, 1, 0, 3, 0]);
      expect(p.fase, FaseGad7.dificultad); // marcó algún problema

      p.elegirDificultad(2);
      await p.enviar();
      expect(p.fase, FaseGad7.gracias);
      expect(p.resultado, EnvioGad7.guardado);
      expect(repo.enviadas.single.toJson(), {'items': [1, 0, 2, 1, 0, 3, 0], 'dificultad': 2});
    });

    test('todo "De nada": se salta la dificultad y se envía con null', () async {
      final repo = Gad7Falso();
      final p = CuestionarioGad7Provider(repo: repo)..comenzar();
      responder(p, [0, 0, 0, 0, 0, 0, 0]);
      await pumpEventQueue();
      expect(p.fase, FaseGad7.gracias);
      expect(repo.enviadas.single.dificultad, isNull);
    });

    test('"Prefiero no responder esta" envía la dificultad en null', () async {
      final repo = Gad7Falso();
      final p = CuestionarioGad7Provider(repo: repo)..comenzar();
      responder(p, [1, 1, 1, 1, 1, 1, 1]);
      p.elegirDificultad(3);
      p.omitirDificultad();
      await pumpEventQueue();
      expect(repo.enviadas.single.dificultad, isNull);
    });

    test('Atrás conserva las respuestas y regresa de la dificultad a la pregunta 7', () {
      final p = CuestionarioGad7Provider(repo: Gad7Falso())..comenzar();
      responder(p, [2, 1]);
      expect(p.indice, 2);
      p.atras();
      expect((p.indice, p.respuestaDe(1)), (1, 1));
      p.atras();
      p.atras();
      expect(p.fase, FaseGad7.intro);

      p.comenzar();
      responder(p, [1, 1, 1, 1, 1, 1, 1]);
      expect(p.fase, FaseGad7.dificultad);
      p.atras();
      expect((p.fase, p.indice, p.respuestaDe(6)), (FaseGad7.pregunta, 6, 1));
    });

    test('un avance retrasado no salta preguntas si ya se movió (doble toque o Atrás)', () {
      final p = CuestionarioGad7Provider(repo: Gad7Falso())..comenzar();
      p.elegir(1);
      p.siguienteDesde(0);
      p.siguienteDesde(0); // el segundo toque llega tarde: no hace nada
      expect(p.indice, 1);
      p.elegir(2);
      p.atras(); // "Atrás" durante la pausa
      p.siguienteDesde(1); // el avance de la pregunta 2 ya no aplica
      expect(p.indice, 0);
    });

    test('no avanza sin respuesta ni envía incompleto', () async {
      final repo = Gad7Falso();
      final p = CuestionarioGad7Provider(repo: repo)..comenzar();
      p.siguienteDesde(0);
      expect(p.indice, 0);
      await p.enviar();
      expect(repo.enviadas, isEmpty);
      expect(p.fase, FaseGad7.pregunta);
    });

    test('409: también termina en gracias ("ya estaban guardadas")', () async {
      final p = CuestionarioGad7Provider(repo: Gad7Falso(envios: [EnvioGad7.yaRespondido]))..comenzar();
      responder(p, [0, 0, 0, 0, 0, 0, 0]);
      await pumpEventQueue();
      expect((p.fase, p.resultado), (FaseGad7.gracias, EnvioGad7.yaRespondido));
    });

    test('error de red → error; Reintentar con las mismas respuestas', () async {
      final repo = Gad7Falso(envios: [RepositoryException('Sin conexión'), EnvioGad7.guardado]);
      final p = CuestionarioGad7Provider(repo: repo)..comenzar();
      responder(p, [1, 2, 0, 0, 0, 0, 0]);
      p.elegirDificultad(1);
      await p.enviar();
      expect((p.fase, p.error), (FaseGad7.error, 'Sin conexión'));
      expect(p.tieneRespuestasSinGuardar, isTrue);

      await p.reintentar();
      expect(p.fase, FaseGad7.gracias);
      expect(repo.enviadas, hasLength(2));
      expect(repo.enviadas.map((r) => '${r.toJson()}').toSet(), hasLength(1)); // las mismas dos veces
    });

    test('salir pide confirmación solo con respuestas sin guardar', () async {
      final p = CuestionarioGad7Provider(repo: Gad7Falso());
      expect(p.tieneRespuestasSinGuardar, isFalse);
      p.comenzar();
      expect(p.tieneRespuestasSinGuardar, isFalse);
      p.elegir(1);
      expect(p.tieneRespuestasSinGuardar, isTrue);
      p.siguienteDesde(0);
      responderDesde(p, 1, [0, 0, 0, 0, 0, 0]);
      p.elegirDificultad(0);
      await p.enviar();
      expect(p.tieneRespuestasSinGuardar, isFalse); // ya se guardó
    });
  });
}

void responderDesde(CuestionarioGad7Provider p, int desde, List<int> valores) {
  for (var k = 0; k < valores.length; k++) {
    p.elegir(valores[k]);
    p.siguienteDesde(desde + k);
  }
}
