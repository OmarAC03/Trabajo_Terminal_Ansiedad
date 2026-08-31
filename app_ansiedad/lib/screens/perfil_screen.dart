import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../avatar_widgets.dart';
import '../providers/perfil_provider.dart';

/// Pantalla de Perfil — capa de UI.
///
/// Tras el refactor a capas, esta pantalla NO llama a la red, NO parsea JSON
/// y NO toca FirebaseAuth para leer/guardar el avatar o el nombre. Solo crea
/// el PerfilProvider, escucha sus cambios y dibuja.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return ChangeNotifierProvider(
      create: (_) => PerfilProvider(uid: uid)..cargar(),
      child: const _PerfilView(),
    );
  }
}

class _PerfilView extends StatelessWidget {
  const _PerfilView();

  static const Color headerColor = Color(0xFF1E6AFB);

  Future<void> _elegirAvatar(BuildContext context, PerfilProvider p) async {
    final elegido = await mostrarSelectorAvatar(context, actual: p.avatar);
    if (elegido == null || elegido == p.avatar) return;

    final ok = await p.actualizarAvatar(elegido);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? "✅ Avatar actualizado" : "❌ No se pudo guardar el avatar. Intenta de nuevo."),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }

  Future<void> _editarNombre(BuildContext context, PerfilProvider p) async {
    final controller = TextEditingController(text: p.nombre);

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Editar nombre"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Tu nombre completo",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: headerColor, foregroundColor: Colors.white),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );

    if (nuevoNombre == null || nuevoNombre.isEmpty || nuevoNombre == p.nombre) return;

    final error = await p.editarNombre(nuevoNombre);
    if (!context.mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Nombre actualizado"), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $error"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Cerrar sesión"),
        content: const Text("¿Seguro que quieres cerrar tu sesión?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _iniciales(String nombre, String email) {
    final base = nombre.isEmpty ? email : nombre;
    final partes = base.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return "?";
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PerfilProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: p.cargar,
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
                  _buildTarjetaPerfil(context, p),
                  const SizedBox(height: 24),
                  _buildSeccionCuenta(p),
                  const SizedBox(height: 24),
                  _buildSeccionAcerca(),
                  const SizedBox(height: 30),
                  _buildBotonCerrarSesion(context),
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

  Widget _buildTarjetaPerfil(BuildContext context, PerfilProvider p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _elegirAvatar(context, p),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                p.avatar != null
                    ? AnimalAvatar(tipo: p.avatar!, size: 84)
                    : CircleAvatar(
                        radius: 42,
                        backgroundColor: headerColor,
                        child: Text(
                          _iniciales(p.nombre, p.email),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: headerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            p.nombre.isEmpty ? "Sin nombre registrado" : p.nombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(p.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: headerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(
              p.rol == 'especialista' ? "ESPECIALISTA" : "PACIENTE",
              style: TextStyle(color: headerColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _editarNombre(context, p),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text("Editar nombre"),
              style: OutlinedButton.styleFrom(
                foregroundColor: headerColor,
                side: BorderSide(color: headerColor.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionCuenta(PerfilProvider p) {
    return _buildSeccion("Cuenta", [
      _buildFila(Icons.email_outlined, "Correo electrónico", p.email),
      _buildFila(Icons.badge_outlined, "Tipo de cuenta", p.rol == 'especialista' ? "Especialista" : "Paciente"),
    ]);
  }

  Widget _buildSeccionAcerca() {
    return _buildSeccion("Acerca de la app", [
      _buildFila(Icons.info_outline, "Proyecto", "Trabajo Terminal — Sistema de Ansiedad"),
      _buildFila(Icons.cloud_outlined, "Servidor", "Conectado (Render + Supabase)"),
    ]);
  }

  Widget _buildSeccion(String titulo, List<Widget> filas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(titulo,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: filas),
        ),
      ],
    );
  }

  Widget _buildFila(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonCerrarSesion(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _cerrarSesion(context),
        icon: const Icon(Icons.logout, color: Colors.red, size: 18),
        label: const Text("Cerrar sesión", style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
