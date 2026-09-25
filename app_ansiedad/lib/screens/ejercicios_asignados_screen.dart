import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_config.dart';
import '../models/ejercicio_asignado.dart';
import '../providers/ejercicios_provider.dart';
import '../providers/pendientes_provider.dart';
import 'tecnicas_screen.dart';

/// "Ejercicios asignados por tu especialista" (Fase 2c) — capa de UI. Se abre
/// desde la pestaña Técnicas; al entrar limpia el badge de Ejercicios. Es una
/// herramienta de apoyo, no un tratamiento (ver Disclaimers.ejercicios).
class EjerciciosAsignadosScreen extends StatelessWidget {
  const EjerciciosAsignadosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return ChangeNotifierProvider(
      create: (context) => EjerciciosProvider(
        pacienteId: uid,
        marcarVisto: context.read<PendientesProvider>().marcarVisto,
      ),
      child: const _EjerciciosView(),
    );
  }
}

const Color _azul = Color(0xFF1E6AFB);

const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String _fecha(DateTime? f) {
  if (f == null) return '';
  final minutos = f.minute.toString().padLeft(2, '0');
  return '${f.day} ${_meses[f.month - 1]} ${f.year}, ${f.hour}:$minutos';
}

class _EjerciciosView extends StatelessWidget {
  const _EjerciciosView();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EjerciciosProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Ejercicios asignados",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: p.cargar,
        child: ListView(
          padding: const EdgeInsets.all(20),
          // Para que el "jalar para actualizar" funcione aun con la lista vacía.
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text("Ejercicios asignados por tu especialista",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            const DisclaimerNota(Disclaimers.ejercicios),
            const SizedBox(height: 20),
            ..._buildContenido(context, p),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContenido(BuildContext context, EjerciciosProvider p) {
    if (p.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator(color: _azul)),
        ),
      ];
    }
    if (p.errorMsg != null) {
      return [
        _buildAviso(Icons.cloud_off, "No se pudieron cargar tus ejercicios", p.errorMsg!),
        const SizedBox(height: 12),
        Center(child: ElevatedButton(onPressed: p.cargar, child: const Text("Reintentar"))),
      ];
    }
    if (p.ejercicios.isEmpty) {
      return [
        _buildAviso(
          Icons.assignment_outlined,
          "Aún no tienes ejercicios asignados",
          "Cuando tu especialista te sugiera un ejercicio aparecerá aquí. Mientras tanto, "
              "puedes practicar cualquiera de las técnicas de relajación.",
        ),
      ];
    }
    return p.ejercicios.map((e) => _buildTarjeta(context, e, p.esNuevo(e))).toList();
  }

  Widget _buildAviso(IconData icono, String titulo, String detalle) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(icono, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(detalle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTarjeta(BuildContext context, EjercicioAsignado e, bool nuevo) {
    // Técnica de la app → se puede abrir directo. Si la app no conoce el slug
    // (versión vieja), se muestra como texto sin acción.
    final tecnica = e.tecnicaId != null ? tecnicaPorId(e.tecnicaId!) : null;
    final titulo = tecnica?.titulo ?? e.textoPersonalizado ?? e.tecnicaId ?? 'Ejercicio';
    final color = tecnica?.color ?? _azul;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: nuevo ? _azul.withValues(alpha: 0.5) : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: tecnica == null ? null : () => abrirTecnica(context, tecnica),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tecnica?.icono ?? Icons.edit_note, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          tecnica != null ? "Técnica de la app · toca para practicarla" : "Ejercicio de tu especialista",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (nuevo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _azul, borderRadius: BorderRadius.circular(10)),
                      child: const Text("Nuevo",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else if (tecnica != null)
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              if (e.nota != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(e.nota!, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3)),
                ),
              ],
              const SizedBox(height: 8),
              Text("Asignado el ${_fecha(e.fechaAsignacion)}",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
