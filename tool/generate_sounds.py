#!/usr/bin/env python3
"""Generates the game sound effects and the ambient music loop.

Effects are small mono 16-bit 44.1 kHz WAV files in assets/audio/. The music
loop is a mono 16-bit 16 kHz WAV in assets/music/ (kept apart so the effect
list stays exact).

Python 3 standard library only. The output is deterministic (fixed random
seed), so running the script twice yields byte-identical files.

Usage: python3 tool/generate_sounds.py
Writes assets/audio/<name>.wav and assets/music/ambient_loop.wav relative to
the repository root.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
PEAK = 10 ** (-3 / 20)  # about -3 dBFS


def envelope(n, attack=0.006, release=0.03):
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    out = []
    for i in range(n):
        gain = 1.0
        if i < a:
            gain = i / a
        if i > n - r:
            gain = min(gain, (n - i) / r)
        out.append(gain)
    return out


def tone(freq, dur, end_freq=None, shape="sine", decay=4.0, harmonic=0.0):
    """One note with optional pitch glide, exponential decay and 2nd harmonic."""
    n = int(dur * RATE)
    env = envelope(n)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq if end_freq is None else freq + (end_freq - freq) * t
        phase += 2 * math.pi * f / RATE
        if shape == "triangle":
            v = (2 / math.pi) * math.asin(math.sin(phase))
        else:
            v = math.sin(phase)
        if harmonic:
            v += harmonic * math.sin(2 * phase)
        samples.append(v * env[i] * math.exp(-decay * t))
    return samples


def noise(dur, decay=6.0, seed=1, smooth=0.6):
    rng = random.Random(seed)
    n = int(dur * RATE)
    env = envelope(n, attack=0.004, release=0.04)
    out = []
    last = 0.0
    for i in range(n):
        last = smooth * last + (1 - smooth) * rng.uniform(-1, 1)
        out.append(last * env[i] * math.exp(-decay * i / n))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.extend(p)
        out.extend([0.0] * int(gap * RATE))
    return out


def write(path, samples, rate=RATE, peak_level=PEAK):
    peak = max(abs(v) for v in samples) or 1.0
    scale = peak_level / peak
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767))
        for v in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(frames)


# ---------------------------------------------------------------------------
# Game specific sounds (SOUNDS_BEGIN)


def build():
    return {
        # A soft, short pluck when a knot joins the line.
        "step": tone(620, 0.09, 700, decay=5.0, harmonic=0.25),
        # A falling glide when the line steps back or resets.
        "undo": tone(560, 0.12, 360, decay=3.5, harmonic=0.15),
        # A low double thump for a tap on an unlinked knot.
        "invalid": seq(
            tone(190, 0.07, 170, shape="triangle", decay=3.0),
            tone(170, 0.09, 150, shape="triangle", decay=3.5),
            gap=0.02,
        ),
        # A rising arpeggio when the labyrinth is solved.
        "solved": seq(
            tone(523.25, 0.09, decay=3.0, harmonic=0.2),
            tone(659.25, 0.09, decay=3.0, harmonic=0.2),
            tone(783.99, 0.09, decay=3.0, harmonic=0.2),
            tone(1046.5, 0.17, decay=4.0, harmonic=0.2),
        ),
        # Two soft rising sparkles when a hint lights the next star.
        "hint": seq(
            tone(880, 0.07, 990, decay=4.0, harmonic=0.3),
            tone(1318.5, 0.12, 1400, decay=5.0, harmonic=0.3),
            gap=0.015,
        ),
        # A dull, falling hum when the line runs into a dead end.
        "dead_end": mix(
            tone(240, 0.26, 180, shape="triangle", decay=4.0),
            tone(120, 0.26, 95, decay=4.5),
        ),
        # A bright chime for each star on the result card.
        "star": mix(
            tone(1567.98, 0.3, decay=6.0, harmonic=0.15),
            tone(2349.3, 0.3, decay=8.0),
            tone(3136.0, 0.12, decay=9.0),
        ),
        # A quick rising arpeggio when the sky level goes up.
        "level_up": seq(
            tone(659.25, 0.07, decay=2.5, harmonic=0.25),
            tone(880.0, 0.07, decay=2.5, harmonic=0.25),
            tone(1108.73, 0.07, decay=2.5, harmonic=0.25),
            tone(1318.51, 0.15, decay=4.0, harmonic=0.25),
        ),
    }


# ---------------------------------------------------------------------------
# Ambient music loop: slow spacey pads, sparse echoing bells, faint wind.

MUSIC_RATE = 16000
MUSIC_SECONDS = 24.0
MUSIC_PEAK = 10 ** (-7 / 20)


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def build_music():
    n = int(MUSIC_SECONDS * MUSIC_RATE)
    buf = [0.0] * n
    two_pi = 2 * math.pi

    # Am9 - Fmaj7 - Cmaj7 - G6, six seconds each. Pads fade over a long
    # raised-cosine window that overlaps its neighbours; indices wrap so the
    # loop seam is seamless.
    chords = [
        [45, 52, 59, 60, 67],
        [41, 48, 57, 60, 64],
        [36, 48, 55, 59, 64],
        [43, 50, 59, 62, 64],
    ]
    chord_len = n // len(chords)
    fade = int(2.0 * MUSIC_RATE)
    window = chord_len + 2 * fade
    for ci, chord in enumerate(chords):
        start = ci * chord_len - fade
        for ni, note in enumerate(chord):
            f = midi(note)
            gain = 0.22 if ni == 0 else 0.12
            detune = 1.0035 + 0.0007 * ni
            for i in range(window):
                x = i / window
                env = 0.5 - 0.5 * math.cos(two_pi * x)
                t = (start + i) / MUSIC_RATE
                v = math.sin(two_pi * f * t) + 0.7 * math.sin(two_pi * f * detune * t)
                v += 0.18 * math.sin(two_pi * 2 * f * t)
                buf[(start + i) % n] += gain * env * v

    # Sparse bell melody from the A minor pentatonic, with a wrapping echo.
    rng = random.Random(7)
    scale = [69, 72, 74, 76, 79, 81, 84, 88]
    beat = 0.75
    bell_len = int(2.4 * MUSIC_RATE)
    beats = int(MUSIC_SECONDS / beat)
    for b in range(beats):
        if rng.random() > 0.42:
            continue
        f = midi(scale[rng.randrange(len(scale))])
        onset = int(b * beat * MUSIC_RATE)
        amp = 0.16 + 0.08 * rng.random()
        for echo in range(4):
            delay = int(echo * 0.5625 * MUSIC_RATE)
            g = amp * (0.42 ** echo)
            for i in range(0, bell_len):
                t = i / MUSIC_RATE
                env = math.exp(-2.6 * t) * min(1.0, i / 80)
                v = math.sin(two_pi * f * t) + 0.25 * math.sin(two_pi * 2.01 * f * t)
                v += 0.08 * math.sin(two_pi * 3.03 * f * t)
                buf[(onset + delay + i) % n] += g * env * v

    # Faint wind: smoothed noise with a slow swell that completes whole cycles.
    # The filter is pre-warmed on the loop tail so the seam has no jump.
    noise_rng = random.Random(11)
    tail = [noise_rng.uniform(-1, 1) for _ in range(n)]
    last = 0.0
    for v in tail[-2000:]:
        last = 0.985 * last + 0.015 * v
    for i in range(n):
        last = 0.985 * last + 0.015 * tail[i]
        swell = 0.5 - 0.5 * math.cos(two_pi * 2 * i / n)
        buf[i] += 1.6 * last * (0.3 + 0.7 * swell)

    return buf


# (SOUNDS_END)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    for name, samples in build().items():
        write(os.path.join(out_dir, name + ".wav"), samples)
    music_dir = os.path.join(root, "assets", "music")
    os.makedirs(music_dir, exist_ok=True)
    write(
        os.path.join(music_dir, "ambient_loop.wav"),
        build_music(),
        rate=MUSIC_RATE,
        peak_level=MUSIC_PEAK,
    )


if __name__ == "__main__":
    main()
