import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cambiar_password_provider.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

/// "Cambiar contraseña" (Bloque 3, HU10 CA4). Se abre desde Perfil → Cuenta.
class CambiarPasswordScreen extends StatelessWidget {
  final CuentaPassword? cuenta;
  const CambiarPasswordScreen({super.key, this.cuenta});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CambiarPasswordProvider(cuenta: cuenta),
      child: const _Formulario(),
    );
  }
}

class _Formulario extends StatefulWidget {
  const _Formulario();

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _ocultar = true;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar(CambiarPasswordProvider p) async {
    FocusScope.of(context).unfocus();
    if (await p.cambiar(_actual.text, _nueva.text, _confirmacion.text)) {
      _actual.clear();
      _nueva.clear();
      _confirmacion.clear();
    }
  }

  Widget _campo(String etiqueta, TextEditingController c, {TextInputAction accion = TextInputAction.next, bool conOjo = false}) {
    return CampoTexto(
      etiqueta: etiqueta,
      controller: c,
      icono: Icons.lock_outline,
      obscureText: _ocultar,
      textInputAction: accion,
      suffixIcon: conOjo
          ? IconButton(
              icon: Icon(_ocultar ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              tooltip: _ocultar ? 'Mostrar contraseñas' : 'Ocultar contraseñas',
              onPressed: () => setState(() => _ocultar = !_ocultar),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CambiarPasswordProvider>();
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Escribe tu contraseña actual y la nueva (mínimo $minimoPassword caracteres). '
            'La usarás la próxima vez que inicies sesión.',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _campo('Contraseña actual', _actual, conOjo: true),
          const SizedBox(height: 12),
          _campo('Nueva contraseña', _nueva),
          const SizedBox(height: 12),
          _campo('Confirma la nueva contraseña', _confirmacion, accion: TextInputAction.done),
          const SizedBox(height: 16),
          if (p.error != null) ...[Aviso.error(p.error!), const SizedBox(height: 12)],
          if (p.listo) ...[
            const Aviso.info('Contraseña actualizada. Úsala la próxima vez que inicies sesión.',
                icono: Icons.check_circle_outline),
            const SizedBox(height: 12),
          ],
          BotonPrimario(texto: 'Guardar contraseña', cargando: p.guardando, onPressed: () => _guardar(p)),
        ],
      ),
    );
  }
}
