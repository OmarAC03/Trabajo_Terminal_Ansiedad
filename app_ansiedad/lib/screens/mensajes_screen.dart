import 'package:flutter/material.dart';

// --- MODELO DE DATOS PARA EL CHAT ---
// Esto nos prepara para recibir JSONs desde tu servidor Node.js mañana
class Mensaje {
  final String tipo; // 'especialista', 'usuario', 'sistema'
  final String texto;
  final String hora;
  final String? remitente;
  final String? iniciales;

  Mensaje({
    required this.tipo,
    required this.texto,
    required this.hora,
    this.remitente,
    this.iniciales,
  });
}

class MensajesScreen extends StatefulWidget {
  const MensajesScreen({super.key});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  final TextEditingController _controladorMensaje = TextEditingController();
  
  // --- HISTORIAL DE CHAT MOCKEADO (Basado en tu diseño) ---
  final List<Mensaje> _mensajes = [
    Mensaje(
      tipo: 'especialista',
      texto: 'Hola Omar, he revisado tus métricas de hoy. Tu nivel de ansiedad ha aumentado. Te recomiendo practicar la técnica de respiración 4-7-8 antes de dormir.',
      hora: 'Hace 2 horas',
      remitente: 'Dra. Morales',
      iniciales: 'DM',
    ),
    Mensaje(
      tipo: 'usuario',
      texto: 'Gracias Dra. Morales, lo haré esta noche. He estado un poco estresado por el trabajo en mesa de ayuda.',
      hora: 'Hace 1 hora',
    ),
    Mensaje(
      tipo: 'especialista',
      texto: 'Es comprensible. Recuerda que puedes usar el botón de alerta si sientes que los síntomas empeoran. También he programado una cita para el viernes.',
      hora: 'Hace 45 min',
      remitente: 'Dra. Morales',
      iniciales: 'DM',
    ),
    Mensaje(
      tipo: 'sistema',
      texto: 'Recordatorio: Tu próxima cita es el viernes 18 a las 10:00 AM',
      hora: 'Hace 30 min',
    ),
  ];

  void _enviarMensaje() {
    if (_controladorMensaje.text.trim().isEmpty) return;
    
    setState(() {
      _mensajes.add(
        Mensaje(
          tipo: 'usuario',
          texto: _controladorMensaje.text,
          hora: 'Ahora',
        ),
      );
      _controladorMensaje.clear();
    });
    
    // Aquí mañana pondremos: socket.emit('chat_message', texto);
  }

  @override
  Widget build(BuildContext context) {
    const Color azulPrimario = Color(0xFF1E6AFB);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Column(
        children: [
          // --- HEADER AZUL (Idéntico a la pantalla principal) ---
          Container(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              color: azulPrimario,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Buenos días,", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
                        const Text("Omar Ángeles", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        Text("Último sync: hace 2 min", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                      SizedBox(width: 8),
                      Text("Sensor conectado · ESP32", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- TÍTULO DEL CHAT Y BADGE ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: azulPrimario, size: 28),
                const SizedBox(width: 10),
                const Text("Mensajes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: azulPrimario.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: const Text("1 nuevo", style: TextStyle(color: azulPrimario, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
          ),

          // --- LISTA DE MENSAJES (El Chat) ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final msg = _mensajes[index];
                if (msg.tipo == 'especialista') return _buildEspecialistaBubble(msg);
                if (msg.tipo == 'sistema') return _buildSistemaBubble(msg);
                return _buildUsuarioBubble(msg);
              },
            ),
          ),

          // --- BARRA DE ENTRADA DE TEXTO ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controladorMensaje,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: const Color(0xFFF6F8FB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _enviarMensaje,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: azulPrimario,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE BURBUJAS DE CHAT ---

  Widget _buildEspecialistaBubble(Mensaje msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15, right: 40),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF1E6AFB).withOpacity(0.1),
                child: Text(msg.iniciales!, style: const TextStyle(color: Color(0xFF1E6AFB), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(msg.remitente!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Text("Especialista", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(msg.texto, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(msg.hora, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildUsuarioBubble(Mensaje msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 40),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E6AFB),
        borderRadius: BorderRadius.circular(20).copyWith(bottomRight: const Radius.circular(5)),
        boxShadow: [BoxShadow(color: const Color(0xFF1E6AFB).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.texto, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.access_time, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(msg.hora, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(width: 8),
              const Icon(Icons.done_all, size: 14, color: Colors.white),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSistemaBubble(Mensaje msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Naranja muy claro
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sistema", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange)),
          const SizedBox(height: 8),
          Text(msg.texto, style: TextStyle(color: Colors.orange[900], fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.orange[300]),
              const SizedBox(width: 4),
              Text(msg.hora, style: TextStyle(color: Colors.orange[300], fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }
}