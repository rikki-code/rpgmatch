#!/usr/bin/env python3
"""Synthesizes the sound packs in view/packs/audio_pack/ from scratch (no samples, so nothing to license).

usage: python3 tools/gen_audio.py [pack ...]     (default: every pack)
Writes .wav plus a .import that makes Godot store them as ADPCM (music also looped);
afterwards run `godot --headless --path . --import`.
A new cue = a function in CUES + a row in SPECS; a new pack = a Profile subclass in PROFILES.
"""
import math
import pathlib
import random
import struct
import sys
import wave

SR = 22050
TAU = math.pi * 2
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "view/packs/audio_pack"
RES_PREFIX = "res://view/packs/audio_pack/"


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ---- DSP primitives -------------------------------------------------------

def silence(sec):
    return [0.0] * int(sec * SR)


def mix(dst, src, at=0.0, gain=1.0):
    start = int(at * SR)
    need = start + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[start + i] += v * gain
    return dst


def lowpass(buf, cutoff):
    a = 1 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for x in buf:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(buf, cutoff):
    low = lowpass(buf, cutoff)
    return [x - l for x, l in zip(buf, low)]


def sweep_lowpass(buf, f0, f1):
    y = 0.0
    out = []
    n = max(len(buf) - 1, 1)
    for i, x in enumerate(buf):
        f = f0 * (f1 / f0) ** (i / n)
        y += (1 - math.exp(-TAU * f / SR)) * (x - y)
        out.append(y)
    return out


def fade_edges(buf, head=0.002, tail=0.01):
    h, t = int(head * SR), int(tail * SR)
    for i in range(min(h, len(buf))):
        buf[i] *= i / h
    for i in range(min(t, len(buf))):
        buf[len(buf) - 1 - i] *= i / t
    return buf


def shape(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(TAU * p)
    if kind == "tri":
        return 4 * abs(p - 0.5) - 1
    if kind == "saw":
        return 2 * p - 1
    return 1.0 if p < 0.5 else -1.0


def tone(freq, dur, amp=1.0, kind="sine", end_freq=None, decay=6.0, attack=0.004, vibrato=0.0):
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    att = max(int(attack * SR), 1)
    for i in range(n):
        t = i / n
        f = freq if end_freq is None else freq * (end_freq / freq) ** t
        if vibrato:
            f *= 1 + vibrato * math.sin(TAU * 5.5 * i / SR)
        phase += f / SR
        out[i] = shape(kind, phase) * amp * min(1.0, i / att) * math.exp(-decay * t)
    return fade_edges(out)


def bell(freq, dur, amp=1.0, ratio=3.5, index=1.8, decay=5.0):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = math.exp(-decay * t / dur)
        mod = math.sin(TAU * freq * ratio * t) * index * env
        out[i] = math.sin(TAU * freq * t + mod) * amp * env * min(1.0, i / 40)
    return fade_edges(out)


def noise(dur, amp=1.0, decay=6.0, rng=random):
    n = int(dur * SR)
    return [rng.uniform(-1, 1) * amp * math.exp(-decay * i / n) for i in range(n)]


def reverb(buf, wet=0.25, size=1.0):
    tail = int(1.2 * size * SR)
    src = buf + [0.0] * tail
    out = list(src)
    for delay, feedback in ((0.0297, 0.72), (0.0371, 0.70), (0.0411, 0.68), (0.0437, 0.66)):
        d = int(delay * size * SR)
        comb = [0.0] * len(src)
        for i in range(len(src)):
            comb[i] = src[i] + (comb[i - d] * feedback if i >= d else 0.0)
        for i in range(len(src)):
            out[i] += comb[i] * wet * 0.25
    return out


def drive(buf, amount):
    norm = math.tanh(amount)
    return [math.tanh(x * amount) / norm for x in buf]


def crackle(dur, per_second, amp=1.0, decay=3.0):
    """Sparse random clicks that thin out: fuse sparks, flying debris."""
    out = silence(dur)
    n = len(out)
    for _ in range(int(per_second * dur)):
        at = int(random.random() ** 1.6 * n)
        gain = amp * random.uniform(0.3, 1.0) * math.exp(-decay * at / n)
        for k in range(int(0.003 * SR)):
            if at + k < n:
                out[at + k] += random.uniform(-1, 1) * gain * (1 - k / (0.003 * SR))
    return out


def explosion(dur, amp=1.0, sub_hz=90, grit=2.2, debris=260):
    """Crack, a mid-range noise body (what small speakers can play), a punchy thump, sub and falling debris, driven hard."""
    out = highpass(noise(0.035, 1.2, 35), 1200)
    mix(out, sweep_lowpass(noise(dur, 1.6, 4.0 / max(dur, 0.2)), 9000, 450), 0.0, 1.0)
    mix(out, drive(tone(sub_hz * 2.2, dur * 0.6, 1.0, end_freq=sub_hz * 0.8, decay=5.0), 2.5), 0.0, 0.8)
    mix(out, drive(tone(sub_hz, dur, 1.0, end_freq=sub_hz * 0.3, decay=4.5), 2.0), 0.0, 0.4)
    mix(out, lowpass(noise(dur * 1.3, 0.7, 2.2), 140), 0.02, 0.3)
    mix(out, crackle(dur * 1.3, debris, 0.7, 2.5), 0.05, 0.8)
    return [x * amp for x in drive(out, grit)]


def finish(buf, peak=0.85):
    top = max((abs(x) for x in buf), default=0.0) or 1.0
    return fade_edges([x / top * peak for x in buf])


# ---- Profiles: the timbre of a pack ----------------------------------------

class Profile:
    name = ""
    display = ""
    octave = 1.0

    def note(self, freq, dur, amp=1.0):
        raise NotImplementedError

    def hit(self, dur=0.08, amp=1.0):
        raise NotImplementedError

    def whoosh(self, dur, lo, hi, amp=1.0, rising=True):
        raise NotImplementedError

    def boom(self, dur, amp=1.0):
        raise NotImplementedError

    def pad(self, freq, dur):
        raise NotImplementedError

    def bass(self, freq, dur):
        raise NotImplementedError

    def arp(self, freq, dur):
        return self.note(freq, dur, 0.8)

    def kick(self):
        return self.hit(0.18, 1.0)

    def tick(self):
        return highpass(noise(0.04, 0.5, 14), 4000)

    def shards(self, dur, amp=0.5):
        raise NotImplementedError

    def sparkle(self, dur=0.4, amp=0.5):
        out = silence(dur)
        for k in range(6):
            mix(out, bell(midi(96 + random.choice((0, 4, 7, 12))) * self.octave, 0.18, amp * 0.6), k * dur / 8)
        return out

    music = {}


class Crystal(Profile):
    name = "crystal"
    display = "Crystal chimes"
    octave = 1.0

    def note(self, freq, dur, amp=1.0):
        return bell(freq * self.octave, dur, amp, 3.5, 1.6, 5.5)

    def hit(self, dur=0.08, amp=1.0):
        out = tone(1900, dur, amp * 0.6, decay=9, end_freq=1300)
        mix(out, highpass(noise(dur, amp * 0.25, 12), 3000))
        return out

    def whoosh(self, dur, lo, hi, amp=1.0, rising=True):
        src = noise(dur, amp, 2.2)
        shaped = sweep_lowpass(src, lo, hi) if rising else sweep_lowpass(src, hi, lo)
        return highpass(shaped, 500)

    def boom(self, dur, amp=1.0):
        out = explosion(dur, amp, 100, 2.0, 160)
        mix(out, self.shards(dur * 0.8, amp * 0.5), 0.02)
        return out

    def shards(self, dur, amp=0.5):
        out = silence(dur)
        for k in range(14):
            at = random.random() ** 1.5 * dur * 0.7
            mix(out, bell(midi(random.choice((84, 88, 91, 95, 100, 103))), random.uniform(0.12, 0.3), amp * random.uniform(0.3, 0.8), 3.1, 1.2, 7), at)
        return out

    def pad(self, freq, dur):
        n = int(dur * SR)
        a = tone(freq, dur, 1.0, "sine", decay=0.0, attack=dur * 0.45)
        mix(a, tone(freq * 2.003, dur, 0.35, "sine", decay=0.0, attack=dur * 0.6))
        return [x * min(1.0, (n - i) / (0.35 * n)) for i, x in enumerate(a)]

    def bass(self, freq, dur):
        return tone(freq, dur, 1.0, "sine", decay=3.0, attack=0.01)

    def arp(self, freq, dur):
        return bell(freq, dur, 0.8, 3.0, 1.2, 6.0)

    music = {
        "menu": dict(bpm=72, bars=8, chords=[(57, (0, 7, 12, 15)), (53, (0, 7, 12, 16)), (48, (0, 7, 12, 16)), (55, (0, 7, 12, 14))], density=0.55, perc=False),
        "game": dict(bpm=88, bars=8, chords=[(57, (0, 7, 12, 15)), (53, (0, 7, 12, 16)), (48, (0, 7, 12, 16)), (55, (0, 7, 12, 14))], density=0.75, perc=False),
        "battle": dict(bpm=116, bars=8, chords=[(57, (0, 7, 12, 15)), (55, (0, 7, 12, 14)), (53, (0, 7, 12, 16)), (52, (0, 7, 11, 16))], density=0.9, perc=True),
    }


class Dungeon(Profile):
    name = "dungeon"
    display = "Dungeon"
    octave = 0.5

    def note(self, freq, dur, amp=1.0):
        out = tone(freq * self.octave, dur, amp, "tri", decay=7, attack=0.003)
        out = lowpass(out, 2600)
        mix(out, highpass(noise(0.012, amp * 0.5, 4), 1500))
        return out

    def hit(self, dur=0.08, amp=1.0):
        out = tone(150, dur * 1.4, amp, end_freq=60, decay=7)
        mix(out, lowpass(noise(dur, amp * 0.5, 10), 900))
        return out

    def whoosh(self, dur, lo, hi, amp=1.0, rising=True):
        src = noise(dur, amp, 2.0)
        return sweep_lowpass(src, lo * 0.4, hi * 0.4) if rising else sweep_lowpass(src, hi * 0.4, lo * 0.4)

    def boom(self, dur, amp=1.0):
        out = explosion(dur, amp, 70, 2.8, 320)
        mix(out, lowpass(noise(dur * 1.5, 0.5, 1.8), 90), 0.05)
        return out

    def shards(self, dur, amp=0.5):
        return crackle(dur, 90, amp, 2.0)

    def pad(self, freq, dur):
        n = int(dur * SR)
        a = tone(freq, dur, 0.8, "saw", decay=0.0, attack=dur * 0.4)
        mix(a, tone(freq * 1.004, dur, 0.8, "saw", decay=0.0, attack=dur * 0.4))
        a = lowpass(a, 520)
        return [x * min(1.0, (n - i) / (0.3 * n)) for i, x in enumerate(a)]

    def bass(self, freq, dur):
        return lowpass(tone(freq, dur, 1.0, "tri", decay=2.5, attack=0.008), 400)

    def arp(self, freq, dur):
        return self.note(freq, dur, 0.9)

    def tick(self):
        return lowpass(noise(0.05, 0.6, 12), 1800)

    def kick(self):
        return self.hit(0.2, 1.1)

    music = {
        "menu": dict(bpm=62, bars=8, chords=[(50, (0, 7, 12, 15)), (46, (0, 7, 12, 14)), (53, (0, 7, 12, 16)), (48, (0, 7, 12, 16))], density=0.4, perc=False),
        "game": dict(bpm=76, bars=8, chords=[(50, (0, 7, 12, 15)), (46, (0, 7, 12, 14)), (53, (0, 7, 12, 16)), (48, (0, 7, 12, 16))], density=0.6, perc=True),
        "battle": dict(bpm=104, bars=8, chords=[(50, (0, 7, 12, 15)), (48, (0, 7, 12, 16)), (46, (0, 7, 12, 14)), (45, (0, 7, 12, 16))], density=0.85, perc=True),
    }


PROFILES = {p.name: p() for p in (Crystal, Dungeon)}

PENTA = [0, 2, 4, 7, 9]  # semitone offsets above C: the destroy cue walks up this scale


# ---- Cues -------------------------------------------------------------------

def note_seq(P, notes, gap, dur=0.3, amp=0.9, wet=0.0):
    out = silence(0.01)
    for k, m in enumerate(notes):
        mix(out, P.note(midi(m), dur, amp), k * gap)
    return reverb(out, wet) if wet else out


def cue_ui_click(P):
    out = P.hit(0.07, 0.8)
    mix(out, P.note(midi(84), 0.09, 0.6))
    return out


def cue_ui_hover(P):
    return P.note(midi(88), 0.05, 0.5)


def cue_menu_open(P):
    return note_seq(P, [72, 79], 0.06, 0.22)


def cue_menu_close(P):
    return note_seq(P, [79, 72], 0.06, 0.2)


def cue_swap(P):
    out = P.whoosh(0.13, 600, 3500, 0.7)
    mix(out, P.note(midi(76), 0.12, 0.5), 0.02)
    return out


def cue_swap_reject(P):
    out = tone(midi(52) * P.octave * 2, 0.12, 0.8, "tri", decay=5)
    mix(out, tone(midi(47) * P.octave * 2, 0.16, 0.8, "tri", decay=5), 0.09)
    return out


def cue_drag_pick(P):
    return P.note(midi(83), 0.06, 0.6)


def cue_drag_drop(P):
    return P.note(midi(71), 0.07, 0.5)


def make_land(P, step):
    out = P.hit(0.06, 0.7)
    mix(out, P.note(midi(60 + step * 2), 0.08, 0.3))
    return out


def cue_tile_pop(P):
    out = tone(500, 0.16, 0.7, end_freq=1500, decay=4)
    mix(out, P.sparkle(0.25, 0.4), 0.03)
    return out


def make_destroy(P, step):
    base = 72 + PENTA[step % 5] + 12 * (step // 5)
    out = P.note(midi(base), 0.28, 0.9)
    mix(out, P.tick(), 0.0, 0.8)
    return out


def cue_match(P):
    out = tone(380, 0.2, 0.6, end_freq=1400, decay=3.5, vibrato=0.02)
    mix(out, P.sparkle(0.3, 0.35), 0.05)
    return out


def cue_combo(P):
    return reverb(note_seq(P, [76, 80, 83, 88], 0.055, 0.3, 0.8), 0.15, 0.5)


def cue_fuse(P):
    out = crackle(0.22, 260, 0.9, 1.0)
    mix(out, highpass(noise(0.22, 0.35, 0.6), 2500))
    mix(out, tone(900, 0.2, 0.25, "saw", end_freq=2600, decay=1.0), 0.0, 0.8)
    return out


def cue_arrow_charge(P):
    out = P.hit(0.05, 0.9)
    mix(out, tone(500, 0.14, 0.45, "saw", end_freq=1800, decay=1.2), 0.01)
    return out


def cue_prism_charge(P):
    n = 0.45
    out = tone(180, n, 0.5, "sine", end_freq=1700, decay=0.0, attack=0.05, vibrato=0.04)
    mix(out, tone(360, n, 0.25, "tri", end_freq=3400, decay=0.0, attack=0.1))
    mix(out, [x * (0.5 + 0.5 * math.sin(TAU * (9 + 28 * i / (n * SR)) * i / SR)) for i, x in enumerate(highpass(noise(n, 0.4, 0.0), 2200))])
    for k in range(6):
        mix(out, P.note(midi(84 + k * 3), 0.1, 0.35), 0.06 + k * 0.06)
    return out


def cue_bomb_blast(P):
    return reverb(P.boom(0.9, 1.0), 0.16, 0.6)


def cue_arrow_launch(P):
    n = 0.22
    out = tone(2600, n, 0.7, "saw", end_freq=320, decay=2.2, attack=0.002)
    out = lowpass(out, 6000)
    mix(out, tone(5200, n * 0.6, 0.25, "sine", end_freq=700, decay=3), 0.0)
    mix(out, highpass(noise(n, 0.4, 2.5), 3000))
    mix(out, P.whoosh(n, 900, 5000, 0.5, rising=False))
    return out


def cue_arrow_blast(P):
    out = P.boom(0.4, 0.9)
    mix(out, tone(1500, 0.18, 0.5, "saw", end_freq=260, decay=3.5), 0.0)
    mix(out, P.note(midi(79), 0.35, 0.5), 0.01)
    return out


def cue_prism_launch(P):
    out = silence(0.3)
    for k in range(9):
        mix(out, P.note(midi(79 + PENTA[k % 5] + 12 * (k // 5)), 0.2, 0.55), k * 0.022)
    mix(out, highpass(noise(0.3, 0.3, 1.5), 3500))
    return out


def cue_prism_blast(P):
    out = P.boom(0.7, 0.9)
    for k, m in enumerate((72, 76, 79, 84, 88)):
        mix(out, P.note(midi(m), 1.0, 0.7), 0.01 * k)
    mix(out, P.shards(0.7, 0.7), 0.03)
    mix(out, P.sparkle(0.7, 0.5), 0.05)
    return reverb(out, 0.25, 0.9)


def cue_combine(P):
    out = tone(300, 0.35, 0.7, end_freq=900, decay=2.5)
    mix(out, P.boom(0.4, 0.6), 0.3)
    mix(out, P.note(midi(84), 0.4, 0.6), 0.28)
    return out


def cue_detonate(P):
    out = P.hit(0.08, 1.0)
    mix(out, tone(500, 0.2, 0.5, end_freq=1400, decay=4), 0.03)
    return out


def cue_shuffle(P):
    out = silence(0.55)
    for k in range(9):
        mix(out, P.whoosh(0.09, 500 + 150 * k, 2500 + 200 * k, 0.5), k * 0.055)
        mix(out, P.tick(), k * 0.055, 0.7)
    return out


def cue_hint(P):
    return note_seq(P, [84, 88], 0.11, 0.4, 0.6)


def cue_quest_tick(P):
    return P.note(midi(96), 0.07, 0.45)


def cue_quest_done(P):
    return note_seq(P, [72, 76, 79, 84, 88], 0.075, 0.6, 0.85, 0.2)


def cue_turn_start(P):
    out = P.note(midi(76), 0.4, 0.8)
    mix(out, P.note(midi(83), 0.5, 0.6), 0.09)
    return out


def cue_target_select(P):
    out = P.hit(0.06, 0.7)
    mix(out, P.note(midi(79), 0.1, 0.5))
    return out


def cue_action_attack(P):
    out = P.whoosh(0.45, 400, 5000, 0.9)
    mix(out, tone(300, 0.45, 0.4, end_freq=1100, decay=1.5, kind="saw"), 0.0, 0.5)
    return out


def cue_action_defend(P):
    out = silence(0.45)
    for k, m in enumerate((67, 72, 76)):
        mix(out, tone(midi(m) * P.octave * 2, 0.45, 0.4, "sine", decay=1.2, attack=0.25), 0.04 * k)
    mix(out, P.sparkle(0.4, 0.3), 0.05)
    return out


def cue_hit(P):
    out = P.boom(0.22, 0.8)
    mix(out, P.hit(0.1, 1.0))
    return out


def cue_crit(P):
    out = P.boom(0.4, 1.0)
    mix(out, P.hit(0.1, 1.0))
    mix(out, P.note(midi(91), 0.5, 0.8), 0.02)
    mix(out, P.sparkle(0.4, 0.5), 0.04)
    return reverb(out, 0.15, 0.6)


def cue_shield(P):
    out = P.note(midi(88), 0.55, 0.9)
    mix(out, P.note(midi(95), 0.5, 0.5), 0.05)
    return out


def cue_death(P):
    out = tone(300 * P.octave * 2, 0.8, 0.8, "tri", end_freq=60, decay=2.5)
    mix(out, P.boom(0.6, 0.7), 0.1)
    return reverb(out, 0.2, 0.8)


def cue_victory(P):
    return note_seq(P, [72, 76, 79, 84, 79, 84, 88], 0.13, 0.9, 0.85, 0.3)


def cue_defeat(P):
    return note_seq(P, [67, 63, 60, 55], 0.28, 1.2, 0.8, 0.35)


# name -> (builder, volume_db, pitch_jitter, cooldown_msec); `variants` makes N pitch steps picked at random
CUES = {
    "ui_click": (cue_ui_click, -6, 0.02, 20, 1),
    "ui_hover": (cue_ui_hover, -16, 0.03, 60, 1),
    "menu_open": (cue_menu_open, -8, 0.0, 80, 1),
    "menu_close": (cue_menu_close, -8, 0.0, 80, 1),
    "swap": (cue_swap, -6, 0.04, 40, 1),
    "swap_reject": (cue_swap_reject, -6, 0.02, 120, 1),
    "drag_pick": (cue_drag_pick, -12, 0.03, 60, 1),
    "drag_drop": (cue_drag_drop, -12, 0.03, 60, 1),
    "tile_land": (make_land, -14, 0.04, 35, 4),
    "tile_pop": (cue_tile_pop, -9, 0.04, 60, 1),
    "destroy": (make_destroy, -9, 0.0, 22, 8),
    "match": (cue_match, -9, 0.03, 70, 1),
    "combo": (cue_combo, -6, 0.0, 120, 1),
    "fuse": (cue_fuse, -8, 0.02, 120, 1),
    "arrow_charge": (cue_arrow_charge, -9, 0.02, 120, 1),
    "prism_charge": (cue_prism_charge, -8, 0.0, 150, 1),
    "bomb_blast": (cue_bomb_blast, -2, 0.03, 80, 1),
    "arrow_launch": (cue_arrow_launch, -7, 0.04, 40, 1),
    "arrow_blast": (cue_arrow_blast, -4, 0.04, 60, 1),
    "prism_launch": (cue_prism_launch, -9, 0.02, 80, 1),
    "prism_blast": (cue_prism_blast, -3, 0.02, 80, 1),
    "combine": (cue_combine, -4, 0.02, 100, 1),
    "detonate": (cue_detonate, -6, 0.03, 100, 1),
    "shuffle": (cue_shuffle, -8, 0.0, 200, 1),
    "hint": (cue_hint, -10, 0.0, 300, 1),
    "quest_tick": (cue_quest_tick, -14, 0.02, 80, 1),
    "quest_done": (cue_quest_done, -5, 0.0, 300, 1),
    "turn_start": (cue_turn_start, -8, 0.0, 300, 1),
    "target_select": (cue_target_select, -9, 0.03, 60, 1),
    "action_attack": (cue_action_attack, -5, 0.03, 100, 1),
    "action_defend": (cue_action_defend, -6, 0.02, 100, 1),
    "hit": (cue_hit, -4, 0.05, 80, 1),
    "crit": (cue_crit, -2, 0.03, 120, 1),
    "shield": (cue_shield, -7, 0.02, 120, 1),
    "death": (cue_death, -3, 0.02, 300, 1),
    "victory": (cue_victory, -3, 0.0, 1000, 1),
    "defeat": (cue_defeat, -3, 0.0, 1000, 1),
}


# ---- Music ------------------------------------------------------------------

def render_music(P, kind, seed):
    rng = random.Random(seed)
    cfg = P.music[kind]
    beat = 60.0 / cfg["bpm"]
    bar = 4 * beat
    loop_len = int(cfg["bars"] * bar * SR)
    out = silence(cfg["bars"] * bar)
    chords = cfg["chords"]
    for b in range(cfg["bars"]):
        root, intervals = chords[b % len(chords)]
        t0 = b * bar
        for iv in intervals[:3]:
            mix(out, P.pad(midi(root + iv), bar * 1.15), t0, 0.16)
        mix(out, P.bass(midi(root - 12), beat * 2.0), t0, 0.45)
        mix(out, P.bass(midi(root - 12 + (7 if b % 2 else 0)), beat * 1.6), t0 + 2 * beat, 0.35)
        for step in range(8):
            if rng.random() < cfg["density"]:
                pitch = root + 12 + intervals[rng.choice((1, 2, 3, 2, 1, 0))] + (12 if rng.random() < 0.25 else 0)
                mix(out, P.arp(midi(pitch), beat * 0.9), t0 + step * beat / 2, 0.2)
        if cfg["perc"]:
            kicks = (0, 1, 2, 3) if kind == "battle" else (0, 2)
            for k in kicks:
                mix(out, P.kick(), t0 + k * beat, 0.5)
            for k in range(8):
                if k % 2 == 1:
                    mix(out, P.tick(), t0 + k * beat / 2, 0.25)
    out = reverb(out, 0.3, 1.2)
    for i in range(loop_len, len(out)):
        out[i - loop_len] += out[i]
    return finish(out[:loop_len], 0.8)


# ---- Output -------------------------------------------------------------------

IMPORT_TEMPLATE = """[remap]

importer="wav"
type="AudioStreamWAV"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={loop}
edit/loop_begin=0
edit/loop_end=-1
compress/mode=2
"""


def write_wav(buf, path, loop=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in buf))
    # import loop_mode 2 = forward (music); 0 = as stored in the wav, i.e. none (cues)
    path.with_name(path.name + ".import").write_text(IMPORT_TEMPLATE.format(loop=2 if loop else 0))


def build_pack(P):
    random.seed(1234)
    folder = OUT / f"{P.name}_pack"
    cue_files = {}
    for name, (builder, _, _, _, variants) in CUES.items():
        files = []
        for v in range(variants):
            buf = finish(builder(P, v) if variants > 1 else builder(P))
            suffix = f"_{v + 1}" if variants > 1 else ""
            write_wav(buf, folder / "sfx" / f"{name}{suffix}.wav")
            files.append(f"sfx/{name}{suffix}.wav")
        cue_files[name] = files
    music_files = {}
    for index, kind in enumerate(P.music):
        write_wav(render_music(P, kind, 100 + index), folder / "music" / f"{kind}.wav", loop=True)
        music_files[kind] = f"music/{kind}.wav"
    write_bank(P, folder, cue_files, music_files)
    print(f"{P.name}: {len(cue_files)} cues, {len(music_files)} tracks")


def write_bank(P, folder, cue_files, music_files):
    lines = [
        '[gd_resource type="Resource" script_class="AudioBank" format=3]',
        "",
        '[ext_resource type="Script" path="res://view/audio/audio_bank.gd" id="bank"]',
        '[ext_resource type="Script" path="res://view/audio/sound_cue.gd" id="cue"]',
    ]
    for files in list(cue_files.values()) + [[f] for f in music_files.values()]:
        for f in files:
            lines.append(f'[ext_resource type="AudioStream" path="{RES_PREFIX}{P.name}_pack/{f}" id="{f}"]')
    lines.append("")
    for name, files in cue_files.items():
        _, volume, jitter, cooldown, _ = CUES[name]
        refs = ", ".join(f'ExtResource("{f}")' for f in files)
        lines += [
            f'[sub_resource type="Resource" id="cue_{name}"]',
            'script = ExtResource("cue")',
            f"streams = Array[AudioStream]([{refs}])",
            f"volume_db = {float(volume)}",
            f"pitch_jitter = {jitter}",
            f"cooldown_msec = {cooldown}",
            "",
        ]
    cues = ", ".join(f'"{n}": SubResource("cue_{n}")' for n in cue_files)
    music = ", ".join(f'"{k}": ExtResource("{f}")' for k, f in music_files.items())
    lines += ["[resource]", 'script = ExtResource("bank")', f"cues = {{{cues}}}", f"music = {{{music}}}", ""]
    (folder / "sound_bank.tres").write_text("\n".join(lines))
    (folder / "LICENSE.txt").write_text("Generated by tools/gen_audio.py from synthesized waveforms only. CC0 / public domain.\n")


if __name__ == "__main__":
    for key in sys.argv[1:] or PROFILES:
        build_pack(PROFILES[key])
