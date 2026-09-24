import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mensaje.dart';
import '../providers/mensajes_provider.dart';
import 'vinculacion_screen.dart';

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

  Future<void> _enviar(MensajesProvider p) async {
    final texto = _controladorTexto.text;
    if (texto.trim().isEmpty) return;
    _controladorTexto.clear();

    final error = await p.enviarMensaje(texto);
    if (error == null || !mounted) return;
    // Si no se pudo enviar, se devuelve el texto al campo para no perderlo.
    _controladorTexto.text = texto;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ $error"), backgroundColor: Colors.red),
    );
  }

  Future<void> _irAVincular(MensajesProvider p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VinculacionScreen()));
    if (mounted) p.cargar();
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
        title: Text(p.especialistaNombre != null ? "Chat con ${p.especialistaNombre}" : "Chat con Especialista"),
        backgroundColor: const Color(0xFF1E6AFB),
        foregroundColor: Colors.white,
      ),
      body: _buildCuerpo(p),
    );
  }

  Widget _buildCuerpo(MensajesProvider p) {
    switch (p.estado) {
      case EstadoChat.cargando:
        return const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)));
      case EstadoChat.sinEspecialista:
        return _buildAviso(
          Icons.link_off,
          "Aún no tienes un especialista vinculado",
          "Vincúlate con el código que te dio tu especialista para poder chatear.",
          "Vincular especialista",
          () => _irAVincular(p),
        );
      case EstadoChat.error:
        return _buildAviso(Icons.cloud_off, "No se pudo abrir el chat", p.errorMsg ?? "", "Reintentar", p.cargar);
      case EstadoChat.listo:
        return Column(
          children: [
            Expanded(
              child: p.mensajes.isEmpty
                  ? Center(child: Text("Aún no hay mensajes. ¡Escribe el primero!", style: TextStyle(color: Colors.grey.shade500)))
                  // reverse: la lista arranca abajo (en el último mensaje), como
                  // cualquier chat, sin tener que manejar un ScrollController.
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: p.mensajes.length,
                      itemBuilder: (context, index) => _buildBurbuja(p, p.mensajes[p.mensajes.length - 1 - index]),
                    ),
            ),
            _buildCajaTexto(p),
          ],
        );
    }
  }

  Widget _buildAviso(IconData icono, String titulo, String detalle, String boton, VoidCallback onPressed) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(detalle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 15),
            ElevatedButton(onPressed: onPressed, child: Text(boton)),
          ],
        ),
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
