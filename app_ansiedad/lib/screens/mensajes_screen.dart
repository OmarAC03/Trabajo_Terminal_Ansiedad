import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_auth/firebase_auth.dart';

class MensajesScreen extends StatefulWidget {
  const MensajesScreen({super.key});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  // Lista local para mostrar los mensajes en pantalla
  List<Map<String, dynamic>> _mensajes = [];
  final TextEditingController _controladorTexto = TextEditingController();
  late IO.Socket socket;

  final String _miPacienteId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _conectarSocket();
  }

  void _conectarSocket() {
    // 1. Configurar la conexión hacia tu Node.js
    socket = IO.io('https://tt-ansiedad-backend.onrender.com', IO.OptionBuilder()
        .setTransports(['websocket']) // Forzar WebSockets
        .disableAutoConnect() 
        .build());

    socket.connect();

    // 2. Evento: Confirmar conexión
    socket.onConnect((_) {
      print('✅ Conectado al servidor de Sockets');
    });

    // 3. Evento: Escuchar nuevos mensajes del servidor
    socket.on('recibir_mensaje', (data) {
      if (!mounted) return;
      setState(() {
        _mensajes.add(data);
      });
    });
  }

  void _enviarMensaje() {
    if (_controladorTexto.text.trim().isEmpty) return;

    // Armamos el paquete de datos
    final dataMensaje = {
      "paciente_id": _miPacienteId,
      "texto": _controladorTexto.text.trim(),
      "tipo_mensaje": "texto"
    };

    // Disparamos el evento hacia Node.js
    socket.emit('enviar_mensaje', dataMensaje);
    
    // Limpiamos la caja de texto
    _controladorTexto.clear();
  }

  @override
  void dispose() {
    // Apagamos el socket al salir de la pantalla
    socket.disconnect();
    socket.dispose();
    _controladorTexto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Chat con Especialista"),
        backgroundColor: const Color(0xFF1E6AFB),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Área de los mensajes
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final msg = _mensajes[index];
                // Por ahora, asumimos que todos los mensajes los enviaste tú
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E6AFB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Text(
                      msg['texto'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Caja de texto inferior
          Container(
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
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E6AFB),
                  radius: 25,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _enviarMensaje,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}