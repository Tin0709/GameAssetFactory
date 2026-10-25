"""Original Sword v001 cues: deterministic mono PCM synthesis, no sample inputs.

Run with Python 3 from any directory to reproduce the five adjacent WAVs exactly.
No Fiery/Actions & Stuff/Minecraft Dungeons audio or repository mp3 is sampled.
"""
from pathlib import Path
import math
import random
import struct
import wave

OUTPUT = Path(__file__).resolve().parent
SAMPLE_RATE = 22050
for kind, length in [("swing", .19), ("impact", .15), ("finisher", .26), ("guard", .16), ("parry", .30)]:
    rng = random.Random(8392 + len(kind))
    filtered = 0
    samples = []
    for index in range(int(length * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        phase = time / length
        noise = rng.uniform(-1, 1)
        filtered = .68 * filtered + .32 * noise
        attack = min(1, time / .004)
        tail = (1 - phase) ** 2
        if kind == "swing":
            envelope = math.sin(math.pi * phase) ** 1.7
            value = (noise - filtered) * .25 * envelope + filtered * .12 * envelope
        elif kind in ("impact", "finisher"):
            base = 100 if kind == "finisher" else 155
            value = (noise * .32 * math.exp(-time * 45)
                     + math.sin(2 * math.pi * (base * time - 80 * time * time)) * .32 * math.exp(-time * 20)
                     + math.sin(2 * math.pi * 920 * time) * .10 * math.exp(-time * 48)) * attack * tail
        else:
            base = 1320 if kind == "parry" else 740
            value = ((math.sin(2 * math.pi * base * time) * .20
                      + math.sin(2 * math.pi * base * 1.47 * time) * .12
                      + math.sin(2 * math.pi * base * 2.13 * time) * .07)
                     * math.exp(-time * (11 if kind == "parry" else 24)) * attack * tail
                     + noise * .12 * math.exp(-time * 90) * attack)
        samples.append(int(max(-.95, min(.95, value)) * 32767))
    with wave.open(str(OUTPUT / (kind + ".wav")), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(SAMPLE_RATE)
        sound.writeframes(struct.pack("<%dh" % len(samples), *samples))
