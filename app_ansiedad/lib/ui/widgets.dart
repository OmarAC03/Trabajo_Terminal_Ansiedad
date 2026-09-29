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

/// Campo de formulario de la guía: etiqueta pequeña semibold arriba, ícono a
/// la izquierda y el resto del estilo del tema (radio 12, foco azul).
class CampoTexto extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controller;
  final IconData icono;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.icono,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoAyuda),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: AppColors.texto, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icono, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Botón primario azul a todo el ancho; muestra un spinner mientras [cargando].
class BotonPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;

  const BotonPrimario({super.key, required this.texto, this.onPressed, this.cargando = false, this.icono});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        // Mientras carga se mantiene azul (atenuado); desactivado por otra
        // razón usa el gris del tema para que se lea como no disponible.
        style: cargando
            ? ElevatedButton.styleFrom(
                disabledBackgroundColor: AppColors.primario.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
              )
            : null,
        child: cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icono != null) ...[Icon(icono, size: 20), const SizedBox(width: 8)],
                  Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// Aviso en línea (equivalente a `Alert` del portal): ícono + texto sobre un
/// fondo suave del mismo tono.
class Aviso extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final Color fondo;

  const Aviso(this.texto, {super.key, required this.icono, required this.color, required this.fondo});

  const Aviso.info(this.texto, {super.key, this.icono = Icons.mark_email_read_outlined})
      : color = AppColors.primario,
        fondo = AppColors.primarioSuave;

  const Aviso.error(this.texto, {super.key, this.icono = Icons.error_outline})
      : color = AppColors.altos,
        fondo = AppColors.altosFondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppColors.radio),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(color: color, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// Tarjeta blanca con borde y sombra sutil.
/// Con [onTap] se vuelve tocable (ripple recortado a las esquinas).
class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? colorBorde;
  final VoidCallback? onTap;

  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.colorBorde,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppColors.radio);
    return Container(
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? AppColors.superficie,
        borderRadius: radio,
        border: Border.all(color: colorBorde ?? AppColors.borde),
        boxShadow: AppColors.sombra,
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radio,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
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

/// Tarjeta de métrica (BPM / SpO2 / HRV): ícono en su color propio, etiqueta
/// arriba, valor grande en negrita máxima y unidad gris abajo.
class TarjetaMetrica extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String unidad;

  /// Color del valor (azul por defecto, o el del estado).
  final Color color;
  final IconData? icono;

  /// Color del ícono; si no se da, usa [color].
  final Color? colorIcono;

  const TarjetaMetrica({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.unidad,
    this.color = AppColors.primario,
    this.icono,
    this.colorIcono,
  });

  @override
  Widget build(BuildContext context) {
    final tonoIcono = colorIcono ?? color;
    return Tarjeta(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: tonoIcono.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, size: 15, color: tonoIcono),
                ),
                const SizedBox(width: 6),
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
