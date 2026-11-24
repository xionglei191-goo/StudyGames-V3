"""Synthesize V9 Expressive, Warm, Child-Friendly Animal Vocalizations.

Generates 7 organic 16-bit mono 22050Hz PCM `.wav` clips (`0.42s`-`0.72s` each)
under `game/assets/audio/animals/` using band-limited glottal/syrinx harmonic
models, time-varying vocal-tract formant resonators, natural pitch glides,
vibrato, and soft cosine fade-in/out envelopes.
"""
from __future__ import annotations

import math
from pathlib import Path
import struct
import wave

import numpy as np


SAMPLE_RATE = 22050
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "game" / "assets" / "audio" / "animals"


def _interp_curve(t: np.ndarray, knots_t: list[float], knots_v: list[float]) -> np.ndarray:
    """Smooth piecewise cosine-interpolated parameter curve."""
    kt = np.asarray(knots_t, dtype=np.float64)
    kv = np.asarray(knots_v, dtype=np.float64)
    out = np.empty_like(t, dtype=np.float64)
    idx = np.searchsorted(kt, t, side="right") - 1
    idx = np.clip(idx, 0, len(kt) - 2)
    t0 = kt[idx]
    t1 = kt[idx + 1]
    v0 = kv[idx]
    v1 = kv[idx + 1]
    span = np.maximum(t1 - t0, 1e-9)
    alpha = np.clip((t - t0) / span, 0.0, 1.0)
    smooth = 0.5 - 0.5 * np.cos(np.pi * alpha)
    out[:] = v0 + (v1 - v0) * smooth
    return out


def _glottal_harmonics(
    f0: np.ndarray,
    num_harmonics: int = 7,
    rolloff: float = 1.45,
    even_warmth: float = 1.0,
) -> np.ndarray:
    """Band-limited soft glottal harmonic source without harsh square edges."""
    phase = 2.0 * np.pi * np.cumsum(f0) / SAMPLE_RATE
    sig = np.zeros_like(f0, dtype=np.float64)
    nyquist_guard = 0.44 * SAMPLE_RATE
    for k in range(1, num_harmonics + 1):
        amp = (1.0 / (k ** rolloff)) * (even_warmth if (k % 2 == 0) else 1.0)
        mask = np.clip((nyquist_guard - k * f0) / 400.0, 0.0, 1.0)
        sig += amp * mask * np.sin(k * phase + 0.17 * k)
    return sig


def _formant_resonator(
    x: np.ndarray,
    fc_curve: np.ndarray | float,
    bw_hz: float,
) -> np.ndarray:
    """Time-varying 2-pole/2-zero bandpass formant resonator."""
    n = len(x)
    if np.isscalar(fc_curve):
        fc = np.full(n, float(fc_curve), dtype=np.float64)
    else:
        fc = np.asarray(fc_curve, dtype=np.float64)
    r = math.exp(-math.pi * bw_hz / SAMPLE_RATE)
    r2 = r * r
    gain = 1.0 - r
    c1 = 2.0 * r * np.cos(2.0 * np.pi * np.clip(fc, 60.0, 0.45 * SAMPLE_RATE) / SAMPLE_RATE)

    y = np.zeros(n, dtype=np.float64)
    y1 = 0.0
    y2 = 0.0
    x2 = 0.0
    x1 = 0.0
    for i in range(n):
        xi = float(x[i])
        yi = gain * (xi - r * x2) + float(c1[i]) * y1 - r2 * y2
        y[i] = yi
        y2 = y1
        y1 = yi
        x2 = x1
        x1 = xi
    return y


def _soft_fade_and_normalize(
    sig: np.ndarray,
    fade_in_s: float = 0.018,
    fade_out_s: float = 0.045,
    peak: float = 0.80,
) -> np.ndarray:
    out = np.asarray(sig, dtype=np.float64).copy()
    out -= np.mean(out)
    n = len(out)
    fi = max(1, int(fade_in_s * SAMPLE_RATE))
    fo = max(1, int(fade_out_s * SAMPLE_RATE))
    if fi < n:
        out[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, fi))
    if fo < n:
        out[-fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.linspace(0.0, 1.0, fo))
    # Gentle soft-knee warmth saturation before peak normalization
    max_abs = float(np.max(np.abs(out)))
    if max_abs > 1e-8:
        out = np.tanh((out / max_abs) * 1.18)
        out /= float(np.max(np.abs(out)))
        out *= peak
    return out


def synth_kitty_meow(rng: np.random.Generator) -> np.ndarray:
    """0.64s soft sweet rising-then-falling kitten 'mew~' (520 -> 760 -> 480Hz) + tiny purr tail."""
    dur = 0.64
    t = np.arange(int(dur * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE
    f0 = _interp_curve(
        t,
        [0.0, 0.06, 0.21, 0.42, 0.55, dur],
        [515.0, 560.0, 765.0, 565.0, 480.0, 465.0],
    )
    vibrato = 1.0 + 0.012 * np.sin(2.0 * np.pi * 6.4 * t) * np.clip((t - 0.10) / 0.20, 0.0, 1.0)
    src = _glottal_harmonics(f0 * vibrato, num_harmonics=7, rolloff=1.42, even_warmth=1.12)

    # Vowel transition: m-ee -> aah -> ooh~
    f1 = _interp_curve(t, [0.0, 0.12, 0.26, 0.50, dur], [420.0, 780.0, 840.0, 540.0, 460.0])
    f2 = _interp_curve(t, [0.0, 0.12, 0.26, 0.50, dur], [1850.0, 2150.0, 1620.0, 1180.0, 1040.0])
    voiced = (
        0.52 * _formant_resonator(src, f1, 140.0)
        + 0.34 * _formant_resonator(src, f2, 220.0)
        + 0.22 * np.sin(2.0 * np.pi * np.cumsum(f0 * vibrato) / SAMPLE_RATE)
    )
    env = _interp_curve(t, [0.0, 0.045, 0.18, 0.40, 0.54, dur], [0.0, 0.85, 1.0, 0.72, 0.18, 0.0])

    # Soft affectionate kitten purr tail (26 Hz warm flutter)
    purr_carrier = (
        np.sin(2.0 * np.pi * 185.0 * t) * 0.65
        + np.sin(2.0 * np.pi * 370.0 * t) * 0.35
        + _formant_resonator(rng.normal(0.0, 0.25, len(t)), 320.0, 160.0)
    )
    purr_mod = 0.5 + 0.5 * np.sin(2.0 * np.pi * 26.5 * t)
    purr_env = _interp_curve(t, [0.0, 0.34, 0.46, 0.58, dur], [0.0, 0.0, 0.15, 0.11, 0.0])

    return _soft_fade_and_normalize(voiced * env + purr_carrier * purr_mod * purr_env, 0.016, 0.045, 0.80)


def synth_puppy_woof(rng: np.random.Generator) -> np.ndarray:
    """0.58s cheerful playful double puppy 'arf-arf!' (280 -> 430 -> 240Hz + friendly 2nd bounce)."""
    dur = 0.58
    t = np.arange(int(dur * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE
    f0 = _interp_curve(
        t,
        [0.0, 0.03, 0.10, 0.22, 0.27, 0.35, 0.47, dur],
        [275.0, 340.0, 430.0, 242.0, 290.0, 458.0, 255.0, 232.0],
    )
    src = _glottal_harmonics(f0, num_harmonics=8, rolloff=1.35, even_warmth=1.18)
    breath = _formant_resonator(rng.normal(0.0, 0.35, len(t)), 950.0, 420.0)

    # Warm chesty "ah-oo" puppy formants for each playful bounce
    f1 = _interp_curve(
        t,
        [0.0, 0.08, 0.21, 0.28, 0.35, 0.52, dur],
        [520.0, 760.0, 460.0, 540.0, 810.0, 470.0, 430.0],
    )
    f2 = _interp_curve(
        t,
        [0.0, 0.08, 0.21, 0.28, 0.35, 0.52, dur],
        [1180.0, 1460.0, 980.0, 1220.0, 1520.0, 1020.0, 960.0],
    )
    body = (
        0.55 * _formant_resonator(src, f1, 155.0)
        + 0.30 * _formant_resonator(src, f2, 240.0)
        + 0.26 * np.sin(2.0 * np.pi * np.cumsum(f0) / SAMPLE_RATE)
    )

    env1 = _interp_curve(t, [0.0, 0.022, 0.085, 0.20, 0.245, dur], [0.0, 0.88, 0.92, 0.22, 0.0, 0.0])
    env2 = _interp_curve(t, [0.0, 0.265, 0.292, 0.36, 0.50, dur], [0.0, 0.0, 0.96, 1.0, 0.24, 0.0])
    puff = (
        _interp_curve(t, [0.0, 0.012, 0.045, dur], [0.0, 0.22, 0.0, 0.0])
        + _interp_curve(t, [0.0, 0.268, 0.282, 0.315, dur], [0.0, 0.0, 0.24, 0.0, 0.0])
    )
    sig = body * (env1 + env2) + breath * puff
    return _soft_fade_and_normalize(sig, 0.012, 0.040, 0.82)


def synth_bunny_chirp(rng: np.random.Generator) -> np.ndarray:
    """0.46s gentle curious bunny nose-twitch squeak-chirp (820 -> 1080Hz soft flute-like harmonic)."""
    dur = 0.46
    t = np.arange(int(dur * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE

    # Two dainty nose-twitch chirrups into a sweet curious upward chirp
    f0 = _interp_curve(
        t,
        [0.0, 0.08, 0.14, 0.22, 0.33, dur],
        [820.0, 960.0, 850.0, 980.0, 1085.0, 940.0],
    )
    vib = 1.0 + 0.010 * np.sin(2.0 * np.pi * 9.5 * t)
    phase = 2.0 * np.pi * np.cumsum(f0 * vib) / SAMPLE_RATE
    flute = 0.74 * np.sin(phase) + 0.20 * np.sin(2.0 * phase + 0.3) + 0.06 * np.sin(3.0 * phase)
    shaped = 0.65 * flute + 0.35 * _formant_resonator(flute, 1020.0, 190.0)

    sniff = _formant_resonator(rng.normal(0.0, 0.18, len(t)), 1650.0, 500.0)
    sniff_env = (
        _interp_curve(t, [0.0, 0.025, 0.065, dur], [0.0, 0.16, 0.0, 0.0])
        + _interp_curve(t, [0.0, 0.09, 0.115, 0.15, dur], [0.0, 0.0, 0.14, 0.0, 0.0])
    )
    chirp_env = (
        _interp_curve(t, [0.0, 0.025, 0.075, 0.125, dur], [0.0, 0.48, 0.35, 0.0, 0.0])
        + _interp_curve(t, [0.0, 0.14, 0.19, 0.31, 0.41, dur], [0.0, 0.0, 0.90, 1.0, 0.20, 0.0])
    )
    return _soft_fade_and_normalize(shaped * chirp_env + sniff * sniff_env, 0.014, 0.038, 0.76)


def synth_bird_tweet(_rng: np.random.Generator) -> np.ndarray:
    """0.56s melodic sunny songbird two-note trill (1450 -> 1950 -> 1680Hz)."""
    dur = 0.56
    t = np.arange(int(dur * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE

    trill_gate = _interp_curve(t, [0.0, 0.25, 0.31, 0.49, dur], [0.0, 0.0, 1.0, 0.8, 0.0])
    trill_hz = 34.0 * np.sin(2.0 * np.pi * 23.0 * t) * trill_gate
    f0 = _interp_curve(
        t,
        [0.0, 0.05, 0.15, 0.23, 0.27, 0.37, 0.48, dur],
        [1450.0, 1680.0, 1840.0, 1590.0, 1540.0, 1950.0, 1680.0, 1650.0],
    ) + trill_hz

    phase = 2.0 * np.pi * np.cumsum(f0) / SAMPLE_RATE
    syrinx = 0.80 * np.sin(phase) + 0.16 * np.sin(2.0 * phase + 0.2) + 0.04 * np.sin(3.0 * phase)
    resonated = 0.70 * syrinx + 0.30 * _formant_resonator(syrinx, 1780.0, 260.0)

    env1 = _interp_curve(t, [0.0, 0.024, 0.11, 0.21, 0.245, dur], [0.0, 0.82, 0.90, 0.20, 0.0, 0.0])
    env2 = _interp_curve(t, [0.0, 0.255, 0.29, 0.39, 0.50, dur], [0.0, 0.0, 0.95, 1.0, 0.24, 0.0])
    return _soft_fade_and_normalize(resonated * (env1 + env2), 0.014, 0.040, 0.76)


def synth_elephant_toot(rng: np.random.Generator) -> np.ndarray:
    """0.68s warm friendly baby-elephant brassy toot (210 -> 360 -> 290Hz)."""
    dur = 0.68
    t = np.arange(int(dur * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE

    f0 = _interp_curve(
        t,
        [0.0, 0.07, 0.22, 0.44, 0.58, dur],
        [210.0, 265.0, 362.0, 328.0, 290.0, 276.0],
    )
    vib = 1.0 + 0.011 * np.sin(2.0 * np.pi * 5.6 * t) * np.clip((t - 0.18) / 0.22, 0.0, 1.0)
    phase = 2.0 * np.pi * np.cumsum(f0 * vib) / SAMPLE_RATE

    # Warm baby-brass harmonic bloom: upper harmonics open gently mid-note
    bloom = _interp_curve(t, [0.0, 0.14, 0.34, 0.56, dur], [0.35, 0.95, 1.0, 0.55, 0.25])
    brass = (
        0.56 * np.sin(phase)
        + 0.34 * bloom * np.sin(2.0 * phase + 0.15)
        + 0.22 * bloom * np.sin(3.0 * phase + 0.35)
        + 0.12 * (bloom ** 1.3) * np.sin(4.0 * phase + 0.50)
        + 0.06 * (bloom ** 1.5) * np.sin(5.0 * phase + 0.70)
    )
    trunk = (
        0.48 * _formant_resonator(brass, _interp_curve(t, [0.0, 0.24, dur], [480.0, 640.0, 520.0]), 135.0)
        + 0.30 * _formant_resonator(brass, _interp_curve(t, [0.0, 0.24, dur], [1080.0, 1340.0, 1140.0]), 210.0)
        + 0.32 * brass
    )
    air = _formant_resonator(rng.normal(0.0, 0.20, len(t)), 720.0, 300.0) * _interp_curve(
        t, [0.0, 0.025, 0.09, dur], [0.0, 0.18, 0.03, 0.0]
    )
    env = _interp_curve(t, [0.0, 0.04, 0.16, 0.46, 0.60, dur], [0.0, 0.84, 1.0, 0.82, 0.24, 0.0])
    return _soft_fade_and_normalize(trunk * env + air, 0.018, 0.050, 0.80)


def synth_dino_chirp(_rng: np.random.Generator) -> np.ndarray:
    """0.54s cute playful baby-dino bubbly chirp-trill (420 -> 690 -> 580Hz) for `textbook_dino`."""
    dur = 0.54
    t = np.arange(int(dur * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE

    bubble = 22.0 * np.sin(2.0 * np.pi * 16.5 * t) * _interp_curve(
        t, [0.0, 0.14, 0.24, 0.44, dur], [0.2, 0.8, 1.0, 0.6, 0.0]
    )
    f0 = _interp_curve(
        t,
        [0.0, 0.06, 0.13, 0.18, 0.32, 0.45, dur],
        [420.0, 535.0, 470.0, 520.0, 692.0, 580.0, 555.0],
    ) + bubble

    src = _glottal_harmonics(f0, num_harmonics=6, rolloff=1.55, even_warmth=1.15)
    f1 = _interp_curve(t, [0.0, 0.16, 0.34, dur], [580.0, 740.0, 880.0, 680.0])
    f2 = _interp_curve(t, [0.0, 0.16, 0.34, dur], [1350.0, 1680.0, 1820.0, 1480.0])
    voiced = (
        0.50 * _formant_resonator(src, f1, 150.0)
        + 0.28 * _formant_resonator(src, f2, 230.0)
        + 0.30 * np.sin(2.0 * np.pi * np.cumsum(f0) / SAMPLE_RATE)
    )
    env = (
        _interp_curve(t, [0.0, 0.025, 0.09, 0.145, dur], [0.0, 0.72, 0.65, 0.18, 0.0])
        + _interp_curve(t, [0.0, 0.14, 0.20, 0.35, 0.47, dur], [0.0, 0.15, 0.96, 1.0, 0.22, 0.0])
    )
    return _soft_fade_and_normalize(voiced * np.clip(env, 0.0, 1.05), 0.015, 0.042, 0.79)


def synth_parrot_squawk(_rng: np.random.Generator) -> np.ndarray:
    """0.60s bright cheerful musical parrot whistle-chirp (780 -> 1240 -> 960Hz) for `textbook_role_xiaoxiao_parrot`."""
    dur = 0.60
    t = np.arange(int(dur * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE

    f0 = _interp_curve(
        t,
        [0.0, 0.06, 0.20, 0.27, 0.33, 0.45, dur],
        [780.0, 940.0, 1245.0, 1060.0, 1150.0, 960.0, 925.0],
    )
    vib = 1.0 + 0.011 * np.sin(2.0 * np.pi * 13.0 * t) * _interp_curve(t, [0.0, 0.30, 0.48, dur], [0.2, 1.0, 0.8, 0.0])
    src = _glottal_harmonics(f0 * vib, num_harmonics=5, rolloff=1.60, even_warmth=1.10)
    whistle = np.sin(2.0 * np.pi * np.cumsum(f0 * vib) / SAMPLE_RATE)

    f1 = _interp_curve(t, [0.0, 0.20, 0.38, dur], [880.0, 1280.0, 1080.0, 960.0])
    f2 = _interp_curve(t, [0.0, 0.20, 0.38, dur], [1880.0, 2350.0, 2040.0, 1920.0])
    voiced = (
        0.44 * _formant_resonator(src, f1, 175.0)
        + 0.24 * _formant_resonator(src, f2, 260.0)
        + 0.42 * whistle
    )
    env1 = _interp_curve(t, [0.0, 0.025, 0.14, 0.25, 0.285, dur], [0.0, 0.86, 1.0, 0.22, 0.0, 0.0])
    env2 = _interp_curve(t, [0.0, 0.28, 0.32, 0.44, 0.54, dur], [0.0, 0.0, 0.92, 0.88, 0.20, 0.0])
    return _soft_fade_and_normalize(voiced * (env1 + env2), 0.015, 0.044, 0.78)


def write_pcm16_wav(path: Path, samples: np.ndarray) -> dict[str, float | int | str]:
    clipped = np.clip(samples, -0.98, 0.98)
    pcm = np.round(clipped * 32767.0).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm.tobytes())
    raw = path.read_bytes()
    assert raw[:4] == b"RIFF" and raw[8:12] == b"WAVE", f"Invalid RIFF header in {path}"
    fmt_tag, channels, rate = struct.unpack_from("<HHI", raw, 20)
    bits = struct.unpack_from("<H", raw, 34)[0]
    assert (fmt_tag, channels, rate, bits) == (1, 1, SAMPLE_RATE, 16)
    dur_s = round(len(pcm) / SAMPLE_RATE, 3)
    rms = round(float(np.sqrt(np.mean(clipped ** 2))), 4)
    return {
        "file": path.name,
        "duration_s": dur_s,
        "frames": int(len(pcm)),
        "bytes": len(raw),
        "rms": rms,
    }


def build_all() -> list[dict[str, float | int | str]]:
    rng = np.random.default_rng(20261122)
    specs = [
        ("kitty_meow.wav", synth_kitty_meow),
        ("puppy_woof.wav", synth_puppy_woof),
        ("bunny_chirp.wav", synth_bunny_chirp),
        ("bird_tweet.wav", synth_bird_tweet),
        ("elephant_toot.wav", synth_elephant_toot),
        ("dino_chirp.wav", synth_dino_chirp),
        ("parrot_squawk.wav", synth_parrot_squawk),
    ]
    manifest: list[dict[str, float | int | str]] = []
    for filename, fn in specs:
        samples = fn(rng)
        info = write_pcm16_wav(OUT_DIR / filename, samples)
        assert 0.42 <= float(info["duration_s"]) <= 0.72, f"Duration out of range: {info}"
        assert float(info["rms"]) > 0.05, f"Clip too quiet: {info}"
        manifest.append(info)
    return manifest


if __name__ == "__main__":
    results = build_all()
    for item in results:
        print(
            f"[OK] {item['file']:18s} | {item['duration_s']:.3f}s | "
            f"{item['frames']:5d} frames | {item['bytes']:6d} bytes | rms={item['rms']:.4f}"
        )
