/*
  Mi Ritmo · Firmware del sensor (ESP32 + MAX30102) · versión 2
  TT 2026-B085 · ESCOM-IPN

  Contrato con la app: SIN CAMBIOS (versión 1). Una línea JSON por segundo:
    {"v":1,"seq":124,"bpm":72,"spo2":97,"rr":[812,830],"dedo":true,"estable":true}

  Cambios respecto a la versión 1:
   1. Se procesan TODAS las muestras del FIFO a 100 Hz. Antes, getIR() y getRed() esperaban
      cada una una muestra nueva: se usaba una de cada dos (50 Hz) y el rojo y el IR venían
      de muestras distintas.
   2. El tiempo de cada latido sale del contador de muestras (10 ms por muestra, con la
      frecuencia real estimada), no de millis() en el momento de procesar.
   3. Detector propio: filtro pasa-banda Butterworth 0.5–5 Hz (dos biquads de orden 2),
      pico sistólico con umbral adaptativo, periodo refractario de 300 ms e interpolación
      parabólica del pico. Sustituye a checkForBeat() de SparkFun, que trunca la señal a
      16 bits, usa el cruce por cero como punto de referencia y descarta los latidos cuya
      amplitud filtrada supera 1000 cuentas.
   4. SpO2 con el cociente de cocientes R = (AC_rojo/DC_rojo) / (AC_IR/DC_IR) y la curva
      de referencia de Maxim. Antes se usaba rojo/IR crudo (solo DC), que no depende de
      la oxigenación. El valor NO está calibrado: se valida contra el oxímetro.
   5. La FC es la mediana de los últimos 5 intervalos RR; se reinicia al quitar el dedo.
   6. MODO_CRUDO = 1 manda por USB cada muestra ("n,ir,rojo") para validar el filtro fuera
      de línea con analiza_crudo.py. Las líneas JSON salen con prefijo "# ". El Bluetooth
      funciona igual en los dos modos.
   7. INVERTIR_CANALES = 1 para módulos con los LED rojo/IR intercambiados (kit 2).
      La captura cruda ya sale con los canales corregidos.
   8. CORRECCION_SPO2: corrección de un punto (−4) obtenida contra un oxímetro comercial.
*/
#include <Wire.h>
#include <MAX30105.h>
#include <math.h>
#include "BluetoothSerial.h"

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth clásico no está habilitado. En Arduino IDE: Tools -> seleccionar una placa ESP32 con Bluetooth.
#endif

// ===================== Configuración =====================
#ifndef MODO_CRUDO
#define MODO_CRUDO 0                       // 1 = captura cruda por USB para validar el filtro
#endif
#define NOMBRE_BT  "TT_SENSOR_CLASICO 1"   // igual que en la versión 1 (en el kit 2, su nombre de siempre)

// Algunos módulos MAX30102 genéricos traen los LED rojo e infrarrojo intercambiados.
// Se detecta con la captura cruda: si el canal "rojo" tiene más pulso (AC/DC) que el "IR",
// R sale > 1 y la SpO2 cae al piso. En ese kit se pone 1. Kit 1: 0. Kit 2: 1.
#ifndef INVERTIR_CANALES
#define INVERTIR_CANALES 0
#endif
#define SDA_PIN 32
#define SCL_PIN 33

const long  UMBRAL_DEDO         = 50000;   // IR crudo mínimo para considerar que hay dedo
const long  UMBRAL_VARIACION_IR = 15000;   // salto máximo entre muestras para "estable"
const long  IR_SATURACION       = 260000;  // cerca del tope del ADC de 18 bits (262143)
const long  RR_MIN_MS = 300;
const long  RR_MAX_MS = 2000;
const float REFRACTARIO_MS  = 300.0f;      // tras un latido se ignora este tiempo
const int   CALENTAMIENTO   = 200;         // muestras (2 s) para que el filtro se asiente
const int   SPO2_PISO       = 70;          // límites de lo que se envía (indicador interno)
// Corrección de un punto contra oxímetro de pulso comercial (12/11/2026): 11 pares, 6 personas,
// 2 kits; sesgo de la curva de Maxim = +4.15 puntos (DE 1.21). Válida solo en el rango observado
// (SpO2 del oxímetro 92–96 %). No es una calibración clínica.
const float CORRECCION_SPO2 = 4.0f;
const int   SPO2_TECHO      = 100;

BluetoothSerial SerialBT;
MAX30105 particleSensor;

// ===================== Filtro =====================
// Biquad en forma directa II transpuesta. Coeficientes Butterworth de orden 2 para fs = 100 Hz
// (scipy.signal.butter(2, 0.5, 'high', fs=100) y butter(2, 5, 'low', fs=100)).
struct Biquad {
  float b0, b1, b2, a1, a2, z1, z2;
  float paso(float x) {
    float y = b0 * x + z1;
    z1 = b1 * x - a1 * y + z2;
    z2 = b2 * x - a2 * y;
    return y;
  }
};
const Biquad PASA_ALTAS = {0.9780304792f, -1.9560609584f, 0.9780304792f, -1.9555782403f, 0.9565436765f, 0, 0};
const Biquad PASA_BAJAS = {0.0200833656f,  0.0401667311f, 0.0200833656f, -1.5610180758f, 0.6413515381f, 0, 0};

struct PasaBanda {
  Biquad pa, pb;
  // Arranca en estado estable para una entrada constante x0: sin el escalón enorme de la DC.
  void reinicia(float x0) {
    pa = PASA_ALTAS; pb = PASA_BAJAS;
    pa.z1 = -pa.b0 * x0;
    pa.z2 =  pa.b2 * x0;
  }
  float paso(float x) { return pb.paso(pa.paso(x)); }
};

// ===================== Detector de latidos =====================
struct Detector {
  PasaBanda filtro;
  float  y1, y2, amp;
  double ultimoPico;
  long   n;
  float  ultimaSalida;   // señal filtrada (sin invertir), para el AC de la SpO2

  void reinicia(float x0) {
    filtro.reinicia(x0);
    y1 = y2 = 0; amp = 0; ultimoPico = -1e9; n = 0; ultimaSalida = 0;
  }
  // x: muestra IR cruda; t: instante de esta muestra (ms); dt: ms por muestra.
  // Devuelve el instante del latido (ms) o -1 si no hubo latido.
  double muestra(float x, double t, float dt) {
    float f = filtro.paso(x);
    ultimaSalida = f;
    float y = -f;                         // invertida: la sístole queda como pico hacia arriba
    double t1 = t - dt;                   // instante de la muestra anterior (candidata a pico)
    double latido = -1;
    if (n > CALENTAMIENTO && y1 > y2 && y1 >= y && y1 > 0.5f * amp && (t1 - ultimoPico) > REFRACTARIO_MS) {
      float den = y2 - 2.0f * y1 + y;
      float desp = (den != 0.0f) ? 0.5f * (y2 - y) / den : 0.0f;   // vértice de la parábola
      latido = t1 + desp * dt;
      ultimoPico = latido;
      amp = (amp == 0.0f) ? y1 : 0.8f * amp + 0.2f * y1;
    }
    if (n > CALENTAMIENTO && (t1 - ultimoPico) > 1500.0) amp *= 0.98f;  // sin latidos: baja el umbral
    if (n == CALENTAMIENTO) amp = 0;
    y2 = y1; y1 = y; n++;
    return latido;
  }
};

Detector det;
PasaBanda filtroRojo;

// ===================== Estado =====================
bool   dedoAnterior = false;
double latidoAnterior = -1;            // -1 = no hay latido previo válido
double tMuestra = 0;                   // tiempo de la muestra actual (ms), por contador
float  msPorMuestra = 10.0f;           // se corrige con la frecuencia real medida
unsigned long t0Millis = 0;
unsigned long muestrasDesdeInicio = 0;
long   irAnterior = 0;

const int MAX_RR_POR_SEGUNDO = 10;
long rrDelSegundo[MAX_RR_POR_SEGUNDO];
int  cuentaRr = 0;

const int N_MEDIANA = 5;
long rrRecientes[N_MEDIANA];
int  nRrRecientes = 0, idxRr = 0;

// acumuladores del segundo
int    muestrasTotales = 0, muestrasConDedo = 0, muestrasEstables = 0;
double sumIrDc = 0, sumRojoDc = 0, sumIrAc2 = 0, sumRojoAc2 = 0;
int    muestrasSpo2 = 0;

const int N_R = 4;                     // promedio de R de los últimos 4 segundos
float rHist[N_R];
int   nR = 0, idxR = 0;

unsigned long ultimoEnvioMs = 0;
unsigned long numeroSecuencia = 0;
unsigned long desbordes = 0;           // veces que el búfer de 4 muestras de la librería se llenó

// ===================== Utilidades =====================
int medianaRr() {
  long v[N_MEDIANA];
  for (int i = 0; i < nRrRecientes; i++) v[i] = rrRecientes[i];
  for (int i = 1; i < nRrRecientes; i++) {          // inserción: son 5 valores
    long k = v[i]; int j = i - 1;
    while (j >= 0 && v[j] > k) { v[j + 1] = v[j]; j--; }
    v[j + 1] = k;
  }
  return (int)v[nRrRecientes / 2];
}

void reiniciaTodo() {
  latidoAnterior = -1;
  nRrRecientes = 0; idxRr = 0;
  nR = 0; idxR = 0;
}

// ===================== Procesamiento de una muestra =====================
void procesaMuestra(long ir, long rojo) {
  muestrasTotales++;
  muestrasDesdeInicio++;
  tMuestra += msPorMuestra;

  bool hayDedo = (ir > UMBRAL_DEDO);
  if (hayDedo) muestrasConDedo++;

  if (hayDedo && !dedoAnterior) {        // dedo recién puesto: filtros en estado estable
    det.reinicia((float)ir);
    filtroRojo.reinicia((float)rojo);
    latidoAnterior = -1;
  }
  dedoAnterior = hayDedo;

  if (hayDedo && irAnterior > 0 && labs(ir - irAnterior) < UMBRAL_VARIACION_IR && ir < IR_SATURACION) {
    muestrasEstables++;
  }
  irAnterior = ir;

  if (!hayDedo) return;

  double latido = det.muestra((float)ir, tMuestra, msPorMuestra);
  float acRojo = filtroRojo.paso((float)rojo);

  if (det.n > CALENTAMIENTO) {           // AC y DC para la SpO2, solo con el filtro asentado
    float acIr = det.ultimaSalida;
    sumIrAc2   += (double)acIr * acIr;
    sumRojoAc2 += (double)acRojo * acRojo;
    sumIrDc    += ir;
    sumRojoDc  += rojo;
    muestrasSpo2++;
  }

  if (latido >= 0) {
    if (latidoAnterior >= 0) {
      long rr = lround(latido - latidoAnterior);
      if (rr >= RR_MIN_MS && rr <= RR_MAX_MS) {
        if (cuentaRr < MAX_RR_POR_SEGUNDO) rrDelSegundo[cuentaRr++] = rr;
        rrRecientes[idxRr] = rr;
        idxRr = (idxRr + 1) % N_MEDIANA;
        if (nRrRecientes < N_MEDIANA) nRrRecientes++;
      }
    }
    latidoAnterior = latido;
  }
}

// ===================== Envío =====================
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

  if (SerialBT.hasClient()) SerialBT.println(linea);
#if MODO_CRUDO
  Serial.print("# ");
  Serial.println(linea);
  Serial.printf("# desbordes=%lu\n", desbordes);
#else
  Serial.println(linea);
#endif
}

void cierraSegundo() {
  bool dedo    = (muestrasTotales > 0) && (muestrasConDedo * 2 > muestrasTotales);
  bool estable = dedo && (muestrasEstables * 2 > muestrasTotales);

  int bpm = 0, spo2 = 0;
  if (dedo) {
    if (nRrRecientes >= 3) bpm = (int)lround(60000.0 / medianaRr());

    if (muestrasSpo2 > 50 && sumIrAc2 > 0 && sumRojoAc2 > 0) {
      double acIr = sqrt(sumIrAc2 / muestrasSpo2),   dcIr = sumIrDc / muestrasSpo2;
      double acRo = sqrt(sumRojoAc2 / muestrasSpo2), dcRo = sumRojoDc / muestrasSpo2;
      float R = (float)((acRo / dcRo) / (acIr / dcIr));
      rHist[idxR] = R; idxR = (idxR + 1) % N_R; if (nR < N_R) nR++;
    }
    if (nR > 0) {
      float r = 0; for (int i = 0; i < nR; i++) r += rHist[i]; r /= nR;
      float s = -45.060f * r * r + 30.354f * r + 94.845f - CORRECCION_SPO2;   // curva de Maxim corregida
      spo2 = (int)lround(s);
      if (spo2 > SPO2_TECHO) spo2 = SPO2_TECHO;
      if (spo2 < SPO2_PISO)  spo2 = SPO2_PISO;
    }
  } else {
    reiniciaTodo();
  }

  enviarPaquete(bpm, spo2, dedo, estable);

  cuentaRr = 0;
  muestrasTotales = muestrasConDedo = muestrasEstables = 0;
  sumIrDc = sumRojoDc = sumIrAc2 = sumRojoAc2 = 0; muestrasSpo2 = 0;
}

// ===================== Arduino =====================
void setup() {
  Serial.begin(115200);
  delay(300);
  SerialBT.begin(NOMBRE_BT);
  Wire.begin(SDA_PIN, SCL_PIN);

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: no se encontro el MAX30102. Revisa el cableado I2C.");
    while (1) { delay(1000); }
  }
  // LED 0x24 (~7.2 mA), promedio de 4, modo rojo+IR, 400 muestras/s -> 100 Hz efectivos,
  // pulso de 411 us (18 bits), rango del ADC 4096 nA. Igual que la versión 1.
  particleSensor.setup(0x24, 4, 2, 400, 411, 4096);
  particleSensor.setPulseAmplitudeRed(0x24);
  particleSensor.setPulseAmplitudeIR(0x24);
  particleSensor.setPulseAmplitudeGreen(0);
  particleSensor.clearFIFO();

  t0Millis = millis();
  ultimoEnvioMs = t0Millis;
}

void loop() {
  // Leer todo lo que haya en el FIFO. La librería guarda solo 4 muestras: si llegan más de 3
  // entre dos llamadas se pierden. Por eso el loop no debe tener delay().
  uint16_t nuevas = particleSensor.check();
  if (nuevas > 3) desbordes++;
  while (particleSensor.available()) {
#if INVERTIR_CANALES
    long ir   = (long)particleSensor.getFIFORed();
    long rojo = (long)particleSensor.getFIFOIR();
#else
    long rojo = (long)particleSensor.getFIFORed();
    long ir   = (long)particleSensor.getFIFOIR();
#endif
    particleSensor.nextSample();
#if MODO_CRUDO
    Serial.printf("%lu,%ld,%ld\n", muestrasDesdeInicio, ir, rojo);
#endif
    procesaMuestra(ir, rojo);
  }

  unsigned long ahora = millis();
  if (ahora - ultimoEnvioMs >= 1000) {
    ultimoEnvioMs = ahora;
    // Frecuencia real de muestreo (el oscilador del sensor no es exacto), tras 10 s de datos.
    if (muestrasDesdeInicio >= 1000) {
      float est = (float)(ahora - t0Millis) / (float)muestrasDesdeInicio;
      if (est > 9.0f && est < 11.0f) msPorMuestra = est;
    }
    cierraSegundo();
  }
}
