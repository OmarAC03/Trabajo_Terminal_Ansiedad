# Bitácora de validación del sensor · TT 2026-B085 · Mi Ritmo

Registro de lo hecho, en orden, con los archivos de evidencia. Se usa para redactar las secciones 5.3.2 (firmware) y 6.6 (validación) del documento técnico.

## 11 nov 2026

### 1. Hoja de validación
- `Validacion_Sensor_MiRitmo.xlsx`: 3 pruebas (oxímetro, repetibilidad, respuesta), con fórmulas de sesgo, DE, límites de Bland-Altman, EAM, Arms y error típico.

### 2. Revisión del firmware v1 (código de Luis Enrique)
Problemas encontrados, verificados contra el código fuente de la librería de SparkFun:
1. `getIR()` y `getRed()` esperan cada una una muestra nueva (`safeCheck`). Se procesaban 50 de cada 100 muestras, y el rojo y el IR venían de muestras distintas. El tiempo del latido se tomaba con `millis()` al procesar.
2. `checkForBeat()`:
   - `averageDCEstimator(int32_t*, uint16_t)` trunca la señal a 16 bits;
   - el latido se marca en el cruce por cero ascendente;
   - el latido se descarta si la amplitud filtrada (máx − mín) es ≥ 1000.
3. SpO2 con `R = rojo/IR` crudos (DC) y la curva `115 − 20R`, ajustada para dar ~95 %. No mide oxigenación.
4. Promedios de 4 valores inicializados en cero y sin reinicio al retirar el dedo.

### 3. Firmware v2
- Carpeta `firmware/TT_Sensor_MiRitmo_v2/`. El JSON no cambia (contrato v1).
- **Lectura del FIFO:** completa a 100 Hz, tiempo por contador de muestras con la frecuencia real estimada y contador de desbordes.
- **Filtro:** Butterworth de orden 2, pasa-altas de 0.5 Hz y pasa-bajas de 5 Hz (fs = 100 Hz), iniciado en estado estable.
- **Detector:**
  - pico de la señal invertida;
  - umbral de 0.5 × la amplitud reciente;
  - refractario de 300 ms;
  - interpolación parabólica.
- **Frecuencia cardiaca:** mediana de 5 RR.
- **SpO2:** cociente de cocientes (AC = RMS filtrada, DC = media por segundo), promedio de 4 s y curva de Maxim −45.060R² + 30.354R + 94.845. Sin calibrar.
- **MODO_CRUDO = 1:** imprime `n,ir,rojo` por USB, más el JSON con "# ".

### 4. Prueba en PC con señal sintética (`firmware/pruebas_host/`)
- Las dos versiones se compilaron con g++ y stubs de la librería: búfer de 4 muestras y espera de `getIR`/`getRed`. La v1 enlaza el `heartRate.cpp` original de SparkFun.
- PPG sintética de 200 s con RR conocidos y RMSSD real de ~39 ms:

| Amplitud | v1 RMSSD | v2 RMSSD | Real |
|---|---|---|---|
| Baja | 95.0 | 36.7 | 38.4 |
| Media | 81.3 | 38.5 | 38.7 |
| Alta | 59.9 | 39.1 | 39.3 |
| Muy alta | sin latidos | 38.9 | 38.8 |

- La v2 también se probó con una deriva de ±2 % del reloj del sensor: estima correctamente la FC del reloj real.
- **Advertencia:** la señal es sintética. Verifica la lógica del firmware, no la exactitud del sensor.

### 5. Primeras sesiones con la v2 (app → servidor → portal)
- 17:48: calidad 99 %, 180 de 181 s válidos, duración 3 min 1 s.
- 18:00: calidad 100 %. FC 96 frente a 93.0 del oxímetro (94/91/94). SpO2 99 frente a 92.3 (90/93/94).
- Sesiones de la v1 de la misma persona: calidad del 53 al 84 % y RMSSD de hasta 115.8 ms. Fuente: reporte PDF del portal, 22 sesiones.
- **Hallazgo:** la línea base consolidada de esta persona se armó con sesiones de la v1, y por eso las sesiones de la v2 salieron "Altos" (z = −2.92). Se propone una fecha de corte en `linea_base.js`, pendiente de implementar.
- **Pendiente:** hora exacta en que se cargó la v2 (dato de Luis).

### 6. Capturas crudas (`firmware/capturas/`)

| Captura | Latidos encontrados frente a la referencia | DE del instante | FC fw / ref / oxímetro | RMSSD fw / ref | R → SpO2 / oxímetro |
|---|---|---|---|---|---|
| P1 (~20:15) | 117/120 | 1.1 ms | 106.5 / 106.6 / 106 (104, 108) | 6.7 / 7.1 | 0.574 → 97.4 / 93.5 (93, 94) |
| P2 (~20:22) | 99/101 | 1.8 ms | 89.1 / 89.0 / 88 (90, 86) | 14.0 / 14.3 | 0.608 → 96.6 / 92.5 (92, 93) |

- **Referencia:** filtfilt Butterworth de 0.5–5 Hz, `find_peaks` con distancia de 300 ms e interpolación parabólica.
- Los latidos no encontrados son los del arranque, en los 2 s de calentamiento.
- En las dos capturas hubo 0 desbordes, 100 % con dedo y estable, y sin saturación.
- Figura del documento: `tt/fig/cap6_val_01_captura.png`.

### 7. Acumulado de la Prueba 1 (n = 3)

| | Sesgo | DE | Límites de concordancia | EAM | Arms |
|---|---|---|---|---|---|
| **FC** | +1.53 | 1.31 | −1.02 a +4.09 | 1.53 (cumple) | 1.87 |
| **SpO2** | +4.89 | 1.54 | +1.86 a +7.91 | 4.89 | 5.05 |

- **Nota:** en la CDMX (~2240 m) la SpO2 normal ronda el 92–95 %.

### Pendiente
- ~10 pares más, de varias personas, con sesiones desde la app.
- Pruebas 2 y 3.
- Fotos del dispositivo.
- Decidir la corrección de un punto de la SpO2 o dejarla como indicador interno.
- Gráfica de Bland-Altman.

## 12 nov 2026

### 8. Captura P3 (~00:50)
- **FC:** firmware 82.5, referencia 82.4, oxímetro 81 y 82. Cumple.
- **Detector:** 92/94 latidos, DE 3.5 ms. RMSSD 27.5 (firmware) y 26.5 (referencia). 0 desbordes.
- **SpO2 anómala:**
  - R = 1.903, por lo que la curva da menos de 70 y el firmware envía 70, su piso.
  - El oxímetro marcó 94 y 95.
  - El canal "rojo" tiene AC/DC del 0.69 %, mayor que el "IR" (0.36 %). En las otras capturas fue al revés (rojo 0.21–0.27 %, IR 0.37–0.44 %).
  - **Hipótesis:** canales rojo/IR intercambiados en el módulo (pasa en algunos módulos genéricos), lo que daría R = 0.526. Pendiente confirmar si se usó otro kit.
- **Riesgo:** en modo normal, una SpO2 menor de 80 invalida cada segundo en la app. Con ese kit, las sesiones saldrían sin segundos válidos.
- **Confirmado:** P3 se midió con el kit 2.
  - Se agregó al firmware la constante `INVERTIR_CANALES` (1 en el kit 2).
  - Se verificó reproduciendo las capturas reales en el firmware compilado en la PC:

| Captura | INVERTIR 0 | INVERTIR 1 | Oxímetro |
|---|---|---|---|
| Kit 1, P1 | **97.5** | 70 | 93.5 |
| Kit 1, P2 | **96.7** | 70 | 92.5 |
| Kit 2, P3 | 70 | **98.2** | 94.5 |

  - Con la configuración correcta, el sesgo del kit 2 (+3.7) es parecido al del kit 1 (+3.9 a +4.2).
  - La FC no cambia: 82.9 en ambos casos.

### 9. Captura 04 (~01:35; kit 2 presumiblemente con INVERTIR_CANALES = 1)
- El intento anterior falló: "no se encontró el MAX30102" (conexión I2C). Tras revisar los cables, funcionó.
- **Ajuste de herramientas:**
  - `captura.py` ya no reinicia el ESP32 al abrir el puerto y avisa del error de I2C;
  - `analiza_crudo.py` descarta las líneas repetidas del puerto (360 en esta captura).
- **Resultados:**
  - 88/91 latidos, con DE de 7.1 ms (mayor que en las capturas anteriores, de 1–3.5 ms).
  - FC: firmware 78.5, referencia 78.2, oxímetro 71 y 79 (media 75).
  - RMSSD: 28.4 (firmware) y 26.6 (referencia).
  - R = 0.569, SpO2 de 97.5 frente al oxímetro (94 y 95): +3.0.
- **Pendiente:** confirmar la persona y que los valores del oxímetro corresponden a esta captura, porque coinciden exactamente con los anotados en el intento fallido.

### 10. Cambio de la referencia fuera de línea (12 nov, ~01:50)
- **Motivo:**
  - En `cal_01` (P3, FC ~71) la referencia por pico sistólico con filtro de fase cero (0.5–5 Hz) confundía la onda dícrota con el latido.
  - Daba RR alternados no fisiológicos (680/1090 ms) y una DE aparente de 28.9 ms.
  - El firmware no mostraba ese problema: su filtro causal suaviza la onda dícrota.
- **Nueva referencia, aplicada a TODAS las capturas:**
  - punto de **máxima pendiente** de subida del pulso, el máximo de la derivada de la señal invertida;
  - filtro Butterworth de 0.5–8 Hz de fase cero;
  - separación mínima del 60 % del periodo dominante (por autocorrelación);
  - interpolación parabólica.
  - Es un punto de referencia habitual en variabilidad por pulso (PRV).
- **Comparación:** como pico y pendiente son puntos distintos del pulso, se quita el desfase mediano (~110–160 ms) antes de medir la dispersión.

**Resultados con la nueva referencia:**

| Captura | Encontrados | DE | FC fw / ref | RMSSD fw / ref |
|---|---|---|---|---|
| P1 (k1) | 117/121 | 1.2 ms | 106.5 / 106.6 | 6.7 / 7.8 |
| P2 (k1) | 99/102 | 2.0 ms | 89.1 / 89.1 | 14.0 / 17.0 |
| P3 (k2, 00:50) | 92/94 | 4.7 ms | 82.5 / 82.5 | 27.5 / 28.1 |
| 04 (k2, sin confirmar) | 88/92 | 7.9 ms | 78.0 / 78.2 | 28.4 / 32.0 |
| cal_01 P3 (k2) | 80/83 | 8.5 ms | 71.0 / 71.4 | 46.0 / 47.2 |

- Los latidos no encontrados son los de los 2 s de calentamiento, más un latido perdido en `cal_01` (a los 21 s, RR de 1530 ms, que la regla del 20 % de la app descarta).
- **Observación:**
  - El RMSSD del firmware (pico) es sistemáticamente un poco menor que el de la referencia (pendiente): entre −0.6 y −3.6 ms.
  - Sin ECG no se puede decidir cuál se acerca más al valor verdadero. Se reporta como diferencia entre métodos.
- **Pendiente:** actualizar la tabla de la sección 6.6.2 del documento con estos valores; la versión v5 tiene los de la referencia anterior.

### 11. Calibración (8 capturas): cal_01
- P3, kit 2. Oxímetro: SpO2 94 y 93, FC 71 y 76.
- Sensor:
  - SpO2 97.8 (R = 0.555): **+4.3**;
  - FC 70.7 de media (a los 30 s 66.8 frente a 71; a los 60 s 74.3 frente a 76).

### 12. cal_02 (P4, kit 2) y ajuste del cálculo de R en el analizador
- **Ajuste del analizador:**
  - El R de toda la captura (0.787) no coincidía con el del firmware.
  - El firmware calcula R por segundo y la variación lenta entre segundos inflaba el AC del canal rojo en el cálculo global.
  - El analizador ahora calcula R por segundo y toma la mediana, como el firmware. Re-aplicado a todas las capturas, coincide con la SpO2 del JSON (±0.1, salvo cal_02, 97.6 frente a 96.7 de media).
  - **Para la calibración se usa la SpO2 que envió el firmware** (la salida real del sistema).
- **cal_02 (P4, kit 2).** Oxímetro: SpO2 95 y 94, FC 75 y 76.
  - SpO2: sensor 96.7, **+2.2**.
  - FC: sensor 76.0, frente a 75.5 del oxímetro.
  - Detector: 84/88 latidos, DE 8.5 ms. RMSSD 31.7 / 31.7.

### 13. cal_03 (P3, kit 2)
- Oxímetro: SpO2 94 y 94, FC 73 y 74.
- **SpO2:** sensor 98.4 (R = 0.517), **+4.4**.
- **FC:** sensor 74.6, **+1.1**.
- **Detector:** 83/88 latidos, DE 11.0 ms. RMSSD 33.7 / 34.9.
- **Dos latidos perdidos** fuera del calentamiento (RR de 1699 y 1472 ms), que la app descarta con la regla del 20 %.
- **Observación:**
  - Con el kit 2 y P3 (pulso de AC ~0.9 % y picos anchos), el detector pierde latidos de vez en cuando (1 en cal_01 y 2 aquí) y la DE sube a 8–11 ms. En el kit 1 era de 1–2 ms.
  - **Posible mejora tras la calibración:** umbral de 0.4 × amplitud en lugar de 0.5. No se cambia ahora para no mezclar versiones a mitad de la serie.

### 14. cal_04 (P4, kit 2)
- Oxímetro: SpO2 94 y 94, FC 73 y 77. Resultados en la tabla final de calibración (sección 15).

### 15. cal_05 (P4, kit 2)
- Oxímetro: SpO2 96 y 95, FC 72 y 68.

### 16. cal_06 (P5, kit 2)
- Oxímetro: SpO2 95 y 96, FC 70 y 71. Contador de desbordes = 2 desde antes de iniciar la captura (acumulado desde el arranque; no aumentó durante la captura).
- **Ajuste de la referencia:**
  - En cal_06 la autocorrelación no tenía un pico claro (modulación respiratoria fuerte) y la referencia tomó un latido de cada dos (FC 38.9).
  - El periodo dominante ahora se estima con el espectro de Welch entre 0.6 y 3 Hz.
  - Re-aplicado a todas las capturas: las anteriores no cambian. En cal_06 la referencia da 82 latidos y FC 71.8.
- **Resultados de cal_06:**
  - SpO2: sensor 98.0 (R = 0.534), **+2.5**.
  - FC: a los 30 s 68.2 frente a 70; a los 60 s 73.3 frente a 71.
  - Detector: 79/82 latidos, DE 12.9 ms. RMSSD 50.6 / 55.0.

### 17. cal_07 (P5, kit 2)
- Oxímetro: SpO2 94 y 94, FC 78 y 73.

### 18. cal_08 (P5, kit 2) y cierre de la calibración (12 nov, ~02:30)
- **cal_08.** Oxímetro: SpO2 93 y 93, FC 78 y 79.
  - Sensor: SpO2 98.2, FC 76.9.
  - Detector: 87/89 latidos, DE 4.1 ms.
- **Concordancia (script `calibra.py`; resultados en `calibracion_resultados.json`):**
  - FC, n = 23 lecturas con el sensor en el mismo instante (±2 s): sesgo −0.44, DE 2.24, límites de concordancia −4.8 a +3.9, EAM 1.66, Arms 2.23. **Cumple.**
  - SpO2, n = 11:
    - global: sesgo +4.15, DE 1.21, límites +1.8 a +6.5;
    - kit 1 (n = 3): +4.9;
    - kit 2 (n = 8): +3.9.
  - **Corrección de un punto (−4) validada dejando uno fuera:** EAM 0.91, límites ±2.6.
- **Firmware:** `CORRECCION_SPO2 = 4.0` en el .ino. Comprobado con las capturas reales reproducidas en la PC: kit 1 da 93.5 (oxímetro 93.5) y kit 2 da 94.2 (oxímetro 94.5).
- **Umbral del detector:** 0.5 frente a 0.4 probado fuera de línea en las 11 capturas.
  - 0.5: 7/972 latidos perdidos. 0.4: 5/972. Los latidos extra son iguales (4).
  - Mejora marginal: **se mantiene 0.5** para no cambiar el firmware ya validado.
- **Detector en las 11 capturas:** 965/972 latidos (99.3 %) fuera de los 2 s de calentamiento. RMSSD del firmware −1.5 ms (−5.6 %) frente a la referencia, correlación 0.99.
- **Figuras:**
  - `cap6_val_01_captura.png`, regenerada con la referencia por pendiente;
  - `cap6_val_02_bland_altman.png`.
- **Documento:** v6 con las secciones 6.6.2 y 6.6.3 completas, y 5.3.2 y 6.9 actualizadas.
