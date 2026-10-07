"""Local human-review showcase from native Blender renders; full media decode."""
from pathlib import Path
import json,hashlib,argparse
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory');BASE=ROOT/'blender/characters/player/cuboid';OUT=BASE/'weapon_hold_r10wh2_review'
CATS=['Pistol','Rifle','Shotgun'];MODES={'Hold':96,'Move':64,'AimAround':288,'Turn':456,'Sprint':208}
EXPECTED={c+'_'+m:n for c in CATS for m,n in MODES.items()};EXPECTED.update(Showcase_Hold=96,Showcase_AimAround=288)
FONT=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22);SMALL=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
def boards():
    files=[]
    for cat in CATS:
        for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
            im=Image.new('RGB',(1440,3408),'#111c25');d=ImageDraw.Draw(im);d.text((16,10),f'R10-WH2 / {cat} / {mode} / frame {f}',font=FONT,fill='white');d.text((16,45),'A — approved WH1',font=SMALL,fill='white');d.text((736,45),'B — refined elbow fold',font=SMALL,fill='white')
            for i,view in enumerate(['Front','FrontThreeQuarter','SupportThreeQuarter','Side','Rear']):
                y=100+i*660
                for j,tag in enumerate(['A','B']):im.paste(Image.open(OUT/f'{cat}_{mode}_f{f}_{tag}_{view}.png').convert('RGB').resize((720,630)),(j*720,y))
                d.text((16,y+632),view,font=SMALL,fill='white')
            name=f'{cat}_{mode}_f{f}_views_AB.jpg';im.save(OUT/name,quality=92);files.append(name)
    # Compact three-class A/B overview, with matching 3/4 cameras.
    im=Image.new('RGB',(1440,2070),'#111c25');d=ImageDraw.Draw(im);d.text((16,10),'R10-WH2 — elbow fold / all three weapons',font=FONT,fill='white')
    d.text((16,45),'A — approved WH1',font=SMALL,fill='white');d.text((736,45),'B — refined fold',font=SMALL,fill='white')
    for i,cat in enumerate(CATS):
        y=100+i*650
        for j,tag in enumerate(['A','B']):im.paste(Image.open(OUT/f'{cat}_Hold_f25_{tag}_FrontThreeQuarter.png').convert('RGB').resize((720,630)),(j*720,y))
        d.text((16,y+631),cat,font=SMALL,fill='white')
    im.save(OUT/'ThreeWeapon_Elbow_AB.jpg',quality=92);return files
def media():
    import cv2
    rows={}
    for job,count in EXPECTED.items():
        p=OUT/(job+'_24fps.mp4');cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);meta=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));decoded=0;frames={}
        wanted=[1,25,49,109,193,301,409,456] if job.endswith('Turn') else [1,49,73,145,217,288] if job.endswith('AimAround') else [1,9,17,33,49,64] if job.endswith('Move') else [1,14,52,104,156,208] if job.endswith('Sprint') else [1,17,33,49,73,96]
        while True:
            ok,frame=cap.read()
            if not ok:break
            decoded+=1
            if decoded in wanted:frames[decoded]=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
        cap.release();assert decoded==count and meta==count and abs(fps-24)<1e-4 and len(frames)==len(wanted),(job,decoded,meta,fps)
        sheet=Image.new('RGB',(1920,64+478*((len(wanted)+1)//2)),'#111c25');d=ImageDraw.Draw(sheet);d.text((16,12),job+' — chronological frames',font=FONT,fill='white')
        for i,f in enumerate(wanted):
            x=(i%2)*960;y=64+(i//2)*478;sheet.paste(frames[f].resize((960,450)),(x,y));d.text((x+12,y+451),f'frame {f} / {(f-1)/24:.3f}s',font=SMALL,fill='white')
        sheet.save(OUT/(job+'_ordered.jpg'),quality=92);rows[job]={'file':p.name,'fps':fps,'decoded_frames':decoded,'metadata_frames':meta,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'loop':not job.endswith(('Turn','Sprint'))}
    result={'passed':True,'required_movies':len(EXPECTED),'movies':rows};(OUT/'media_validation.json').write_text(json.dumps(result,indent=2));return result
def preserve():
    baseline=json.loads((OUT/'protected_files.json').read_text());changed=[];missing=[]
    for n,h in baseline.items():
        p=ROOT/n
        if not p.is_file():missing.append(n)
        elif hashlib.sha256(p.read_bytes()).hexdigest()!=h:changed.append(n)
    result={'passed':not changed and not missing,'checked_files':len(baseline),'changed':changed,'missing':missing};(OUT/'file_preservation.json').write_text(json.dumps(result,indent=2));assert result['passed'],result;return result
def page():
    cards=''.join(f'<article><div class="cardtop"><span class="index">0{i+1}</span><h3>{"Rifle / M4" if c=="Rifle" else c}</h3></div><a class="poseLink" href="{c}_Hold_f25_B_FrontThreeQuarter.png"><img class="pose" data-cat="{c}" src="{c}_Hold_f25_B_FrontThreeQuarter.png" alt="{c} refined hold"></a><p class="caption">WH2 · refined elbow fold</p></article>' for i,c in enumerate(CATS))
    doc='''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>R10-WH2 — Weapon hold showcase</title><style>
:root{color-scheme:dark;--ink:#e7edf3;--muted:#aebbc8;--panel:#1b2936;--line:#344553;--accent:#8edbd4}*{box-sizing:border-box}body{margin:0;background:#101b25;color:var(--ink);font:17px/1.5 'Segoe UI',Arial,sans-serif}main{max-width:1440px;margin:auto;padding:36px 28px 64px}header{margin-bottom:24px}.eyebrow{letter-spacing:.15em;color:var(--accent);font-size:13px}h1{font-size:42px;line-height:1.15;margin:10px 0 14px}h2{font-size:25px;margin:0 0 14px}h3{font-size:21px;margin:0}p{color:var(--muted);max-width:950px}.badge{display:inline-block;border:1px solid #8f7640;border-radius:30px;padding:5px 13px;color:#e8cf92;font-size:13px}.section{margin-top:40px}button,a{font:inherit}button{border:1px solid var(--line);border-radius:7px;color:var(--ink);background:#172532;padding:8px 14px;cursor:pointer}button:hover,button.active{border-color:var(--accent);background:#27423f;color:#e1fffb}.tools{display:flex;flex-wrap:wrap;gap:8px;margin:15px 0}.group{display:flex;gap:7px;flex-wrap:wrap;margin-right:18px}.hero{background:var(--panel);border:1px solid var(--line);border-radius:12px;overflow:hidden}video,img{display:block;max-width:100%;width:100%}.herotext{padding:16px 22px;display:flex;justify-content:space-between;gap:14px;color:var(--muted);font-size:14px}.gallery{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}.gallery article{border:1px solid var(--line);border-radius:10px;background:var(--panel);overflow:hidden}.cardtop{display:flex;align-items:center;gap:12px;padding:15px 18px}.index{font-size:13px;color:var(--accent)}.caption{margin:12px 18px;font-size:14px}.compare{border:1px solid var(--line);border-radius:10px;overflow:hidden}.compareNote{padding:12px 20px;font-size:14px;color:var(--muted)}a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}footer{margin-top:40px;border-top:1px solid var(--line);padding-top:24px;font-size:14px}footer a{margin-right:22px}@media(max-width:850px){main{padding:24px 16px}h1{font-size:32px}.gallery{grid-template-columns:1fr}.herotext{display:block}}
</style></head><body><main><header><div class="eyebrow">R10 / WH2 · ART REVIEW</div><h1>Weapon hold showcase</h1><p>Clear upward elbow folds, with the approved right-hand ownership, light left support and right-eye relationship. Pistol, rifle/M4 and shotgun share the same direction.</p><span class="badge">Study only · awaiting human review</span></header>
<div class="hero"><video id="showcase" controls muted loop preload="metadata" poster="Showcase_Hold_f25.png" src="Showcase_Hold_24fps.mp4"></video><div class="herotext"><span>PISTOL → RIFLE / M4 → SHOTGUN</span><span id="heroNote">Living ready hold · 4 seconds</span></div></div><div class="tools"><button class="active" data-show="Hold">Living hold</button><button data-show="AimAround">Aim-around</button><a style="padding:8px" href="Showcase_Hold_f25.png">Stable three-weapon pose</a></div>
<section class="section"><h2>Shape & silhouette</h2><p>Choose an angle or switch to the approved pose. Click a character to inspect the full render.</p><div class="tools"><div class="group" id="angleButtons"><button class="active" data-angle="FrontThreeQuarter">Front 3/4</button><button data-angle="SupportThreeQuarter">Support 3/4</button><button data-angle="Side">Side</button><button data-angle="Front">Front</button><button data-angle="Rear">Rear</button></div><div class="group" id="versionButtons"><button class="active" data-version="B">WH2 refined</button><button data-version="A">WH1 approved</button></div></div><div class="gallery">'''+cards+'''</div></section>
<section class="section"><h2>A/B in motion</h2><p>A is the approved WH1 hold. B refines the elbow fold. Both use the same weapon placement, head motion and lower-body phase.</p><div class="tools"><div class="group" id="classButtons"><button class="active" data-class="Pistol">Pistol</button><button data-class="Rifle">Rifle / M4</button><button data-class="Shotgun">Shotgun</button></div><div class="group" id="modeButtons"><button class="active" data-mode="Hold">Ready</button><button data-mode="AimAround">Look-around</button><button data-mode="Move">Walk</button><button data-mode="Turn">Turning</button><button data-mode="Sprint">Sprint</button></div></div><div class="compare"><video id="comparison" controls muted loop preload="metadata" src="Pistol_Hold_24fps.mp4"></video><div class="compareNote" id="compareNote">A approved WH1 · left / B refined elbow fold · right</div></div><p><a id="boardLink" href="Pistol_Hold_f25_views_AB.jpg">Matched multi-view A/B board</a> · <a id="sheetLink" href="Pistol_Hold_ordered.jpg">Chronological motion frames</a></p></section>
<footer><a href="ThreeWeapon_Elbow_AB.jpg">Three-weapon A/B overview</a><a href="R10WH2_REPORT.txt">Study notes</a><a href="../player_weapon_hold_r10wh2_study.blend">Blender study</a><p>Existing models, rig and locomotion are preserved. This pass changes the arm poses. Visual approval is pending before production migration.</p></footer></main><script>
let angle='FrontThreeQuarter',version='B',weapon='Pistol',mode='Hold';
function mark(group,button){group.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b===button));}
function poses(){document.querySelectorAll('.pose').forEach(im=>{const src=im.dataset.cat+'_Hold_f25_'+version+'_'+angle+'.png';im.src=src;im.closest('a').href=src;im.closest('article').querySelector('.caption').textContent=version==='B'?'WH2 · refined elbow fold':'WH1 · approved base';});}
document.querySelectorAll('[data-angle]').forEach(b=>b.onclick=()=>{angle=b.dataset.angle;mark(document.getElementById('angleButtons'),b);poses();});
document.querySelectorAll('[data-version]').forEach(b=>b.onclick=()=>{version=b.dataset.version;mark(document.getElementById('versionButtons'),b);poses();});
document.querySelectorAll('[data-show]').forEach(b=>b.onclick=()=>{const v=document.getElementById('showcase');v.pause();v.src='Showcase_'+b.dataset.show+'_24fps.mp4';v.poster=b.dataset.show==='Hold'?'Showcase_Hold_f25.png':'Showcase_AimAround_f73.png';v.load();document.querySelectorAll('[data-show]').forEach(x=>x.classList.toggle('active',x===b));document.getElementById('heroNote').textContent=b.dataset.show==='Hold'?'Living ready hold · 4 seconds':'Continuous left/right scan · 12 seconds';});
function comparison(){const v=document.getElementById('comparison');v.pause();v.src=weapon+'_'+mode+'_24fps.mp4';v.loop=!['Turn','Sprint'].includes(mode);v.load();document.getElementById('compareNote').textContent='A approved WH1 · left / B refined elbow fold · right'+(mode==='Turn'?' · original path-case cuts; not a loop':mode==='Sprint'?' · 208-frame excerpt; not a loop':'');document.getElementById('boardLink').href=weapon+'_'+(mode==='AimAround'?'AimAround_f73':'Hold_f25')+'_views_AB.jpg';document.getElementById('sheetLink').href=weapon+'_'+mode+'_ordered.jpg';}
document.querySelectorAll('[data-class]').forEach(b=>b.onclick=()=>{weapon=b.dataset.class;mark(document.getElementById('classButtons'),b);comparison();});document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;mark(document.getElementById('modeButtons'),b);comparison();});
</script></body></html>'''
    (OUT/'index.html').write_text(doc,encoding='utf-8')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--stills-only',action='store_true');args=parser.parse_args();b=boards();page()
    if args.stills_only:print(json.dumps({'boards':len(b),'page':True}))
    else:m=media();p=preserve();print(json.dumps({'movies':len(m['movies']),'boards':len(b),'preservation':p}))
