import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vinculacion_provider.dart';

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
  static const Color headerColor = Color(0xFF1E6AFB);

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
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $error"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VinculacionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Especialista", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => p.cargar(),
        child: p.isLoading
            ? ListView(children: const [
                Padding(
                  padding: EdgeInsets.only(top: 150),
                  child: Center(child: CircularProgressIndicator(color: headerColor)),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (p.errorMsg != null) _buildBannerError(p.errorMsg!),
                  p.vinculacion.vinculado ? _buildTarjetaVinculado(p) : _buildFormularioCodigo(p),
                ],
              ),
      ),
    );
  }

  Widget _buildBannerError(String mensaje) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje, style: const TextStyle(color: Colors.orange, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildTarjetaVinculado(VinculacionProvider p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: headerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.verified_user, color: headerColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            "Ya estás vinculado",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            p.vinculacion.especialistaNombre ?? "Especialista",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioCodigo(VinculacionProvider p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Vincúlate con tu especialista", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Pídele a tu especialista el código de vinculación y escríbelo aquí. "
            "Solo se hace una vez.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controladorCodigo,
            textCapitalization: TextCapitalization.characters,
            enabled: !p.isVinculando,
            decoration: InputDecoration(
              hintText: "Código de vinculación",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _vincular(p),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: p.isVinculando ? null : () => _vincular(p),
              style: ElevatedButton.styleFrom(
                backgroundColor: headerColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: p.isVinculando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Vincular"),
            ),
          ),
        ],
      ),
    );
  }
}
