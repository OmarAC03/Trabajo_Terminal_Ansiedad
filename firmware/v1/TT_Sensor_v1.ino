#include <Wire.h>
#include <MAX30105.h>
#include "heartRate.h"
#include "BluetoothSerial.h"

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth clásico no está habilitado. En Arduino IDE: Tools -> seleccionar una placa ESP32 con Bluetooth.
#endif

BluetoothSerial SerialBT;
MAX30105 particleSensor;

#define SDA_PIN 32
#define SCL_PIN 33

const long UMBRAL_DEDO = 50000;
const long RR_MIN_MS = 300;
const long RR_MAX_MS = 2000;
const long UMBRAL_VARIACION_IR = 15000;
const long MIN_SENIAL_SPO2 = 10000;

// Estado de Latidos
unsigned long ultimoLatidoMs = 0;
float bpmInstantaneo = 0;
int bpmPromedio = 0;

const byte TAM_PROMEDIO = 4;
byte historialBpm[TAM_PROMEDIO];
byte idxBpm = 0;

// Historial para suavizado de SpO2
byte historialSpo2[TAM_PROMEDIO];
byte idxSpo2 = 0;

const int MAX_RR_POR_SEGUNDO = 10;
long rrDelSegundo[MAX_RR_POR_SEGUNDO];
int cuentaRr = 0;

// Estado de Calidad
int spo2Actual = 0;
bool dedoPresente = false;
long irAnterior = 0;
bool senalEstable = false;

// Temporizador
unsigned long ultimoEnvioMs = 0;
const unsigned long INTERVALO_ENVIO_MS = 1000;
unsigned long numeroSecuencia = 0;

int muestrasConDedo = 0;
int muestrasEstables = 0;
int muestrasTotales = 0;

void setup() {
  Serial.begin(115200);
  delay(300);

  SerialBT.begin("TT_SENSOR_CLASICO 1");

  Wire.begin(SDA_PIN, SCL_PIN);

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: no se encontro el MAX30102. Revisa el cableado I2C.");
    while (1) { delay(1000); }
  }

  // Ajuste de brillo a 0x24 (~7.2 mA) para mejorar relación señal-ruido en tejido amplio
  particleSensor.setup(0x24, 4, 2, 400, 411, 4096);
  particleSensor.setPulseAmplitudeRed(0x24);
  particleSensor.setPulseAmplitudeIR(0x24);
  particleSensor.setPulseAmplitudeGreen(0);

  ultimoEnvioMs = millis();
}

void loop() {
  long irValue  = particleSensor.getIR();
  long redValue = particleSensor.getRed();

  muestrasTotales++;

  // 1) Presencia de dedo
  bool hayDedoAhora = (irValue > UMBRAL_DEDO);
  if (hayDedoAhora) muestrasConDedo++;

  // 2) Estabilidad de señal
  bool estableAhora = false;
  if (hayDedoAhora && irAnterior > 0) {
    long variacion = abs(irValue - irAnterior);
    estableAhora = (variacion < UMBRAL_VARIACION_IR);
    if (estableAhora) muestrasEstables++;
  }
  irAnterior = irValue;

  // 3) Detección de latido y RR
  if (hayDedoAhora && checkForBeat(irValue)) {
    unsigned long ahora = millis();

    if (ultimoLatidoMs > 0) {
      long rr = (long)(ahora - ultimoLatidoMs);

      if (rr >= RR_MIN_MS && rr <= RR_MAX_MS) {
        if (cuentaRr < MAX_RR_POR_SEGUNDO) {
          rrDelSegundo[cuentaRr++] = rr;
        }
        
        bpmInstantaneo = 60000.0 / (float)rr;
        if (bpmInstantaneo > 40 && bpmInstantaneo < 180) {
          historialBpm[idxBpm++] = (byte)bpmInstantaneo;
          idxBpm %= TAM_PROMEDIO;
          
          int suma = 0;
          for (byte i = 0; i < TAM_PROMEDIO; i++) suma += historialBpm[i];
          bpmPromedio = suma / TAM_PROMEDIO;
        }
      }
    }
    ultimoLatidoMs = ahora;
  }

// 4) Cálculo de SpO2 Calibrado (Ajuste para MAX30102 en dedo)
  if (hayDedoAhora && redValue > MIN_SENIAL_SPO2 && irValue > MIN_SENIAL_SPO2) {
    float R = (float)redValue / (float)irValue;
    
    // Curva ajustada: incrementa la constante base para elevar el piso de oxigenación a ~95%
    int spo2Calc = (int)(115.0 - (20.0 * R));
    
    if (spo2Calc > 100) spo2Calc = 100;
    if (spo2Calc < 80)  spo2Calc = 80;

    // Promedio móvil para estabilizar la lectura
    historialSpo2[idxSpo2++] = (byte)spo2Calc;
    idxSpo2 %= TAM_PROMEDIO;
    int sumaSpo2 = 0;
    for (byte i = 0; i < TAM_PROMEDIO; i++) sumaSpo2 += historialSpo2[i];
    spo2Actual = sumaSpo2 / TAM_PROMEDIO;
  }

  // 5) Envío a 1 Hz
  unsigned long ahoraMs = millis();
  if (ahoraMs - ultimoEnvioMs >= INTERVALO_ENVIO_MS) {
    ultimoEnvioMs = ahoraMs;

    dedoPresente = (muestrasTotales > 0) && (muestrasConDedo * 2 > muestrasTotales);
    senalEstable = dedoPresente && (muestrasEstables * 2 > muestrasTotales);

    int bpmEnvio  = dedoPresente ? bpmPromedio : 0;
    int spo2Envio = dedoPresente ? spo2Actual  : 0;

    enviarPaquete(bpmEnvio, spo2Envio, dedoPresente, senalEstable);

    cuentaRr = 0;
    muestrasConDedo = 0;
    muestrasEstables = 0;
    muestrasTotales = 0;

    if (!dedoPresente) {
      ultimoLatidoMs = 0;
      bpmPromedio = 0;
      spo2Actual = 0;
    }
  }
}

void enviarPaquete(int bpm, int spo2, bool dedo, bool estable) {
  numeroSecuencia++;

  String rrStr = "[";
  for (int i = 0; i < cuentaRr; i++) {
    if (i > 0) rrStr += ",";
    rrStr += String(rrDelSegundo[i]);
  }
  rrStr += "]";

  String linea = "{\"v\":1";
  linea += ",\"seq\":" + String(numeroSecuencia);
  linea += ",\"bpm\":" + String(bpm);
  linea += ",\"spo2\":" + String(spo2);
  linea += ",\"rr\":" + rrStr;
  linea += ",\"dedo\":" + String(dedo ? "true" : "false");
  linea += ",\"estable\":" + String(estable ? "true" : "false");
  linea += "}";

  if (SerialBT.hasClient()) {
    SerialBT.println(linea);
  }

  Serial.println(linea);
}