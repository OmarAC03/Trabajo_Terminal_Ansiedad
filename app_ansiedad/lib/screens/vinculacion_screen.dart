import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vinculacion_provider.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

/// Pantalla "Especialista vinculado" — capa de UI.
///
/// Sigue el mismo patrón que Historial/Perfil: NO llama a la red ni parsea
/// JSON. Solo crea el VinculacionProvider, escucha sus cambios y dibuja. Se
/// abre desde PerfilScreen (solo visible para pacientes).
class VinculacionScreen extends StatelessWidget {
  const VinculacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VinculacionProvider()..cargar(),
      child: const _VinculacionView(),
    );
  }
}

class _VinculacionView extends StatefulWidget {
  const _VinculacionView();

  @override
  State<_VinculacionView> createState() => _VinculacionViewState();
}

class _VinculacionViewState extends State<_VinculacionView> {
  // El controlador del campo de texto es puramente de UI, igual que en
  // MensajesScreen: no forma parte del estado de la vinculación.
  final TextEditingController _controladorCodigo = TextEditingController();

  @override
  void dispose() {
    _controladorCodigo.dispose();
    super.dispose();
  }

  Future<void> _vincular(VinculacionProvider p) async {
    final codigo = _controladorCodigo.text.trim();
    if (codigo.isEmpty) return;

    final error = await p.vincular(codigo);
    if (!mounted) return;

    if (error == null) {
      _controladorCodigo.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Vinculado con ${p.vinculacion.especialistaNombre ?? 'tu especialista'}"),
          backgroundColor: AppColors.normal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $error"), backgroundColor: AppColors.altos),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final p = context.watch<VinculacionProvider>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: appBarGradiente("Especialista"),
      body: RefreshIndicator(
        onRefresh: () => p.cargar(),
        child: p.isLoading
            ? ListView(children: const [
                Padding(
                  padding: EdgeInsets.only(top: 150),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primario)),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (p.errorMsg != null) ...[
                    Aviso(
                      p.errorMsg!,
                      icono: Icons.warning_amber_rounded,
                      color: AppColors.elevados,
                      fondo: AppColors.elevadosFondo,
                    ),
                    const SizedBox(height: 16),
                  ],
                  p.vinculacion.vinculado ? _buildTarjetaVinculado(p) : _buildFormularioCodigo(p),
                ],
              ),
      ),
    );
  }

  Widget _buildTarjetaVinculado(VinculacionProvider p) {
    return Tarjeta(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
            child: const Icon(Icons.verified_user, color: AppColors.primario, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            "Ya estás vinculado",
            style: TextStyle(fontSize: 14, color: AppColors.textoAyuda),
          ),
          const SizedBox(height: 4),
          Text(
            p.vinculacion.especialistaNombre ?? "Especialista",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.texto),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioCodigo(VinculacionProvider p) {
    return Tarjeta(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Vincúlate con tu especialista",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.texto)),
          const SizedBox(height: 6),
          const Text(
            "Pídele a tu especialista el código de vinculación y escríbelo aquí. "
            "Solo se hace una vez.",
            style: TextStyle(color: AppColors.textoAyuda, fontSize: 13),
          ),
          const SizedBox(height: 20),
          CampoTexto(
            etiqueta: "Código de vinculación",
            controller: _controladorCodigo,
            icono: Icons.key_outlined,
            hint: "Ej. A1B2C3",
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            enabled: !p.isVinculando,
            onSubmitted: (_) => _vincular(p),
          ),
          const SizedBox(height: 16),
          BotonPrimario(
            texto: "Vincular",
            icono: Icons.link,
            cargando: p.isVinculando,
            onPressed: () => _vincular(p),
          ),
        ],
      ),
    );
  }
}
