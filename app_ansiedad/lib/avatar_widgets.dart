import 'package:flutter/material.dart';
import 'ui/app_colors.dart';

/// Avatares de perfil (versión final, punto 5): las expresiones exportadas de
/// la mascota (assets/mascota, con sus variantes 2.0x y 3.0x). Se guardan en
/// `photoURL` de Firebase Auth como `avatar:<id>` (ej. `avatar:feliz`).
///
/// Se ofrecen 11 de las 12 expresiones: `avatar_preocupado` queda fuera y no
/// se muestran nombres, para que el avatar no parezca una etiqueta del estado
/// del paciente (regla de oro).
enum TipoAvatar { feliz, saludando, sereno, celebrando, genial, guinando, jugueton, meditando, concentrado, pensativo, neutral }

/// Los animales de antes (zorro, gato…): las cuentas que tenían uno guardado
/// ven la mascota feliz en su lugar, sin perder su elección de "tener avatar".
const Set<String> _avataresAnteriores = {'zorro', 'gato', 'buho', 'panda', 'conejo', 'oso'};

const TipoAvatar avatarPorDefecto = TipoAvatar.feliz;

extension TipoAvatarInfo on TipoAvatar {
  String get id => name;

  String get ruta => 'assets/mascota/avatar_$id.png';

  static TipoAvatar? desdeId(String? id) {
    if (id == null) return null;
    for (final t in TipoAvatar.values) {
      if (t.id == id) return t;
    }
    if (_avataresAnteriores.contains(id)) return avatarPorDefecto;
    return null;
  }
}

/// Extrae el TipoAvatar guardado en el `photoURL` de Firebase, si existe.
/// Formato esperado: "avatar:feliz". Si el campo trae otra cosa (o es nulo,
/// como en cuentas sin avatar), devuelve null.
TipoAvatar? avatarDesdePhotoUrl(String? photoUrl) {
  if (photoUrl == null || !photoUrl.startsWith('avatar:')) return null;
  return TipoAvatarInfo.desdeId(photoUrl.substring('avatar:'.length));
}

String avatarAPhotoUrl(TipoAvatar tipo) => 'avatar:${tipo.id}';

// =============================================================
// WIDGET: círculo blanco con la mascota adentro
// =============================================================
class MascotaAvatar extends StatelessWidget {
  final TipoAvatar tipo;
  final double size;

  const MascotaAvatar({super.key, required this.tipo, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.primarioSuave, width: 2),
      ),
      child: ClipOval(child: Image.asset(tipo.ruta, fit: BoxFit.contain)),
    );
  }
}

// =============================================================
// SELECTOR: hoja inferior con la cuadrícula de opciones
// =============================================================
Future<TipoAvatar?> mostrarSelectorAvatar(BuildContext context, {TipoAvatar? actual}) {
  return showModalBottomSheet<TipoAvatar>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SelectorAvatar(actual: actual, onElegir: (t) => Navigator.pop(context, t)),
  );
}

class SelectorAvatar extends StatelessWidget {
  final TipoAvatar? actual;
  final ValueChanged<TipoAvatar> onElegir;
  const SelectorAvatar({super.key, this.actual, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Elige tu avatar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: [
                for (final (i, tipo) in TipoAvatar.values.indexed)
                  Semantics(
                    button: true,
                    selected: tipo == actual,
                    label: 'Avatar ${i + 1}',
                    child: GestureDetector(
                      onTap: () => onElegir(tipo),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tipo == actual ? AppColors.primario : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: MascotaAvatar(tipo: tipo),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
