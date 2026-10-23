/// Estado de la conexión con el sensor físico y lo que se le dice al paciente
/// (Fase M7a, paso 4). Lógica pura, sin Flutter: se prueba con `flutter test`
/// (test/estado_sensor_test.dart).
///
/// Los textos hablan de la CONEXIÓN, nunca de la medición: sin valores, sin
/// etiquetas (normal / elevados / altos), como el resto de la app del paciente.
library;

/// De dónde salen las lecturas de la medición.
enum FuenteLecturas { ninguna, simulacion, sensor }

enum EstadoSensor {
  /// Aún no se ha intentado conectar.
  desconectado,

  /// Pidiendo permisos, buscando el dispositivo vinculado y abriendo la conexión.
  buscando,

  /// Conectado; esperando los primeros paquetes para saber si el firmware
  /// habla el contrato (`CONTRATO_SENSOR.md`).
  verificando,

  /// Conectado y compatible: se puede medir.
  listo,

  /// No hay un dispositivo `TT_SENSOR_CLASICO` vinculado en el celular.
  noVinculado,

  /// El paciente no dio el permiso de Bluetooth (dispositivos cercanos).
  sinPermisos,

  /// El firmware no manda el contrato v1 (por ejemplo, el que manda `hrv`).
  noCompatible,

  /// Se conectó, pero no llegó ningún paquete en el tiempo límite.
  sinDatos,

  /// La conexión se cayó (sensor apagado o fuera de alcance).
  perdido,

  /// No se pudo abrir la conexión (sensor apagado, lejos u ocupado).
  error,
}

/// Nombre con el que el paciente busca el sensor en los ajustes de Bluetooth.
const nombreSensor = 'TT_SENSOR_CLASICO';

/// El sensor está trabajando (se muestra un indicador de progreso).
bool sensorOcupado(EstadoSensor e) => e == EstadoSensor.buscando || e == EstadoSensor.verificando;

/// El estado ofrece "Reintentar".
bool sensorReintentable(EstadoSensor e) => switch (e) {
      EstadoSensor.noVinculado ||
      EstadoSensor.sinPermisos ||
      EstadoSensor.noCompatible ||
      EstadoSensor.sinDatos ||
      EstadoSensor.perdido ||
      EstadoSensor.error =>
        true,
      _ => false,
    };

/// Texto para el paciente según el estado de la conexión.
String textoEstadoSensor(EstadoSensor e) => switch (e) {
      EstadoSensor.desconectado => 'Toca "Sensor" (arriba) para conectarlo.',
      EstadoSensor.buscando => 'Buscando tu sensor…',
      EstadoSensor.verificando => 'Conectando con tu sensor…',
      EstadoSensor.listo => 'Sensor conectado. Ya puedes iniciar tu medición.',
      EstadoSensor.noVinculado =>
        'Vincula $nombreSensor en los ajustes de Bluetooth del celular y vuelve a intentar.',
      EstadoSensor.sinPermisos =>
        'Para usar el sensor, permite el acceso a "Dispositivos cercanos" (Bluetooth) en los ajustes de la app.',
      EstadoSensor.noCompatible =>
        'Tu sensor necesita una actualización de su programa (firmware) para medir con esta app.',
      EstadoSensor.sinDatos =>
        'El sensor se conectó, pero no llegan datos. Revisa que esté encendido y vuelve a intentar.',
      EstadoSensor.perdido => 'Se perdió la conexión con el sensor. Revisa que esté encendido y cerca.',
      EstadoSensor.error => 'No se pudo conectar con el sensor. Revisa que esté encendido y cerca del celular.',
    };
