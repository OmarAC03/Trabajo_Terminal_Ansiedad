import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';
import 'logger.dart';

void main() {
  // runZonedGuarded envuelve TODO lo que sigue (incluida la inicialización
  // async de Firebase) para que un error asíncrono no atrapado no tire la
  // app en silencio: queda registrado con AppLogger antes de perderse.
  runZonedGuarded(() async {
    // 1. Asegura que los widgets estén listos antes de llamar a código nativo
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Errores de framework (construcción de widgets, layout, etc.): antes
    // solo se veían como la pantalla roja de depuración o se perdían en
    // release. Ahora quedan registrados igual que cualquier otro error.
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        details.exceptionAsString(),
        tag: 'flutter',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    // 3. Errores que ocurren fuera de la zona de Flutter (p. ej. en un
    // isolate o callback de plataforma).
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.error('Error de plataforma no capturado', tag: 'platform', error: error, stackTrace: stack);
      return true;
    };

    // 4. En vez de la pantalla roja de depuración, una tarjeta simple: la
    // pantalla roja solo tiene sentido durante desarrollo activo con el
    // widget que falló a la vista; en el resto de los casos solo asusta.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const _PantallaErrorInesperado();
    };

    // 5. Inicializa Firebase con las opciones del proyecto
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(const AppAnsiedad());
  }, (Object error, StackTrace stack) {
    AppLogger.error('Error asíncrono no capturado', tag: 'zone', error: error, stackTrace: stack);
  });
}

class AppAnsiedad extends StatelessWidget {
  const AppAnsiedad({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Ansiedad',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(), // Decide solo entre Login y la app según la sesión
    );
  }
}

class _PantallaErrorInesperado extends StatelessWidget {
  const _PantallaErrorInesperado();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F8FB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              SizedBox(height: 12),
              Text(
                'Algo salió mal en esta pantalla.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
