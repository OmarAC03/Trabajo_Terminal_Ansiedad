import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../contenido/textos_educativos.dart';
import '../logger.dart';
import '../providers/alerta_provider.dart';
import '../providers/inicio_provider.dart';
import '../repositories/perfil_repository.dart';
import '../ui/app_colors.dart';
import '../ui/formato_fecha.dart';
import '../ui/widgets.dart';
import 'medicion_screen.dart';

/// Pantalla principal del paciente (Fase M1c). Reemplaza al Monitor en vivo:
/// muestra la ÚLTIMA sesión guardada (no lecturas en vivo), explica cada
/// indicador, da consejos fijos y lleva a la medición guiada.
///
/// Nunca se ve rota: sin mediciones muestra un mensaje de primer uso; si el
/// GET falla, un aviso con "Reintentar" (nunca como primer uso). El botón, los
/// textos educativos, los consejos y el disclaimer no dependen del GET.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlertaProvider()),
        ChangeNotifierProvider(create: (_) => InicioProvider(pacienteId: uid)..cargar()),
      ],
      child: const _InicioView(),
    );
  }
}

class _InicioView extends StatelessWidget {
  const _InicioView();

  Future<void> _iniciarMedicion(BuildContext context) async {
    final alerta = context.read<AlertaProvider>();
    final inicio = context.read<InicioProvider>();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MedicionScreen(alerta: alerta)));
    // Al volver, la nueva sesión (si se guardó) pasa a ser la "última".
    inicio.cargar();
  }

  @override
  Widget build(BuildContext context) {
    final inicio = context.watch<InicioProvider>();
    final alerta = context.watch<AlertaProvider>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: RefreshIndicator(
        onRefresh: inicio.cargar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Encabezado(inicio: inicio, alerta: alerta),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BotonMedicion(
                      habilitado: alerta.modoSimulacion,
                      onTap: () => _iniciarMedicion(context),
                    ),
                    if (!alerta.modoSimulacion) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Activa la simulación (arriba) para iniciar una medición.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textoAyuda),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (inicio.sinMediciones) ...[
                      const _PrimerUso(),
                      const SizedBox(height: 16),
                    ],
                    _Indicadores(inicio),
                    if (inicio.spo2Bajo) ...[
                      const SizedBox(height: 12),
                      const Aviso(
                        TextosEducativos.avisoSpo2Bajo,
                        icono: Icons.health_and_safety_outlined,
                        color: AppColors.guia,
                        fondo: AppColors.guiaFondo,
                      ),
                    ],
                    const SizedBox(height: 24),
                    const _Consejos(),
                    const SizedBox(height: 16),
                    const DisclaimerNota(Disclaimers.inicio),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Encabezado: saludo, última medición, chip de la fuente y mascota ---

class _Encabezado extends StatefulWidget {
  final InicioProvider inicio;
  final AlertaProvider alerta;
  const _Encabezado({required this.inicio, required this.alerta});

  @override
  State<_Encabezado> createState() => _EncabezadoState();
}

class _EncabezadoState extends State<_Encabezado> {
  String? _nombre;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  /// El nombre vive en la tabla `usuarios`; se lee una vez con el
  /// PerfilRepository. Mientras carga o si falla, se usa la parte del correo.
  Future<void> _cargarNombre() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final perfil = await PerfilRepository().obtenerPerfil(uid);
      final nombre = perfil.nombre.trim();
      if (mounted && nombre.isNotEmpty) setState(() => _nombre = nombre);
    } catch (e) {
      AppLogger.warning('No se pudo cargar el nombre para el saludo', tag: 'inicio', error: e);
    }
  }

  String get _primerNombre {
    final respaldo = FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? "Paciente";
    return (_nombre ?? respaldo).split(RegExp(r'\s+')).first;
  }

  static String _saludo(DateTime ahora) {
    final h = ahora.hour;
    if (h >= 5 && h < 12) return 'Buenos días';
    if (h >= 12 && h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// Líneas bajo el saludo según el estado de la última sesión.
  List<String> _lineasMedicion(DateTime ahora) {
    final i = widget.inicio;
    final ultima = i.ultima;
    if (ultima != null) {
      return [
        'Tu última medición: ${fechaRelativa(ultima.fechaInicio, ahora: ahora)}',
        if (!mismoDia(ultima.fechaInicio, ahora)) 'Aún no has medido hoy',
      ];
    }
    return switch (i.estado) {
      EstadoInicio.cargando => ['Cargando tu última medición…'],
      EstadoInicio.error => ['No pudimos cargar tu última medición'],
      EstadoInicio.listo => ['Aún no has hecho tu primera medición'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final mascota = widget.inicio.sinMediciones ? 'mascota_saludando.png' : 'mascota_reposo.png';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.gradienteEncabezado,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_saludo(ahora)}, $_primerNombre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    for (final linea in _lineasMedicion(ahora))
                      Text(
                        linea,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                    const SizedBox(height: 12),
                    _ChipFuente(widget.alerta),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // La mascota es azul: va sobre un cuadro blanco para que no se
              // pierda en el gradiente.
              Container(
                width: 88,
                height: 88,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset('assets/mascota/$mascota', fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip translúcido con la fuente de lecturas y el interruptor de simulación.
class _ChipFuente extends StatelessWidget {
  final AlertaProvider alerta;
  const _ChipFuente(this.alerta);

  @override
  Widget build(BuildContext context) {
    final sim = alerta.modoSimulacion;
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: alerta.isScanning ? null : alerta.toggleSimulacion,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sim ? Icons.science : Icons.sensors_off, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                sim ? 'Simulación activa' : 'Sin sensor',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 2),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: sim,
                  onChanged: alerta.isScanning ? null : (_) => alerta.toggleSimulacion(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.45),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Botón principal ---

class _BotonMedicion extends StatelessWidget {
  final bool habilitado;
  final VoidCallback onTap;
  const _BotonMedicion({required this.habilitado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const minutos = ConfigMedicion.objetivoValidoSeg ~/ 60;
    final radio = BorderRadius.circular(AppColors.radio + 4);
    return Opacity(
      opacity: habilitado ? 1 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradienteEncabezado,
          borderRadius: radio,
          boxShadow: habilitado
              ? [BoxShadow(color: AppColors.primario.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radio,
            onTap: habilitado ? onTap : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Iniciar medición',
                          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Unos $minutos minutos en reposo',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Primer uso ---

class _PrimerUso extends StatelessWidget {
  const _PrimerUso();

  @override
  Widget build(BuildContext context) {
    return const Tarjeta(
      color: AppColors.primarioSuave,
      colorBorde: AppColors.primarioSuave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TextosEducativos.primerUso,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.texto, height: 1.35),
          ),
          SizedBox(height: 6),
          Text(
            TextosEducativos.sobreLaMedicion,
            style: TextStyle(fontSize: 13, color: AppColors.textoAyuda, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// --- Indicadores de la última sesión ---

class _Indicadores extends StatelessWidget {
  final InicioProvider inicio;
  const _Indicadores(this.inicio);

  @override
  Widget build(BuildContext context) {
    final s = inicio.ultima;
    final cargando = inicio.estado == EstadoInicio.cargando;
    String? valor(double? v) => v?.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: EtiquetaSeccion('Tus indicadores')),
            if (s != null)
              const Text('De tu última medición', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ],
        ),
        // Recarga fallida: se avisa sin vaciar la sesión que ya se ve.
        if (s != null && inicio.errorMsg != null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 13, color: AppColors.textoSecundario),
                SizedBox(width: 4),
                Text('No se pudo actualizar', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ],
            ),
          ),
        if (inicio.estado == EstadoInicio.error) ...[
          const SizedBox(height: 8),
          Tarjeta(
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined, color: AppColors.textoAyuda),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'No pudimos cargar tu última medición.',
                    style: TextStyle(fontSize: 13, color: AppColors.texto),
                  ),
                ),
                TextButton(
                  onPressed: inicio.recargando ? null : inicio.cargar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Tarjeta(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _FilaIndicador(
                info: TextosEducativos.hrv,
                icono: Icons.timer,
                color: AppColors.metricaHrv,
                valor: valor(s?.hrvRmssd),
                cargando: cargando,
              ),
              const Divider(height: 1, color: AppColors.borde),
              _FilaIndicador(
                info: TextosEducativos.frecuencia,
                icono: Icons.favorite,
                color: AppColors.metricaBpm,
                valor: valor(s?.bpmPromedio),
                cargando: cargando,
              ),
              const Divider(height: 1, color: AppColors.borde),
              _FilaIndicador(
                info: TextosEducativos.spo2,
                icono: Icons.water_drop,
                color: AppColors.metricaSpo2,
                valor: valor(s?.spo2Promedio),
                cargando: cargando,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fila a todo el ancho: nombre + resumen a la izquierda, valor a la derecha;
/// al tocarla se despliega la explicación del indicador.
class _FilaIndicador extends StatefulWidget {
  final InfoIndicador info;
  final IconData icono;
  final Color color;
  final String? valor;
  final bool cargando;

  const _FilaIndicador({
    required this.info,
    required this.icono,
    required this.color,
    required this.valor,
    required this.cargando,
  });

  @override
  State<_FilaIndicador> createState() => _FilaIndicadorState();
}

class _FilaIndicadorState extends State<_FilaIndicador> {
  bool _abierta = false;

  Widget _valor() {
    if (widget.valor != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(widget.valor!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.texto)),
          const SizedBox(width: 3),
          Text(widget.info.unidad, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ],
      );
    }
    if (widget.cargando) {
      return Container(
        width: 44,
        height: 18,
        decoration: BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(6)),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _abierta = !_abierta),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icono, size: 18, color: widget.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.info.nombre,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.texto),
                      ),
                      Text(widget.info.resumen, style: const TextStyle(fontSize: 12, color: AppColors.textoAyuda)),
                    ],
                  ),
                ),
                _valor(),
                AnimatedRotation(
                  turns: _abierta ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, color: AppColors.textoSecundario),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _abierta
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(46, 10, 8, 2),
                      child: Text(
                        widget.info.explicacion,
                        style: const TextStyle(fontSize: 13, color: AppColors.textoAyuda, height: 1.4),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Consejos fijos ---

class _Consejos extends StatelessWidget {
  const _Consejos();

  static const _iconos = [Icons.schedule, Icons.air, Icons.bedtime_outlined];

  @override
  Widget build(BuildContext context) {
    const consejos = TextosEducativos.consejos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EtiquetaSeccion('Consejos'),
        const SizedBox(height: 8),
        for (var i = 0; i < consejos.length; i++) ...[
          Tarjeta(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconos[i], size: 22, color: AppColors.primario),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        consejos[i].titulo,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.texto),
                      ),
                      const SizedBox(height: 4),
                      for (final punto in consejos[i].puntos)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            consejos[i].puntos.length > 1 ? '• $punto' : punto,
                            style: const TextStyle(fontSize: 13, color: AppColors.textoAyuda, height: 1.4),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (i < consejos.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
