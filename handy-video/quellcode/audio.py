import numpy as np, json, wave, sys, os
D = os.path.dirname(os.path.abspath(__file__))
SR = 44100
T = 64.0
N = int(SR * T)
rng = np.random.default_rng(7)
L = np.zeros(N); R = np.zeros(N)
ev = json.load(open(os.path.join(D, 'events.json')))

def tt(n): return np.arange(n) / SR
def add(sig, t0, gain=1.0, pan=0.0):
    i0 = int(t0 * SR)
    if i0 >= N: return
    sig = sig[:N - i0]
    l = np.cos((pan + 1) * np.pi / 4); r = np.sin((pan + 1) * np.pi / 4)
    L[i0:i0 + len(sig)] += sig * gain * l * 1.414
    R[i0:i0 + len(sig)] += sig * gain * r * 1.414

def fft_filter(x, lo=None, hi=None):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    if lo: m *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4)
    if hi: m *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X * m, len(x))

def env_adsr(n, a, r):
    e = np.ones(n); na = int(a * SR); nr = int(r * SR)
    if na: e[:na] = np.linspace(0, 1, na) ** 2
    if nr: e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e

def note(f, dur, harm=6, roll=1.6, det=0.003):
    t = tt(int(dur * SR)); s = np.zeros_like(t)
    for d in (-det, 0, det):
        for k in range(1, harm + 1):
            s += np.sin(2 * np.pi * f * (1 + d) * k * t + k * 1.3) / k ** roll
    return s / 3

def mtof(m): return 440 * 2 ** ((m - 69) / 12)

# ---------------- pad (0..48) ----------------
chords = [[45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [36, 43, 52, 55, 60], [43, 50, 55, 59, 62]]
seg = 6.0
t0 = 0.0; ci = 0
while t0 < 48.5:
    ch = chords[ci % 4]
    prog = min(t0 / 41, 1)
    for j, m in enumerate(ch):
        s = note(mtof(m), seg + 2.0, harm=3 + int(5 * prog), roll=1.8 - 0.5 * prog)
        s *= env_adsr(len(s), 1.8, 2.2)
        add(s, t0, 0.035 * (0.7 + 0.5 * prog), pan=(j - 2) * 0.25)
    t0 += seg; ci += 1
# sub pulse heartbeat during zoom
for k in range(int(6.5 / 0.8), int(41 / 0.8)):
    tb = k * 0.8
    t = tt(int(0.35 * SR)); s = np.sin(2 * np.pi * 55 * t) * np.exp(-t * 12)
    add(s, tb, 0.10 * min(1, (tb - 5) / 10))

# ---------------- halving ticks ----------------
for (tk, k) in ev['ticks'] + [[40.9, 26]]:
    f = 880 * 2 ** (k / 30)
    t = tt(int(0.6 * SR))
    s = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)) * np.exp(-t * 7)
    s[:40] *= np.linspace(0, 1, 40)
    add(s, tk, 0.10, pan=0.3 * np.sin(k))

# ---------------- riser 33..41 ----------------
d = 8.0; t = tt(int(d * SR))
nz = fft_filter(rng.standard_normal(len(t)), lo=300, hi=6000)
nz /= np.abs(nz).max()
s = nz * (t / d) ** 2.5 * 0.5
sw = np.sin(2 * np.pi * np.cumsum(200 + 900 * (t / d) ** 2) / SR) * (t / d) ** 2 * 0.25
add(s + sw, 33.0, 0.35)

# ---------------- impact at 41 ----------------
t = tt(int(3.0 * SR))
boom = np.sin(2 * np.pi * np.cumsum(60 * np.exp(-t * 1.2) + 32) / SR) * np.exp(-t * 1.6)
burst = fft_filter(rng.standard_normal(len(t)), hi=2500) * np.exp(-t * 8)
burst /= np.abs(burst).max()
add(boom * 0.9 + burst * 0.25, 41.0, 0.55)

# ---------------- electron stage 41..48.2 ----------------
t = tt(int(6.8 * SR))
drone = (np.sin(2 * np.pi * 55 * t) + 0.5 * np.sin(2 * np.pi * 82.4 * t) + 0.3 * np.sin(2 * np.pi * 110.3 * t)) * env_adsr(len(t), 1.0, 1.5)
add(drone, 41.0, 0.08)
for m in [69, 72, 76, 81, 84]:
    s = note(mtof(m), 6.4, harm=2) * env_adsr(int(6.4 * SR), 1.5, 1.6)
    add(s, 41.2, 0.022, pan=rng.uniform(-0.6, 0.6))
for i in range(70):
    tb = 41.2 + rng.uniform(0, 6.2)
    f = rng.uniform(2500, 7000)
    t = tt(int(0.25 * SR)); s = np.sin(2 * np.pi * f * t) * np.exp(-t * 25)
    add(s, tb, 0.025, pan=rng.uniform(-0.9, 0.9))
for k in range(4):
    tb = 41.2 + k * 1.6
    t = tt(int(0.8 * SR)); s = np.sin(2 * np.pi * (70 + 30 * np.exp(-t * 5)) * t) * np.exp(-t * 5)
    add(s, tb, 0.18)

# ---------------- whoosh zoom-out 47.9..49.2 ----------------
d = 1.7; t = tt(int(d * SR))
nz = fft_filter(rng.standard_normal(len(t)), lo=150, hi=4000); nz /= np.abs(nz).max()
e = np.sin(np.pi * t / d) ** 2
add(nz * e, 47.45, 0.38)
# dive whoosh at the start
d = 1.6; t = tt(int(d * SR))
nz = fft_filter(rng.standard_normal(len(t)), lo=200, hi=3000); nz /= np.abs(nz).max()
add(nz * np.sin(np.pi * t / d) ** 3, 5.0, 0.22)
# soft hit on phone
t = tt(int(2.5 * SR))
hit = np.sin(2 * np.pi * 50 * t) * np.exp(-t * 4) + 0.3 * fft_filter(rng.standard_normal(len(t)), hi=1200) * np.exp(-t * 20) / 3
add(hit, 49.05, 0.4)
for j, m in enumerate([45, 52, 57, 60, 64]):
    s = note(mtof(m), 2.6, harm=4) * env_adsr(int(2.6 * SR), 0.02, 1.5)
    add(s, 49.05, 0.04, pan=(j - 2) * 0.2)

# ---------------- cross-section 51.3..57.6 ----------------
for j, m in enumerate([41, 48, 53, 57, 60]):
    s = note(mtof(m), 6.4, harm=4) * env_adsr(int(6.4 * SR), 1.2, 1.2)
    add(s, 51.3, 0.03, pan=(j - 2) * 0.25)
t = tt(int(4.2 * SR))
hum = (np.sin(2 * np.pi * 100 * t) + 0.4 * np.sin(2 * np.pi * 200 * t) + 0.2 * np.sin(2 * np.pi * 300 * t)) * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * t))
hum *= env_adsr(len(t), 0.8, 1.0)
add(hum, 53.0, 0.03)
for tb, f in [(52.7, 900), (53.75, 1320), (53.85, 1760), (55.6, 1047), (55.7, 1568)]:
    t = tt(int(0.5 * SR)); s = np.sin(2 * np.pi * f * t) * np.exp(-t * 9)
    add(s, tb, 0.09)

# ---------------- typing outro ----------------
for j, m in enumerate([43, 50, 55, 59, 62]):
    s = note(mtof(m), 4.4, harm=4) * env_adsr(int(4.4 * SR), 0.8, 1.0)
    add(s, 57.2, 0.03, pan=(j - 2) * 0.25)
for tb in ev['taps']:
    t = tt(int(0.05 * SR))
    clk = fft_filter(rng.standard_normal(len(t)), lo=1500, hi=9000) * np.exp(-t * 160)
    clk /= np.abs(clk).max()
    add(clk + 0.4 * np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 200), tb, 0.12, pan=rng.uniform(-0.2, 0.2))
# final chord
for j, m in enumerate([45, 52, 57, 59, 64, 71]):
    s = note(mtof(m), 2.6, harm=5) * env_adsr(int(2.6 * SR), 0.6, 1.4)
    add(s, 61.95, 0.045, pan=(j - 2.5) * 0.2)
t = tt(int(2.4 * SR)); s = np.sin(2 * np.pi * 1760 * t) * np.exp(-t * 2.5) + 0.5 * np.sin(2 * np.pi * 2637 * t) * np.exp(-t * 3)
add(s, 62.05, 0.05)

# ---------------- reverb ----------------
def reverb(x, seed):
    r = np.random.default_rng(seed); n = int(2.2 * SR); ti = np.arange(n) / SR
    ir = r.standard_normal(n) * np.exp(-ti * 2.6); ir = fft_filter(ir, lo=120, hi=7000); ir[:int(0.012*SR)] = 0; ir /= np.sqrt((ir**2).sum())
    m = 1 << int(np.ceil(np.log2(len(x) + n)))
    y = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)[:len(x)]
    return y
wet = 0.32
L2 = L + wet * reverb(L, 11) * 3; R2 = R + wet * reverb(R, 12) * 3
L, R = L2, R2
# ---------------- master ----------------
mix = np.stack([L, R], 1)
fade = np.ones(N); nf = int(1.2 * SR); fade[-nf:] = np.linspace(1, 0, nf) ** 1.5
mix *= fade[:, None]
mix /= np.abs(mix).max(); mix = np.tanh(mix * 2.6) / np.tanh(2.6)
mix /= np.abs(mix).max() / 0.89
w = wave.open(os.path.join(D, 'audio.wav'), 'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((mix * 32767).astype('<i2').tobytes()); w.close()
print('ok', mix.shape)
