import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../avatar_widgets.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const Color headerColor = Color(0xFF1E6AFB);
  final String _baseUrl = 'https://tt-ansiedad-backend.onrender.com';

  bool _isLoading = true;
  String? _errorMsg;
  String _nombre = "";
  String _email = "";
  String _rol = "paciente";
  TipoAvatar? _avatar;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _errorMsg = "No se detectó una sesión activa.";
      });
      return;
    }

    // El avatar vive en Firebase (photoURL), no en Supabase.
    _avatar = avatarDesdePhotoUrl(FirebaseAuth.instance.currentUser?.photoURL);

    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/usuarios/$uid'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nombre = data['nombre'] ?? "";
          _email = data['email'] ?? (FirebaseAuth.instance.currentUser?.email ?? "");
          _rol = data['rol'] ?? "paciente";
          _isLoading = false;
        });
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Aun si falla la carga del perfil en Supabase, mostramos al menos
        // el correo de Firebase para que la pantalla no quede vacía del todo.
        _email = FirebaseAuth.instance.currentUser?.email ?? "";
        _errorMsg = "No se pudo cargar tu perfil completo. Desliza para reintentar.";
      });
    }
  }

  Future<void> _elegirAvatar() async {
    final elegido = await mostrarSelectorAvatar(context, actual: _avatar);
    if (elegido == null || elegido == _avatar) return;

    final avatarAnterior = _avatar;
    setState(() => _avatar = elegido); // optimista

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Sin sesión activa");
      await user.updatePhotoURL(avatarAPhotoUrl(elegido));
      await user.reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Avatar actualizado"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _avatar = avatarAnterior);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No se pudo guardar el avatar. Intenta de nuevo."), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editarNombre() async {
    final controller = TextEditingController(text: _nombre);

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

    if (nuevoNombre == null || nuevoNombre.isEmpty || nuevoNombre == _nombre) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Actualización optimista: mostramos el cambio de inmediato...
    final nombreAnterior = _nombre;
    setState(() => _nombre = nuevoNombre);

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/usuarios/$uid'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"nombre": nuevoNombre}),
      );

      if (response.statusCode != 200) throw Exception('statusCode ${response.statusCode}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Nombre actualizado"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // ...y si falla, la revertimos y avisamos (a diferencia del bug que
      // encontramos en Sincronizar, aquí sí queremos feedback de error).
      if (!mounted) return;
      setState(() => _nombre = nombreAnterior);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No se pudo guardar el cambio. Intenta de nuevo."), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cerrarSesion() async {
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
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return "?";
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _cargarPerfil,
        child: _isLoading
            ? ListView(children: const [
                Padding(
                  padding: EdgeInsets.only(top: 150),
                  child: Center(child: CircularProgressIndicator(color: headerColor)),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_errorMsg != null) _buildBannerError(),
                  _buildTarjetaPerfil(),
                  const SizedBox(height: 24),
                  _buildSeccionCuenta(),
                  const SizedBox(height: 24),
                  _buildSeccionAcerca(),
                  const SizedBox(height: 30),
                  _buildBotonCerrarSesion(),
                ],
              ),
      ),
    );
  }

  Widget _buildBannerError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.orange, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildTarjetaPerfil() {
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
            onTap: _elegirAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _avatar != null
                    ? AnimalAvatar(tipo: _avatar!, size: 84)
                    : CircleAvatar(
                        radius: 42,
                        backgroundColor: headerColor,
                        child: Text(
                          _iniciales(_nombre.isEmpty ? _email : _nombre),
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
            _nombre.isEmpty ? "Sin nombre registrado" : _nombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(_email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: headerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(
              _rol == 'especialista' ? "ESPECIALISTA" : "PACIENTE",
              style: TextStyle(color: headerColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _editarNombre,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text("Editar nombre"),
              style: OutlinedButton.styleFrom(
                foregroundColor: headerColor,
                side: BorderSide(color: headerColor.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionCuenta() {
    return _buildSeccion("Cuenta", [
      _buildFila(Icons.email_outlined, "Correo electrónico", _email),
      _buildFila(Icons.badge_outlined, "Tipo de cuenta", _rol == 'especialista' ? "Especialista" : "Paciente"),
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

  Widget _buildBotonCerrarSesion() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _cerrarSesion,
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