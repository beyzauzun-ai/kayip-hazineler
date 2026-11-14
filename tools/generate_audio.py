"""Kayıp Hazineler — oyunun tüm seslerini üreten script (9. aşama).

Tamamen özgün, prosedürel üretim: yalnızca Python standart kütüphanesi.
Dışarıdan hiçbir örnek, ses paketi veya kayıt kullanılmaz. Her ses sabit bir
tohumla üretilir; script her çalıştırıldığında aynı dosyaları üretir.

Onaylanan üç ses (music_main, amb_waves, treasure_success) kullanıcıya
dinletilen örneklerin kendisidir; `onayli_ses_ornekleri.py` içindeki
değiştirilmemiş kodla üretilir. Bu script onları yeniden üretip proje
klasöründeki dosyalarla byte düzeyinde karşılaştırır (--dogrula).

Kullanım:
  python -X utf8 tools/generate_audio.py              # yeni sesleri assets/audio'ya yazar
  python -X utf8 tools/generate_audio.py --dogrula    # onaylı 3 sesi doğrular, hiçbir şey yazmaz
"""

import hashlib
import math
import os
import random
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import onayli_ses_ornekleri as base  # noqa: E402  (onaylı örneklerin değiştirilmemiş kodu)
from onayli_ses_ornekleri import (  # noqa: E402
    TAU, add, analyze, accordion, bass, celesta, envelope, kick, midi_hz, normalize, note,
    one_pole_lowpass, reverb, shaker, write_wav,
)

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO_DIR = os.path.join(PROJECT, "assets", "audio")
SR_SFX = 44100
SR_LOOP = 32000

# Onaylanan örnek → oyundaki dosya adı.
APPROVED = {
    "music_main.wav": base.make_music,
    "amb_waves.wav": base.make_waves,
    "treasure_success.wav": base.make_treasure,
}


# --- Ortak yardımcılar --------------------------------------------------------------

def silence(seconds, sr):
    return [0.0] * int(seconds * sr)


def noise(n, rng):
    return [rng.random() * 2 - 1 for _ in range(n)]


def highpass(x, amount=0.85):
    out, prev = [], 0.0
    for s in x:
        out.append(s - prev * amount)
        prev = s
    return out


def bandpass(x, low, high, sr):
    return highpass(one_pole_lowpass(x, high, sr), math.exp(-TAU * low / sr))


def crossfade_loop(x, n, fade):
    """x en az n + fade uzunlukta; sondaki fazlalık başa eşit güçle bindirilir."""
    loop = x[:n]
    for i in range(fade):
        a = i / fade
        loop[i] = x[i] * math.sin(a * math.pi / 2) + x[n + i] * math.cos(a * math.pi / 2)
    return loop


def tone(freq, dur, sr, shape="sine", attack=0.005, decay=None, release=0.05, vibrato=0.0):
    n = int(dur * sr)
    out, ph = [], 0.0
    for i in range(n):
        t = i / sr
        f = freq(t) if callable(freq) else freq
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * 5.5 * t)
        ph += TAU * f / sr
        if shape == "sine":
            s = math.sin(ph)
        elif shape == "tri":
            s = 2.0 / math.pi * math.asin(math.sin(ph))
        elif shape == "saw":
            s = sum(math.sin(k * ph) / k for k in range(1, 8)) * 0.6
        else:  # yumuşak kare
            s = sum(math.sin(k * ph) / k for k in (1, 3, 5, 7)) * 0.8
        a = min(1.0, t / attack) if attack > 0 else 1.0
        e = math.exp(-t / decay) if decay else 1.0
        r = min(1.0, (dur - t) / release) if release > 0 else 1.0
        out.append(s * a * e * max(0.0, r))
    return out


def metal(freq, dur, sr, decay=0.12):
    """Sikke şıngırtısı: yüksek, harmonik olmayan kısmiler, hızlı sönüm."""
    n = int(dur * sr)
    parts = [(1.0, 1.0), (2.41, 0.6), (3.83, 0.4), (5.62, 0.25)]
    return [sum(g * math.sin(TAU * freq * k * i / sr) for k, g in parts) * math.exp(-i / sr / decay) * min(1.0, i / sr / 0.001) * 0.35 for i in range(n)]


def thud(sr, f0=95.0, f1=45.0, dur=0.35, decay=0.1):
    return tone(lambda t: f1 + (f0 - f1) * math.exp(-t / 0.03), dur, sr, "sine", 0.002, decay, 0.02)


def knock(sr, rng, freq=520.0, dur=0.12):
    """Tahta vuruşu: rezonanslı kısa gürültü + ton."""
    n = int(dur * sr)
    nz = bandpass(noise(n, rng), freq * 0.6, freq * 2.0, sr)
    return [(nz[i] * 1.6 + 0.5 * math.sin(TAU * freq * i / sr)) * math.exp(-i / sr / 0.03) for i in range(n)]


def bell(freq, dur, sr, decay=0.9):
    return celesta(freq, dur, sr, decay)


# --- Müzik: açık artırma -------------------------------------------------------------

AUCTION_EIGHTH = 0.26
AUCTION_CHORDS = ["Bm", "G", "D", "A", "Bm", "G", "A", "A", "Bm", "Em", "A", "D"]
AUCTION_CHORD_NOTES = {
    "D": ["D4", "F#4", "A4"], "G": ["D4", "G4", "B4"], "A": ["C#4", "E4", "A4"],
    "Bm": ["D4", "F#4", "B4"], "Em": ["E4", "G4", "B4"],
}
AUCTION_BASS = {"D": ("D2", "A2"), "G": ("G2", "D3"), "A": ("A2", "E2"), "Bm": ("B2", "F#2"), "Em": ("E2", "B2")}
AUCTION_MELODY = [
    [("F#4", 1), ("R", 1), ("F#4", 1), ("B4", 2), ("R", 1)],
    [("G4", 1), ("R", 1), ("B4", 1), ("D5", 2), ("R", 1)],
    [("A4", 1), ("R", 1), ("F#4", 1), ("A4", 2), ("R", 1)],
    [("E4", 3), ("C#5", 3)],
    [("B4", 1), ("R", 1), ("D5", 1), ("F#5", 2), ("R", 1)],
    [("G5", 1), ("F#5", 1), ("E5", 1), ("D5", 3)],
    [("C#5", 1), ("R", 1), ("E5", 1), ("A4", 2), ("R", 1)],
    [("C#5", 3), ("E5", 3)],
    [("D5", 1), ("C#5", 1), ("B4", 1), ("F#4", 2), ("R", 1)],
    [("G4", 1), ("A4", 1), ("B4", 1), ("E5", 3)],
    [("C#5", 1), ("B4", 1), ("A4", 1), ("E4", 2), ("C#5", 1)],
    [("D5", 3), ("R", 3)],
]


def render_auction_cycle(buf, offset, sr, rng):
    bar_len = int(6 * AUCTION_EIGHTH * sr)
    e = int(AUCTION_EIGHTH * sr)
    for b, chord in enumerate(AUCTION_CHORDS):
        start = offset + b * bar_len
        add(buf, start, kick(sr), 0.45)
        for k in range(6):
            add(buf, start + k * e, shaker(sr, rng, 0.12 if k in (0, 3) else 0.07))
        root, fifth = AUCTION_BASS[chord]
        add(buf, start, bass(midi_hz(note(root)), 0.45, sr), 0.9)
        add(buf, start + 3 * e, bass(midi_hz(note(fifth)), 0.45, sr), 0.75)
        freqs = [midi_hz(note(nm)) for nm in AUCTION_CHORD_NOTES[chord]]
        pad = accordion(freqs, AUCTION_EIGHTH * 2.6, sr)
        add(buf, start, pad, 0.55)
        add(buf, start + 3 * e, pad, 0.45)
        pos = start
        for nm, length in AUCTION_MELODY[b]:
            if nm != "R":
                add(buf, pos, celesta(midi_hz(note(nm)), length * AUCTION_EIGHTH + 0.5, sr, 0.5), 0.75)
            pos += length * e


def make_music_auction():
    sr = SR_LOOP
    cycle = int(len(AUCTION_CHORDS) * 6 * AUCTION_EIGHTH * sr)
    buf = [0.0] * (2 * cycle)
    render_auction_cycle(buf, 0, sr, random.Random(9201))
    render_auction_cycle(buf, cycle, sr, random.Random(9201))
    buf = reverb(buf, sr, wet=0.28, room=0.8)
    return normalize(buf[cycle:2 * cycle], -2.0), sr, True


# --- Ortam ve gemi döngüleri --------------------------------------------------------------

def make_wind():
    sr = SR_LOOP
    n, fade = int(20.0 * sr), int(2.0 * sr)
    rng = random.Random(9202)
    src = bandpass(noise(n + fade, rng), 250.0, 1400.0, sr)
    out = []
    for i, s in enumerate(src):
        t = (i % n) / sr
        gust = 0.45 + 0.3 * math.sin(TAU * t / 10.0) + 0.2 * math.sin(TAU * t / 4.0 + 0.7)
        out.append(s * max(0.1, gust))
    return normalize(crossfade_loop(out, n, fade), -12.0), sr, True


def make_ship_water():
    """Pruva suyu: orta frekanslı akış hışırtısı + 1 ve 2 sn'lik çalkantı; 4 sn döngü."""
    sr = SR_LOOP
    n, fade = int(4.0 * sr), int(0.8 * sr)
    rng = random.Random(9203)
    hiss = bandpass(noise(n + fade, rng), 500.0, 2800.0, sr)
    low = one_pole_lowpass(noise(n + fade, rng), 300.0, sr)
    out = []
    for i in range(n + fade):
        t = (i % n) / sr
        slosh = 0.65 + 0.2 * math.sin(TAU * t / 1.0) + 0.15 * math.sin(TAU * t / 2.0 + 1.1)
        out.append(hiss[i] * slosh + low[i] * 2.5)
    return normalize(crossfade_loop(out, n, fade), -8.0), sr, True


# --- Tek seferlik efektler ----------------------------------------------------------------

def make_ship_creak():
    sr = SR_SFX
    rng = random.Random(9204)
    dur = 0.7
    n = int(dur * sr)
    out, ph = [], 0.0
    for i in range(n):
        t = i / sr
        f = 115.0 - 30.0 * t / dur + 6.0 * math.sin(TAU * 7.0 * t)
        ph += TAU * f / sr
        grain = 0.55 + 0.45 * math.sin(TAU * 38.0 * t) ** 2
        s = sum(math.sin(k * ph) / k for k in range(1, 9)) * grain
        out.append(s * math.sin(math.pi * t / dur) ** 1.5)
    out = bandpass(out, 180.0, 1800.0, sr)
    return normalize(reverb(out, sr, 0.15, 0.6), -6.0), sr, False


def make_rock_hit():
    sr = SR_SFX
    rng = random.Random(9205)
    buf = silence(0.6, sr)
    add(buf, 0, thud(sr, 110.0, 42.0, 0.5, 0.12), 1.0)
    add(buf, 0, knock(sr, rng, 380.0, 0.15), 0.6)
    crunch = one_pole_lowpass(noise(int(0.25 * sr), rng), 1800.0, sr)
    add(buf, int(0.01 * sr), [c * math.exp(-i / sr / 0.06) for i, c in enumerate(crunch)], 0.9)
    return normalize(reverb(buf, sr, 0.15, 0.6), -2.0), sr, False


def make_discovery_bell():
    sr = SR_SFX
    buf = silence(1.8, sr)
    add(buf, 0, bell(midi_hz(note("G5")), 1.8, sr, 0.9), 0.7)
    add(buf, int(0.16 * sr), bell(midi_hz(note("D6")), 1.6, sr, 0.8), 0.6)
    rng = random.Random(9206)
    for k in range(8):
        t0 = 0.2 + rng.random() * 0.8
        add(buf, int(t0 * sr), celesta(midi_hz(rng.choice([note("D7"), note("G7"), note("B6")])), 0.3, sr, 0.1), 0.08)
    return normalize(reverb(buf, sr, 0.3, 0.82), -3.0), sr, False


def make_extract_loop():
    """3 sn boyunca yükselen büyülü ton (E basılı tutulurken); bırakılınca kesilir."""
    sr = SR_SFX
    dur = 3.1
    rng = random.Random(9207)
    buf = silence(dur, sr)
    rise = tone(lambda t: 280.0 * 2 ** (1.6 * t / dur), dur, sr, "tri", 0.15, None, 0.1)
    add(buf, 0, [s * (0.35 + 0.65 * i / len(rise)) * (0.8 + 0.2 * math.sin(TAU * (4 + 8 * i / len(rise)) * i / sr)) for i, s in enumerate(rise)], 0.35)
    for k in range(18):
        t0 = rng.random() * (dur - 0.2)
        f0 = 600.0 + rng.random() * 500.0
        add(buf, int(t0 * sr), tone(lambda t, f0=f0: f0 * (1 + 3 * t), 0.06, sr, "sine", 0.002, 0.02, 0.01), 0.15)
    for k in range(10):
        t0 = 0.3 + k * 0.27
        add(buf, int(t0 * sr), celesta(midi_hz(note("D6")) * 2 ** (k / 12.0 * 1.2), 0.4, sr, 0.15), 0.12)
    return normalize(reverb(buf, sr, 0.25, 0.75), -5.0), sr, False


def make_extract_fail():
    sr = SR_SFX
    buf = silence(0.75, sr)
    add(buf, 0, tone(330.0, 0.22, sr, "square", 0.005, None, 0.05), 0.5)
    add(buf, int(0.2 * sr), tone(lambda t: 220.0 - 40.0 * t / 0.4, 0.4, sr, "square", 0.005, 0.25, 0.08), 0.55)
    buf = one_pole_lowpass(buf, 1600.0, sr)
    return normalize(reverb(buf, sr, 0.15, 0.6), -5.0), sr, False


def make_ui_denied():
    sr = SR_SFX
    buf = silence(0.3, sr)
    for k in range(2):
        add(buf, int(k * 0.12 * sr), tone(196.0, 0.09, sr, "tri", 0.003, 0.05, 0.02), 0.7)
    return normalize(one_pole_lowpass(buf, 1500.0, sr), -9.0), sr, False


def make_timer_warning():
    sr = SR_SFX
    buf = silence(1.4, sr)
    for k in range(2):
        add(buf, int(k * 0.28 * sr), bell(midi_hz(note("A5")), 1.1, sr, 0.6), 0.7)
        add(buf, int(k * 0.28 * sr), bell(midi_hz(note("A4")), 1.1, sr, 0.6), 0.4)
    return normalize(reverb(buf, sr, 0.25, 0.75), -4.0), sr, False


def make_timer_tick():
    sr = SR_SFX
    rng = random.Random(9208)
    buf = silence(0.12, sr)
    add(buf, 0, knock(sr, rng, 1500.0, 0.1), 0.8)
    add(buf, 0, tone(1800.0, 0.05, sr, "sine", 0.001, 0.012, 0.005), 0.4)
    return normalize(buf, -6.0), sr, False


def _fanfare(notes, chord, sr, rng, length, brass_decay=0.5, bells=True):
    buf = silence(length, sr)
    for k, (nm, t0, d) in enumerate(notes):
        f = midi_hz(note(nm))
        add(buf, int(t0 * sr), one_pole_lowpass(tone(f, d, sr, "saw", 0.02, brass_decay, 0.06, 0.004), 2600.0, sr), 0.35)
    t_chord = notes[-1][1]
    for nm in chord:
        f = midi_hz(note(nm))
        add(buf, int(t_chord * sr), one_pole_lowpass(tone(f, length - t_chord - 0.05, sr, "saw", 0.03, 0.9, 0.4, 0.003), 2200.0, sr), 0.18)
    if bells:
        for k in range(10):
            t0 = t_chord + rng.random() * 0.8
            add(buf, int(t0 * sr), celesta(midi_hz(rng.choice([note("D6"), note("F#6"), note("A6"), note("D7")])), 0.6, sr, 0.25), 0.12)
    cym = highpass(noise(int(1.2 * sr), rng), 0.97)
    add(buf, int(t_chord * sr), [c * math.exp(-i / sr / 0.35) * 0.12 for i, c in enumerate(cym)])
    return buf


def make_mission_win():
    sr = SR_SFX
    rng = random.Random(9209)
    notes = [("D4", 0.0, 0.16), ("F#4", 0.15, 0.16), ("A4", 0.3, 0.16), ("D5", 0.45, 0.9)]
    buf = _fanfare(notes, ["D4", "F#4", "A4", "D5"], sr, rng, 2.4)
    return normalize(reverb(buf, sr, 0.25, 0.8), -2.0), sr, False


def make_mission_lose():
    sr = SR_SFX
    buf = silence(2.4, sr)
    rng = random.Random(9210)
    for k, nm in enumerate(["A4", "G4", "F4", "D4"]):
        add(buf, int(k * 0.32 * sr), base.flute(midi_hz(note(nm)), 0.5 if k < 3 else 1.3, sr, rng), 0.6)
    add(buf, int(0.96 * sr), accordion([midi_hz(note(nm)) for nm in ["D3", "F3", "A3"]], 1.3, sr), 0.7)
    return normalize(reverb(buf, sr, 0.3, 0.8), -4.0), sr, False


def make_auction_waiting():
    sr = SR_SFX
    rng = random.Random(9211)
    dur = 1.25
    buf = silence(dur, sr)
    t, gap = 0.0, 0.13
    while t < dur - 0.1:
        add(buf, int(t * sr), knock(sr, rng, 260.0 + 60.0 * t, 0.1), 0.25 + 0.4 * t / dur)
        t += gap
        gap = max(0.045, gap * 0.86)
    for k in range(3):
        add(buf, int(k * 0.4 * sr), knock(sr, rng, 1400.0 if k % 2 == 0 else 1100.0, 0.06), 0.3)
    return normalize(buf, -6.0), sr, False


def make_auction_new_offer():
    sr = SR_SFX
    rng = random.Random(9212)
    buf = silence(0.9, sr)
    for k, f in enumerate([2600.0, 3100.0, 3700.0]):
        add(buf, int(k * 0.07 * sr), metal(f, 0.4, sr, 0.14), 0.6)
    add(buf, int(0.2 * sr), tone(lambda t: 660.0 * 2 ** (t / 0.25), 0.25, sr, "tri", 0.005, None, 0.06), 0.3)
    add(buf, int(0.42 * sr), celesta(midi_hz(note("E6")), 0.5, sr, 0.3), 0.35)
    return normalize(reverb(buf, sr, 0.2, 0.7), -4.0), sr, False


def make_auction_sold():
    sr = SR_SFX
    rng = random.Random(9213)
    buf = silence(1.3, sr)
    add(buf, 0, knock(sr, rng, 300.0, 0.18), 1.0)
    add(buf, 0, thud(sr, 140.0, 70.0, 0.25, 0.06), 0.6)
    for k in range(9):
        t0 = 0.12 + k * 0.07 + rng.random() * 0.03
        add(buf, int(t0 * sr), metal(2400.0 + rng.random() * 1600.0, 0.35, sr, 0.12), 0.45)
    return normalize(reverb(buf, sr, 0.2, 0.7), -3.0), sr, False


def make_auction_buyers_left():
    sr = SR_SFX
    rng = random.Random(9214)
    buf = silence(1.3, sr)
    add(buf, 0, tone(lambda t: 392.0 - 20.0 * t, 0.35, sr, "tri", 0.02, None, 0.08, 0.01), 0.5)
    add(buf, int(0.33 * sr), tone(lambda t: 311.0 - 60.0 * t, 0.8, sr, "tri", 0.02, 0.6, 0.2, 0.012), 0.5)
    murmur = bandpass(noise(int(1.1 * sr), rng), 200.0, 900.0, sr)
    add(buf, 0, [m * math.sin(math.pi * i / len(murmur)) * 0.6 for i, m in enumerate(murmur)])
    return normalize(reverb(buf, sr, 0.2, 0.7), -5.0), sr, False


def make_auction_rank():
    sr = SR_SFX
    rng = random.Random(9215)
    notes = [("A4", 0.0, 0.14), ("D5", 0.13, 0.14), ("F#5", 0.26, 0.14), ("A5", 0.39, 0.3), ("F#5", 0.68, 0.14), ("A5", 0.81, 1.0)]
    buf = _fanfare(notes, ["D4", "A4", "D5", "F#5"], sr, rng, 2.8)
    return normalize(reverb(buf, sr, 0.28, 0.82), -2.0), sr, False


def make_ui_click():
    sr = SR_SFX
    buf = silence(0.08, sr)
    add(buf, 0, tone(1250.0, 0.06, sr, "sine", 0.001, 0.015, 0.01), 0.8)
    add(buf, 0, tone(2500.0, 0.03, sr, "sine", 0.001, 0.006, 0.005), 0.3)
    return normalize(buf, -10.0), sr, False


def make_ui_move():
    sr = SR_SFX
    buf = silence(0.06, sr)
    add(buf, 0, tone(1700.0, 0.045, sr, "sine", 0.001, 0.01, 0.01), 0.7)
    return normalize(buf, -16.0), sr, False


NEW_SOUNDS = {
    "music_auction.wav": make_music_auction,
    "amb_wind.wav": make_wind,
    "ship_water.wav": make_ship_water,
    "ship_creak.wav": make_ship_creak,
    "rock_hit.wav": make_rock_hit,
    "discovery_bell.wav": make_discovery_bell,
    "extract_loop.wav": make_extract_loop,
    "extract_fail.wav": make_extract_fail,
    "ui_denied.wav": make_ui_denied,
    "timer_warning.wav": make_timer_warning,
    "timer_tick.wav": make_timer_tick,
    "mission_win.wav": make_mission_win,
    "mission_lose.wav": make_mission_lose,
    "auction_waiting.wav": make_auction_waiting,
    "auction_new_offer.wav": make_auction_new_offer,
    "auction_sold.wav": make_auction_sold,
    "auction_buyers_left.wav": make_auction_buyers_left,
    "auction_rank.wav": make_auction_rank,
    "ui_click.wav": make_ui_click,
    "ui_move.wav": make_ui_move,
}


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def verify_approved():
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        for name, fn in APPROVED.items():
            x, sr, _ = fn()
            path = os.path.join(tmp, name)
            write_wav(path, x, sr)
            same = os.path.exists(os.path.join(AUDIO_DIR, name)) and sha(path) == sha(os.path.join(AUDIO_DIR, name))
            ok = ok and same
            print(f"  onaylı {name:<22} yeniden üretim birebir aynı: {'EVET' if same else 'HAYIR'}")
    return ok


def main():
    if "--dogrula" in sys.argv:
        sys.exit(0 if verify_approved() else 1)
    os.makedirs(AUDIO_DIR, exist_ok=True)
    for name, fn in NEW_SOUNDS.items():
        x, sr, is_loop = fn()
        write_wav(os.path.join(AUDIO_DIR, name), x, sr)
        analyze(name, x, sr, is_loop)


if __name__ == "__main__":
    main()
