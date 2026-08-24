import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'auth gate.dart';

void main() async {
  // 1. Asegura que los widgets estén listos antes de llamar a código nativo
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa Firebase con las opciones de tu proyecto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. ¡AQUÍ ESTÁ LA CORRECCIÓN! Llamamos a AppAnsiedad
  runApp(const AppAnsiedad());
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