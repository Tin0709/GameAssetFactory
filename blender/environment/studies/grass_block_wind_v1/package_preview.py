"""Package rendered frames as a four-second GIF; originals stay available."""
from pathlib import Path
from PIL import Image

OUT=Path(__file__).resolve().parent
paths=sorted((OUT/'wind_frames').glob('*.png'))
assert len(paths)==48,len(paths)
frames=[Image.open(p).convert('RGB') for p in paths]
palette=frames[0].quantize(colors=256)
indexed=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
# GIF uses 10ms ticks. Repeat 80,80,90ms for exactly 4000ms over 48 frames.
durations=[80 if i%3<2 else 90 for i in range(48)]
assert sum(durations)==4000
indexed[0].save(OUT/'wind_preview.gif',save_all=True,append_images=indexed[1:],duration=durations,loop=0,optimize=False,disposal=2)
with Image.open(OUT/'wind_preview.gif') as gif:
    duration=0
    for i in range(gif.n_frames):
        gif.seek(i);duration+=gif.info['duration']
    assert gif.n_frames==48 and duration==4000
    print({'gif_frames':gif.n_frames,'duration_ms':duration,'dimensions':gif.size})
print('WIND_PREVIEW_PACKAGED')
