from pathlib import Path
from PIL import Image
OUT=Path(__file__).resolve().parent
paths=sorted((OUT/'player_demo_frames').glob('*.png'))
assert len(paths)==64
frames=[Image.open(p).convert('RGB') for p in paths]
sheet=Image.new('RGB',(1024,1024))
for i,frame in enumerate(frames):sheet.paste(frame.resize((128,128)),((i%8)*128,(i//8)*128))
palette=sheet.quantize(colors=256)
indexed=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
durations=[120 if i%2==0 else 130 for i in range(64)]
indexed[0].save(OUT/'player_reaction_demo.gif',save_all=True,append_images=indexed[1:],duration=durations,loop=0,optimize=False,disposal=2)
with Image.open(OUT/'player_reaction_demo.gif') as gif:
    duration=0
    for i in range(gif.n_frames):gif.seek(i);duration+=gif.info['duration']
    assert gif.n_frames==64 and duration==8000
    print({'frames':gif.n_frames,'duration_ms':duration,'dimensions':gif.size})
