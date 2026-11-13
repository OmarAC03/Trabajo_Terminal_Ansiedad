"""Corre el firmware v2 compilado en la PC con PPG sintética y evalúa lo que recibiría la app."""
import sys, json, subprocess, numpy as np
sys.path.insert(0, '.')
from sim_pba import ppg

def genera(path, ac=1000, hr=75, R=0.5, dic=0.35, seed=1, quitar_dedo=True):
    tt, ir, beats = ppg(dur=200, ac=ac, hr=hr, dic=dic, seed=seed)
    dc_ir = 120000; dc_r = 90000
    x = (dc_ir - ir) / ac                                   # forma normalizada del pulso
    red = dc_r - (R * ac / dc_ir * dc_r) * x                 # AC_r/DC_r = R·AC_ir/DC_ir
    red = red + np.random.default_rng(seed).normal(0, 0.02 * ac * dc_r / dc_ir, red.size)
    if quitar_dedo:
        m = (tt > 100) & (tt < 105); ir[m] = 3000; red[m] = 2000
    np.savetxt(path, np.c_[ir, red.astype(int)], fmt='%d', delimiter=',')
    return beats

def evalua_app(lineas):
    """Reglas de la app (simplificadas): validez por segundo, cadena RR con cortes, RMSSD."""
    validos = 0; total = 0; difs = []; prev = None; bpms = []; spo2 = []
    for L in lineas:
        p = json.loads(L); total += 1
        ok = p['dedo'] and p['estable'] and 40 <= p['bpm'] <= 180 and p['spo2'] >= 80 and all(300 <= r <= 2000 for r in p['rr'])
        rr = p['rr']
        if not ok: prev = None; continue
        for r in rr:
            if prev is not None and abs(r - prev) > 0.2 * prev: ok = False
        if not ok: prev = None; continue
        validos += 1; bpms.append(p['bpm']); spo2.append(p['spo2'])
        for r in rr:
            if prev is not None: difs.append(r - prev)
            prev = r
    return validos, total, np.sqrt(np.mean(np.square(difs))), np.mean(bpms), np.mean(spo2)

if __name__ == '__main__':
    print('caso                         | seg. válidos | RMSSD fw vs real | FC fw vs real | SpO2 fw (esperada)')
    for ac, hr, R, per in ((500, 70, 0.5, 10.0), (1500, 90, 0.5, 10.0), (3000, 65, 0.7, 10.0), (1000, 75, 0.5, 10.2), (1000, 75, 0.9, 9.8)):
        beats = genera('s.csv', ac=ac, hr=hr, R=R)
        out = subprocess.run(['./sim', 's.csv', str(per)], capture_output=True, text=True).stdout.splitlines()
        lin = [l for l in out if l.startswith('{')]
        v, t, rm, fc, sp = evalua_app(lin)
        rr = np.diff(beats * 1000); real = np.sqrt(np.mean(np.diff(rr) ** 2))
        esp = -45.060 * R * R + 30.354 * R + 94.845
        print(f'AC {ac:4d} FC {hr} R {R} T {per:4.1f} ms | {v:3d}/{t:3d}      | {rm:5.1f} vs {real:5.1f}   | {fc:5.1f} vs {60000/rr.mean():5.1f} | {sp:5.1f} ({esp:.1f})')
