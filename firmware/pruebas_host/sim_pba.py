"""Puerto fiel de checkForBeat (SparkFun heartRate.cpp) para probarlo con PPG sintética."""
import numpy as np
def i16(v): v &= 0xFFFF; return v - 0x10000 if v & 0x8000 else v
def u16(v): return v & 0xFFFF
COEF = [172, 321, 579, 927, 1360, 1858, 2390, 2916, 3391, 3768, 4012, 4096]
class PBA:
    def __init__(s):
        s.avg = 0; s.cbuf = [0]*32; s.off = 0; s.cur = 0; s.prev = 0
        s.mx = 0; s.mn = 0; s.ACmax = 20; s.ACmin = -20; s.pos = 0; s.neg = 0
    def dc(s, x):
        s.avg += ((u16(x) << 15) - s.avg) >> 4
        return i16(s.avg >> 15)
    def fir(s, din):
        s.cbuf[s.off] = i16(din)
        z = COEF[11] * s.cbuf[(s.off - 11) & 31]
        for i in range(11):
            z += COEF[i] * i16(s.cbuf[(s.off - i) & 31] + s.cbuf[(s.off - 22 + i) & 31])
        s.off = (s.off + 1) % 32
        return i16(z >> 15)
    def beat(s, sample):
        b = False; s.prev = s.cur
        e = s.dc(sample); s.cur = s.fir(sample - e)
        if s.prev < 0 and s.cur >= 0:
            s.ACmax, s.ACmin = s.mx, s.mn; s.pos, s.neg = 1, 0; s.mx = 0
            if 20 < s.ACmax - s.ACmin < 1000: b = True
        if s.prev > 0 and s.cur <= 0: s.pos, s.neg = 0, 1; s.mn = 0
        if s.pos and s.cur > s.prev: s.mx = s.cur
        if s.neg and s.cur < s.prev: s.mn = s.cur
        return b

def ppg(dur=180, fs=100, hr=75, rmssd=40, dc=120000, ac=1000, seed=1, dic=0.35):
    """PPG sintética: latidos con RR conocidos, forma con muesca dícrota, deriva respiratoria y ruido."""
    rng = np.random.default_rng(seed)
    rr = []; t = 0; base = 60000 / hr
    while t < dur * 1000 + 2000:
        r = base + rng.normal(0, rmssd / np.sqrt(2)); rr.append(r); t += r
    beats = np.cumsum(rr) / 1000
    tt = np.arange(0, dur, 1 / fs); x = np.zeros_like(tt)
    for b in beats:
        d = tt - b; m = (d > -0.1) & (d < 1.2)
        x[m] += np.exp(-((d[m] - 0.12) / 0.07) ** 2) + dic * np.exp(-((d[m] - 0.38) / 0.09) ** 2)
    x = (x - x.min()) / (x.max() - x.min())
    sig = dc - ac * x + 0.15 * ac * np.sin(2 * np.pi * 0.25 * tt) + rng.normal(0, ac * 0.02, tt.size)  # la absorción sube en sístole
    return tt, sig.astype(int), beats

def corre(tt, sig, paso, fs=100):
    p = PBA(); det = []
    for k in range(0, len(sig), paso):
        if p.beat(int(sig[k])): det.append(tt[k])
    return np.array(det)

def evalua(det, beats):
    rr_det = np.diff(det) * 1000
    ok = rr_det[(rr_det >= 300) & (rr_det <= 2000)]
    rr_true = np.diff(beats) * 1000
    rm = lambda r: np.sqrt(np.mean(np.diff(r) ** 2)) if len(r) > 2 else float('nan')
    return len(det), len(beats[beats < det.max()]) if len(det) else 0, rm(ok), rm(rr_true[:len(ok)])

if __name__ == '__main__':
    print('AC p2p | proceso | latidos detectados / reales | RMSSD medido vs real (ms)')
    for ac in (300, 600, 900, 1500, 3000):
        tt, s, beats = ppg(ac=ac)
        for paso, nom in ((2, '50 Hz (código actual)'), (1, '100 Hz (corregido)')):
            det = corre(tt, s, paso)
            n, nt, rm, rt = evalua(det, beats) if len(det) > 3 else (len(det), len(beats), float('nan'), float('nan'))
            print(f'{ac:6d} | {nom:22s} | {n:4d} / {len(beats[beats<180]):4d} | {rm:6.1f} vs {rt:5.1f}')
