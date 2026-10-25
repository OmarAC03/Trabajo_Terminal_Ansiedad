import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../contenido/gad7_textos.dart';
import '../models/gad7.dart';
import '../providers/cuestionario_gad7_provider.dart';
import '../repositories/gad7_repository.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

/// Cuestionario GAD-7 quincenal (Fase M5a): introducción → 7 preguntas (una
/// por pantalla, avanza sola al elegir) → dificultad (solo si marcó algún
/// problema) → envío → agradecimiento.
///
/// El paciente NUNCA ve su resultado: ni puntaje, ni severidad, ni "te fue
/// bien". El instrumento se muestra exacto (`TextosGad7`, en "usted"); los
/// textos de la app van en "tú". Devuelve `true` al cerrar si se guardó, para
/// que Inicio recargue y la tarjeta desaparezca.
class Gad7Screen extends StatelessWidget {
  final Gad7Repository? repo;
  const Gad7Screen({super.key, this.repo});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CuestionarioGad7Provider(repo: repo),
      child: const _Gad7View(),
    );
  }
}

class _Gad7View extends StatelessWidget {
  const _Gad7View();

  Future<void> _salir(BuildContext context, CuestionarioGad7Provider p) async {
    if (p.fase == FaseGad7.enviando) return;
    if (p.tieneRespuestasSinGuardar) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(TextosGad7.salirTitulo),
          content: const Text(TextosGad7.salirTexto),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quedarme')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (context.mounted) Navigator.of(context).pop(p.fase == FaseGad7.gracias);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CuestionarioGad7Provider>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir(context, p);
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoGradiente(
              icono: Icons.assignment_outlined,
              titulo: TextosGad7.titulo,
              subtitulo: 'Cómo te has sentido las últimas 2 semanas',
              accion: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Salir',
                onPressed: () => _salir(context, p),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: switch (p.fase) {
                  FaseGad7.intro => _Intro(p),
                  FaseGad7.pregunta => _Pregunta(p, key: ValueKey('pregunta-${p.indice}')),
                  FaseGad7.dificultad => _Dificultad(p),
                  FaseGad7.enviando => const _Enviando(),
                  FaseGad7.error => _Error(p),
                  FaseGad7.gracias => _Gracias(p, onListo: () => _salir(context, p)),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final CuestionarioGad7Provider p;
  const _Intro(this.p);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset('assets/mascota/mascota_reposo.png', height: 100),
        const SizedBox(height: 12),
        const Text(
          TextosGad7.introTitulo,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        const SizedBox(height: 16),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final punto in TextosGad7.introPuntos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline, size: 18, color: AppColors.primario),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(punto, style: const TextStyle(fontSize: 14, color: AppColors.texto, height: 1.35)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BotonPrimario(texto: TextosGad7.comenzar, onPressed: p.comenzar),
        const SizedBox(height: 16),
        const DisclaimerNota(disclaimerGad7),
      ],
    );
  }
}

/// Barra y "Pregunta X de 7". No muestra valores ni sumas.
class _Progreso extends StatelessWidget {
  final int actual; // 1–7
  const _Progreso(this.actual);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pregunta $actual de ${RespuestaGad7.numItems}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoAyuda),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: actual / RespuestaGad7.numItems,
            minHeight: 6,
            backgroundColor: AppColors.borde,
            color: AppColors.primario,
          ),
        ),
      ],
    );
  }
}

/// Una opción como tarjeta grande (sin el valor numérico).
class _Opcion extends StatelessWidget {
  final String texto;
  final bool marcada;
  final VoidCallback onTap;
  const _Opcion({required this.texto, required this.marcada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: marcada ? AppColors.primarioSuave : AppColors.superficie,
        borderRadius: BorderRadius.circular(AppColors.radio),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.radio),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radio),
              border: Border.all(color: marcada ? AppColors.primario : AppColors.borde, width: marcada ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  marcada ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: marcada ? AppColors.primario : AppColors.textoSecundario,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: marcada ? FontWeight.w600 : FontWeight.normal,
                      color: AppColors.texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pregunta extends StatelessWidget {
  final CuestionarioGad7Provider p;
  const _Pregunta(this.p, {super.key});

  static const Duration _pausaAntesDeAvanzar = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final i = p.indice;
    final marcada = p.respuestaDe(i);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Progreso(i + 1),
        const SizedBox(height: 18),
        const Text(TextosGad7.encabezado, style: TextStyle(fontSize: 13, color: AppColors.textoAyuda, height: 1.35)),
        const SizedBox(height: 10),
        Text(
          TextosGad7.items[i],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.texto, height: 1.3),
        ),
        const SizedBox(height: 18),
        for (final o in TextosGad7.opciones)
          _Opcion(
            texto: o.texto,
            marcada: marcada == o.valor,
            onTap: () {
              p.elegir(o.valor);
              // Avanza solo tras una pausa breve, para que se vea la opción
              // marcada. siguienteDesde no hace nada si la pantalla ya cambió.
              Future.delayed(_pausaAntesDeAvanzar, () => p.siguienteDesde(i));
            },
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: p.atras,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Atrás'),
          ),
        ),
      ],
    );
  }
}

class _Dificultad extends StatelessWidget {
  final CuestionarioGad7Provider p;
  const _Dificultad(this.p);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Última pregunta (opcional)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoAyuda),
        ),
        const SizedBox(height: 10),
        const Text(
          TextosGad7.preguntaDificultad,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.texto, height: 1.3),
        ),
        const SizedBox(height: 18),
        for (final o in TextosGad7.opcionesDificultad)
          _Opcion(texto: o.texto, marcada: p.dificultad == o.valor, onTap: () => p.elegirDificultad(o.valor)),
        const SizedBox(height: 10),
        BotonPrimario(
          texto: TextosGad7.enviar,
          icono: Icons.send,
          onPressed: p.dificultad == null ? null : p.enviar,
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: p.omitirDificultad, child: const Text(TextosGad7.omitirDificultad)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: p.atras,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Atrás'),
          ),
        ),
      ],
    );
  }
}

class _Enviando extends StatelessWidget {
  const _Enviando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.primario),
          SizedBox(height: 16),
          Text(TextosGad7.enviando, style: TextStyle(fontSize: 14, color: AppColors.textoAyuda)),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final CuestionarioGad7Provider p;
  const _Error(this.p);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Aviso.error(p.error ?? 'No se pudieron guardar tus respuestas.'),
        const SizedBox(height: 16),
        BotonPrimario(texto: 'Reintentar', icono: Icons.refresh, onPressed: p.reintentar),
      ],
    );
  }
}

/// Agradecimiento: SIN resultado. El mensaje de apoyo es el mismo para todos
/// (no depende de las respuestas, para no delatarlas).
class _Gracias extends StatelessWidget {
  final CuestionarioGad7Provider p;
  final VoidCallback onListo;
  const _Gracias(this.p, {required this.onListo});

  @override
  Widget build(BuildContext context) {
    final yaEstaba = p.resultado == EnvioGad7.yaRespondido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset('assets/mascota/mascota_celebrando.png', height: 120),
        const SizedBox(height: 12),
        const Text(
          TextosGad7.graciasTitulo,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.texto),
        ),
        const SizedBox(height: 8),
        Text(
          yaEstaba ? TextosGad7.yaGuardadoTexto : TextosGad7.graciasTexto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.textoAyuda, height: 1.35),
        ),
        const SizedBox(height: 20),
        const Aviso(
          TextosGad7.apoyo,
          icono: Icons.favorite_border,
          color: AppColors.primario,
          fondo: AppColors.primarioSuave,
        ),
        if (TextosGad7.apoyoLinea != null) ...[
          const SizedBox(height: 8),
          const Aviso(
            TextosGad7.apoyoLinea ?? '',
            icono: Icons.phone_outlined,
            color: AppColors.primario,
            fondo: AppColors.primarioSuave,
          ),
        ],
        const SizedBox(height: 20),
        BotonPrimario(texto: TextosGad7.listo, onPressed: onListo),
      ],
    );
  }
}
