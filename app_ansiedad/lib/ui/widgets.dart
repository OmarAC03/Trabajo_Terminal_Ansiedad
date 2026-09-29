import 'package:flutter/material.dart';
import '../app_config.dart';
import 'app_colors.dart';

/// Componentes visuales compartidos (equivalente a `web_portal/src/ui/components.js`).
/// Solo apariencia: no guardan estado ni tocan datos.

/// Encabezado con gradiente azul (GUIA_ESTILO_APP.md, sección 2): ícono en
/// cuadro translúcido, título blanco en negrita y subtítulo al 70 %.
/// [inferior] permite colgar contenido extra dentro del gradiente.
class EncabezadoGradiente extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final Widget? inferior;

  const EncabezadoGradiente({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.accion,
    this.inferior,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.gradienteEncabezado,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icono, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        if (subtitulo != null)
                          Text(
                            subtitulo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  ?accion,
                ],
              ),
              if (inferior != null) ...[
                const SizedBox(height: 16),
                inferior!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// AppBar con el mismo gradiente, para pantallas que se abren encima de las
/// pestañas (con flecha de regreso).
AppBar appBarGradiente(String titulo, {List<Widget>? acciones}) {
  return AppBar(
    title: Text(titulo),
    actions: acciones,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.gradienteEncabezado)),
  );
}

/// Tarjeta blanca con borde y sombra sutil.
class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const Tarjeta({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.superficie,
        borderRadius: BorderRadius.circular(AppColors.radio),
        border: Border.all(color: AppColors.borde),
        boxShadow: AppColors.sombra,
      ),
      child: child,
    );
  }
}

/// Etiqueta gris, pequeña, en mayúsculas con espaciado (títulos de sección y
/// de métricas).
class EtiquetaSeccion extends StatelessWidget {
  final String texto;
  const EtiquetaSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textoSecundario,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Tarjeta de métrica (BPM / SpO2 / HRV): etiqueta arriba, valor grande en
/// negrita máxima y unidad gris abajo.
class TarjetaMetrica extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String unidad;
  final Color color;
  final IconData? icono;

  const TarjetaMetrica({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.unidad,
    this.color = AppColors.primario,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Flexible(child: EtiquetaSeccion(etiqueta)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          ),
          Text(unidad, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ],
      ),
    );
  }
}

/// Badge del semáforo con su fondo suave. Recibe el texto CRUDO de la BD
/// ('Alta' | 'Moderada' | 'Baja') y muestra la etiqueta visible
/// (Altos / Elevados / Normal); null → "Sin lecturas".
class BadgeEstado extends StatelessWidget {
  final String? estadoDB;
  const BadgeEstado(this.estadoDB, {super.key});

  @override
  Widget build(BuildContext context) {
    final sinDato = estadoDB == null;
    final estado = EstadoAnsiedadInfo.desdeTexto(estadoDB);
    final color = sinDato ? AppColors.sinLecturas : estado.color;
    final fondo = sinDato ? AppColors.sinLecturasFondo : estado.colorFondo;
    final texto = sinDato ? 'Sin lecturas' : estado.textoUI;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
