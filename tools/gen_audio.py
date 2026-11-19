#!/usr/bin/env python3
"""
Gerador procedural de TODO o áudio do jogo SHIN (efeitos, ambientes e música).

Nenhuma amostra externa é utilizada: cada som é sintetizado matematicamente
(osciladores, ruído filtrado, envelopes). Por isso o áudio é 100% original e
pode ser distribuído junto com o jogo sem restrições de licença.

Uso:
    python3 tools/gen_audio.py            # gera assets/audio/*.wav

Requer apenas Python 3 + numpy.
"""
import os
import struct
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(1337)


# ---------------------------------------------------------------- utilidades
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_exp(n, decay):
    t = np.arange(n) / SR
    return np.exp(-t / max(decay, 1e-4))


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    e = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = max(1, min(ai, n))
    e[:ai] = np.linspace(0, 1, ai)
    if di > 0 and ai + di < n:
        e[ai:ai + di] = np.linspace(1, s, di)
    if ri > 0 and ri < n:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def noise(n):
    return rng.uniform(-1, 1, n)


def fft_filter(x, lo=0.0, hi=None, q_shape=1.0):
    """Filtro passa-faixa suave via FFT (sem scipy)."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    m = np.ones_like(f)
    if lo > 0:
        m *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** (2 * q_shape))
    if hi is not None:
        m *= 1 / (1 + (f / hi) ** (2 * q_shape))
    return np.fft.irfft(X * m, n)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def write_wav(name, x, loop=False):
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype("<i2").tobytes()
    chunks = b""
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks += b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop:
        # chunk 'smpl' com ponto de loop: o importador do Godot detecta o loop
        n = len(x)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    data = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    with open(os.path.join(OUT, name + ".wav"), "wb") as fh:
        fh.write(data)
    print(f"  {name}.wav  {len(x)/SR:5.2f}s{'  (loop)' if loop else ''}")


def place(buf, sig, start_s, gain=1.0):
    i = int(start_s * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i] * gain


def place_loop(buf, sig, start_s, gain=1.0):
    """Insere com 'wrap-around' para loops sem emenda."""
    i = int(start_s * SR) % len(buf)
    n = len(sig)
    end = i + n
    if end <= len(buf):
        buf[i:end] += sig * gain
    else:
        k = len(buf) - i
        buf[i:] += sig[:k] * gain
        rest = sig[k:]
        while len(rest) > 0:
            m = min(len(rest), len(buf))
            buf[:m] += rest[:m] * gain
            rest = rest[m:]


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# --------------------------------------------------------------- instrumentos
def taiko(dur=0.9, f0=95, f1=48, gain=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * env_exp(n, 0.28)
    skin = fft_filter(noise(n), 60, 900) * env_exp(n, 0.035) * 0.9
    return (body + skin) * gain


def shime(dur=0.25, gain=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 380 * t) * env_exp(n, 0.05)
    click = fft_filter(noise(n), 1500, 6000) * env_exp(n, 0.012)
    return (body * 0.6 + click) * gain


def koto(freq, dur=1.6, gain=0.4, bright=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    bend = 1 + 0.004 * np.exp(-t * 25)
    for h in range(1, 9):
        amp = (1.0 / h ** 1.2) * (bright if h > 2 else 1)
        dec = 0.9 / (1 + 0.45 * h)
        out += amp * np.sin(2 * np.pi * freq * h * bend * t + h) * np.exp(-t / dec)
    pluck = fft_filter(noise(n), 1500, 7000) * env_exp(n, 0.008) * 0.15
    return (out + pluck) * gain * adsr(n, 0.002, 0.05, 1.0, 0.05)


def shamisen(freq, dur=0.5, gain=0.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for h in range(1, 12):
        out += (1 / h) * np.sin(2 * np.pi * freq * h * t) * np.exp(-t / (0.35 / (1 + 0.3 * h)))
    buzz = fft_filter(noise(n), 2000, 8000) * env_exp(n, 0.02) * 0.3
    return (out * 0.5 + buzz) * gain


def flute(freq, dur=1.5, gain=0.35, breath=0.25, vib=5.0, slide=True):
    """Flauta estilo shakuhachi: sopro + vibrato + portamento inicial."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib_amt = 0.006 * np.clip(t / 0.4, 0, 1)
    f = freq * (1 + vib_amt * np.sin(2 * np.pi * vib * t))
    if slide:
        f *= 2 ** ((-0.9 * np.exp(-t * 14)) / 12)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    br = fft_filter(noise(n), freq * 0.8, freq * 3.5) * breath
    e = adsr(n, 0.12, 0.2, 0.75, min(0.35, dur * 0.4))
    return (tone * 0.6 + br) * e * gain


def drone(freq, dur, gain=0.15):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(2 * np.pi * freq * 1.5 * t + 0.3)
    x += 0.25 * np.sin(2 * np.pi * freq * 2.003 * t)
    return x * gain


def gong(dur=4.0, f=110, gain=0.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, d in [(1, 1, 2.5), (1.48, 0.6, 1.8), (2.03, 0.5, 1.4), (2.74, 0.35, 1.0), (3.6, 0.25, 0.7), (4.9, 0.2, 0.5)]:
        out += a * np.sin(2 * np.pi * f * r * t * (1 + 0.002 * np.sin(2 * np.pi * 3 * t))) * np.exp(-t / d)
    hit = fft_filter(noise(n), 300, 3000) * env_exp(n, 0.04) * 0.5
    return (out + hit) * gain * adsr(n, 0.004, 0.1, 1.0, 0.3)


# Escala japonesa "In" (miyako-bushi) e "Yo"
IN_SCALE = [0, 1, 5, 7, 8]       # D Eb G A Bb
YO_SCALE = [0, 2, 5, 7, 9]


def scale_note(root, scale, idx):
    octv, deg = divmod(idx, len(scale))
    return root + 12 * octv + scale[deg]


# --------------------------------------------------------------------- SFX
def sfx():
    print("Efeitos:")
    # Golpe leve: sopro de ar curto
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    sweep = np.zeros(n)
    x = noise(n)
    a = fft_filter(x, 900, 5000) * np.sin(np.pi * np.clip(t / 0.22, 0, 1)) ** 2
    write_wav("swing_light", fade(norm(a, 0.7)))

    n = int(0.45 * SR)
    t = np.arange(n) / SR
    a = fft_filter(noise(n), 400, 3000) * np.sin(np.pi * np.clip(t / 0.38, 0, 1)) ** 1.5
    a += fft_filter(noise(n), 120, 600) * np.sin(np.pi * np.clip(t / 0.38, 0, 1)) ** 2 * 0.8
    write_wav("swing_heavy", fade(norm(a, 0.85)))

    # Choque metálico de espadas
    def metal(dur, base, decay, gain=0.9, seed_partials=None):
        n = int(dur * SR)
        t = np.arange(n) / SR
        out = np.zeros(n)
        parts = seed_partials or [1, 2.76, 5.40, 8.93, 13.34]
        for i, r in enumerate(parts):
            out += np.sin(2 * np.pi * base * r * t + i) * np.exp(-t / (decay / (1 + i * 0.5))) / (1 + i * 0.4)
        hit = fft_filter(noise(n), 2000, 9000) * env_exp(n, 0.006)
        return norm(out + hit * 1.5, gain)

    write_wav("clash", fade(metal(0.7, 1180, 0.25)))
    write_wav("block", fade(metal(0.5, 760, 0.12, 0.8)))
    p = metal(1.2, 1560, 0.5, 0.75) + metal(1.2, 2340, 0.35, 0.4)
    write_wav("parry", fade(norm(p, 0.9)))

    # Corte acertando (impacto surdo)
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    a = fft_filter(noise(n), 80, 1400) * env_exp(n, 0.05)
    a += np.sin(2 * np.pi * (140 * np.exp(-t * 10) + 60) * t) * env_exp(n, 0.08)
    a += fft_filter(noise(n), 2500, 7000) * env_exp(n, 0.02) * 0.4
    write_wav("hit", fade(norm(a, 0.9)))

    # Dano no jogador (impacto mais grave)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    a = np.sin(2 * np.pi * (90 * np.exp(-t * 6) + 45) * t) * env_exp(n, 0.15)
    a += fft_filter(noise(n), 100, 900) * env_exp(n, 0.06)
    write_wav("hurt", fade(norm(a, 0.9)))

    # Passo na terra
    n = int(0.16 * SR)
    a = fft_filter(noise(n), 90, 900) * env_exp(n, 0.03)
    a += fft_filter(noise(n), 1500, 4000) * env_exp(n, 0.01) * 0.2
    write_wav("step", fade(norm(a, 0.5)))

    # Esquiva (sopro + tecido)
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    a = fft_filter(noise(n), 300, 2500) * np.sin(np.pi * np.clip(t / 0.35, 0, 1)) ** 2
    write_wav("dodge", fade(norm(a, 0.6)))

    # Arco disparando
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    tw = np.sin(2 * np.pi * 180 * t * (1 + 0.1 * np.exp(-t * 30))) * env_exp(n, 0.09)
    whoosh = fft_filter(noise(n), 1200, 6000) * np.exp(-((t - 0.12) / 0.07) ** 2) * 0.6
    write_wav("bow", fade(norm(tw + whoosh, 0.7)))

    n = int(0.25 * SR)
    a = fft_filter(noise(n), 300, 3000) * env_exp(n, 0.03)
    a += np.sin(2 * np.pi * 300 * np.arange(n) / SR) * env_exp(n, 0.04) * 0.5
    write_wav("arrow_hit", fade(norm(a, 0.6)))

    # Morte de inimigo (queda)
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    a = fft_filter(noise(n), 60, 600) * (env_exp(n, 0.1) + 0.6 * np.exp(-((t - 0.45) / 0.05) ** 2))
    a += np.sin(2 * np.pi * 70 * t) * np.exp(-((t - 0.45) / 0.08) ** 2) * 0.7
    write_wav("fall", fade(norm(a, 0.8)))

    # Habilidade especial: corte lunar
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    w = fft_filter(noise(n), 400, 6000) * np.sin(np.pi * np.clip(t / 0.6, 0, 1)) ** 2
    shimmer = np.zeros(n)
    for k, f in enumerate([1320, 1760, 2217, 2637]):
        shimmer += np.sin(2 * np.pi * f * t) * np.exp(-np.maximum(t - 0.05 * k, 0) / 0.5) * (t > 0.05 * k)
    low = np.sin(2 * np.pi * (200 * np.exp(-t * 4) + 50) * t) * env_exp(n, 0.4)
    write_wav("special", fade(norm(w + shimmer * 0.25 + low * 0.8, 0.9)))

    # Coleta / pergaminho
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    a = np.zeros(n)
    for k, m in enumerate([74, 79, 81, 86]):
        st = int(k * 0.09 * SR)
        a[st:] += koto(midi(m), (n - st) / SR, 0.5, 1.2)[: n - st]
    write_wav("pickup", fade(norm(a, 0.7)))

    # Ponto de salvamento: sino de templo
    write_wav("checkpoint", fade(norm(gong(3.0, 330, 1.0) * 0.6 + koto(midi(81), 3.0, 0.4), 0.7)))
    write_wav("gong", fade(norm(gong(4.5, 98, 1.0), 0.9)))

    # Interface
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    write_wav("ui_click", fade(norm(np.sin(2 * np.pi * 1200 * t) * env_exp(n, 0.02), 0.4)))
    write_wav("ui_select", fade(norm(koto(midi(81), 0.6, 0.5, 1.4), 0.5)))

    # Armadilha: lâminas surgindo
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    a = fft_filter(noise(n), 1500, 8000) * env_exp(n, 0.05)
    a += metal(0.5, 620, 0.1, 0.5)
    write_wav("trap", fade(norm(a, 0.7)))

    # Transição de fase
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    a = fft_filter(noise(n), 200, 2500) * np.sin(np.pi * t / 2.0) ** 2
    a += taiko(2.0, 80, 40, 1.0) * 0.8
    write_wav("transition", fade(norm(a, 0.8)))

    # Onda de choque (chefes)
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    a = np.sin(2 * np.pi * (70 * np.exp(-t * 3) + 30) * t) * env_exp(n, 0.35)
    a += fft_filter(noise(n), 50, 1200) * env_exp(n, 0.25)
    write_wav("slam", fade(norm(a, 0.95)))

    # Grito/rugido do chefe (formante sintético)
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    f = 110 * (1 + 0.15 * np.sin(2 * np.pi * 6 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = sum(np.sin(k * ph) / k for k in range(1, 30))
    v = fft_filter(saw, 400, 1100) + fft_filter(noise(n), 300, 2000) * 0.4
    write_wav("roar", fade(norm(v * adsr(n, 0.08, 0.2, 0.8, 0.4), 0.85)))


# ---------------------------------------------------------------- ambientes
def ambiences():
    print("Ambientes:")
    dur = 16.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    # vento: ruído filtrado com modulação lenta (periódica para loop perfeito)
    def wind(gain=1.0, lo=150, hi=900):
        w = fft_filter(noise(n), lo, hi)
        mod = 0.6 + 0.4 * np.sin(2 * np.pi * t / dur * 2) * np.sin(2 * np.pi * t / dur * 3 + 1)
        return norm(w, 1) * mod * gain

    forest = wind(0.45)
    for _ in range(14):
        st = rng.uniform(0, dur)
        f = rng.uniform(2500, 4200)
        k = int(rng.integers(2, 5))
        for j in range(k):
            m = int(0.09 * SR)
            tt = np.arange(m) / SR
            chirp = np.sin(2 * np.pi * (f + 1800 * tt / 0.09) * tt) * np.sin(np.pi * tt / 0.09) ** 2
            place_loop(forest, chirp, st + j * 0.13, 0.12)
    write_wav("amb_forest", norm(forest, 0.6), loop=True)

    village = wind(0.35)
    crack = np.zeros(n)
    for _ in range(260):
        st = rng.uniform(0, dur)
        m = int(rng.uniform(0.005, 0.03) * SR)
        c = fft_filter(noise(m), 800, 6000) * env_exp(m, 0.005)
        place_loop(crack, c, st, rng.uniform(0.2, 1.0))
    roar = fft_filter(noise(n), 60, 400) * 0.35
    village += norm(crack, 0.5) + roar
    write_wav("amb_village", norm(village, 0.6), loop=True)

    night = wind(0.25, 100, 600)
    for _ in range(40):
        st = rng.uniform(0, dur)
        f = rng.uniform(4200, 5200)
        m = int(0.35 * SR)
        tt = np.arange(m) / SR
        cr = np.sin(2 * np.pi * f * tt) * (np.sin(2 * np.pi * 28 * tt) > 0.2) * np.sin(np.pi * tt / 0.35)
        place_loop(night, cr, st, 0.05)
    write_wav("amb_night", norm(night, 0.55), loop=True)

    mountain = wind(0.7, 200, 1400)
    write_wav("amb_mountain", norm(mountain, 0.6), loop=True)

    castle = wind(0.5, 80, 700)
    for k in range(4):
        place_loop(castle, taiko(1.5, 70, 38, 1.0), k * 4.0 + 1.0, 0.25)
    write_wav("amb_castle", norm(castle, 0.6), loop=True)


# ------------------------------------------------------------------- música
def music_menu():
    bpm = 66
    beat = 60 / bpm
    bars = 12
    dur = bars * 4 * beat
    buf = np.zeros(int(dur * SR))
    root = 50  # D3
    buf += drone(midi(root - 12), dur, 0.10)
    # koto em arpejo
    pattern = [0, 2, 4, 5, 4, 2]
    for b in range(bars):
        for i in range(8):
            deg = pattern[i % len(pattern)] + (2 if b % 4 == 2 else 0)
            place_loop(buf, koto(midi(scale_note(root, IN_SCALE, deg)), 2.0, 0.22), (b * 4 + i * 0.5) * beat)
    # melodia de shakuhachi
    mel = [(7, 2), (8, 1), (7, 1), (5, 3), (None, 1), (4, 1), (5, 1), (7, 2), (6, 4),
           (7, 2), (9, 2), (8, 1), (7, 1), (5, 4), (4, 2), (3, 2), (4, 4), (None, 4)]
    pos = 4 * beat * 2
    for deg, ln in mel:
        if deg is not None:
            place_loop(buf, flute(midi(scale_note(root + 12, IN_SCALE, deg)), ln * beat * 1.05, 0.3), pos)
        pos += ln * beat
    for b in range(0, bars, 2):
        place_loop(buf, taiko(1.2, 80, 42, 0.5), b * 4 * beat)
    write_wav("music_menu", norm(buf, 0.75), loop=True)


def music_explore():
    bpm = 84
    beat = 60 / bpm
    bars = 16
    dur = bars * 4 * beat
    buf = np.zeros(int(dur * SR))
    root = 50
    buf += drone(midi(root - 12), dur, 0.07)
    prog = [0, 0, 3, 2]
    for b in range(bars):
        off = prog[b % 4]
        for i, deg in enumerate([0, 2, 4, 2, 5, 2, 4, 2]):
            place_loop(buf, koto(midi(scale_note(root, IN_SCALE, deg + off)), 1.4, 0.18), (b * 4 + i * 0.5) * beat)
        place_loop(buf, taiko(0.9, 90, 45, 0.35), b * 4 * beat)
        place_loop(buf, shime(0.2, 0.12), (b * 4 + 2.5) * beat)
    mel = [(9, 3), (8, 1), (7, 4), (None, 2), (5, 1), (7, 1), (8, 4), (7, 2), (5, 2),
           (4, 3), (5, 1), (7, 4), (None, 4), (9, 2), (10, 2), (9, 1), (8, 1), (7, 4), (5, 2), (7, 6), (None, 6)]
    pos = 4 * beat * 4
    for deg, ln in mel:
        if deg is not None:
            place_loop(buf, flute(midi(scale_note(root, IN_SCALE, deg)), ln * beat, 0.24), pos)
        pos += ln * beat
    write_wav("music_explore", norm(buf, 0.72), loop=True)


def music_combat():
    bpm = 126
    beat = 60 / bpm
    bars = 16
    dur = bars * 4 * beat
    buf = np.zeros(int(dur * SR))
    root = 50
    buf += drone(midi(root - 12), dur, 0.08)
    kit = [1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1]
    for b in range(bars):
        for s in range(16):
            tt = (b * 4 + s * 0.25) * beat
            if kit[s]:
                place_loop(buf, taiko(0.7, 100 if s % 4 == 0 else 85, 46, 0.8 if s % 4 == 0 else 0.55), tt)
            if s % 2 == 1:
                place_loop(buf, shime(0.15, 0.18 if s % 4 == 3 else 0.09), tt)
        riff = [0, 0, 1, 0, 3, 0, 2, 1] if b % 4 < 2 else [0, 0, 1, 0, 4, 3, 2, 1]
        for i, deg in enumerate(riff):
            place_loop(buf, shamisen(midi(scale_note(root, IN_SCALE, deg)), 0.4, 0.25), (b * 4 + i * 0.5) * beat)
    mel = [(10, 2), (9, 1), (8, 1), (7, 4), (8, 2), (7, 1), (5, 1), (4, 4),
           (5, 2), (7, 2), (8, 2), (10, 2), (9, 8)]
    for rep in range(2):
        pos = (8 * rep + 4) * 4 * beat if rep else 4 * 4 * beat
        pos = (4 + 6 * rep) * 4 * beat
        for deg, ln in mel:
            place_loop(buf, flute(midi(scale_note(root + 12, IN_SCALE, deg)), ln * beat, 0.2, slide=True), pos)
            pos += ln * beat
    write_wav("music_combat", norm(buf, 0.8), loop=True)


def music_boss():
    bpm = 140
    beat = 60 / bpm
    bars = 16
    dur = bars * 4 * beat
    buf = np.zeros(int(dur * SR))
    root = 45  # A2
    buf += drone(midi(root - 12), dur, 0.12)
    buf += drone(midi(root - 12 + 1), dur, 0.04)  # dissonância
    kit = [1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1]
    for b in range(bars):
        for s in range(16):
            tt = (b * 4 + s * 0.25) * beat
            if kit[s]:
                place_loop(buf, taiko(0.8, 110 if s % 4 == 0 else 80, 40, 0.9 if s % 8 == 0 else 0.6), tt)
            place_loop(buf, shime(0.12, 0.08 + 0.08 * (s % 4 == 2)), tt)
        riff = [0, 1, 0, 3, 0, 1, 4, 3]
        for i, deg in enumerate(riff):
            place_loop(buf, shamisen(midi(scale_note(root + 12, IN_SCALE, deg)), 0.35, 0.28), (b * 4 + i * 0.5) * beat)
        if b % 8 == 0:
            place_loop(buf, gong(4.0, 73, 0.5), b * 4 * beat)
    mel = [(11, 4), (10, 2), (8, 2), (7, 6), (6, 2), (7, 2), (8, 2), (10, 2), (11, 2), (12, 8)]
    pos = 4 * 4 * beat
    for deg, ln in mel:
        place_loop(buf, flute(midi(scale_note(root + 12, IN_SCALE, deg)), ln * beat, 0.24, breath=0.4, vib=6.5), pos)
        pos += ln * beat
    write_wav("music_boss", norm(buf, 0.82), loop=True)


def music_victory():
    bpm = 72
    beat = 60 / bpm
    dur = 24 * beat
    buf = np.zeros(int(dur * SR) + SR * 3)
    root = 50
    mel = [(0, 1), (2, 1), (3, 2), (4, 1), (3, 1), (2, 2), (3, 1), (4, 1), (5, 2), (7, 6)]
    pos = 0.5
    for deg, ln in mel:
        place(buf, flute(midi(scale_note(root + 12, YO_SCALE, deg)), ln * beat * 1.1, 0.3), pos)
        pos += ln * beat
    for i in range(24):
        deg = [0, 2, 4, 5][i % 4]
        place(buf, koto(midi(scale_note(root, YO_SCALE, deg)), 2.0, 0.2), 0.5 + i * beat)
    place(buf, gong(5.0, 147, 0.4), 0.5)
    place(buf, gong(5.0, 147, 0.4), 0.5 + 20 * beat)
    write_wav("music_victory", fade(norm(buf, 0.75), 0.01, 2.0))


def music_defeat():
    dur = 6.0
    buf = np.zeros(int(dur * SR))
    root = 50
    place(buf, gong(5.5, 73, 0.6), 0)
    for k, deg in enumerate([4, 3, 1, 0]):
        place(buf, flute(midi(scale_note(root, IN_SCALE, deg)), 1.4, 0.28, slide=True), 0.3 + k * 1.2)
    write_wav("music_defeat", fade(norm(buf, 0.7), 0.01, 1.5))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    ambiences()
    print("Música:")
    music_menu()
    music_explore()
    music_combat()
    music_boss()
    music_victory()
    music_defeat()
    print("Concluído.")
