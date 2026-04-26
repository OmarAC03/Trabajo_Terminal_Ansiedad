import 'package:flutter/material.dart';

class TecnicasScreen extends StatelessWidget {
  const TecnicasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50], // Fondo rojizo
      body: const Center(
        child: Text(
          '🚨 Pantalla de Alerta / Ritmo Cardíaco',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}