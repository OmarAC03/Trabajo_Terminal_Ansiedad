import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/eliminar_cuenta_provider.dart';
import '../ui/app_colors.dart';
import '../ui/formato_fecha.dart';
import '../ui/widgets.dart';

/// Textos de la pantalla (Bloque 1, paso 3). Lo que se borra y lo que se
/// conserva es lo mismo que hace el backend al atender (backend/eliminacion.js).
class TextosEliminarCuenta {
  TextosEliminarCuenta._();

  static const String titulo = 'Eliminar mi cuenta';
  static const String explicacion =
      'Puedes pedir que se elimine tu cuenta y tus datos. El administrador atenderá tu solicitud; '
      'mientras tanto puedes seguir usando la app con normalidad.';
  static const String tituloSeBorra = 'Cuando se atienda, se borrará:';
  static const List<String> seBorra = [
    'Tus mediciones y tus respuestas a los cuestionarios.',
    'Tus mensajes con tu especialista y los ejercicios que te asignó.',
    'Tu cuenta: ya no podrás iniciar sesión.',
  ];
  static const String seConserva =
      'Solo se conserva, sin tu nombre ni tu correo, el registro de que aceptaste el aviso de privacidad '
      'y de esta solicitud.';
  static const String irreversible = 'No se puede deshacer y, una vez enviada, la solicitud no se puede cancelar.';
  static const String casilla = 'Entiendo que se borrarán mi cuenta y mis datos.';
  static const String enviar = 'Enviar solicitud';
  static const String enviada = 'Solicitud enviada';
  static String pendienteDesde(String fecha) =>
      'Enviaste tu solicitud $fecha. Está pendiente de que el administrador la atienda.';
}

/// Pantalla "Eliminar mi cuenta" (RF-19 / RF-34). Se abre desde Perfil (solo
/// pacientes).
class EliminarCuentaScreen extends StatelessWidget {
  const EliminarCuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EliminarCuentaProvider()..cargar(),
      child: const _EliminarCuentaView(),
    );
  }
}

class _EliminarCuentaView extends StatelessWidget {
  const _EliminarCuentaView();

  Future<void> _enviar(BuildContext context, EliminarCuentaProvider p) async {
    final ok = await p.solicitar();
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(TextosEliminarCuenta.enviada)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EliminarCuentaProvider>();
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: appBarGradiente(TextosEliminarCuenta.titulo),
      body: SafeArea(
        child: p.cargando
            ? const Center(child: CircularProgressIndicator(color: AppColors.primario))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(TextosEliminarCuenta.explicacion, style: TextStyle(fontSize: 14, color: AppColors.texto)),
                  const SizedBox(height: 16),
                  Tarjeta(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(TextosEliminarCuenta.tituloSeBorra,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.texto)),
                        for (final t in TextosEliminarCuenta.seBorra) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.remove_circle_outline, size: 16, color: AppColors.textoAyuda),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5, color: AppColors.texto))),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(TextosEliminarCuenta.seConserva,
                            style: TextStyle(fontSize: 12.5, color: AppColors.textoAyuda)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (p.yaSolicitada)
                    Aviso.info(
                      TextosEliminarCuenta.pendienteDesde(
                        fechaRelativa(p.solicitud!.fechaSolicitud, ahora: DateTime.now()),
                      ),
                      icono: Icons.hourglass_top,
                    )
                  else ...[
                    const Aviso(
                      TextosEliminarCuenta.irreversible,
                      icono: Icons.warning_amber_rounded,
                      color: AppColors.guia,
                      fondo: AppColors.guiaFondo,
                    ),
                    CheckboxListTile(
                      value: p.entiende,
                      onChanged: p.enviando ? null : (v) => p.marcarEntiende(v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.altos,
                      title: const Text(TextosEliminarCuenta.casilla,
                          style: TextStyle(fontSize: 14, color: AppColors.texto)),
                    ),
                    if (p.error != null) ...[
                      Aviso.error(p.error!),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: p.puedeEnviar ? () => _enviar(context, p) : null,
                        icon: p.enviando
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.delete_outline),
                        label: const Text(TextosEliminarCuenta.enviar),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.altos, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
