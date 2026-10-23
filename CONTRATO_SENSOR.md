# Contrato de datos del sensor (ESP32 → app)

> **Versión del contrato: 1** · Fase M7a (integración del sensor físico) · Estado: **BORRADOR, por validar con el firmware**
>
> Este documento define **qué debe mandar el ESP32 por Bluetooth** para que la app pueda medir
> la variabilidad de la frecuencia cardiaca (HRV, RMSSD) con el sensor real. La app ya funciona
> con este formato en modo simulación; falta que el firmware lo mande.

---

## ⚠️ ANTES DE EMPEZAR: frecuencia de muestreo del MAX30102

**Esto es lo más importante del contrato y hay que confirmarlo primero.**

La app calcula el RMSSD con los intervalos entre latidos (`rr`). El RMSSD en reposo de un
estudiante suele estar entre **20 y 60 ms**, así que el error de cada RR tiene que ser bastante
menor que eso. El error depende de cada cuánto se muestrea la señal del MAX30102:

| Muestreo del MAX30102 | Resolución de cada RR | ¿Sirve para RMSSD? |
|---|---|---|
| 50 Hz | ±20 ms | ❌ No: el error es del tamaño del propio RMSSD |
| **100 Hz** | **±10 ms** | ⚠️ **Mínimo aceptable** |
| **200 Hz** (o 100 Hz con interpolación del pico) | ±5 ms o mejor | ✅ **Recomendado** |

**Preguntas para el firmware (responder antes de cerrar el contrato):**

1. ¿A qué frecuencia está configurado hoy el MAX30102 (`sampleRate`) y cuánto se puede subir
   sin que el ESP32 se atrase?
2. ¿Cómo se detecta cada latido (pico de la señal IR, cruce por umbral, otro)? ¿Se puede
   interpolar el pico (por ejemplo, parabólica sobre las 3 muestras alrededor del máximo)?
3. ¿Se puede calcular `dedo` y `estable` (ver abajo) con lo que ya mide el firmware?
4. ¿El envío de 1 paquete por segundo puede ir con un temporizador propio, independiente de los
   latidos?

---

## 1. Conexión

- **Bluetooth clásico (SPP / `BluetoothSerial`)**, igual que hoy. **No BLE.**
- Nombre del dispositivo: **`TT_SENSOR_CLASICO`** (la app busca ese nombre entre los
  dispositivos ya vinculados en el celular).
- El ESP32 solo envía; la app no le manda comandos (por ahora).

## 2. Formato: una línea JSON por segundo

**Un paquete por segundo (1 Hz)**, no uno por latido. La app cuenta el tiempo de la medición por
segundos (cada paquete es un segundo; la medición necesita 180 segundos válidos). Los latidos de
ese segundo viajan dentro del arreglo `rr`.

```json
{"v":1,"seq":1234,"bpm":72,"spo2":97,"rr":[812,798],"dedo":true,"estable":true}
```

Seguido de un salto de línea `\n`.

| Campo | Tipo | Significado | Obligatorio |
|---|---|---|---|
| `v` | entero | Versión del contrato. Hoy siempre `1`. | Sí |
| `seq` | entero | Contador que sube de 1 en 1 con cada paquete (puede reiniciar en 0 al encender). La app lo usa para detectar paquetes perdidos. | Sí |
| `bpm` | entero | Frecuencia cardiaca del momento. `0` si no hay señal válida. | Sí |
| `spo2` | entero | SpO2 en %. `0` si no hay señal válida. | Sí |
| `rr` | arreglo de enteros (ms) | **Intervalos entre latidos CRUDOS** que terminaron desde el paquete anterior, en orden. **Sin promediar, sin filtrar, sin suavizar.** `[]` si en ese segundo no terminó ningún latido. | Sí (aunque vaya vacío) |
| `dedo` | booleano | `true` si hay un dedo sobre el sensor (señal IR por encima del umbral de presencia). | Sí |
| `estable` | booleano | `true` si la señal es usable: no está saturada y la amplitud de los picos es estable (sin movimiento). | Sí |

**Ya no se manda `hrv`.** El RMSSD lo calcula la app a partir de `rr`. Si el firmware lo sigue
mandando, la app lo ignora (no estorba).

## 3. Reglas del envío

1. **Todos los campos, siempre**, en todos los paquetes. Un paquete al que le falte cualquiera de
   `v`, `seq`, `rr`, `dedo` o `estable` cuenta como **segundo sin señal** (nunca se da por bueno).
2. **Una línea por paquete**, terminada en `\n` (se acepta `\r\n`). JSON compacto, sin espacios
   ni saltos de línea dentro. **Solo ASCII.** Menos de 200 bytes por línea.
3. **1 paquete por segundo**, con su propio temporizador. Si por algún motivo llegan dos
   paquetes en el mismo segundo, la app los junta (suma sus `rr`), pero lo correcto es 1 Hz.
4. **`seq` consecutivo.** Si la app ve un salto (por ejemplo 40 → 42), asume que se perdió un
   paquete y **no** calcula la diferencia entre el último RR antes del hueco y el primero después.
5. **RR crudos y completos.** Cada latido detectado aparece exactamente una vez, en el paquete del
   segundo en que terminó. No se repite en el siguiente paquete.
6. **Sin dedo o con señal mala se sigue mandando el paquete** (con `dedo:false` o
   `estable:false`, y `bpm`/`spo2` en `0` si no hay valor). La app necesita esos segundos para
   guiar al paciente ("Acomoda tu dedo", "Mantén la mano quieta").

## 4. Ejemplos

Señal buena, dos latidos en este segundo:
```json
{"v":1,"seq":101,"bpm":74,"spo2":98,"rr":[805,812],"dedo":true,"estable":true}
```

Señal buena, ningún latido terminó en este segundo (normal con FC baja):
```json
{"v":1,"seq":102,"bpm":71,"spo2":98,"rr":[],"dedo":true,"estable":true}
```

Sin dedo:
```json
{"v":1,"seq":103,"bpm":0,"spo2":0,"rr":[],"dedo":false,"estable":false}
```

Dedo puesto pero con movimiento:
```json
{"v":1,"seq":104,"bpm":88,"spo2":96,"rr":[640],"dedo":true,"estable":false}
```

Ejemplo de envío en Arduino (solo de referencia; adaptar a cómo el firmware arma sus datos):

```cpp
// rr[] = intervalos (ms) de los latidos que terminaron desde el último envío; nRr = cuántos.
SerialBT.printf("{\"v\":1,\"seq\":%lu,\"bpm\":%d,\"spo2\":%d,\"rr\":[", seq++, bpm, spo2);
for (int i = 0; i < nRr; i++) SerialBT.printf(i ? ",%d" : "%d", rr[i]);
SerialBT.printf("],\"dedo\":%s,\"estable\":%s}\n", dedo ? "true" : "false", estable ? "true" : "false");
nRr = 0;
```

## 5. Qué hace la app con cada segundo (para entender qué cuenta)

Un segundo es **válido** solo si cumple todo esto (constantes en `ConfigMedicion`,
`app_ansiedad/lib/app_config.dart`):

- `dedo` y `estable` en `true`;
- `bpm` entre 40 y 180, `spo2` entre 80 y 100;
- cada RR entre 300 y 2000 ms, y ninguno cambia más de **20 %** respecto al anterior (filtro de
  artefactos habitual en HRV de corto plazo).

Si un segundo no es válido, la cadena de RR se corta: el RMSSD nunca resta dos RR separados por
un segundo malo o por un paquete perdido. La medición termina cuando junta **180 segundos
válidos** (tope: 10 minutos).

**Firmware no compatible:** al conectar, el primer paquete con `"v":1` deja al sensor como
compatible. Si llegan **3 paquetes JSON seguidos sin `v`** (por ejemplo, el firmware anterior que
manda `hrv` ya calculado) o uno con otra versión de `v`, la app lo marca como "Firmware no
compatible" y no ofrece la medición con el sensor. Las líneas que no son JSON (ruido del serial)
no cuentan. Se vuelve a verificar en cada conexión.

## 6. Cambios a este contrato

Cualquier cambio de formato sube el número de `v` y se anota aquí. La app y el firmware deben
cambiar juntos.

| Versión | Fecha | Cambio |
|---|---|---|
| 1 | 2026-10-21 | Primera versión (borrador, pendiente de validar el muestreo con el firmware). |
