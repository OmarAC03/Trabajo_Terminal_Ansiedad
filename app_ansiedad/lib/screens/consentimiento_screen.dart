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
            const ContenidoPrivacidad(),
            const SizedBox(height: 8),
            _Casilla(
              texto: TextosPrivacidad.casillaAviso,
              valor: p.aceptaAviso,
              onChanged: p.enviando ? null : p.marcarAviso,
            ),
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

/// Solo lectura del aviso y el consentimiento (enlace del registro).
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

/// Los dos textos en tarjetas, con la marca de borrador mientras lo sean.
class ContenidoPrivacidad extends StatelessWidget {
  const ContenidoPrivacidad({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (TextosPrivacidad.esBorrador) ...[
          const Aviso(
            TextosPrivacidad.marcaBorrador,
            icono: Icons.edit_note,
            color: AppColors.guia,
            fondo: AppColors.guiaFondo,
          ),
          const SizedBox(height: 12),
        ],
        const _Seccion(titulo: TextosPrivacidad.tituloAviso, parrafos: TextosPrivacidad.aviso),
        const SizedBox(height: 12),
        const _Seccion(titulo: TextosPrivacidad.tituloConsentimiento, parrafos: TextosPrivacidad.consentimiento),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final List<String> parrafos;
  const _Seccion({required this.titulo, required this.parrafos});

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.texto)),
          for (final parrafo in parrafos) ...[
            const SizedBox(height: 10),
            Text(parrafo, style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.texto)),
          ],
        ],
      ),
    );
  }
}
