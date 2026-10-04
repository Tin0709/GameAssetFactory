from PIL import Image, ImageDraw
from pathlib import Path
OUT=Path(__file__).parent
frames=[Image.open(OUT/'frames'/f'{i:04d}.png').convert('RGBA') for i in range(1,49)]
# APNG preserves alpha and a 24 FPS time base.
frames[0].save(OUT/'Player_Idle.apng',save_all=True,append_images=frames[1:],duration=1000/24,loop=0,disposal=0,blend=0)
# GIF durations are quantized to 10 ms. 40/40/50/40/40/40 = 250 ms,
# repeated eight times: exactly two seconds, without a duplicated closure frame.
bg=[]
for frame in frames:
    canvas=Image.new('RGBA',frame.size,(28,38,46,255));canvas.alpha_composite(frame)
    bg.append(canvas.convert('RGB'))
palette=bg[0].quantize(colors=256)
gif=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in bg]
gif[0].save(OUT/'Player_Idle.gif',save_all=True,append_images=gif[1:],duration=[40,40,50,40,40,40]*8,loop=0,optimize=False,disposal=2)
sheet=Image.new('RGB',(4*320,2*346),(28,38,46))
draw=ImageDraw.Draw(sheet)
for j,f in enumerate([1,7,13,19,25,31,37,43]):
    thumb=bg[f-1].resize((320,320))
    x=(j%4)*320;y=(j//4)*346
    sheet.paste(thumb,(x,y));draw.text((x+14,y+322),f'Frame {f:02d}',fill='white')
sheet.save(OUT/'idle_pose_sheet.jpg')
with Image.open(OUT/'Player_Idle.gif') as check:
    count=check.n_frames; duration=0
    for i in range(count):
        check.seek(i);duration+=check.info['duration']
    assert count==48 and duration==2000
print({'gif_frames':count,'duration_ms':duration,'apng':'Player_Idle.apng'})
