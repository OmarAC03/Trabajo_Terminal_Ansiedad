import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mensaje.dart';
import '../providers/mensajes_provider.dart';

/// Pantalla de Mensajes (chat con especialista) — capa de UI.
///
/// Tras el refactor a capas, esta pantalla NO toca Socket.io: solo crea el
/// MensajesProvider, escucha sus cambios y dibuja, igual que Historial,
/// Perfil y Alerta.
class MensajesScreen extends StatelessWidget {
  const MensajesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return ChangeNotifierProvider(
      create: (_) => MensajesProvider(pacienteId: uid),
      child: const _MensajesView(),
    );
  }
}

class _MensajesView extends StatefulWidget {
  const _MensajesView();

  @override
  State<_MensajesView> createState() => _MensajesViewState();
}

class _MensajesViewState extends State<_MensajesView> {
  // El controlador del campo de texto es puramente de UI (foco, contenido
  // tecleado): no forma parte del estado del chat, así que vive aquí y no
  // en el provider.
  final TextEditingController _controladorTexto = TextEditingController();

  void _enviar(MensajesProvider p) {
    p.enviarMensaje(_controladorTexto.text);
    _controladorTexto.clear();
  }

  @override
  void dispose() {
    _controladorTexto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MensajesProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Chat con Especialista"),
        backgroundColor: const Color(0xFF1E6AFB),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: p.mensajes.length,
              itemBuilder: (context, index) => _buildBurbuja(p, p.mensajes[index]),
            ),
          ),
          _buildCajaTexto(p),
        ],
      ),
    );
  }

  Widget _buildBurbuja(MensajesProvider p, Mensaje msg) {
    final esMio = p.esMio(msg);
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: esMio ? const Color(0xFF1E6AFB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            bottomLeft: Radius.circular(esMio ? 15 : 0),
            topRight: const Radius.circular(15),
            bottomRight: Radius.circular(esMio ? 0 : 15),
          ),
          border: esMio ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          msg.texto,
          style: TextStyle(color: esMio ? Colors.white : Colors.black87, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCajaTexto(MensajesProvider p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controladorTexto,
              decoration: InputDecoration(
                hintText: "Escribe un mensaje...",
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _enviar(p),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF1E6AFB),
            radius: 25,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _enviar(p),
            ),
          ),
        ],
      ),
    );
  }
}
