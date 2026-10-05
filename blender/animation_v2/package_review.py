from pathlib import Path
from PIL import Image,ImageDraw
import json,html
OUT=Path(__file__).resolve().parent
catalog={a['name']:a for kind in ['player','zombie'] for a in json.loads((OUT/(kind+'_actions.json')).read_text())}
cards=[]
for folder in sorted((OUT/'frames').iterdir()):
    paths=sorted(folder.glob('[0-9][0-9][0-9].png'))
    if len(paths)!=24:continue
    a=catalog[folder.name];frames=[]
    for path in paths:
        im=Image.open(path).convert('RGBA');bg=Image.new('RGBA',im.size,(28,37,47,255));bg.alpha_composite(im)
        frames.append(bg.convert('RGB'))
    duration=round(a['frames']/a['fps']/len(frames)*1000)
    # Add readable rests to one-shot demonstrations without changing clip data.
    times=[duration]*len(frames)
    if not a['loop']:times[0]=400;times[-1]=600
    frames[0].save(OUT/(folder.name+'.gif'),save_all=True,append_images=frames[1:],duration=times,loop=0,disposal=2)
    sheet=Image.new('RGB',(1280,700),(28,37,47));draw=ImageDraw.Draw(sheet)
    for i in range(8):
        x=i%4*320;y=i//4*350;sheet.paste(frames[i*3],(x,y));draw.text((x+10,y+325),f'{folder.name} / phase {i/8:.3f}',fill='white')
    sheet.save(OUT/(folder.name+'_poses.jpg'),quality=92)
    sides=sorted(folder.glob('side_*.png'))
    if sides:
        for i,path in enumerate(sides):
            im=Image.open(path).convert('RGBA');bg=Image.new('RGBA',im.size,(28,37,47,255));bg.alpha_composite(im)
            x=i%4*320;y=i//4*350;sheet.paste(bg.convert('RGB'),(x,y))
        sheet.save(OUT/(folder.name+'_side_poses.jpg'),quality=92)
    cards.append(f'<article><h2>{html.escape(folder.name)}</h2><img src="{folder.name}.gif"><p>{a["layer"]} · {a["frames"]/a["fps"]:.2f}s</p><a href="{folder.name}_poses.jpg">Pose sheet</a></article>')
(OUT/'review.html').write_text('''<!doctype html><html><meta charset="utf-8"><title>Animation V2 review</title><style>body{background:#151e28;color:#e6edf5;font:16px system-ui;margin:32px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px}article{background:#1c252f;padding:16px;border-radius:12px}h2{font-size:17px}img{width:100%;max-width:384px}a{color:#7fdad5}p{color:#aabbce}</style><h1>GameAssetFactory · Animation V2</h1><p>Original motion. Player V6 / zombie V2 geometry and textures preserved. Rigid arms and legs. Review composites demonstrate the modular layers; Godot integration is pending.</p><p><a href="../../ANIMATION_SYSTEM_V2.md">Architecture and review instructions</a></p><main>'''+''.join(cards)+'</main></html>',encoding='utf8')
print('PACKAGED',len(cards),'previews')
