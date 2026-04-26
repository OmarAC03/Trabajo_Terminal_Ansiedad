import 'package:flutter/material.dart';
import 'main_layout.dart';

void main() {
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
      home: const MainLayout(),
    );
  }
}