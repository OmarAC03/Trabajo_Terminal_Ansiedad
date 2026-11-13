# Firmware v2 del sensor · Mi Ritmo

## Archivos
- `TT_Sensor_MiRitmo_v2/TT_Sensor_MiRitmo_v2.ino`: firmware corregido. El JSON es idéntico al de la v1, así que la app no cambia.
- `captura.py`: graba la señal cruda del puerto USB en un archivo.
- `analiza_crudo.py`: analiza esa captura y genera una gráfica (detector del firmware frente a una referencia fuera de línea, FC, RMSSD y SpO2).
- `v1/TT_Sensor_v1.ino`: la versión anterior, sin cambios, como respaldo.
- `pruebas_host/`: el firmware compilado en la PC con señales sintéticas (comparación entre v1 y v2).

## Kits
- **Kit 1:** `INVERTIR_CANALES 0`.
- **Kit 2:** `INVERTIR_CANALES 1`. Su módulo trae los LED rojo e infrarrojo intercambiados.
- En cada kit, `NOMBRE_BT` lleva el nombre Bluetooth que ese kit ya usaba.
- Marquen físicamente cada caja (1 y 2) para no confundirlas.

## Paso 1 · Cargar la v2
1. Abre el `.ino` en Arduino IDE con la misma placa y la misma librería (SparkFun MAX3010x) que usaste para la v1.
2. Deja `MODO_CRUDO` en 0 y súbelo al ESP32.
3. Haz una sesión normal desde la app. El nombre Bluetooth es el mismo: `TT_SENSOR_CLASICO 1`.

## Paso 2 · Captura cruda (60 s, con el oxímetro puesto)
1. Cambia `#define MODO_CRUDO 0` por `1` y súbelo. El Bluetooth sigue funcionando igual.
2. Cierra el monitor serie del IDE.
3. Ejecuta `pip install pyserial numpy scipy matplotlib`.
4. Ejecuta `python captura.py COM5 70`. Usa tu puerto: en Windows es COMx, en Linux es /dev/ttyUSB0.
5. Durante la captura: sensor en un índice y oxímetro en el otro, sentado y quieto. Anota la FC y la SpO2 del oxímetro a los 30 s y a los 60 s.
6. Ejecuta `python analiza_crudo.py captura.txt`.
7. Manda `captura.txt`, la gráfica `captura_analisis.png` y lo que marcó el oxímetro.

Al terminar, regresa `MODO_CRUDO` a 0 y vuelve a subir el firmware antes de las pruebas de la hoja de validación.

## Qué revisar en la salida del analizador
- **Desbordes:** deben ser 0.
- **Latidos de la referencia encontrados por el firmware:** cerca del 100 %, con una DE de pocos ms.
- **El IR no debe saturar el ADC** (más de 260000). Si satura, baja la corriente del LED (0x24 → 0x1C).
- **SpO2 calculada frente a la del oxímetro:** la curva no está calibrada. Si hay una diferencia constante, se documenta y, en su caso, se corrige con los datos del oxímetro; no se ajusta "a ojo".
