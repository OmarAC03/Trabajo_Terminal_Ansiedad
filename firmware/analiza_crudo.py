"""Analiza una captura cruda del sensor (firmware v2 con MODO_CRUDO = 1).

Uso:  python analiza_crudo.py captura.txt
La captura es lo que sale por el monitor serie: líneas "n,ir,rojo" (100 por segundo)
y líneas "# {json}" (una por segundo). Genera captura_analisis.png y un resumen en pantalla.

Compara tres cosas:
  1. El detector del firmware (modelo en Python, misma lógica que el .ino).
  2. Una referencia fuera de línea: filtro Butterworth 0.5–5 Hz de fase cero (filtfilt)
     y picos con scipy.find_peaks. No sustituye a un ECG; sirve para revisar el filtro.
  3. Lo que el firmware mandó realmente en los JSON.
Requiere: pip install numpy scipy matplotlib
"""
import sys, json, re
import numpy as np
from scipy.signal import butter, filtfilt, find_peaks
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt

FS = 100.0
HP = ([0.9780304792, -1.9560609584, 0.9780304792], [1, -1.9555782403, 0.9565436765])
LP = ([0.0200833656, 0.0401667311, 0.0200833656], [1, -1.5610180758, 0.6413515381])

class Biquad:
    def __init__(s, b, a): s.b, s.a = b, a; s.z1 = s.z2 = 0.0
    def __call__(s, x):
        y = s.b[0] * x + s.z1
        s.z1 = s.b[1] * x - s.a[1] * y + s.z2
        s.z2 = s.b[2] * x - s.a[2] * y
        return y

def detector_firmware(ir, dt=10.0):
    """Misma lógica que Detector::muestra() del firmware v2."""
    hp, lp = Biquad(*HP), Biquad(*LP)
    hp.z1 = -HP[0][0] * ir[0]; hp.z2 = HP[0][2] * ir[0]
    y1 = y2 = amp = 0.0; ultimo = -1e9; lat = []; filt = np.zeros(len(ir))
    for n, x in enumerate(ir):
        f = lp(hp(float(x))); filt[n] = f; y = -f; t1 = (n - 1) * dt
        if n > 200 and y1 > y2 and y1 >= y and y1 > 0.5 * amp and t1 - ultimo > 300:
            den = y2 - 2 * y1 + y
            off = 0.5 * (y2 - y) / den if den != 0 else 0.0
            ultimo = t1 + off * dt; lat.append(ultimo)
            amp = y1 if amp == 0 else 0.8 * amp + 0.2 * y1
        if n > 200 and t1 - ultimo > 1500: amp *= 0.98
        if n == 200: amp = 0.0
        y2, y1 = y1, y
    return np.array(lat), filt

def referencia(ir):
    """Referencia fuera de línea independiente del firmware: punto de máxima pendiente de subida
    del pulso (máximo de la derivada de la señal invertida), con filtro Butterworth 0.5–8 Hz de fase
    cero. Es un punto de referencia habitual en variabilidad por pulso porque no se confunde con la
    onda dícrota. Devuelve (instantes en ms, señal filtrada de referencia)."""
    b, a = butter(2, [0.5, 8.0], btype='band', fs=FS)
    f = -filtfilt(b, a, ir.astype(float))
    dv = np.gradient(f)
    # periodo dominante por espectro (Welch) entre 0.6 y 3 Hz: robusto a la modulación respiratoria
    from scipy.signal import welch
    fr, P = welch(f[200:], fs=FS, nperseg=min(1024, len(f) - 200))
    m = (fr >= 0.6) & (fr <= 3.0); periodo = FS / fr[m][np.argmax(P[m])]
    pk, _ = find_peaks(dv, distance=max(int(0.3 * FS), int(0.6 * periodo)), prominence=0.4 * np.percentile(dv, 98))
    t = []
    for p in pk:
        if 0 < p < len(dv) - 1:
            den = dv[p - 1] - 2 * dv[p] + dv[p + 1]
            t.append((p + (0.5 * (dv[p - 1] - dv[p + 1]) / den if den else 0)) * 1000 / FS)
    return np.array(t), -f

def metricas(lat):
    rr = np.diff(lat)
    ok = (rr >= 300) & (rr <= 2000)
    pares = [b - a for a, b, oa, ob in zip(rr[:-1], rr[1:], ok[:-1], ok[1:]) if oa and ob and abs(b - a) <= 0.2 * a]
    rmssd = np.sqrt(np.mean(np.square(pares))) if pares else float('nan')
    fc = 60000 / np.median(rr[ok]) if ok.any() else float('nan')
    return rr, rmssd, fc, len(pares), max(len(rr) - 1, 0)

def main(ruta):
    filas, js = [], []; desb = None
    for linea in open(ruta, encoding='utf-8', errors='ignore'):
        linea = linea.strip()
        if linea.startswith('# desbordes='):
            desb = int(linea.split('=')[1]); continue
        if linea.startswith('#'):
            try: js.append(json.loads(linea.lstrip('# ')))
            except ValueError: pass
        elif re.fullmatch(r'\d+,\d+,\d+', linea):
            filas.append([int(v) for v in linea.split(',')])
    d = np.array(filas)
    _, idx = np.unique(d[:, 0], return_index=True)          # quita líneas repetidas del puerto
    repetidas = len(d) - len(idx); d = d[np.sort(idx)]
    if repetidas: print(f'Aviso: {repetidas} líneas repetidas descartadas')
    n, ir, rojo = d[:, 0], d[:, 1], d[:, 2]
    perdidas = int(np.sum(np.diff(n) - 1))
    dedo = ir > 50000
    print(f'Muestras: {len(n)} ({len(n)/FS:.1f} s)  ·  muestras perdidas por el puerto serie: {perdidas}')
    if desb is not None: print(f'Desbordes del búfer de la librería: {desb}' + ('  <- deberían ser 0: algo en el loop tarda más de 30 ms' if desb else ' (bien)'))
    print(f'Con dedo: {100*dedo.mean():.0f} %  ·  IR DC medio: {ir[dedo].mean():.0f}  ·  rojo DC medio: {rojo[dedo].mean():.0f}')
    if ir[dedo].max() > 260000: print('AVISO: el IR llega a saturar el ADC (> 260000). Bajar la corriente del LED.')
    seg = ir[dedo]; lat_fw, filt = detector_firmware(seg); lat_ref, ref = referencia(seg)
    p2p = np.percentile(filt[200:], 98) - np.percentile(filt[200:], 2)
    print(f'Amplitud pulsátil IR (pico a pico, filtrada): {p2p:.0f} cuentas ({100*p2p/seg.mean():.2f} % de la DC)')
    print('  · referencia: checkForBeat() de la v1 descartaba el latido si su amplitud filtrada pasaba de 1000 cuentas')
    for nom, lat in (('Detector del firmware v2', lat_fw), ('Referencia fuera de línea', lat_ref)):
        rr, rm, fc, ok, tot = metricas(lat)
        print(f'{nom:27s}: {len(lat)} latidos · FC {fc:.1f} lpm · RMSSD {rm:.1f} ms · pares válidos {ok}/{tot}')
    # concordancia latido a latido: los dos métodos usan puntos distintos del pulso (pico frente a
    # máxima pendiente), así que se quita el desfase mediano y se mide la dispersión
    if len(lat_fw) > 5 and len(lat_ref) > 5:
        bruto = np.array([lat_fw[np.argmin(np.abs(lat_fw - t))] - t for t in lat_ref])
        off = np.median(bruto[np.abs(bruto) < 400])
        dif = np.array([lat_fw[np.argmin(np.abs(lat_fw - off - t))] - off - t for t in lat_ref])
        cerca = np.abs(dif) < 120
        print(f'Latidos de la referencia encontrados por el firmware: {cerca.sum()}/{len(lat_ref)} · desfase fijo {off:.0f} ms · DE {dif[cerca].std():.1f} ms')
        print('  · el desfase fijo es la distancia entre pico y pendiente más el retraso del filtro; no cambia los RR')
    # SpO2 como la calcula el firmware: R por segundo (AC = RMS de la señal filtrada, DC = media)
    b, a = butter(2, [0.5, 5.0], btype='band', fs=FS)
    rj = rojo[dedo].astype(float); fi = filtfilt(b, a, seg.astype(float)); fr = filtfilt(b, a, rj)
    Rs = []
    for k in range(2, len(seg) // 100):
        sl = slice(k * 100, (k + 1) * 100)
        Rs.append((fr[sl].std() / rj[sl].mean()) / (fi[sl].std() / seg[sl].mean()))
    R = float(np.median(Rs))
    print(f'R por segundo (mediana, como el firmware) = {R:.3f}  ->  SpO2 (curva Maxim) = {-45.060*R*R + 30.354*R + 94.845:.1f} %  (comparar con el oxímetro)')
    if js:
        rr_js = [r for p in js for r in p['rr']]
        print(f'JSON del firmware: {len(js)} paquetes · {len(rr_js)} RR · FC media {np.mean([p["bpm"] for p in js if p["bpm"]]):.1f} · SpO2 media {np.mean([p["spo2"] for p in js if p["spo2"]]):.1f}')
    # gráfica
    t = np.arange(len(seg)) / FS
    fig, ax = plt.subplots(3, 1, figsize=(12, 8), sharex=True)
    ax[0].plot(t, seg, lw=0.8, color='#555'); ax[0].set_ylabel('IR crudo')
    ax[1].plot(t, -filt, lw=0.8, color='#1F4E79', label='filtro del firmware (invertido)')
    ax[1].plot(lat_fw / 1000, np.interp(lat_fw / 1000, t, -filt), 'o', ms=4, color='#C00000', label='latidos firmware')
    ax[1].plot(lat_ref / 1000, np.interp(lat_ref / 1000, t, -filt), 'x', ms=6, color='#2E7D32', label='referencia (máx. pendiente)')
    ax[1].legend(loc='upper right', fontsize=8); ax[1].set_ylabel('IR filtrado 0.5–5 Hz')
    rr = np.diff(lat_fw); ax[2].plot(lat_fw[1:] / 1000, rr, '.-', lw=0.8, color='#1F4E79', label='RR firmware')
    rr2 = np.diff(lat_ref); ax[2].plot(lat_ref[1:] / 1000, rr2, '.', ms=3, color='#2E7D32', label='RR referencia')
    ax[2].set_ylabel('RR (ms)'); ax[2].set_xlabel('tiempo con dedo (s)'); ax[2].legend(fontsize=8)
    for a_ in ax: a_.grid(alpha=0.3)
    plt.tight_layout(); salida = re.sub(r'\.\w+$', '', ruta) + '_analisis.png'; plt.savefig(salida, dpi=120)
    print('Gráfica:', salida)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'captura.txt')
