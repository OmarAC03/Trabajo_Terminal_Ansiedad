import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logger.dart';
import '../ui/estructura_acceso.dart';
import '../ui/widgets.dart';

/// Restablecer contraseña por correo (HU02, lado paciente). Mismo mecanismo
/// que `web_portal/src/RecuperarPassword.js`: Firebase manda el enlace y
/// hospeda la página donde se escribe la contraseña nueva; no pasa por el
/// backend ni por la base de datos.
class RecuperarPasswordScreen extends StatefulWidget {
  /// Correo que ya estaba escrito en el login, para no pedirlo dos veces.
  final String emailInicial;

  const RecuperarPasswordScreen({super.key, this.emailInicial = ''});

  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  // Mismo texto exista o no la cuenta: no se revela qué correos están
  // registrados (con la protección contra enumeración de Firebase activa,
  // ni siquiera avisa si el correo no existe).
  static const String _mensajeEnviado =
      'Si existe una cuenta con ese correo, te enviamos un enlace para restablecer tu contraseña. '
      'Revisa también tu carpeta de spam.';

  late final TextEditingController _emailController = TextEditingController(text: widget.emailInicial);
  bool _enviando = false;
  bool _enviado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Si el correo cambia después de enviar, el aviso ya no aplica a él.
    _emailController.addListener(() {
      if (_enviado) setState(() => _enviado = false);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Devuelve null cuando el resultado debe tratarse como envío exitoso.
  String? _mensajeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return null; // Por si la protección contra enumeración está apagada.
      case 'invalid-email':
      case 'missing-email':
        return 'Escribe un correo electrónico válido.';
      case 'too-many-requests':
        return 'Demasiadas solicitudes. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu red e inténtalo de nuevo.';
      default:
        return 'No se pudo enviar el enlace. Inténtalo de nuevo.';
    }
  }

  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _error = 'Escribe un correo electrónico válido.';
        _enviado = false;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.setLanguageCode('es'); // idioma del correo de Firebase
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _enviado = true);
    } on FirebaseAuthException catch (e, st) {
      final mensaje = _mensajeError(e);
      if (mensaje != null) {
        AppLogger.error('Error al enviar el correo de restablecimiento', tag: 'auth', error: e, stackTrace: st);
      }
      if (mounted) {
        setState(() {
          _error = mensaje;
          _enviado = mensaje == null;
        });
      }
    } catch (e, st) {
      AppLogger.error('Error inesperado al enviar el correo de restablecimiento', tag: 'auth', error: e, stackTrace: st);
      if (mounted) setState(() => _error = 'No se pudo enviar el enlace. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EstructuraAcceso(
      conRegreso: true,
      titulo: 'Restablecer contraseña',
      subtitulo: 'Te enviaremos un enlace a tu correo para crear una contraseña nueva.',
      formulario: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoTexto(
            etiqueta: 'Correo electrónico',
            controller: _emailController,
            icono: Icons.mail_outline,
            hint: 'tu@correo.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (!_enviando) _enviar();
            },
          ),
          if (_enviado) ...[
            const SizedBox(height: 16),
            const Aviso.info(_mensajeEnviado),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Aviso.error(_error!),
          ],
          const SizedBox(height: 20),
          BotonPrimario(
            texto: _enviado ? 'Reenviar enlace' : 'Enviar enlace',
            icono: Icons.send_outlined,
            cargando: _enviando,
            onPressed: _enviar,
          ),
        ],
      ),
      pie: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Volver a iniciar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
