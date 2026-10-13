/// Excepción de la capa de datos con un mensaje ya listo para el usuario.
/// La UI/estado la captura y muestra el mensaje sin tener que saber de HTTP.
///
/// Compartida por todos los repositorios.
class RepositoryException implements Exception {
  final String mensaje;
  RepositoryException(this.mensaje);
  @override
  String toString() => mensaje;
}
