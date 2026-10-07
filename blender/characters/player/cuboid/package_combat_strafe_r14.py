"""Package actual Blender renders; decode and inspect video metadata."""
from pathlib import Path
import json,cv2,math
from PIL import Image,ImageDraw
BASE=Path(__file__).resolve().parent;OUT=BASE/'combat_strafe_r14_review'
checks={}
for p in sorted(OUT.glob('*.mp4')):
    cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);n=0
    while True:
        ok,img=cap.read()
        if not ok:break
        n+=1
    cap.release();checks[p.name]={'decoded_frames':n,'fps':fps,'bytes':p.stat().st_size}
    assert fps==24 and n==(268 if p.name.startswith('D_') else 80),(p.name,n,fps)
(OUT/'video_validation.json').write_text(json.dumps(checks,indent=2))
# Fresh contact sheet from video frames, same visible camera and no enemy occlusion.
sheet=Image.new('RGB',(7*280,2*300),(17,22,31));draw=ImageDraw.Draw(sheet)
for row,c in enumerate(['B','C']):
    cap=cv2.VideoCapture(str(OUT/f'{c}_Front.mp4'))
    for col,f in enumerate([1,4,8,11,14,18,20]):
        cap.set(cv2.CAP_PROP_POS_FRAMES,f-1);ok,im=cap.read();assert ok
        im=Image.fromarray(cv2.cvtColor(im,cv2.COLOR_BGR2RGB));im=im.resize((360,270));im=im.crop((40,0,320,270));sheet.paste(im,(col*280,row*300));draw.text((col*280+10,row*300+275),f'{"RIGHT" if c=="B" else "LEFT"} / frame {f}',fill='white')
    cap.release()
sheet.save(OUT/'contact_sheet.png')
if (OUT/'D_ThreeQuarter.mp4').exists():
    sheet=Image.new('RGB',(5*320,3*265),(17,22,31));draw=ImageDraw.Draw(sheet);cap=cv2.VideoCapture(str(OUT/'D_ThreeQuarter.mp4'))
    for i,f in enumerate([1,30,51,70,83,100,107,120,140,167,187,198,212,235,268]):
        cap.set(cv2.CAP_PROP_POS_FRAMES,f-1);ok,im=cap.read();assert ok
        im=Image.fromarray(cv2.cvtColor(im,cv2.COLOR_BGR2RGB)).resize((320,240));sheet.paste(im,((i%5)*320,(i//5)*265));draw.text(((i%5)*320+8,(i//5)*265+243),f'Frame {f}',fill='white')
    cap.release();sheet.save(OUT/'sequence_sheet.png')

v=json.loads((OUT/'validation.json').read_text())
for case in ['B','C']:
    rows=json.loads((OUT/f'measurements_{case}.json').read_text());xy=[];xr=[]
    for n in ['Leg.L','Leg.R']:
        lead=(n=='Leg.R')==(case=='B');lo,hi=(8,21) if lead else (1,11)
        vs=[r['feet'][n]['center'] for r in rows if lo<=r['frame']<=hi]
        xy.append(max(math.dist(p[:2],vs[0][:2]) for p in vs));xr.append(max(p[0] for p in vs)-min(p[0] for p in vs))
    v['cases'][case]['support_horizontal_drift_m']=max(xy);v['cases'][case]['support_travel_axis_range_m']=max(xr)
(OUT/'validation.json').write_text(json.dumps(v,indent=2))

html='''<!doctype html><meta charset="utf-8"><title>R14 · Combat strafe V1</title>
<style>body{margin:0;background:#101721;color:#edf2f7;font:16px system-ui}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:32px;margin:0 0 12px}p{color:#b9c7d7;line-height:1.55}button,select,a.button{background:#24374d;color:white;border:1px solid #4a6480;border-radius:6px;padding:10px 16px;margin:4px;text-decoration:none;cursor:pointer}.row{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}article{background:#192431;border-radius:10px;padding:12px}video{width:100%;background:#0a1018}h2{font-size:19px}strong{color:#8bdfcf}.badge{display:inline-block;padding:6px 10px;background:#493a19;color:#ffe1a1;border-radius:5px}.wide{max-width:980px}img{width:100%}table{border-collapse:collapse}td,th{padding:9px 18px;border-bottom:1px solid #394555;text-align:left}a{color:#a4dbff}@media(max-width:900px){.row{grid-template-columns:1fr}}</style>
<main><span class="badge">ARTISTIC STATUS: AWAITING HUMAN REVIEW</span><h1>R14 · Combat strafing</h1>
<p>20-frame shuffle · 24 FPS · 0.833 seconds · unchanged rifle-ready arm/weapon pose.<br>Character right is screen-left in the front view. The orange enemy marker is visible in the elevated view.</p>
<select id="view"><option value="Gameplay">Elevated gameplay</option><option value="ThreeQuarter">Front three-quarter</option><option value="Front">Front</option><option value="Side">Side</option></select>
<button onclick="playAll()">Restart and play A/B/C</button><button onclick="document.querySelectorAll('.compare').forEach(v=>v.pause())">Pause all</button>
<div class="row">'''
for c,title,caption in [('A','A · Existing walk, travelling sideways','Original Walk lower-body pose at its native cadence.'),('B','B · Combat Strafe Right','RIGHT leads → LEFT follows.'),('C','C · Combat Strafe Left','LEFT leads → RIGHT follows.')]:
    html+=f'<article><h2>{title}</h2><video class="compare" data-case="{c}" controls muted playsinline preload="metadata" src="{c}_Gameplay.mp4" poster="{c}_Gameplay.png"></video><p>{caption}</p></article>'
html+='''</div><p>All three parents travel at 0.192 m/s. Each clip contains 80 frames. Replay resets the finite travel path; the authored leg cycles themselves are seamless.</p>
<h2>Continuous · Right → Stop → Left → Right</h2><p>24 FPS / 11.17 seconds. Gait phase and parent speed ease together; the reversal brakes through double support. No instantaneous direction switch.</p>
<select id="seqview"><option value="Gameplay">Elevated gameplay</option><option value="ThreeQuarter">Front three-quarter</option></select><br>
<video id="sequence" class="wide" controls muted playsinline preload="metadata" src="D_Gameplay.mp4" poster="D_Gameplay.png"></video>
<h2>Measured motion</h2><table><tr><th>Check</th><th>Right</th><th>Left</th></tr><tr><td>Maximum torso/Hips relative yaw</td><td>1.300°</td><td>1.300°</td></tr><tr><td>Lead / trailing swing</td><td>R: 1–8 / L: 11–18</td><td>L: 1–8 / R: 11–18</td></tr><tr><td>Hips bounce / lateral shift</td><td>14 mm / ±10 mm</td><td>14 mm / ±10 mm</td></tr><tr><td>Minimum floor clearance</td><td>2.87 mm</td><td>2.87 mm</td></tr></table>
<p>The continuous sequence also remains under 1.300° relative yaw. Checks sample every 1/8 frame, including blends. Hips yaw is ±2°; inherited chest yaw stays within ±0.959°. The Spine supplies a small eased counterbalance. Head and weapon retain the ready pose.</p>
<p><strong>Rig limitation:</strong> rigid single-bone legs cannot flex knees or articulate soles. The study uses small FK leg translations (up to 36.7 mm), allowing minor hip seam changes. Lateral planted-foot drift is under 0.08 mm; forward/back sole drift reaches 13.6 mm as the rigid legs turn. Foot clearance peaks at 41 mm. These are study compromises for human review, not artistic approval.</p>
<h2>Foot sequence</h2><img src="contact_sheet.png"><h2>Stop and reversal samples</h2><img src="sequence_sheet.png">
<p><a href="REPORT.md">Full report</a> · <a href="validation.json">Numerical validation</a> · <a href="video_validation.json">Video decode checks</a></p>
<script>const vs=[...document.querySelectorAll('.compare')];function playAll(){vs.forEach(v=>{v.currentTime=0;v.playbackRate=1;v.play()})}document.querySelector('#view').onchange=e=>{vs.forEach(v=>{v.pause();v.src=v.dataset.case+'_'+e.target.value+'.mp4';v.poster=v.dataset.case+'_'+e.target.value+'.png';v.load()})};document.querySelector('#seqview').onchange=e=>{const v=document.querySelector('#sequence');v.src='D_'+e.target.value+'.mp4';v.poster='D_'+e.target.value+'.png';v.load()};</script></main>'''
(OUT/'index.html').write_text(html,encoding='utf-8')
print(json.dumps(checks,indent=2))
