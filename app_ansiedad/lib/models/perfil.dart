/// El perfil del usuario tal como lo devuelve el backend (tabla `usuarios`).
///
/// Reemplaza el `Map<String, dynamic>` suelto que PerfilScreen manejaba antes.
class Perfil {
  final String nombre;
  final String email;
  final String rol; // 'paciente' | 'especialista'

  Perfil({required this.nombre, required this.email, required this.rol});

  factory Perfil.fromJson(Map<String, dynamic> json, {String emailRespaldo = ''}) {
    return Perfil(
      nombre: (json['nombre'] ?? '').toString(),
      email: (json['email'] ?? emailRespaldo).toString(),
      rol: (json['rol'] ?? 'paciente').toString(),
    );
  }
}
