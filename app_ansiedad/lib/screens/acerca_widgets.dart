import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../contenido/acerca_textos.dart';
import '../contenido/marca.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

/// Comprueba si el servidor responde (GET /api/salud, pública). Devuelve
/// true/false; nunca lanza.
typedef ComprobarServidor = Future<bool> Function();

Future<bool> comprobarServidor() async {
  try {
    final res = await http.get(Uri.parse(AppConfig.urlSalud)).timeout(const Duration(seconds: 60));
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Perfil → "Acerca de la app" (versión final, punto 6): solo el estado de la
/// conexión y la versión. Sin URL del servidor ni nombres de proveedores.
class SeccionAcercaApp extends StatefulWidget {
  final ComprobarServidor comprobar;
  const SeccionAcercaApp({super.key, this.comprobar = comprobarServidor});

  @override
  State<SeccionAcercaApp> createState() => _SeccionAcercaAppState();
}

enum _Conexion { comprobando, conectado, sinConexion }

class _SeccionAcercaAppState extends State<SeccionAcercaApp> {
  _Conexion _estado = _Conexion.comprobando;

  @override
  void initState() {
    super.initState();
    _comprobar();
  }

  Future<void> _comprobar() async {
    if (mounted) setState(() => _estado = _Conexion.comprobando);
    final ok = await widget.comprobar();
    if (mounted) setState(() => _estado = ok ? _Conexion.conectado : _Conexion.sinConexion);
  }

  @override
  Widget build(BuildContext context) {
    final (texto, color, icono) = switch (_estado) {
      _Conexion.comprobando => ('Comprobando…', AppColors.textoSecundario, Icons.sync),
      _Conexion.conectado => ('Conectado', AppColors.primario, Icons.cloud_done_outlined),
      _Conexion.sinConexion => ('Sin conexión', AppColors.guia, Icons.cloud_off_outlined),
    };
    return _Seccion(titulo: 'Acerca de la app', filas: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          children: [
            const IconoApp(),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Marca.nombreApp,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.texto)),
                  SizedBox(height: 2),
                  Text(Marca.lema, style: TextStyle(fontSize: 13, color: AppColors.textoAyuda)),
                  SizedBox(height: 6),
                  Text('${Marca.nombreMascota}: «${Marca.fraseMascota}»',
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.primarioOscuro)),
                ],
              ),
            ),
          ],
        ),
      ),
      InkWell(
        onTap: _estado == _Conexion.comprobando ? null : _comprobar,
        child: _Fila(
          icono: icono,
          etiqueta: 'Estado',
          valor: Text(texto, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ),
      ),
      const _Fila(
        icono: Icons.info_outline,
        etiqueta: 'Versión',
        valor: Text(AppConfig.versionApp,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.texto)),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: DisclaimerNota(Disclaimers.alcance),
      ),
    ]);
  }
}

/// "Acerca del proyecto": logos de la ESCOM y el IPN y el texto, con los dos
/// primeros párrafos y "Leer más".
class SeccionAcercaProyecto extends StatefulWidget {
  const SeccionAcercaProyecto({super.key});

  @override
  State<SeccionAcercaProyecto> createState() => _SeccionAcercaProyectoState();
}

class _SeccionAcercaProyectoState extends State<SeccionAcercaProyecto> {
  bool _completo = false;

  static const _estilo = TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.texto);

  @override
  Widget build(BuildContext context) {
    final visibles = _completo
        ? TextosAcerca.parrafos
        : TextosAcerca.parrafos.take(TextosAcerca.parrafosVisibles).toList();
    final hayMas = TextosAcerca.parrafos.length > TextosAcerca.parrafosVisibles;
    return _Seccion(titulo: 'Acerca del proyecto', filas: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/institucion/escudo_ipn.png', height: 64, semanticLabel: 'Escudo del IPN'),
                const SizedBox(width: 24),
                Image.asset('assets/institucion/escudo_escom.png', height: 64, semanticLabel: 'Escudo de la ESCOM'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(TextosAcerca.titulo,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.texto)),
            for (final p in visibles) ...[
              const SizedBox(height: 10),
              Text(p, style: _estilo),
            ],
            if (hayMas)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _completo = !_completo),
                  child: Text(_completo ? TextosAcerca.leerMenos : TextosAcerca.leerMas),
                ),
              ),
            const SizedBox(height: 4),
            const Text(TextosAcerca.pie, style: TextStyle(fontSize: 11.5, color: AppColors.textoAyuda, height: 1.35)),
          ],
        ),
      ),
    ]);
  }
}

/// El ícono de la app tal como se ve en el celular: Riti feliz sobre el
/// fondo azul claro del ícono adaptativo (pubspec.yaml, flutter_launcher_icons).
class IconoApp extends StatelessWidget {
  final double tamano;
  const IconoApp({super.key, this.tamano = 64});

  static const String ruta = 'assets/mascota/avatar_feliz.png';
  static const Color fondo = Color(0xFFEAF3FE);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      padding: EdgeInsets.all(tamano * 0.1),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(tamano * 0.26),
        border: Border.all(color: AppColors.borde),
      ),
      child: Image.asset(ruta, fit: BoxFit.contain, semanticLabel: 'Ícono de ${Marca.nombreApp}'),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final List<Widget> filas;
  const _Seccion({required this.titulo, required this.filas});

  @override
  Widget build(BuildContext context) {
    final conDivisores = <Widget>[];
    for (var i = 0; i < filas.length; i++) {
      if (i > 0) conDivisores.add(const Divider(height: 1, indent: 16, endIndent: 16));
      conDivisores.add(filas[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: EtiquetaSeccion(titulo)),
        Tarjeta(padding: EdgeInsets.zero, child: Column(children: conDivisores)),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Widget valor;
  const _Fila({required this.icono, required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppColors.textoSecundario),
          const SizedBox(width: 12),
          Expanded(child: Text(etiqueta, style: const TextStyle(color: AppColors.textoAyuda, fontSize: 13))),
          valor,
        ],
      ),
    );
  }
}
