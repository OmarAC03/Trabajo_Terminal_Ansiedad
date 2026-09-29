import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'vinculacion_screen.dart';
import '../app_config.dart';
import '../avatar_widgets.dart';
import '../providers/perfil_provider.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';

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

  Future<void> _elegirAvatar(BuildContext context, PerfilProvider p) async {
    final elegido = await mostrarSelectorAvatar(context, actual: p.avatar);
    if (elegido == null || elegido == p.avatar) return;

    final ok = await p.actualizarAvatar(elegido);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? "✅ Avatar actualizado" : "❌ No se pudo guardar el avatar. Intenta de nuevo."),
      backgroundColor: ok ? AppColors.normal : AppColors.altos,
    ));
  }

  Future<void> _editarNombre(BuildContext context, PerfilProvider p) async {
    final controller = TextEditingController(text: p.nombre);

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
        const SnackBar(content: Text("✅ Nombre actualizado"), backgroundColor: AppColors.normal),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $error"), backgroundColor: AppColors.altos),
      );
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text("¿Seguro que quieres cerrar tu sesión?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.altos, foregroundColor: Colors.white),
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
      backgroundColor: AppColors.fondo,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EncabezadoGradiente(
            icono: Icons.person_outline,
            titulo: "Mi Perfil",
            subtitulo: "Tu cuenta y tu especialista",
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: p.cargar,
              child: p.isLoading
                  ? ListView(children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 120),
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
                        _buildTarjetaPerfil(context, p),
                        const SizedBox(height: 20),
                        _buildSeccionCuenta(p),
                        if (p.rol == 'paciente') ...[
                          const SizedBox(height: 20),
                          _buildSeccionEspecialista(context),
                        ],
                        const SizedBox(height: 20),
                        _buildSeccionAcerca(),
                        const SizedBox(height: 24),
                        _buildBotonCerrarSesion(context),
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaPerfil(BuildContext context, PerfilProvider p) {
    return Tarjeta(
      padding: const EdgeInsets.all(20),
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
                        backgroundColor: AppColors.primario,
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
                      color: AppColors.primario,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            p.nombre.isEmpty ? "Sin nombre registrado" : p.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.texto),
          ),
          const SizedBox(height: 4),
          Text(p.email, style: const TextStyle(color: AppColors.textoAyuda, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primarioSuave, borderRadius: BorderRadius.circular(999)),
            child: Text(
              p.rol == 'especialista' ? "ESPECIALISTA" : "PACIENTE",
              style: const TextStyle(color: AppColors.primario, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _editarNombre(context, p),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text("Editar nombre"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primario,
                side: BorderSide(color: AppColors.primario.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radio)),
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

  Widget _buildSeccionEspecialista(BuildContext context) {
    return _buildSeccion("Especialista", [
      Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.radio),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VinculacionScreen())),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.medical_services_outlined, size: 18, color: AppColors.primario),
                SizedBox(width: 12),
                Expanded(
                  child: Text("Especialista vinculado",
                      style: TextStyle(color: AppColors.texto, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textoSecundario),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSeccionAcerca() {
    return _buildSeccion("Acerca de la app", [
      _buildFila(Icons.info_outline, "Proyecto", "Trabajo Terminal — Sistema de Ansiedad"),
      _buildFila(Icons.cloud_outlined, "Servidor", "Conectado (Render + Supabase)"),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: DisclaimerNota(Disclaimers.alcance),
      ),
    ]);
  }

  /// Título gris en mayúsculas + tarjeta con filas separadas por líneas.
  Widget _buildSeccion(String titulo, List<Widget> filas) {
    final conDivisores = <Widget>[];
    for (var i = 0; i < filas.length; i++) {
      if (i > 0) conDivisores.add(const Divider(height: 1, indent: 16, endIndent: 16));
      conDivisores.add(filas[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: EtiquetaSeccion(titulo),
        ),
        Tarjeta(
          padding: EdgeInsets.zero,
          child: Column(children: conDivisores),
        ),
      ],
    );
  }

  Widget _buildFila(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppColors.textoSecundario),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textoAyuda, fontSize: 13)),
          ),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.texto),
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
        icon: const Icon(Icons.logout, size: 18),
        label: const Text("Cerrar sesión"),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.altos,
          backgroundColor: AppColors.superficie,
          side: const BorderSide(color: AppColors.altos),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radio)),
        ),
      ),
    );
  }
}
