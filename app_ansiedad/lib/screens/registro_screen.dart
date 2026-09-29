import 'package:app_ansiedad/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:app_ansiedad/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_ansiedad/api_client.dart';
import 'package:app_ansiedad/ui/app_colors.dart';
import 'package:app_ansiedad/ui/estructura_acceso.dart';
import 'package:app_ansiedad/ui/widgets.dart';
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
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.altos),
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
        SnackBar(content: Text(errorValidacion), backgroundColor: AppColors.elevados),
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
    return EstructuraAcceso(
      conRegreso: true,
      titulo: 'Crear cuenta',
      subtitulo: 'Regístrate para comenzar tu monitoreo biométrico',
      formulario: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoTexto(
            etiqueta: 'Nombre completo',
            controller: _nombreController,
            icono: Icons.person_outline,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Correo electrónico',
            controller: _emailController,
            icono: Icons.mail_outline,
            hint: 'tu@correo.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Contraseña',
            controller: _passwordController,
            icono: Icons.lock_outline,
            hint: 'Mínimo 6 caracteres',
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 24),
          BotonPrimario(
            texto: 'Registrarme',
            cargando: _isLoading,
            onPressed: _registrarUsuario,
          ),
        ],
      ),
    );
  }
}
