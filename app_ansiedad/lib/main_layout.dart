import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/pendientes.dart';
import 'providers/pendientes_provider.dart';
import 'screens/alerta_screen.dart';
import 'screens/historial_screen.dart';
import 'screens/mensajes_screen.dart'; // ¡Nueva pantalla!
import 'screens/perfil_screen.dart';
import 'screens/tecnicas_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _indiceActual = 0;

  static const int _indiceMensajes = 2;

  // Badges de Mensajes y Ejercicios (Fase 2c). Se crea aquí (y no en build)
  // porque este State lo usa directamente al cambiar de pestaña.
  final PendientesProvider _pendientes = PendientesProvider();

  // Lista de las 5 pantallas conectadas a la barra
  final List<Widget> _pantallas = [
    const AlertaScreen(),
    const HistorialScreen(),
    const MensajesScreen(), // La conectamos aquí
    const TecnicasScreen(),
    const PerfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendientes.dispose();
    super.dispose();
  }

  // Sin sondeo en segundo plano; al volver se consulta de inmediato.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pendientes.refrescar();
      _pendientes.iniciarSondeo();
    } else if (state == AppLifecycleState.paused) {
      _pendientes.detenerSondeo();
    }
  }

  // Mensajes se marca como visto al ENTRAR y también al SALIR, porque lo que
  // llega mientras el chat está abierto el paciente ya lo vio en pantalla.
  // (Ejercicios se marca al abrir su pantalla, desde la pestaña Técnicas.)
  void _cambiarPestana(int index) {
    final anterior = _indiceActual;
    setState(() => _indiceActual = index);
    if (anterior == index) return;

    if (index == _indiceMensajes || anterior == _indiceMensajes) {
      _pendientes.marcarVisto(SeccionPendiente.mensajes);
    } else {
      _pendientes.refrescar();
    }
  }

  /// Ícono con contador. El de Mensajes se oculta mientras esa pestaña está
  /// abierta (lo nuevo ya está a la vista).
  Widget _conBadge(Widget icono, int cantidad) {
    return Badge(
      isLabelVisible: cantidad > 0,
      label: Text(cantidad > 9 ? '9+' : '$cantidad'),
      child: icono,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _pendientes,
      child: Consumer<PendientesProvider>(
        builder: (context, pendientes, _) {
          final mensajes = _indiceActual == _indiceMensajes ? 0 : pendientes.mensajes;
          final ejercicios = pendientes.ejercicios;
          return Scaffold(
            // 🚨 LA CORRECCIÓN DE ORO ESTÁ AQUÍ
            body: IndexedStack(
              index: _indiceActual,
              children: _pantallas,
            ),
            // Usamos BottomNavigationBar clásico para tener control total del diseño
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _indiceActual,
                onTap: _cambiarPestana,
                backgroundColor: Colors.white,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: const Color(0xFF1E6AFB), // Azul de tu diseño
                unselectedItemColor: Colors.grey[400],
                selectedFontSize: 12,
                unselectedFontSize: 12,
                elevation: 0,
                items: [
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.home_outlined),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.home),
                    ),
                    label: 'Inicio',
                  ),
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.bar_chart),
                    ),
                    label: 'Historial',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _conBadge(const Icon(Icons.chat_bubble_outline), mensajes),
                    ),
                    activeIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.chat_bubble),
                    ),
                    label: 'Mensajes',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _conBadge(const Icon(Icons.spa_outlined), ejercicios),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _conBadge(const Icon(Icons.spa), ejercicios),
                    ),
                    label: 'Técnicas',
                  ),
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.person_outline),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.person),
                    ),
                    label: 'Perfil',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
