import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../app_config.dart';
import '../logger.dart';
import '../medicion/aviso_sesiones.dart';
import '../medicion/calculo_sesion.dart';
import '../models/eva_respuesta.dart';
import '../models/lectura_cruda.dart';
import '../models/sesion_medicion.dart';
import '../repositories/sesion_repository.dart';

enum FaseMedicion { preparacion, midiendo, completada, noCompletada }

/// Qué mensaje de guía ve el paciente durante la captura. Siempre positivo y
/// accionable; nunca un veredicto sobre su medición (DISENO_FLUJO_MEDICION.md §10).
enum GuiaMedicion { detectando, midiendo, casiListo, acomodaDedo, manoQuieta }

enum EstadoEnvio { enviando, enviada, error }

/// EVA post-medición (Fase M2). `esperandoSesion`: el paciente ya respondió
/// pero la sesión aún no tiene id (se está subiendo o falló); la EVA espera en
/// memoria y se manda en cuanto llega el id.
enum EstadoEva { pendiente, esperandoSesion, enviando, guardada, omitida, error }

/// Conduce una sesión de medición guiada (Fase M1b): preparación → captura →
/// completada (y se sube sola) o no completada (se invita a reintentar). Al
/// completarse ofrece la EVA (Fase M2), opcional.
///
/// Escucha las lecturas (una por segundo) y las pasa a [AcumuladorSesion].
/// Un vigía de 1 s rellena como "sin señal" los segundos que no llegaron
/// (sensor callado, app en segundo plano), para que la duración total refleje
/// el tiempo real desde `fecha_inicio`.
class MedicionProvider extends ChangeNotifier {
  final Stream<LecturaCruda> _fuente;
  final OrigenSesion origen;
  final SesionRepository _repo;

  /// Se llama al tocar "Comenzar" (en simulación: colocar el dedo).
  final VoidCallback? alComenzar;

  /// Mantener la pantalla encendida durante la captura (wakelock_plus). Se
  /// puede sustituir en las pruebas, donde no hay plataforma.
  final Future<void> Function(bool encender) _pantallaEncendida;

  MedicionProvider({
    required Stream<LecturaCruda> fuente,
    required this.origen,
    this.alComenzar,
    SesionRepository? repo,
    Future<void> Function(bool encender)? pantallaEncendida,
  })  : _fuente = fuente,
        _repo = repo ?? SesionRepository(),
        _pantallaEncendida = pantallaEncendida ?? ((encender) => WakelockPlus.toggle(enable: encender));

  static final _sinSenal = LecturaCruda(bpm: 0, spo2: 0, hrv: 0, dedo: false, estable: false);

  FaseMedicion _fase = FaseMedicion.preparacion;
  FaseMedicion get fase => _fase;

  AcumuladorSesion? _acumulador;
  StreamSubscription<LecturaCruda>? _sub;
  Timer? _vigia;
  bool _enSegundoPlano = false;

  MotivoSenal _ultimoMotivo = MotivoSenal.valida;
  int _invalidosSeguidos = 0;

  SesionMedicion? _sesion;
  SesionMedicion? get sesion => _sesion;

  EstadoEnvio? _estadoEnvio;
  EstadoEnvio? get estadoEnvio => _estadoEnvio;
  String? _errorEnvio;
  String? get errorEnvio => _errorEnvio;

  /// Id que el backend asignó a la sesión (necesario para guardar la EVA).
  String? _sesionId;

  EstadoEva _estadoEva = EstadoEva.pendiente;
  EstadoEva get estadoEva => _estadoEva;
  EvaRespuesta? _eva;
  String? _errorEva;
  String? get errorEva => _errorEva;

  /// "Listo" se habilita con la sesión guardada y la EVA guardada u omitida.
  bool get puedeTerminar =>
      _fase == FaseMedicion.completada &&
      _estadoEnvio == EstadoEnvio.enviada &&
      (_estadoEva == EstadoEva.guardada || _estadoEva == EstadoEva.omitida);

  double get progreso => _acumulador?.progreso ?? 0;

  /// Segundos de señal válida que faltan para completar.
  int get segundosRestantes =>
      ConfigMedicion.objetivoValidoSeg - (_acumulador?.segundosValidos ?? 0);

  GuiaMedicion get guia {
    final a = _acumulador;
    if (a == null) return GuiaMedicion.detectando;
    // Un segundo malo aislado solo pausa el anillo; la guía aparece si dura.
    if (_invalidosSeguidos >= 2) {
      if (_ultimoMotivo == MotivoSenal.sinDedo) return GuiaMedicion.acomodaDedo;
      if (a.segundosValidos > 0) return GuiaMedicion.manoQuieta;
    }
    if (a.segundosValidos == 0) return GuiaMedicion.detectando;
    if (progreso >= 0.9) return GuiaMedicion.casiListo;
    return GuiaMedicion.midiendo;
  }

  /// La señal es buena ahora mismo (para animar el pulso).
  bool get senalBuena => _invalidosSeguidos == 0 && (_acumulador?.segundosValidos ?? 0) > 0;

  /// Se puede salir sin perder nada: no hay captura en curso, la sesión está
  /// guardada y no hay una EVA ya respondida esperando a enviarse. Salir con la
  /// EVA sin responder equivale a omitirla (es opcional).
  bool get puedeSalirSinConfirmar =>
      _fase == FaseMedicion.preparacion ||
      _fase == FaseMedicion.noCompletada ||
      (_fase == FaseMedicion.completada &&
          _estadoEnvio == EstadoEnvio.enviada &&
          _estadoEva != EstadoEva.esperandoSesion &&
          _estadoEva != EstadoEva.enviando);

  void comenzar() {
    if (_fase == FaseMedicion.midiendo) return;
    _acumulador = AcumuladorSesion(fechaInicio: DateTime.now());
    _ultimoMotivo = MotivoSenal.valida;
    _invalidosSeguidos = 0;
    _sesion = null;
    _sesionId = null;
    _estadoEnvio = null;
    _errorEnvio = null;
    _estadoEva = EstadoEva.pendiente;
    _eva = null;
    _errorEva = null;
    _fase = FaseMedicion.midiendo;

    alComenzar?.call();
    _sub = _fuente.listen(_registrar);
    _vigia = Timer.periodic(const Duration(seconds: 1), (_) => _vigilar());
    _pantalla(true);
    notifyListeners();
  }

  void _pantalla(bool encender) {
    _pantallaEncendida(encender).catchError((Object e) {
      AppLogger.warning('No se pudo cambiar el bloqueo de pantalla', tag: 'medicion', error: e);
    });
  }

  /// Vuelve a la pantalla de indicaciones (tras una medición no completada).
  void reiniciar() {
    _detener();
    _acumulador = null;
    _fase = FaseMedicion.preparacion;
    notifyListeners();
  }

  void cancelar() => _detener();

  /// Mientras la app está en segundo plano, lo que llegue no cuenta como válido.
  void setSegundoPlano(bool valor) => _enSegundoPlano = valor;

  void _registrar(LecturaCruda lectura) {
    if (_fase != FaseMedicion.midiendo) return;
    _rellenarHuecos();
    if (_fase != FaseMedicion.midiendo) return;
    _anotar(_acumulador!.agregar(_enSegundoPlano ? _sinSenal : lectura));
    _revisarTermino();
    notifyListeners();
  }

  void _vigilar() {
    if (_fase != FaseMedicion.midiendo) return;
    final antes = _acumulador!.segundosTotales;
    _rellenarHuecos();
    if (_acumulador!.segundosTotales != antes) {
      _revisarTermino();
      notifyListeners();
    }
  }

  /// Registra como "sin señal" los segundos transcurridos que no trajeron
  /// lectura. Se tolera 1 s de desfase entre el reloj y la fuente.
  void _rellenarHuecos() {
    final a = _acumulador!;
    final transcurridos = DateTime.now().difference(a.fechaInicio).inSeconds;
    while (a.segundosTotales < transcurridos - 1 && !a.agotada) {
      _anotar(a.agregar(_sinSenal));
    }
    _revisarTermino();
  }

  void _anotar(MotivoSenal motivo) {
    _ultimoMotivo = motivo;
    _invalidosSeguidos = motivo == MotivoSenal.valida ? 0 : _invalidosSeguidos + 1;
  }

  void _revisarTermino() {
    final a = _acumulador!;
    if (_fase != FaseMedicion.midiendo) return;
    if (a.completa) {
      _detener();
      try {
        _sesion = a.construir(origen: origen);
        _fase = FaseMedicion.completada;
        enviar();
      } on StateError catch (e) {
        AppLogger.warning('Sesión completa sin datos suficientes: ${e.message}', tag: 'medicion');
        _fase = FaseMedicion.noCompletada;
      }
    } else if (a.agotada) {
      _detener();
      _fase = FaseMedicion.noCompletada;
    }
  }

  /// Sube la sesión. Si falla, queda en memoria para "Reintentar envío".
  Future<void> enviar() async {
    final s = _sesion;
    if (s == null || _estadoEnvio == EstadoEnvio.enviando || _estadoEnvio == EstadoEnvio.enviada) return;
    _estadoEnvio = EstadoEnvio.enviando;
    _errorEnvio = null;
    notifyListeners();
    try {
      final id = await _repo.enviarSesion(s);
      AppLogger.info('Sesión de medición guardada ($id)', tag: 'medicion');
      _sesionId = id;
      _estadoEnvio = EstadoEnvio.enviada;
      // Inicio e Historial se recargan solos con la sesión nueva.
      AvisoSesiones.notificarGuardada();
      // Si el paciente ya respondió la EVA mientras se subía la sesión, se
      // manda ahora que hay id.
      if (_estadoEva == EstadoEva.esperandoSesion) _enviarEva();
    } on RepositoryException catch (e) {
      _estadoEnvio = EstadoEnvio.error;
      _errorEnvio = e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al guardar la sesión', tag: 'medicion', error: e, stackTrace: stackTrace);
      _estadoEnvio = EstadoEnvio.error;
      _errorEnvio = 'Ocurrió un error inesperado.';
    }
    // El paciente pudo salir de la pantalla mientras se enviaba.
    if (!_desechado) notifyListeners();
  }

  // --- EVA post-medición (Fase M2) ---

  /// El paciente tocó "Guardar". Si la sesión ya tiene id se envía; si no,
  /// espera en memoria hasta que la sesión termine de subirse.
  void responderEva(EvaRespuesta eva) {
    if (_estadoEva != EstadoEva.pendiente) return;
    _eva = eva;
    if (_sesionId != null) {
      _enviarEva();
    } else {
      _estadoEva = EstadoEva.esperandoSesion;
      notifyListeners();
    }
  }

  /// "Omitir": no se guarda nada (la EVA omitida es ausencia de fila). También
  /// sirve para salir de un error de envío sin guardar la respuesta.
  void omitirEva() {
    if (_estadoEva != EstadoEva.pendiente && _estadoEva != EstadoEva.error) return;
    _estadoEva = EstadoEva.omitida;
    _eva = null;
    _errorEva = null;
    notifyListeners();
  }

  /// "Reintentar" tras un error al guardar la EVA.
  void reintentarEva() {
    if (_estadoEva == EstadoEva.error && _sesionId != null) _enviarEva();
  }

  Future<void> _enviarEva() async {
    final eva = _eva;
    final sesionId = _sesionId;
    if (eva == null || sesionId == null) return;
    _estadoEva = EstadoEva.enviando;
    _errorEva = null;
    notifyListeners();
    try {
      await _repo.enviarEva(sesionId, eva);
      _estadoEva = EstadoEva.guardada;
    } on RepositoryException catch (e) {
      _estadoEva = EstadoEva.error;
      _errorEva = e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al guardar la EVA', tag: 'medicion', error: e, stackTrace: stackTrace);
      _estadoEva = EstadoEva.error;
      _errorEva = 'Ocurrió un error inesperado.';
    }
    if (!_desechado) notifyListeners();
  }

  void _detener() {
    _sub?.cancel();
    _sub = null;
    _vigia?.cancel();
    _vigia = null;
    _pantalla(false);
  }

  bool _desechado = false;

  @override
  void dispose() {
    _desechado = true;
    _detener();
    super.dispose();
  }
}
