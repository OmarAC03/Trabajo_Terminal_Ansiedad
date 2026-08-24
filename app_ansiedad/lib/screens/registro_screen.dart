import 'package:app_ansiedad/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:app_ansiedad/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_ansiedad/api_client.dart';
import 'dart:convert';


class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  /// Validaciones locales ANTES de tocar Firebase o la red: fallar barato.
  /// Devuelve un mensaje de error, o null si todo está bien.
  String? _validarCampos() {
    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (nombre.isEmpty || email.isEmpty || pass.isEmpty) {
      return 'Por favor llena todos los campos';
    }
    // Formato de email razonable (no exhaustivo, pero atrapa errores comunes).
    final emailValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailValido) {
      return 'El correo no tiene un formato válido';
    }
    if (pass.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  Future<void> _registrarUsuario() async {
    // Paso 0: validar antes de crear nada.
    final errorValidacion = _validarCampos();
    if (errorValidacion != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorValidacion), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() { _isLoading = true; });

    User? usuarioCreado; // referencia para poder revertir si algo falla después

    try {
      // Paso 1: crear la cuenta en Firebase Auth.
      final UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      usuarioCreado = cred.user;
      final String nuevoUid = usuarioCreado!.uid;

      // Paso 2: guardar el perfil en Supabase (vía backend).
      final response = await ApiClient.post(
        Uri.parse(AppConfig.urlUsuarios),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": nuevoUid,
          "nombre": _nombreController.text.trim(),
          "email": _emailController.text.trim(),
          "rol": "paciente",
        }),
      );

      if (response.exito) {
        // Paso 3: éxito completo (Firebase + Supabase). Entrar a la app.
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
        return;
      }

      // Paso 2 falló: TRANSACCIÓN COMPENSATORIA.
      // La cuenta de Firebase ya existe pero el perfil NO se guardó. Para no
      // dejar una "cuenta fantasma", deshacemos el paso 1 borrando la cuenta
      // recién creada. Así el registro es "todo o nada".
      await _revertirCuenta(usuarioCreado);
      _mostrarError(
        "No se pudo completar el registro (${response.mensajeUsuario}). "
        "No se creó ninguna cuenta; intenta de nuevo.",
      );

    } on FirebaseAuthException catch (e) {
      // El fallo fue al CREAR la cuenta: no hay nada que revertir.
      String mensajeError = 'Ocurrió un error al registrar';
      if (e.code == 'weak-password') {
        mensajeError = 'La contraseña es muy débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        mensajeError = 'Este correo ya tiene una cuenta.';
      } else if (e.code == 'invalid-email') {
        mensajeError = 'El correo no tiene un formato válido.';
      }
      _mostrarError(mensajeError);
    } catch (e) {
      // Error inesperado DESPUÉS de crear la cuenta (ej. excepción de red no
      // controlada): también revertimos para no dejar cuenta fantasma.
      if (usuarioCreado != null) {
        await _revertirCuenta(usuarioCreado);
      }
      _mostrarError('No se pudo completar el registro. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  /// Deshace la creación de la cuenta de Firebase (compensación). Si el borrado
  /// mismo falla (raro), como mínimo cerramos la sesión para que no quede una
  /// sesión activa a medias.
  Future<void> _revertirCuenta(User? usuario) async {
    try {
      await usuario?.delete();
    } catch (_) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {/* nada más que hacer */}
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1E6AFB);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Crear Cuenta",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Regístrate para comenzar tu monitoreo biométrico",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // Campo Nombre
              TextField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: "Nombre completo",
                  prefixIcon: const Icon(Icons.person, color: primaryBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),

              // Campo Correo
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: const Icon(Icons.email, color: primaryBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),

              // Campo Contraseña
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: const Icon(Icons.lock, color: primaryBlue),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 30),

              // Botón Registrar
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrarUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Registrarme", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}