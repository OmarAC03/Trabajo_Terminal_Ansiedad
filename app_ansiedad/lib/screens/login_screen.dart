import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main_layout.dart'; // O la ruta correcta donde tengas tu MainLayout
import 'registro_screen.dart';
import '../ui/app_colors.dart';
import '../ui/estructura_acceso.dart';
import '../ui/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Instancia de Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Función para iniciar sesión
  Future<void> _iniciarSesion() async {
    // Validar que los campos no estén vacíos
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos'), backgroundColor: AppColors.elevados),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Intentar login en Firebase
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Si es exitoso, navegar a la pantalla principal y destruir el historial de navegación
      Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainLayout()), 
      );

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensajeError = 'Ocurrió un error al iniciar sesión';
      
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        mensajeError = 'No se encontró un usuario con ese correo.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        mensajeError = 'Contraseña incorrecta.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeError), backgroundColor: AppColors.altos),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EstructuraAcceso(
      titulo: 'Bienvenido',
      subtitulo: 'Inicia sesión para continuar',
      formulario: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) _iniciarSesion();
            },
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 24),
          BotonPrimario(
            texto: 'Iniciar sesión',
            cargando: _isLoading,
            onPressed: _iniciarSesion,
          ),
        ],
      ),
      pie: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('¿No tienes cuenta?', style: TextStyle(color: AppColors.textoAyuda, fontSize: 13)),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegistroScreen()),
              );
            },
            child: const Text('Regístrate aquí', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
