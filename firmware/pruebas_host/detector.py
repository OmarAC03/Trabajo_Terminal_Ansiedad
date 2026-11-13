"""Modelo en Python del detector propuesto (idéntico en lógica al firmware corregido)."""
import numpy as np
from sim_pba import ppg, corre
class Biquad:
    def __init__(s, b, a): s.b, s.a = b, a; s.z1 = s.z2 = 0.0
    def __call__(s, x):  # forma directa II transpuesta
        y = s.b[0] * x + s.z1
        s.z1 = s.b[1] * x - s.a[1] * y + s.z2
        s.z2 = s.b[2] * x - s.a[2] * y
        return y
HP = ([0.9780304792, -1.9560609584, 0.9780304792], [1, -1.9555782403, 0.9565436765])
LP = ([0.0200833656, 0.0401667311, 0.0200833656], [1, -1.5610180758, 0.6413515381])
class Detector:
    REFRACT = 300; FS_MS = 10
    def __init__(s):
        s.hp = None; s.calent = 200   # 2 s de calentamiento del filtro
    def reinicia(s, x0):
        s.hp = Biquad(*HP); s.lp = Biquad(*LP)
        s.hp.z1 = -HP[0][0] * x0; s.hp.z2 = HP[0][2] * x0   # arranca en estado estable: sin escalón
        s.y1 = s.y2 = 0.0; s.amp = 0.0; s.ultimo = -10**9; s.n = 0
    def muestra(s, ir):
        """Devuelve el instante del latido en ms (con interpolación) o None."""
        if s.hp is None: s.reinicia(float(ir))
        y = -s.lp(s.hp(float(ir)))            # invertida: la sístole queda como pico
        t1 = (s.n - 1) * s.FS_MS; res = None
        if s.n > s.calent and s.y1 > s.y2 and s.y1 >= y and s.y1 > 0.5 * s.amp and t1 - s.ultimo > s.REFRACT:
            den = s.y2 - 2 * s.y1 + y
            off = 0.5 * (s.y2 - y) / den if den != 0 else 0.0     # vértice de la parábola, en muestras
            tb = t1 + off * s.FS_MS
            res = tb; s.ultimo = tb
            s.amp = s.y1 if s.amp == 0 else 0.8 * s.amp + 0.2 * s.y1
        if s.n > s.calent and t1 - s.ultimo > 1500: s.amp *= 0.98   # sin latido 1.5 s: baja el umbral poco a poco
        if s.n == s.calent: s.amp = 0.0
        s.y2, s.y1 = s.y1, y; s.n += 1
        return res

def rr_validos(det_ms):
    """RR 300–2000 y regla del 20 % de la app; RMSSD solo con pares consecutivos válidos."""
    rr = np.diff(det_ms); pares = []; ok = 0
    for a, b in zip(rr[:-1], rr[1:]):
        if 300 <= a <= 2000 and 300 <= b <= 2000 and abs(b - a) <= 0.2 * a:
            pares.append(b - a); ok += 1
    rm = np.sqrt(np.mean(np.square(pares))) if pares else float('nan')
    return ok, len(rr) - 1, rm

if __name__ == '__main__':
    print('caso                              | método           | latidos det/real | pares válidos | RMSSD med vs real')
    for ac in (300, 1000, 3000):
        for dic in (0.2, 0.35, 0.5):
            for hr in (65, 95):
                import sim_pba
                tt, s, beats = ppg(ac=ac, hr=hr, seed=ac + hr, dic=dic)
                real = np.sqrt(np.mean(np.diff(np.diff(beats * 1000)) ** 2))
                # PBA actual (50 Hz efectivos)
                pba = corre(tt, s, 2) * 1000
                d = Detector(); nuevo = np.array([r for x in s if (r := d.muestra(x)) is not None])
                for nom, det in (('PBA actual 50 Hz', pba), ('propuesto 100 Hz', nuevo)):
                    ok, tot, rm = rr_validos(det) if len(det) > 3 else (0, 0, float('nan'))
                    print(f'AC {ac:4d} dic {dic:.2f} FC {hr:3d}            | {nom:16s} | {len(det):4d}/{len(beats[beats<180]):4d}        | {ok:4d}/{tot:4d}     | {rm:6.1f} vs {real:5.1f}')
