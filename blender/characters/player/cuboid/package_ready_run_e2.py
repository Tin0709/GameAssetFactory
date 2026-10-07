"""Package normal-time review renders and a small pose sheet."""
from pathlib import Path
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parent/'ready_run_e2_review'
for mode in ['Detail','GameplayScale']:
    frames=[Image.open(P/f'{mode}_{i:04d}.png').convert('RGB') for i in range(1,161)]
    palette=frames[0].quantize(colors=256)
    gs=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    duration=[10*(round((i+1)*100/24)-round(i*100/24)) for i in range(160)]
    gs[0].save(P/f'{mode}_ABC_24fps.gif',save_all=True,append_images=gs[1:],duration=duration,loop=0,disposal=1,optimize=True)
    # Keep only meaningful sample frames, plus the animated comparison.
    sheet=Image.new('RGB',(1280,760),(30,38,46));d=ImageDraw.Draw(sheet)
    for k,i in enumerate([0,1,3,4,5,6,8,9]):
        x=(k%2)*640;y=(k//2)*190
        sheet.paste(frames[i].resize((640,360)).crop((0,70,640,235)),(x,y+24))
        d.text((x+8,y+5),f'Run source phase {1+(i*1.6)%16:.1f} / playback {i/24:.3f}s',fill='white')
    sheet.save(P/f'{mode}_key_poses.png')
    for im in frames:im.close()
print('Packaged both 160-frame comparisons; 6.67 seconds at average 24 FPS.')
