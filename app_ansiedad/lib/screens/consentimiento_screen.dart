import 'package:flutter/material.dart';
import '../sesion.dart';
import 'package:provider/provider.dart';
import '../contenido/privacidad_textos.dart';
import '../providers/consentimiento_provider.dart';
import '../ui/app_colors.dart';
import '../ui/pantalla_cargando.dart';
import '../ui/widgets.dart';

/// Puerta de consentimiento (Bloque 1, paso 2): va entre "hay sesión" y la
/// app ([AuthGate]). Si la cuenta es de un paciente que no aceptó la versión
/// vigente del aviso y el consentimiento, muestra [_PantallaConsentimiento] y
/// la app no se ve hasta aceptar. Especialistas y admins pasan directo.
class PuertaConsentimiento extends StatelessWidget {
  final Widget child;
  const PuertaConsentimiento({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConsentimientoProvider()..cargar(),
      child: Consumer<ConsentimientoProvider>(
        builder: (context, p, _) {
          switch (p.estado) {
            case EstadoPuerta.continuar:
              return child;
            case EstadoPuerta.pedirConsentimiento:
              return const _PantallaConsentimiento();
            case EstadoPuerta.error:
              return _PantallaErrorPuerta(mensaje: p.error, onReintentar: p.cargar);
            case EstadoPuerta.cargando:
              // Primera petición al servidor: aquí se nota si Render despierta.
              return const PantallaCargando();
          }
        },
      ),
    );
  }
}

class _PantallaConsentimiento extends StatelessWidget {
  const _PantallaConsentimiento();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConsentimientoProvider>();
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: appBarGradiente(TextosPrivacidad.titulo),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(TextosPrivacidad.introduccion, style: TextStyle(fontSize: 14, color: AppColors.texto)),
            const SizedBox(height: 16),
            if (TextosPrivacidad.esBorrador) ...[const MarcaBorrador(), const SizedBox(height: 12)],
            // A (simplificado) con su enlace al integral (B), y su casilla.
            const TarjetaTexto(titulo: TextosPrivacidad.tituloAviso, bloques: TextosPrivacidad.avisoSimplificado),
            const EnlaceAvisoCompleto(),
            _Casilla(
              texto: TextosPrivacidad.casillaAviso,
              valor: p.aceptaAviso,
              onChanged: p.enviando ? null : p.marcarAviso,
            ),
            const SizedBox(height: 12),
            // C (consentimiento) con su casilla propia. Las dos empiezan sin marcar.
            const TarjetaTexto(
                titulo: TextosPrivacidad.tituloConsentimiento, bloques: TextosPrivacidad.consentimientoInformado),
            const SizedBox(height: 4),
            _Casilla(
              texto: TextosPrivacidad.casillaConsentimiento,
              valor: p.aceptaConsentimiento,
              onChanged: p.enviando ? null : p.marcarConsentimiento,
            ),
            if (p.error != null) ...[
              const SizedBox(height: 8),
              Aviso.error(p.error!),
            ],
            const SizedBox(height: 16),
            BotonPrimario(
              texto: TextosPrivacidad.aceptar,
              cargando: p.enviando,
              onPressed: p.puedeAceptar ? p.aceptar : null,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: p.enviando ? null : Sesion.cerrarSesionUsuario,
              child: const Text(TextosPrivacidad.salir),
            ),
          ],
        ),
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  final String texto;
  final bool valor;
  final ValueChanged<bool>? onChanged;
  const _Casilla({required this.texto, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: valor,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.primario,
      title: Text(texto, style: const TextStyle(fontSize: 14, color: AppColors.texto)),
    );
  }
}

class _PantallaErrorPuerta extends StatelessWidget {
  final String? mensaje;
  final VoidCallback onReintentar;
  const _PantallaErrorPuerta({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Aviso.error(mensaje ?? TextosPrivacidad.errorCarga),
                const SizedBox(height: 16),
                BotonPrimario(texto: TextosPrivacidad.reintentar, onPressed: onReintentar, icono: Icons.refresh),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: Sesion.cerrarSesionUsuario,
                  child: const Text(TextosPrivacidad.salir),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Solo lectura del aviso simplificado y el consentimiento (enlace del
/// registro y Perfil → Privacidad → Aviso de privacidad).
class TextosPrivacidadScreen extends StatelessWidget {
  const TextosPrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: appBarGradiente(TextosPrivacidad.tituloAviso),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: const [ContenidoPrivacidad()]),
      ),
    );
  }
}

/// El aviso integral (B).
class AvisoIntegralScreen extends StatelessWidget {
  const AvisoIntegralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: appBarGradiente(TextosPrivacidad.tituloAviso),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            if (TextosPrivacidad.esBorrador) ...[MarcaBorrador(), SizedBox(height: 12)],
            TarjetaTexto(titulo: TextosPrivacidad.tituloAvisoIntegral, bloques: TextosPrivacidad.avisoIntegral),
          ],
        ),
      ),
    );
  }
}

/// A, el enlace a B y C, con la marca de borrador mientras lo sean.
class ContenidoPrivacidad extends StatelessWidget {
  const ContenidoPrivacidad({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (TextosPrivacidad.esBorrador) ...[MarcaBorrador(), SizedBox(height: 12)],
        TarjetaTexto(titulo: TextosPrivacidad.tituloAviso, bloques: TextosPrivacidad.avisoSimplificado),
        EnlaceAvisoCompleto(),
        TarjetaTexto(titulo: TextosPrivacidad.tituloConsentimiento, bloques: TextosPrivacidad.consentimientoInformado),
      ],
    );
  }
}

class MarcaBorrador extends StatelessWidget {
  const MarcaBorrador({super.key});

  @override
  Widget build(BuildContext context) => const Aviso(
        TextosPrivacidad.marcaBorrador,
        icono: Icons.edit_note,
        color: AppColors.guia,
        fondo: AppColors.guiaFondo,
      );
}

class EnlaceAvisoCompleto extends StatelessWidget {
  const EnlaceAvisoCompleto({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvisoIntegralScreen())),
        icon: const Icon(Icons.article_outlined, size: 18),
        label: const Text(TextosPrivacidad.leerCompleto),
      ),
    );
  }
}

/// Tarjeta con título y bloques (subtítulos, párrafos y viñetas).
class TarjetaTexto extends StatelessWidget {
  final String titulo;
  final List<BloqueTexto> bloques;
  const TarjetaTexto({super.key, required this.titulo, required this.bloques});

  static const _estilo = TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.texto);

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.texto)),
          for (final b in bloques)
            switch (b.tipo) {
              TipoBloque.subtitulo => Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(b.texto,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.texto)),
                ),
              TipoBloque.parrafo => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextoConNegritas(b.texto, estilo: _estilo),
                ),
              TipoBloque.vineta => Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: _estilo),
                      Expanded(child: TextoConNegritas(b.texto, estilo: _estilo)),
                    ],
                  ),
                ),
            },
        ],
      ),
    );
  }
}

/// Texto con tramos en **negrita**.
class TextoConNegritas extends StatelessWidget {
  final String texto;
  final TextStyle estilo;
  const TextoConNegritas(this.texto, {super.key, required this.estilo});

  @override
  Widget build(BuildContext context) {
    final partes = texto.split('**');
    return Text.rich(TextSpan(
      style: estilo,
      children: [
        for (var i = 0; i < partes.length; i++)
          TextSpan(text: partes[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null),
      ],
    ));
  }
}
