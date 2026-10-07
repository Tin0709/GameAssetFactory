"""Normal-speed A/B strips from the actual Godot renderer; no slow motion."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
BASE = Path(__file__).resolve().parents[1]/'.validation/ready_e3'
OUT = BASE/'review'
OUT.mkdir(parents=True,exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
for weapon,name in [(1,'M4A1'),(2,'Shotgun')]:
    for view in ['gameplay','detail']:
        for context in ['Idle','Run']:
            frames = []
            for i in range(64):
                canvas = Image.new('RGB',(1280,408),'#101c26')
                draw = ImageDraw.Draw(canvas)
                for mode,x in [('legacy',0),('living',640)]:
                    frame = Image.open(BASE/'rendered'/f'{weapon}_{view}_{context}_{mode}_{i:03d}.png').convert('RGB').resize((640,360),Image.Resampling.LANCZOS)
                    canvas.paste(frame,(x,48))
                    draw.text((x+14,7),f'{name} {context} | '+('A: LongGunHold_V2' if mode=='legacy' else 'B: Living Ready'),font=font,fill='white')
                    draw.text((x+14,27),'24 FPS playback | Run V7 1.60 | '+('Run in-place diagnostic' if context=='Run' else 'Idle composition'),font=font,fill='#a7c2ca')
                frames.append(canvas)
            durations = [[40,40,40,50,40,40][i%6] for i in range(64)]
            frames[0].save(OUT/f'{name}_{context}_{view}_AB.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False)
            if view == 'detail':
                sheet = Image.new('RGB',(1280,408*4))
                for row,idx in enumerate([0,2,4,6]): sheet.paste(frames[idx],(0,row*408))
                sheet.save(OUT/f'{name}_{context}_detail_phases.png')
metrics = json.loads((BASE/'rendered/measurements.json').read_text())
summary = {key:{mode:{('weapon_origin' if bone=='grip' else bone):round((max(values)-min(values))*1000,3) for bone,values in parts.items()} for mode,parts in item.items()} for key,item in metrics.items()}
(OUT/'vertical_ranges_mm.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
