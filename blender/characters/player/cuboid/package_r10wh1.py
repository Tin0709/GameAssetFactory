"""Real Blender evidence, explicit movie inventory, full decode and file hashes."""
from pathlib import Path
import argparse,hashlib,json,html
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory');BASE=ROOT/'blender/characters/player/cuboid';OUT=BASE/'weapon_hold_r10wh1_review'
CATS=['Rifle','Shotgun','Pistol'];EXPECTED={c+'_'+m:n for c in CATS for m,n in [('Hold',96),('Move',64),('AimAround',288),('Turn',456),('Sprint',208)]}
FONT=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22);SMALL=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
def stills():
    names=[]
    for c in CATS:
        for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
            im=Image.new('RGB',(1440,2748),'#111c25');d=ImageDraw.Draw(im);d.text((16,10),f'R10-WH1 / {c} / {mode} / frame {f}',font=FONT,fill='white');d.text((16,45),'A — current R9-W4',font=SMALL,fill='white');d.text((736,45),'B — CHARACTER RIGHT primary / LEFT light support',font=SMALL,fill='white')
            for i,view in enumerate(['Front','FrontThreeQuarter','Side','Rear']):
                y=100+i*660
                for j,label in enumerate(['A','B']):im.paste(Image.open(OUT/f'{c}_{mode}_f{f}_{label}_{view}.png').convert('RGB').resize((720,630)),(j*720,y))
                d.text((16,y+632),view,font=SMALL,fill='white')
            name=f'{c}_{mode}_f{f}_views_AB.jpg';im.save(OUT/name,quality=92);names.append(name)
    return names
def media():
    import cv2
    rows={}
    for job,count in EXPECTED.items():
        p=OUT/(job+'_AB_24fps.mp4');cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);meta_count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));decoded=0;frames={}
        wanted=[1,25,49,73,109,145,193,241,301,349,409,456] if job.endswith('_Turn') else [1,49,73,145,217,288] if job.endswith('_AimAround') else [1,9,17,33,49,64] if job.endswith('_Move') else [1,14,52,104,156,208] if job.endswith('_Sprint') else [1,17,33,49,73,96]
        while True:
            ok,frame=cap.read()
            if not ok:break
            decoded+=1
            if decoded in wanted:frames[decoded]=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
        cap.release();assert decoded==count and meta_count==count and abs(fps-24)<1e-4 and len(frames)==len(wanted),(job,decoded,meta_count,fps)
        sheet=Image.new('RGB',(1920,64+478*((len(wanted)+1)//2)),'#111c25');d=ImageDraw.Draw(sheet);d.text((16,12),job+' — chronological A/B frames (A left / B right)',font=FONT,fill='white')
        for i,f in enumerate(wanted):
            x=(i%2)*960;y=64+(i//2)*478;sheet.paste(frames[f].resize((960,450)),(x,y));d.text((x+12,y+451),f'frame {f} / {(f-1)/24:.3f}s',font=SMALL,fill='white')
        sheet.save(OUT/(job+'_ordered_AB.jpg'),quality=92);rows[job]={'file':p.name,'fps':fps,'decoded_frames':decoded,'metadata_frames':meta_count,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'loop':not job.endswith(('_Sprint','_Turn'))}
    context={}
    for cat in CATS:
        p=OUT/(cat+'_Turn_context_AB_24fps.mp4');cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);decoded=0
        while True:
            ok,frame=cap.read()
            if not ok:break
            decoded+=1
        cap.release();assert decoded==456 and abs(fps-24)<1e-4,(p.name,decoded,fps)
        context[cat]={'file':p.name,'fps':fps,'decoded_frames':decoded,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    result={'passed':True,'required_movies':len(EXPECTED),'movies':rows,'context_movies':context};(OUT/'media_validation.json').write_text(json.dumps(result,indent=2));return result
def preserve():
    baseline=json.loads((OUT/'protected_files.json').read_text());changed=[];missing=[]
    for name,expected in baseline.items():
        p=ROOT/name
        if not p.is_file():missing.append(name)
        elif hashlib.sha256(p.read_bytes()).hexdigest()!=expected:changed.append(name)
    result={'passed':not changed and not missing,'checked_files':len(baseline),'changed':changed,'missing':missing};(OUT/'file_preservation.json').write_text(json.dumps(result,indent=2));assert result['passed'],result;return result
def page(movies):
    body=[]
    for c in CATS:
        body.append(f'<section id="{c}"><h2>{c}</h2><p>A: exact R9-W4 result. B: new character-right ownership, left light support and right-eye sight relationship.</p>')
        for mode in ['Hold','Move','AimAround','Turn','Sprint']:
            job=c+'_'+mode;row=movies['movies'][job];loop=' loop' if row['loop'] else '';note=' — original path-case cuts; not a loop' if mode=='Turn' else ' — 208-frame excerpt; full Blender loop is 832 frames' if mode=='Sprint' else ''
            body.append(f'<h3>{mode}{note}</h3><video controls muted preload="metadata"{loop} src="{row["file"]}"></video><p><a href="{job}_ordered_AB.jpg">Chronological frames</a></p>')
            if mode=='Turn':body.append(f'<details><summary>Wide trajectory context</summary><video controls muted preload="metadata" src="{c}_Turn_context_AB_24fps.mp4"></video></details>')
        for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
            name=f'{c}_{mode}_f{f}_views_AB.jpg';body.append(f'<details><summary>{mode} f{f}: front / front 3/4 / side / rear</summary><a href="{name}"><img loading="lazy" src="{name}"></a></details>')
        body.append('</section>')
    p='''<!doctype html><html><head><meta charset="utf-8"><title>R10-WH1 Weapon Hold Review</title><style>body{font:17px Arial;background:#111c25;color:#e7edf4;max-width:1400px;margin:24px auto;padding:0 20px}a{color:#8bcaff}nav{background:#1b2b39;padding:16px;position:sticky;top:0;z-index:3}nav a{margin-right:24px}section{border-top:1px solid #3a4d60;margin-top:32px;padding-top:16px}video,img{width:100%}p{line-height:1.5}summary{cursor:pointer;padding:14px}.status{color:#f8d27c}</style></head><body><h1>R10-WH1 — Right-hand firearm hold</h1><p class="status">ARTISTIC STATUS: AWAITING HUMAN REVIEW • STUDY ONLY</p><p>The character's RIGHT arm owns the gun. In the neutral front view that is screen-left. The LEFT arm crosses the body for a shallow supporting touch. The right-eye relationship and head lean remain through living motion.</p><nav><a href="#Rifle">Rifle first</a><a href="#Shotgun">Shotgun</a><a href="#Pistol">Pistol</a><a href="R10WH1_REPORT.txt">Report</a></nav><p>Judge ownership, weight, support softness and motion by viewing the clips. Geometry tests cannot establish artistic approval. Current locomotion is preserved; no production migration.</p>'''+''.join(body)+'<p>Primary references: <a href="reference_1.webp">reference 1</a> / <a href="reference_2.jpg">reference 2</a>.</p></body></html>'
    (OUT/'index.html').write_text(p,encoding='utf-8')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--stills-only',action='store_true');args=parser.parse_args();boards=stills()
    if args.stills_only:print(json.dumps({'boards':len(boards)}))
    else:
        movies=media();protection=preserve();page(movies);print(json.dumps({'movies':len(movies['movies']),'boards':len(boards),'preservation':protection}))
