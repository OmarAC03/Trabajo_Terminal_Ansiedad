import 'package:flutter/material.dart';
import 'screens/alerta_screen.dart';
import 'screens/historial_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _indiceActual = 0;

  // El IndexedStack mantiene el estado (y la conexión Bluetooth) viva 
  // de todas las pantallas, aunque no las estés viendo.
  final List<Widget> _pantallas = [
    const AlertaScreen(),
    const HistorialScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceActual,
        children: _pantallas,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
          });
        },
        selectedItemColor: const Color(0xFF1E6AFB),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: "Monitor"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
        ],
      ),
    );
  }
}