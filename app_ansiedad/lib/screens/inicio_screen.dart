import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../contenido/textos_educativos.dart';
import '../logger.dart';
import '../medicion/aviso_sesiones.dart';
import '../medicion/mensajes_mascota.dart';
import '../models/calibracion.dart';
import '../models/sesion_medicion.dart';
import '../providers/alerta_provider.dart';
import '../providers/inicio_provider.dart';
import '../repositories/perfil_repository.dart';
import '../ui/app_colors.dart';
import '../ui/fila_indicador.dart';
import '../ui/formato_fecha.dart';
import '../ui/progreso_calibracion.dart';
import '../ui/widgets.dart';
import 'medicion_screen.dart';

/// Pantalla principal del paciente (Fase M1c). Reemplaza al Monitor en vivo:
/// muestra la ÚLTIMA sesión guardada (no lecturas en vivo), explica cada
/// indicador, da consejos fijos y lleva a la medición guiada. Desde M3, la
/// mascota acompaña la calibración de la línea base ("día X de 7") sin decir
/// nunca el estado: ni etiqueta, ni banda, ni z (regla de oro).
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
        // Se recarga sola al guardarse una sesión nueva (AvisoSesiones).
        ChangeNotifierProvider(
          create: (_) => InicioProvider(pacienteId: uid, aviso: AvisoSesiones.guardadas)..cargar(),
        ),
      ],
      child: const _InicioView(),
    );
  }
}

class _InicioView extends StatelessWidget {
  const _InicioView();

  void _iniciarMedicion(BuildContext context, {required bool yaHabiaMedidoHoy}) {
    final alerta = context.read<AlertaProvider>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MedicionScreen(alerta: alerta, yaHabiaMedidoHoy: yaHabiaMedidoHoy),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final inicio = context.watch<InicioProvider>();
    final alerta = context.watch<AlertaProvider>();
    // La base es la del origen con el que se va a medir (simulación o sensor).
    final origen = (alerta.modoSimulacion ? OrigenSesion.simulacion : OrigenSesion.sensor).valor;
    final calibracion = inicio.calibracionDe(origen);
    final mensaje = mensajeInicio(sinMediciones: inicio.sinMediciones, calibracion: calibracion);

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: RefreshIndicator(
        onRefresh: inicio.cargar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Encabezado(inicio: inicio, alerta: alerta, avatar: mensaje?.ruta),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BotonMedicion(
                      habilitado: alerta.modoSimulacion,
                      onTap: () => _iniciarMedicion(context, yaHabiaMedidoHoy: calibracion?.medidoHoy ?? false),
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
                    if (mensaje != null) ...[
                      _ConociendoTuRitmo(
                        mensaje: mensaje,
                        calibracion: inicio.sinMediciones ? null : calibracion,
                        primerUso: inicio.sinMediciones,
                      ),
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

  /// Expresión de la mascota según su mensaje (M3); null = la de antes.
  final String? avatar;
  const _Encabezado({required this.inicio, required this.alerta, this.avatar});

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
    final mascota = widget.avatar ??
        'assets/mascota/${widget.inicio.sinMediciones ? 'mascota_saludando.png' : 'mascota_reposo.png'}';

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
                child: Image.asset(mascota, fit: BoxFit.contain),
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

/// "Conociendo tu ritmo" (Fase M3): la mascota con el mensaje de su etapa y,
/// mientras la base no se consolida, los 7 puntos del "día X de 7". En el
/// primer uso es la bienvenida (reemplaza a la tarjeta de primer uso y
/// conserva su texto educativo). Celebra el hábito, nunca el valor.
class _ConociendoTuRitmo extends StatelessWidget {
  final MensajeMascota mensaje;
  final Calibracion? calibracion;
  final bool primerUso;
  const _ConociendoTuRitmo({required this.mensaje, this.calibracion, this.primerUso = false});

  @override
  Widget build(BuildContext context) {
    final c = calibracion;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Conociendo tu ritmo',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.texto),
          ),
          const SizedBox(height: 12),
          MascotaConMensaje(mensaje),
          if (c != null && mostrarProgreso(c)) ...[
            const SizedBox(height: 14),
            ProgresoCalibracion(c),
          ],
          if (primerUso) ...[
            const SizedBox(height: 12),
            const Text(
              TextosEducativos.sobreLaMedicion,
              style: TextStyle(fontSize: 13, color: AppColors.textoAyuda, height: 1.35),
            ),
          ],
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
              FilaIndicador(
                info: TextosEducativos.hrv,
                icono: Icons.timer,
                color: AppColors.metricaHrv,
                valor: valor(s?.hrvRmssd),
                cargando: cargando,
              ),
              const Divider(height: 1, color: AppColors.borde),
              FilaIndicador(
                info: TextosEducativos.frecuencia,
                icono: Icons.favorite,
                color: AppColors.metricaBpm,
                valor: valor(s?.bpmPromedio),
                cargando: cargando,
              ),
              const Divider(height: 1, color: AppColors.borde),
              FilaIndicador(
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
