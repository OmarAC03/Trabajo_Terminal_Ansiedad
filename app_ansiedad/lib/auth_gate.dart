import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'main_layout.dart';

/// Puerta de entrada de la app.
///
/// Antes, `main.dart` mandaba SIEMPRE a LoginScreen, incluso si el usuario ya
/// tenía sesión activa (Firebase la recuerda entre aperturas). Eso obligaba a
/// iniciar sesión cada vez. AuthGate escucha el estado de autenticación y
/// decide solo:
///   - sesión activa   -> MainLayout (la app)
///   - sin sesión      -> LoginScreen
///   - cargando         -> pantalla de carga breve
///
/// Al reaccionar a `authStateChanges`, también maneja el cierre de sesión y la
/// expiración de sesión de forma centralizada: si la sesión desaparece por
/// cualquier motivo, el usuario vuelve a Login automáticamente.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Esperando la primera respuesta de Firebase sobre si hay sesión.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PantallaCarga();
        }

        // Hay un usuario autenticado -> a la app.
        if (snapshot.hasData) {
          return const MainLayout();
        }

        // No hay sesión -> login.
        return const LoginScreen();
      },
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6F8FB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_heart, size: 60, color: Color(0xFF1E6AFB)),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Color(0xFF1E6AFB)),
          ],
        ),
      ),
    );
  }
}