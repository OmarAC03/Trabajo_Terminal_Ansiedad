"""Guarda la salida del sensor (MODO_CRUDO = 1) en un archivo.
Uso:  python captura.py COM5 70            (Windows; en Linux/Mac: /dev/ttyUSB0)
      python captura.py                    (sin argumentos: lista los puertos disponibles)
Requiere: pip install pyserial
Cierra el monitor serie del Arduino IDE antes de usarlo (solo un programa puede abrir el puerto).
"""
import sys, time, serial
from serial.tools import list_ports

if len(sys.argv) < 2:
    print('Puertos disponibles:')
    for p in list_ports.comports(): print(f'  {p.device:8s} {p.description}')
    print('Uso: python captura.py COMx 70'); sys.exit()

puerto = sys.argv[1]; segundos = float(sys.argv[2]) if len(sys.argv) > 2 else 70
salida = sys.argv[3] if len(sys.argv) > 3 else 'captura.txt'
s = serial.Serial()
s.port, s.baudrate, s.timeout = puerto, 115200, 1
s.dtr = False; s.rts = False          # no dejar el ESP32 detenido en reset al abrir el puerto
try:
    s.open()
except serial.SerialException as e:
    print('No se pudo abrir', puerto, '->', e)
    print('¿Monitor serie del IDE abierto? ¿Puerto correcto? Ejecuta "python captura.py" para ver la lista.')
    sys.exit(1)

time.sleep(0.2); s.reset_input_buffer()     # descarta lo que quedó guardado en el puerto
print(f'Puerto {puerto} abierto. Esperando datos del sensor...')
n = muestras = errores = json0 = 0; inicio = time.time(); aviso = False; fin = None
with open(salida, 'w', encoding='utf-8') as f:
    while True:
        linea = s.readline().decode('utf-8', 'ignore').strip()
        ahora = time.time()
        if linea:
            f.write(linea + '\n'); n += 1
            if linea[:1].isdigit(): muestras += 1
            if 'ERROR' in linea or 'Revisa' in linea or 'MAX3010' in linea: errores += 1
            if linea.startswith('{'): json0 += 1
            if fin is None and muestras > 0:
                fin = ahora + segundos
                print(f'Llegan muestras. Grabando {segundos:.0f} s en {salida}. Dedo quieto, sin hablar.')
            if muestras and muestras % 1000 == 0: print(f'  {muestras} muestras...'); f.flush()
        if fin is None and not aviso and ahora - inicio > 6:
            aviso = True
            if n == 0:
                print('  No llega nada en 6 s. Presiona el botón EN/RST del ESP32. Si sigue igual, el puerto no es el correcto.')
            elif errores:
                print('  El ESP32 NO encuentra el sensor MAX30102 (error de I2C). Revisa cables y conector del dedal (SDA 32, SCL 33, 3.3 V, GND).')
            elif json0:
                print('  Llegan datos normales pero no muestras crudas: el firmware está con MODO_CRUDO 0. Cámbialo a 1 y vuelve a subirlo.')
            else:
                print('  Llegan líneas que no se reconocen. Ejemplo:', linea[:80])
        if fin is None and ahora - inicio > 30:
            print('Sin muestras en 30 s. Se detiene. Revisa los avisos de arriba.'); break
        if fin is not None and ahora >= fin: break
s.close()
print(f'Listo: {salida} · {muestras} muestras ({muestras/100:.0f} s)')
