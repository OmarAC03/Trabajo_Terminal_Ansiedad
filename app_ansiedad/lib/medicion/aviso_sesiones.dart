import 'package:flutter/foundation.dart';

/// Aviso global de "se guardó una sesión nueva".
///
/// Inicio e Historial viven en un `IndexedStack` y no se recargan al cambiar de
/// pestaña: escuchan este aviso para mostrar la sesión nueva sin que el
/// paciente tenga que deslizar para refrescar. Quien guarda una sesión llama a
/// [notificarGuardada].
class AvisoSesiones {
  AvisoSesiones._();

  static final ValueNotifier<int> guardadas = ValueNotifier<int>(0);

  static void notificarGuardada() => guardadas.value++;
}
