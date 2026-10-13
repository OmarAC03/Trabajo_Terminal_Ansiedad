import 'package:flutter/material.dart';
import '../contenido/textos_educativos.dart';
import 'app_colors.dart';

/// Fila a todo el ancho: nombre + resumen a la izquierda, valor a la derecha;
/// al tocarla se despliega la explicación del indicador. La usan Inicio (última
/// sesión) y el detalle de una sesión del Historial.
class FilaIndicador extends StatefulWidget {
  final InfoIndicador info;
  final IconData icono;
  final Color color;
  final String? valor;
  final bool cargando;

  /// Reemplaza al resumen del indicador bajo el nombre (p. ej. "Mín 70 · Máx 76").
  final String? subtitulo;

  const FilaIndicador({
    super.key,
    required this.info,
    required this.icono,
    required this.color,
    required this.valor,
    this.cargando = false,
    this.subtitulo,
  });

  @override
  State<FilaIndicador> createState() => _FilaIndicadorState();
}

class _FilaIndicadorState extends State<FilaIndicador> {
  bool _abierta = false;

  Widget _valor() {
    if (widget.valor != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(widget.valor!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.texto)),
          const SizedBox(width: 3),
          Text(widget.info.unidad, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ],
      );
    }
    if (widget.cargando) {
      return Container(
        width: 44,
        height: 18,
        decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(6)),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _abierta = !_abierta),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icono, size: 18, color: widget.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.info.nombre,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.texto),
                      ),
                      Text(widget.subtitulo ?? widget.info.resumen, style: const TextStyle(fontSize: 12, color: AppColors.textoAyuda)),
                    ],
                  ),
                ),
                _valor(),
                AnimatedRotation(
                  turns: _abierta ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, color: AppColors.textoSecundario),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _abierta
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(46, 10, 8, 2),
                      child: Text(
                        widget.info.explicacion,
                        style: const TextStyle(fontSize: 13, color: AppColors.textoAyuda, height: 1.4),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
