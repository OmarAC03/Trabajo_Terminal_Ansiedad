import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/pendientes.dart';
import 'providers/pendientes_provider.dart';
import 'notificaciones/servicio_push.dart';
import 'notificaciones/notificaciones_locales.dart';
import 'screens/inicio_screen.dart';
import 'screens/historial_screen.dart';
import 'screens/mensajes_screen.dart'; // ¡Nueva pantalla!
import 'screens/perfil_screen.dart';
import 'screens/tecnicas_screen.dart';
import 'ui/app_colors.dart';

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
    const InicioScreen(),
    const HistorialScreen(),
    const MensajesScreen(), // La conectamos aquí
    const TecnicasScreen(),
    const PerfilScreen(),
  ];

  // Notificaciones push (Bloque 3): tocar una abre su pestaña (D8); con la
  // app abierta no se muestran y solo se refrescan los badges (D5).
  final List<StreamSubscription<Object?>> _suscripciones = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarPush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _suscripciones) {
      s.cancel();
    }
    NotificacionesLocales.tocada.removeListener(_alTocarLocal);
    _pendientes.dispose();
    super.dispose();
  }

  Future<void> _iniciarPush() async {
    final push = ServicioPush.instancia;
    try {
      _suscripciones.add(push.fuente.tiposAbiertos.listen(_abrirTipo));
      _suscripciones.add(push.fuente.enPrimerPlano.listen((_) => _pendientes.refrescar()));
      // Notificación local tocada (recordatorio del GAD-7).
      NotificacionesLocales.tocada.addListener(_alTocarLocal);
      _alTocarLocal();
      final inicial = await push.fuente.tipoDeArranque();
      if (inicial != null) _abrirTipo(inicial);
      await push.registrar();
      if (mounted && await push.debePreguntar()) await _explicarPermiso(push);
    } catch (_) {
      // Sin Firebase Messaging (p. ej. en pruebas) la app sigue igual.
    }
  }

  void _alTocarLocal() {
    final tipo = NotificacionesLocales.tocada.value;
    if (tipo == null) return;
    NotificacionesLocales.tocada.value = null;
    _abrirTipo(tipo);
  }

  void _abrirTipo(String tipo) {
    final indice = pestanaParaTipo(tipo);
    if (indice != null && mounted) _cambiarPestana(indice);
  }

  /// Explicación antes del diálogo del sistema (se muestra una sola vez).
  Future<void> _explicarPermiso(ServicioPush push) async {
    final activar = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.notifications_active_outlined, size: 40, color: AppColors.primario),
              const SizedBox(height: 12),
              const Text('¿Activar avisos?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.texto)),
              const SizedBox(height: 8),
              const Text(
                'Te avisamos de mensajes y ejercicios de tu especialista, y cuando toca el cuestionario '
                'quincenal. Nunca mostramos su contenido. Puedes cambiarlo después en Perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textoSecundario),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activar avisos')),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
            ],
          ),
        ),
      ),
    );
    if (activar == true) {
      await push.pedirPermiso();
    } else {
      await push.posponer();
    }
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
      backgroundColor: AppColors.altos,
      label: Text(cantidad > 9 ? '9+' : '$cantidad'),
      child: icono,
    );
  }

  /// Ícono de la barra: el activo lleva un puntito azul debajo; el inactivo
  /// deja el mismo espacio transparente para que la barra no brinque.
  Widget _icono(IconData icono, int cantidad, {required bool activo}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _conBadge(Icon(icono), cantidad),
          const SizedBox(height: 3),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: activo ? AppColors.primario : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _item(IconData inactivo, IconData activo, String label, {int badge = 0}) {
    return BottomNavigationBarItem(
      icon: _icono(inactivo, badge, activo: false),
      activeIcon: _icono(activo, badge, activo: true),
      label: label,
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
            // Barra inferior de GUIA_ESTILO_APP.md: blanca con borde superior,
            // inactivo gris, activo azul con puntito debajo.
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                color: AppColors.superficie,
                border: Border(top: BorderSide(color: AppColors.borde)),
              ),
              child: BottomNavigationBar(
                currentIndex: _indiceActual,
                onTap: _cambiarPestana,
                backgroundColor: AppColors.superficie,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppColors.primario,
                unselectedItemColor: AppColors.textoSecundario,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                elevation: 0,
                items: [
                  _item(Icons.home_outlined, Icons.home, 'Inicio'),
                  _item(Icons.bar_chart_outlined, Icons.bar_chart, 'Historial'),
                  _item(Icons.chat_bubble_outline, Icons.chat_bubble, 'Mensajes', badge: mensajes),
                  _item(Icons.spa_outlined, Icons.spa, 'Técnicas', badge: ejercicios),
                  _item(Icons.person_outline, Icons.person, 'Perfil'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
