"""Timestamped comparison artifacts from decoded originals + 24 FPS Blender renders."""
import cv2,json,html
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;OUT=BASE/'reference_study_r1_review'
REF=BASE.parents[3]/'references/animation/minecraft_locomotion_reference/originals'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',13)
videos={}
for tag in ['093200','093249']:
    cap=cv2.VideoCapture(str(REF/('Screen Recording 2026-10-07 '+tag+'.mp4')));fs=[]
    while True:
        ok,f=cap.read()
        if not ok:break
        fs.append(Image.fromarray(cv2.cvtColor(f,cv2.COLOR_BGR2RGB)))
    cap.release();videos[tag]=fs
def panel(im,w=270,h=400):
    im=im.copy();im.thumbnail((w,h),Image.Resampling.LANCZOS)
    out=Image.new('RGB',(w,h),(29,34,40));out.paste(im,((w-im.width)//2,(h-im.height)//2));return out
def candidate(gait,view,i):
    return Image.open(OUT/(gait+'_'+view)/('%03d.png'%i)).convert('RGB')
def savevideo(frames,path,fps=24):
    # mp4v is a playable local fallback; GIF/HTML accompany it for broad support.
    import numpy as np
    wr=cv2.VideoWriter(str(path),cv2.VideoWriter_fourcc(*'mp4v'),fps,frames[0].size)
    assert wr.isOpened()
    for im in frames:wr.write(cv2.cvtColor(np.asarray(im),cv2.COLOR_RGB2BGR))
    wr.release()
def savegif(frames,path):
    # GIF ticks are 10ms: 40,40,50,40,40,40 = 250ms / 6 frames => exact mean 24fps.
    durations=[40,40,50,40,40,40]
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=[durations[i%6] for i in range(len(frames))],loop=0,optimize=False)

notes=[]
for gait,period,anchors in [('walk',16,{'front':25,'rear':65}),('sprint',13,{'front':90,'rear':205})]:
    for view in ['front','rear']:
        tag='093249' if view=='front' else '093200';start=anchors[view];frames=[]
        # Each take is independently anchored for similar arm presentation, not synchronized.
        for i in range(48):
            sf=start+round(i*30/24);ci=(i+(8 if gait=='walk' else 0))%period
            out=Image.new('RGB',(560,465),(20,25,31));d=ImageDraw.Draw(out)
            out.paste(panel(videos[tag][sf]),(5,40));out.paste(panel(candidate(gait,view,ci)),(285,40))
            d.text((10,6),gait.upper()+' | '+view+' take '+tag,font=font,fill='white')
            d.text((10,443),f'Reference f{sf} / {sf/30:.3f}s',font=small,fill='#dce4eb')
            d.text((290,443),f'Candidate f{ci+1} / t={i/24:.3f}s',font=small,fill='#dce4eb')
            frames.append(out)
        # Front Walk source window ends ~2.4s: only use 1.333s of this take.
        if gait=='walk' and view=='front':frames=frames[:32]
        stem=gait+'_'+view+'_comparison';savegif(frames,OUT/(stem+'.gif'));savevideo(frames,OUT/(stem+'.mp4'))
        chosen=[0,period//4,period//2,3*period//4]
        sheet=Image.new('RGB',(1120,930),(20,25,31))
        for j,i in enumerate(chosen):sheet.paste(frames[i],((j%2)*560,(j//2)*465))
        sheet.save(OUT/(stem+'_poses.jpg'),quality=94)
        notes.append({'gait':gait,'view':view,'source_take':tag,'start_source_frame':start,'preview_seconds':len(frames)/24,'candidate_period_frames':period,'candidate_start_frame':9 if gait=='walk' else 1,'source_sampling':'nearest 30 FPS frame at 24 FPS output, no intentional speed change'})

both=[]
for i in range(208):
    out=Image.new('RGB',(560,455),(20,25,31));d=ImageDraw.Draw(out)
    for x,gait,p in [(5,'walk',16),(285,'sprint',13)]:
        out.paste(panel(candidate(gait,'front',i%p)),(x,40));d.text((x+8,8),f'{gait.title()} | {p/24:.3f}s',font=font,fill='white')
    d.text((10,438),'24 FPS / 1.0x | independent cycles | in place',font=small,fill='white');both.append(out)
savegif(both,OUT/'walk_sprint_normal_speed.gif');savevideo(both,OUT/'walk_sprint_normal_speed.mp4')
(OUT/'comparison_metadata.json').write_text(json.dumps(notes,indent=2))
body='''<!doctype html><html><head><meta charset="utf-8"><title>R1 Walk + Sprint study</title><style>body{background:#121920;color:#e9eef3;font:16px system-ui;max-width:1200px;margin:32px auto;padding:20px}h1{font-size:28px}section{display:flex;flex-wrap:wrap;gap:20px}figure{margin:0 0 24px}img{max-width:100%;height:auto}figcaption{max-width:560px;padding:8px 0;color:#b8c7d6}button{padding:10px;cursor:pointer}a{color:#8fd0ff}</style></head><body><h1>R1 — Walk + Sprint / first-pass study</h1><p>Original motion on the existing rigid cuboid rig. Normal speed: 24 FPS, 1.0×. Source review used decoded frames, not observed continuous playback. The front and rear recordings are separate takes.</p><p><button onclick="document.querySelectorAll('img[data-anim]').forEach(i=>{let s=i.src;i.src='';i.src=s})">Restart animated comparisons</button></p><h2>Walk and Sprint</h2><figure><img data-anim src="walk_sprint_normal_speed.gif"><figcaption>Independent 0.667 s Walk and 0.542 s Sprint clocks. Endpoint keys retained; duplicate endpoints are excluded from playback.</figcaption></figure>'''
for gait in ['walk','sprint']:
    body+='<h2>'+gait.title()+' — reference / candidate</h2><section>'
    for view in ['front','rear']:
        stem=gait+'_'+view+'_comparison'
        body+=f'<figure><img data-anim src="{stem}.gif"><figcaption>{view.title()} take, independently anchored. Camera framing is approximate; no 3D measurement is implied. <a href="{stem}_poses.jpg">Timestamped pose sheet</a> · <a href="{stem}.mp4">MP4</a></figcaption></figure>'
    body+='</section>'
body+='<h2>Project gameplay scale</h2><img src="gameplay_scale.png"><p>Project elevated camera, 14.5 vertical units, 1280×720. Walk left; Sprint right.</p><p>Technical checks are not artistic approval. See R1_REPORT.txt for limitations, preservation and checks.</p></body></html>'
(OUT/'index.html').write_text(body,encoding='utf-8')
print('R1_PACKAGE_DONE')

