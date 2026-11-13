# Validación del sensor y firmware v2 · 11–12 nov 2026

Resumen para el repositorio y el contexto del proyecto. El detalle completo está en `BITACORA_VALIDACION.md`.

## 1. Qué se hizo
1. **Revisión del firmware v1** (ESP32 + MAX30102). Se encontraron cuatro problemas:
   - procesaba 50 de 100 muestras por segundo (`getIR()` y `getRed()` esperan cada una una muestra nueva);
   - `checkForBeat()` de SparkFun trunca la señal a 16 bits, usa el cruce por cero y descarta los latidos con amplitud filtrada mayor de 1000;
   - la SpO2 se calculaba con rojo/IR crudo y una constante ajustada para que diera "~95";
   - los promedios arrancaban en cero.
2. **Firmware v2**, con el mismo contrato JSON, así que la app no cambia:
   - lectura completa del FIFO a 100 Hz, con el tiempo por contador de muestras;
   - pasa-banda Butterworth de 0.5–5 Hz;
   - detector de pico con umbral adaptativo, refractario de 300 ms e interpolación parabólica;
   - FC = mediana de 5 RR;
   - SpO2 por cociente de cocientes con la curva de Maxim y una corrección de −4;
   - `MODO_CRUDO` para la captura de señal y `INVERTIR_CANALES` por kit.
3. **Prueba en PC con señal sintética** (v1 frente a v2): la v1 inflaba el RMSSD de 1.5 a 2.5 veces y con señal fuerte no detectaba latidos. La v2 queda casi exacta.
4. **Validación con señal real:** 11 capturas crudas de 68–70 s, 5 personas, 2 kits, más una sesión desde la app, todas con un oxímetro comercial.
5. **Hallazgo en el kit 2:** sus LED rojo e IR vienen intercambiados. Se corrige con `INVERTIR_CANALES 1`.

## 2. Resultados
| Medida | Resultado |
|---|---|
| Latidos encontrados frente a la referencia fuera de línea | 965/972 (99.3 %) |
| FC firmware frente a la referencia | diferencia ≤ 0.8 lpm |
| RMSSD firmware frente a la referencia | −1.5 ms (−5.6 %), r = 0.99 (sin ECG) |
| FC frente al oxímetro (n = 23) | sesgo −0.4, LoA −4.8 a +3.9, EAM 1.7 → **cumple** |
| SpO2 frente al oxímetro (n = 11) | sesgo +4.2, LoA +1.8 a +6.5 → corrección de −4 |
| SpO2 corregida (dejando uno fuera) | EAM 0.9, LoA ±2.6 |
| Calidad de sesión | v1: 53–84 %; v2: 92–100 %, y las sesiones terminan en 3 min |

**Límites:**
- la referencia es un oxímetro comercial y no hubo ECG;
- la SpO2 se validó solo entre 92 y 96 %;
- son pocas personas con mediciones repetidas.

La SpO2 se queda como dato de apoyo y no interviene en la línea base ni en las bandas.

## 3. Configuración de los kits (firmware v2)
| Kit | `INVERTIR_CANALES` | `MODO_CRUDO` | `NOMBRE_BT` |
|---|---|---|---|
| 1 | 0 | 0 | `TT_SENSOR_CLASICO 1` |
| 2 | 1 | 0 | su nombre de siempre |

`MODO_CRUDO 1` solo se usa para capturar la señal con `captura.py` y analizarla con `analiza_crudo.py`.

## 4. Pendientes que dependen de esto
- **Servidor: fecha de corte de la línea base.** Las sesiones de origen sensor anteriores al cambio a la v2 (11/11/2026, ~17:40; Luis confirma la hora) no deben entrar en la línea base ni recibir banda, porque la v1 inflaba la HRV. Mezclarlas produce "Altos" falsos, como en las sesiones de las 17:48 y 18:00. No se borra nada.
- **App v1.1:** valorar si se muestra la SpO2 al estudiante. Con la corrección queda razonable, pero sigue como indicador de apoyo.
- **Pruebas 2 y 3** (repetibilidad y sentadillas) con una cuenta PRUEBA, para cerrar la sección 6.6.4.
- **Documento:** 5.3.2 y 6.6.1–6.6.3 ya redactadas en la v6. Falta la 6.6.4.

## 5. Archivos
- `firmware/TT_Sensor_MiRitmo_v2/TT_Sensor_MiRitmo_v2.ino`: firmware v2.
- `firmware/v1/TT_Sensor_v1.ino`: respaldo de la versión anterior.
- `firmware/captura.py` y `firmware/analiza_crudo.py`: captura y análisis de la señal cruda.
- `firmware/pruebas_host/`: compilación en PC con señal sintética (v1 frente a v2).
- `validacion/Validacion_Sensor_MiRitmo.xlsx`, `BITACORA_VALIDACION.md` y `calibracion.csv`: datos y registro.
