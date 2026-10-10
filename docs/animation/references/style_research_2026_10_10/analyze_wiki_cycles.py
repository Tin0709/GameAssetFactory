"""Analyze reference GIF pixels only. Never produces game-ready animation data."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, math, shutil

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
FONT=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',15)
SOURCES={
 'run':Path('C:/Users/ADMIN/Downloads/Player_Master_Run_%28Dungeons_II%29.gif'),
 'walk':Path('C:/Users/ADMIN/Downloads/Player_Master_Walk_%28Dungeons_II%29.gif'),
 'jump':ROOT/'blender/animation/reviews/player_animation_library_v1/jump_dungeons_gif_v004/references/Player_Jump_(Dungeons_II).gif',
 'land':ROOT/'blender/animation/reviews/player_animation_library_v1/jump_dungeons_gif_v004/references/Player_Jump_Land_(Dungeons_II).gif'}
NAMES={'run':'Player_Master_Run','walk':'Player_Master_Walk','jump':'Player_Jump','land':'Player_Jump_Land'}
records=[]
for name,path in SOURCES.items():
    if name in ['run','walk']:
        dest=OUT/(name+'_reference.gif')
        if not dest.exists():shutil.copyfile(path,dest)
        path=dest
    im=Image.open(path)
    frames=[]; times=[]; ms=0
    for i in range(im.n_frames):
        im.seek(i); frame=im.convert('RGBA').copy()
        dur=im.info.get('duration',0)
        frames.append(frame);times.append({'frame':i,'start_ms':ms,'duration_ms':dur});ms+=dur
    bounds=[f.getbbox() for f in frames]
    crop=(min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds))
    cols=5;w=240;h=320
    canvas=Image.new('RGB',(cols*w,math.ceil(len(frames)/cols)*h),'#252a32')
    draw=ImageDraw.Draw(canvas)
    for i,(f,t) in enumerate(zip(frames,times)):
        f=f.crop(crop);f.thumbnail((w-16,h-45))
        x=i%cols*w;y=i//cols*h
        canvas.paste(f,(x+(w-f.width)//2,y+(h-40-f.height)//2),f)
        draw.text((x+7,y+h-33),f"f{i:02d} {t['start_ms']/1000:.3f}s",font=FONT,fill='white')
        draw.text((x+7,y+h-17),f"duration {t['duration_ms']}ms",font=FONT,fill='white')
    canvas.save(OUT/(name+'_cycle.jpg'),quality=95)
    records.append({'id':name,'source_file':path.relative_to(ROOT).as_posix(),
      'page_url':'https://minecraft.wiki/w/File:'+NAMES[name]+'_(Dungeons_II).gif',
      'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'dimensions':im.size,
      'duration_ms':ms,'frame_count':len(frames),'frames':times,'constant_crop_xyxy':crop,
      'sheet':name+'_cycle.jpg','timing_scope':'GIF display delays, not original engine key times',
      'rights':'Mojang imagery; reference analysis only, never runtime asset or keyframe source.'})
(OUT/'wiki_cycles.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps([{k:v for k,v in r.items() if k!='frames'} for r in records],indent=2))
