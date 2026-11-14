"""Kayıp Hazineler — 9. aşama ses ÖRNEKLERİ (yalnızca 3 adet).

Tamamen özgün, prosedürel üretim: yalnızca Python standart kütüphanesi
(math, random, wave, struct). Dışarıdan örnek/ses paketi kullanılmaz.
Sabit tohum: aynı script her çalıştırmada aynı dosyaları üretir.

Çıktılar (bu script'in klasörüne):
  ornek_korsan_muzigi.wav   ~19,2 sn, 6/8 neşeli korsan havası, döngüye uygun
  ornek_deniz_dalgalari.wav 24 sn, yumuşak dalga ortamı, kesintisiz döngü
  ornek_hazine_bulma.wav    ~2,6 sn, büyülü ödül efekti
"""

import math
import os
import random
import struct
import wave

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
TAU = 2.0 * math.pi


# --- Yardımcılar ---------------------------------------------------------------

def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def note(name):
    """'A4', 'F#5', 'Bb3' → MIDI numarası."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = names[name[0]]
    i = 1
    if name[i] == "#":
        base += 1
        i += 1
    elif name[i] == "b":
        base -= 1
        i += 1
    return 12 * (int(name[i:]) + 1) + base


def envelope(n, sr, attack, release, sustain_level=1.0):
    a = max(1, int(attack * sr))
    r = max(1, int(release * sr))
    env = [sustain_level] * n
    for i in range(min(a, n)):
        env[i] = sustain_level * i / a
    for i in range(min(r, n)):
        env[n - 1 - i] *= i / r
    return env


def add(buf, start, samples, gain=1.0):
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < len(buf):
            buf[j] += s * gain


def one_pole_lowpass(x, cutoff, sr):
    k = 1.0 - math.exp(-TAU * cutoff / sr)
    y, out = 0.0, []
    for s in x:
        y += k * (s - y)
        out.append(y)
    return out


def reverb(x, sr, wet=0.25, room=0.8, damp=0.35):
    """Basit Schroeder yankısı: 4 paralel tarak + 2 tüm geçiren filtre."""
    combs = [0.0297, 0.0371, 0.0411, 0.0437]
    out = [0.0] * len(x)
    for c in combs:
        d = int(c * sr)
        line = [0.0] * d
        idx, lp = 0, 0.0
        for i, s in enumerate(x):
            v = line[idx]
            lp = v * (1.0 - damp) + lp * damp
            line[idx] = s + lp * room
            idx = (idx + 1) % d
            out[i] += v * 0.25
    for c, g in [(0.0050, 0.7), (0.0017, 0.7)]:
        d = int(c * sr)
        line = [0.0] * d
        idx = 0
        for i in range(len(out)):
            v = line[idx]
            inp = out[i]
            y = -g * inp + v
            line[idx] = inp + g * y
            idx = (idx + 1) % d
            out[i] = y
    return [d_ * (1.0 - wet) + w * wet for d_, w in zip(x, out)]


def normalize(x, peak_db):
    peak = max(abs(s) for s in x) or 1.0
    k = 10 ** (peak_db / 20.0) / peak
    return [s * k for s in x]


def write_wav(path, x, sr):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for s in x:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
        w.writeframes(bytes(frames))


# --- Enstrümanlar --------------------------------------------------------------------

def flute(freq, dur, sr, rng):
    """Islık/flüt: hafif vibratolu, nefes gürültülü yumuşak ton."""
    n = int(dur * sr)
    env = envelope(n, sr, 0.035, 0.09, 1.0)
    out, ph = [], 0.0
    for i in range(n):
        t = i / sr
        vib = 1.0 + 0.004 * math.sin(TAU * 5.6 * t) * min(1.0, t / 0.15)
        ph += TAU * freq * vib / sr
        s = math.sin(ph) + 0.22 * math.sin(2 * ph) + 0.07 * math.sin(3 * ph)
        s += (rng.random() * 2 - 1) * 0.025
        out.append(s * env[i] * 0.55)
    return out


def celesta(freq, dur, sr, decay=0.55):
    """Çan/selesta: harmonik olmayan kısmilerle parlak, sönümlenen vuruş."""
    n = int(dur * sr)
    partials = [(1.0, 1.0), (2.0, 0.38), (3.0, 0.12), (4.17, 0.10), (5.43, 0.05)]
    out = []
    for i in range(n):
        t = i / sr
        a = min(1.0, t / 0.003)
        s = 0.0
        for k, g in partials:
            s += g * math.sin(TAU * freq * k * t) * math.exp(-t / (decay / k ** 0.6))
        out.append(s * a * 0.5)
    return out


def accordion(freqs, dur, sr):
    """Akordeon benzeri kısa akor: hafif akortsuz iki ses, tremolo, yumuşatılmış."""
    n = int(dur * sr)
    env = envelope(n, sr, 0.02, 0.06, 1.0)
    out = [0.0] * n
    for f in freqs:
        for det in (-0.0018, 0.0018):
            ff = f * (1.0 + det)
            for i in range(n):
                t = i / sr
                s = 0.0
                for k in range(1, 6):
                    s += math.sin(TAU * ff * k * t) / k
                out[i] += s
    for i in range(n):
        t = i / sr
        out[i] *= env[i] * (1.0 + 0.08 * math.sin(TAU * 6.0 * t)) * 0.09
    return one_pole_lowpass(out, 2400.0, sr)


def bass(freq, dur, sr):
    n = int(dur * sr)
    out = []
    for i in range(n):
        t = i / sr
        tri = 2.0 / math.pi * math.asin(math.sin(TAU * freq * t))
        s = 0.7 * math.sin(TAU * freq * t) + 0.3 * tri
        out.append(s * math.exp(-t / 0.32) * min(1.0, t / 0.004) * 0.6)
    return out


def kick(sr):
    n = int(0.22 * sr)
    out, ph = [], 0.0
    for i in range(n):
        t = i / sr
        f = 50.0 + 70.0 * math.exp(-t / 0.03)
        ph += TAU * f / sr
        out.append(math.sin(ph) * math.exp(-t / 0.09) * 0.55)
    return out


def shaker(sr, rng, gain):
    n = int(0.06 * sr)
    out, prev = [], 0.0
    for i in range(n):
        t = i / sr
        w = rng.random() * 2 - 1
        hp = w - prev
        prev = w
        out.append(hp * math.exp(-t / 0.015) * gain)
    return out


# --- 1. Korsan müziği ---------------------------------------------------------------

EIGHTH = 0.2          # 6/8, sekizlik 0,2 sn → ölçü 1,2 sn (canlı, neşeli)
CHORDS = ["D", "G", "D", "A", "D", "G", "A", "D", "Bm", "G", "D", "A", "G", "A", "D", "D"]
CHORD_NOTES = {
    "D": ["D4", "F#4", "A4"], "G": ["D4", "G4", "B4"], "A": ["C#4", "E4", "A4"], "Bm": ["D4", "F#4", "B4"],
}
BASS = {"D": ("D2", "A2"), "G": ("G2", "D3"), "A": ("A2", "E2"), "Bm": ("B2", "F#2")}
# Melodi: (nota, sekizlik sayısı); "R" = es. Her ölçü 6 sekizlik.
MELODY = [
    [("A4", 2), ("F#4", 1), ("A4", 2), ("D5", 1)],
    [("B4", 2), ("G4", 1), ("B4", 2), ("D5", 1)],
    [("A4", 2), ("F#4", 1), ("E4", 1), ("F#4", 1), ("A4", 1)],
    [("E4", 2), ("A4", 1), ("C#5", 3)],
    [("D5", 2), ("C#5", 1), ("B4", 2), ("A4", 1)],
    [("G4", 2), ("B4", 1), ("D5", 3)],
    [("C#5", 2), ("B4", 1), ("A4", 1), ("G4", 1), ("E4", 1)],
    [("D4", 3), ("R", 3)],
    [("F#4", 2), ("B4", 1), ("D5", 2), ("B4", 1)],
    [("G4", 2), ("B4", 1), ("D5", 2), ("G5", 1)],
    [("F#5", 2), ("E5", 1), ("D5", 2), ("A4", 1)],
    [("E5", 3), ("C#5", 3)],
    [("D5", 2), ("B4", 1), ("G4", 2), ("B4", 1)],
    [("C#5", 2), ("E5", 1), ("A5", 3)],
    [("F#5", 2), ("E5", 1), ("D5", 1), ("C#5", 1), ("B4", 1)],
    [("D5", 4), ("R", 2)],
]


def render_cycle(buf, offset, sr, rng):
    bar_len = int(6 * EIGHTH * sr)
    e = int(EIGHTH * sr)
    for b, chord in enumerate(CHORDS):
        start = offset + b * bar_len
        # Davul: ölçü başı tok vuruş, sekizliklerde hafif çıngırak.
        add(buf, start, kick(sr), 0.9)
        add(buf, start + 3 * e, kick(sr), 0.5)
        for k in range(6):
            add(buf, start + k * e, shaker(sr, rng, 0.25 if k in (0, 3) else 0.14))
        # Bas: 1. ve 4. sekizlik (kök ve beşli).
        root, fifth = BASS[chord]
        add(buf, start, bass(midi_hz(note(root)), 0.55, sr))
        add(buf, start + 3 * e, bass(midi_hz(note(fifth)), 0.55, sr), 0.85)
        # Akordeon "um-pa-pa": 2-3 ve 5-6. sekizliklerde kısa akorlar.
        freqs = [midi_hz(note(nm)) for nm in CHORD_NOTES[chord]]
        stab = accordion(freqs, EIGHTH * 0.75, sr)
        for k in (1, 2, 4, 5):
            add(buf, start + k * e, stab, 0.9 if k in (1, 4) else 0.7)
        # Melodi (flüt) + ölçü başlarında bir oktav yukarıda selesta parıltısı.
        pos = start
        for i, (nm, length) in enumerate(MELODY[b]):
            if nm != "R":
                f = midi_hz(note(nm))
                add(buf, pos, flute(f, length * EIGHTH * 0.95, sr, rng), 0.85)
                if i == 0:
                    add(buf, pos, celesta(f * 2.0, 0.9, sr, 0.4), 0.22)
            pos += length * e


def make_music():
    sr = 32000
    rng = random.Random(9101)
    cycle = int(len(CHORDS) * 6 * EIGHTH * sr)
    # İki tur üretilip ikincisi alınır: yankı ve nota kuyrukları döngü başına
    # sarılmış olur, böylece parça kesintisiz döngüye girebilir.
    buf = [0.0] * (2 * cycle)
    render_cycle(buf, 0, sr, rng)
    rng = random.Random(9101)
    render_cycle(buf, cycle, sr, rng)
    buf = reverb(buf, sr, wet=0.22, room=0.78)
    out = buf[cycle:2 * cycle]
    return normalize(out, -1.5), sr, True


# --- 2. Deniz dalgaları ----------------------------------------------------------------

def make_waves():
    sr = 32000
    seconds = 24.0
    n = int(seconds * sr)
    fade = int(2.0 * sr)
    total = n + fade
    rng = random.Random(9102)
    # Kabarma zarfı: döngü süresine tam bölünen periyotlar (6 sn, 4,8 sn, 8 sn)
    # ve farklı evreler; böylece döngü sınırında zarf da süreklidir.
    def swell(i):
        t = (i % n) / sr
        s = 0.55 + 0.30 * math.sin(TAU * t / 6.0) + 0.18 * math.sin(TAU * t / 4.8 + 1.3) + 0.12 * math.sin(TAU * t / 8.0 + 2.1)
        return max(0.05, s)
    # Gürültü kaynakları.
    white = [rng.random() * 2 - 1 for _ in range(total)]
    brown, b = [], 0.0
    for w in white:
        b = (b + w * 0.02) * 0.995
        brown.append(b)
    rumble = one_pole_lowpass(brown, 380.0, sr)
    foam_src = one_pole_lowpass(white, 3200.0, sr)
    foam_hp, prev = [], 0.0
    for s in foam_src:
        foam_hp.append(s - prev * 0.85)
        prev = s
    out = []
    for i in range(total):
        sw = swell(i)
        # Köpük, kabarmanın tepesinde belirir (yumuşak eşik).
        crest = max(0.0, sw - 0.75) ** 1.5 * 3.0
        out.append(rumble[i] * (0.6 + 0.8 * sw) * 1.8 + foam_hp[i] * (0.04 + crest * 0.22))
    out = one_pole_lowpass(out, 5000.0, sr)
    # Sondaki fazlalık başa eşit güçle çapraz geçirilir → kesintisiz döngü.
    loop = out[:n]
    for i in range(fade):
        a = i / fade
        g_in = math.sin(a * math.pi / 2)
        g_out = math.cos(a * math.pi / 2)
        loop[i] = out[i] * g_in + out[n + i] * g_out
    return normalize(loop, -6.0), sr, True


# --- 3. Hazine bulma ---------------------------------------------------------------------

def make_treasure():
    sr = 44100
    rng = random.Random(9103)
    n = int(2.6 * sr)
    buf = [0.0] * n
    # Yumuşak "vuuş" yükselişi.
    whoosh, prev = [], 0.0
    for i in range(int(0.5 * sr)):
        t = i / sr
        w = rng.random() * 2 - 1
        prev += (w - prev) * (0.02 + 0.25 * t / 0.5)
        whoosh.append(prev * math.sin(math.pi * t / 0.5) ** 2 * 0.5)
    add(buf, 0, whoosh)
    # Yükselen büyülü arpej (D majör pentatonik), selesta tınısı.
    arp = ["D5", "F#5", "A5", "B5", "D6", "F#6", "A6"]
    for k, nm in enumerate(arp):
        add(buf, int((0.12 + k * 0.065) * sr), celesta(midi_hz(note(nm)), 1.4, sr, 0.5), 0.55)
    # Ödül akoru: yumuşak D majör ped + üstte parlak çan.
    chord_start = int(0.62 * sr)
    for nm in ["D4", "A4", "D5", "F#5"]:
        f = midi_hz(note(nm))
        m = n - chord_start
        env = envelope(m, sr, 0.04, 1.4, 1.0)
        pad = [0.0] * m
        for i in range(m):
            t = i / sr
            pad[i] = (math.sin(TAU * f * t) + 0.3 * math.sin(TAU * 2 * f * t)) * env[i] * math.exp(-t / 1.1) * 0.18
        add(buf, chord_start, pad)
    add(buf, chord_start, celesta(midi_hz(note("D7")), 1.6, sr, 0.8), 0.35)
    # Işıltı: rastgele, çok yüksek minik çanlar (parıltı tozu).
    for k in range(22):
        t0 = 0.55 + rng.random() * 1.4
        f = midi_hz(rng.choice([note("A6"), note("D7"), note("F#7"), note("A7")]))
        add(buf, int(t0 * sr), celesta(f, 0.35, sr, 0.12), 0.12 * (1.0 - (t0 - 0.55) / 1.6))
    buf = reverb(buf, sr, wet=0.3, room=0.82)
    # Sona doğru kısa sönümleme (kuyruk kesilmesin).
    tail = int(0.25 * sr)
    for i in range(tail):
        buf[n - 1 - i] *= i / tail
    return normalize(buf, -1.0), sr, False


# --- Analiz -------------------------------------------------------------------------------

def analyze(name, x, sr, is_loop):
    peak = max(abs(s) for s in x)
    rms = math.sqrt(sum(s * s for s in x) / len(x))
    db = lambda v: 20 * math.log10(max(v, 1e-9))
    clipped = sum(1 for s in x if abs(s) >= 0.999)
    print(f"{name}")
    print(f"  süre: {len(x) / sr:.2f} sn  örnekleme: {sr} Hz  tepe: {db(peak):.1f} dBFS  ortalama (RMS): {db(rms):.1f} dBFS  kırpılan örnek: {clipped}")
    if is_loop:
        jump = abs(x[-1] - x[0])
        typical = sum(abs(x[i + 1] - x[i]) for i in range(0, len(x) - 1, 7)) / ((len(x) - 1) // 7)
        w = int(0.5 * sr)
        rms_head = math.sqrt(sum(s * s for s in x[:w]) / w)
        rms_tail = math.sqrt(sum(s * s for s in x[-w:]) / w)
        print(f"  döngü sınırı sıçraması: {jump:.4f} (tipik örnek farkı {typical:.4f}, oran {jump / typical:.2f})")
        print(f"  ilk/son 0,5 sn RMS: {db(rms_head):.1f} / {db(rms_tail):.1f} dBFS (fark {abs(db(rms_head) - db(rms_tail)):.1f} dB)")


def main():
    for name, fn in [("ornek_korsan_muzigi.wav", make_music), ("ornek_deniz_dalgalari.wav", make_waves), ("ornek_hazine_bulma.wav", make_treasure)]:
        x, sr, is_loop = fn()
        write_wav(os.path.join(OUT_DIR, name), x, sr)
        analyze(name, x, sr, is_loop)


if __name__ == "__main__":
    main()
