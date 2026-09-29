import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mensaje.dart';
import '../providers/mensajes_provider.dart';
import '../ui/app_colors.dart';
import '../ui/widgets.dart';
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
      SnackBar(content: Text("❌ $error"), backgroundColor: AppColors.altos),
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
      backgroundColor: AppColors.fondo,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoGradiente(
            icono: Icons.chat_bubble_outline,
            titulo: "Mensajes",
            subtitulo: p.especialistaNombre != null
                ? "Conversación con ${p.especialistaNombre}"
                : "Chat con tu especialista",
          ),
          Expanded(child: _buildCuerpo(p)),
        ],
      ),
    );
  }

  Widget _buildCuerpo(MensajesProvider p) {
    switch (p.estado) {
      case EstadoChat.cargando:
        return const Center(child: CircularProgressIndicator(color: AppColors.primario));
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
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text("Aún no hay mensajes. ¡Escribe el primero!",
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textoAyuda)),
                      ),
                    )
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.primarioSuave, shape: BoxShape.circle),
              child: Icon(icono, size: 34, color: AppColors.primario),
            ),
            const SizedBox(height: 15),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.texto, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(detalle,
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoAyuda, fontSize: 13)),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onPressed, child: Text(boton)),
          ],
        ),
      ),
    );
  }

  static String _hora(DateTime? f) =>
      f == null ? '' : "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";

  /// Burbujas como en el portal: las propias en azul a la derecha, las del
  /// especialista en blanco con borde a la izquierda; hora debajo.
  Widget _buildBurbuja(MensajesProvider p, Mensaje msg) {
    final esMio = p.esMio(msg);
    final hora = _hora(msg.fechaEnvio);
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: esMio ? AppColors.primario : AppColors.superficie,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(esMio ? 16 : 4),
                    bottomRight: Radius.circular(esMio ? 4 : 16),
                  ),
                  border: esMio ? null : Border.all(color: AppColors.borde),
                  boxShadow: AppColors.sombra,
                ),
                child: Text(
                  msg.texto,
                  style: TextStyle(color: esMio ? Colors.white : AppColors.texto, fontSize: 15, height: 1.3),
                ),
              ),
              if (hora.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(hora, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCajaTexto(MensajesProvider p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.superficie,
        border: Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controladorTexto,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: AppColors.texto, fontSize: 15),
              decoration: InputDecoration(
                hintText: "Escribe un mensaje...",
                fillColor: AppColors.fondo,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.borde),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.borde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primario, width: 2),
                ),
              ),
              onSubmitted: (_) => _enviar(p),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primario,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              tooltip: "Enviar",
              onPressed: () => _enviar(p),
            ),
          ),
        ],
      ),
    );
  }
}
