from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
OUT=Path(__file__).parent
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
report={}
for name,count in [('Player_Idle',48),('Player_Walk',32),('Player_Run',24)]:
    images=[Image.open(OUT/'frames'/name/f'{f:04d}.png').convert('RGBA') for f in range(1,count+1)]
    durations=[(round((i+1)*100/24)-round(i*100/24))*10 for i in range(count)]
    images[0].save(OUT/f'{name}.apng',save_all=True,append_images=images[1:],duration=1000/24,loop=0,disposal=0,blend=0)
    backgrounds=[]
    for im in images:
        bg=Image.new('RGBA',im.size,(24,32,40,255));bg.alpha_composite(im);backgrounds.append(bg.convert('RGB'))
    atlas=Image.new('RGB',(384*8,384*((count+7)//8)),(24,32,40))
    for i,im in enumerate(backgrounds):atlas.paste(im,(i%8*384,i//8*384))
    pal=atlas.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    gifframes=[im.quantize(palette=pal,dither=Image.Dither.NONE) for im in backgrounds]
    gifframes[0].save(OUT/f'{name}.gif',save_all=True,append_images=gifframes[1:],duration=durations,loop=0,optimize=False,disposal=2)
    images[0].save(OUT/f'{name}_preview.png')
    # All frames in chronological order for temporal QA, plus eight key poses.
    cell=192;sheet=Image.new('RGB',(8*cell,((count+7)//8)*(cell+24)),(24,32,40));draw=ImageDraw.Draw(sheet)
    for i,im in enumerate(backgrounds):
        x=i%8*cell;y=i//8*(cell+24);sheet.paste(im.resize((cell,cell),Image.Resampling.LANCZOS),(x,y));draw.text((x+8,y+cell),f'{i+1:02d}  {(i/24):.2f}s',font=font,fill=(190,210,220))
    sheet.save(OUT/f'{name}_all_frames.jpg',quality=92)
    keys=Image.new('RGB',(4*256,2*280),(24,32,40));draw=ImageDraw.Draw(keys)
    for j in range(8):
        i=j*count//8;x=j%4*256;y=j//4*280;keys.paste(backgrounds[i].resize((256,256),Image.Resampling.LANCZOS),(x,y));draw.text((x+8,y+256),f'{name} / frame {i+1}',font=font,fill=(190,210,220))
    keys.save(OUT/f'{name}_key_poses.jpg',quality=94)
    with Image.open(OUT/f'{name}.gif') as gif:
        ms=0
        for i in range(gif.n_frames):gif.seek(i);ms+=gif.info['duration']
        assert gif.n_frames==count and abs(ms-count/24*1000)<=5
    report[name]={'frames':count,'fps':24,'duration_ms':ms,'gif_frame_count_verified':True,'apng_transparent':True,'normal_speed_preview':str(OUT/f'{name}.gif')}
(OUT/'preview_report.json').write_text(json.dumps(report,indent=2))
# Browser-playable gallery; local artifacts only.
cards=''.join(f'<article><h2>{n.replace("Player_","")}</h2><img src="{n}.apng" alt="{n} at 24 FPS"><p>{c} frames · 24 FPS · {c/24:.2f} seconds</p></article>' for n,c in [('Player_Idle',48),('Player_Walk',32),('Player_Run',24)])
(OUT/'movement_preview.html').write_text('<!doctype html><html><meta charset="utf-8"><title>Player movement foundation</title><style>body{background:#182028;color:#e4edef;font:16px system-ui;margin:40px}h1{font-size:24px}main{display:flex;flex-wrap:wrap;gap:20px}article{background:#202c35;padding:20px;border-radius:12px}h2{font-size:18px}img{width:384px;height:384px}p{color:#a7bac5}</style><h1>Original cuboid movement · 24 FPS</h1><main>'+cards+'</main><p>In-place loops. APNGs preserve transparency. The closing key is excluded from playback.</p></html>',encoding='utf-8')
print(json.dumps(report))
