"""Package normal-time A/B sequences without altering authored assets."""
from pathlib import Path
from PIL import Image, ImageDraw
BASE=Path(__file__).resolve().parent/'ready_e1_review'
for layer,count in [('Idle',96),('Run',160)]:
    frames=[Image.open(BASE/f'{layer}_motion_{i:04d}.png').convert('RGB') for i in range(1,count+1)]
    # APNG supports millisecond timing; GIF duration is quantized to 10 ms.
    durations=[round((i+1)*1000/24)-round(i*1000/24) for i in range(count)]
    frames[0].save(BASE/f'{layer}_AB_24fps.png',save_all=True,append_images=frames[1:],duration=durations,loop=0)
    gd=[(round((i+1)*100/24)-round(i*100/24))*10 for i in range(count)]
    palette=frames[0].quantize(colors=256)
    gifs=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    gifs[0].save(BASE/f'{layer}_AB.gif',save_all=True,append_images=gifs[1:],duration=gd,loop=0,disposal=1,optimize=True)
    picks=[0,6,11,18,25,31] if layer=='Idle' else [0,3,6,9,43,76]
    sheet=Image.new('RGB',(960,636),(25,32,40));draw=ImageDraw.Draw(sheet)
    for k,i in enumerate(picks):
        x=(k%3)*320;y=(k//3)*318
        thumb=frames[i].resize((320,192))
        sheet.paste(thumb,(x,y+24));draw.text((x+8,y+7),f'{layer} frame {i+1} / {(i/24):.3f}s',fill='white')
    sheet.save(BASE/f'{layer}_contact_sheet.png')
    for im in frames:im.close()
print('Packaged Idle and Run at 24 FPS; source images retained as evidence.')
