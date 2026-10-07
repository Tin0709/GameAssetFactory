import json,html
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;OUT=BASE/'turning_study_r3_review';meta=json.loads((OUT/'preview_metadata.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
manifest=[]
for stem,count in [('ab',456),('gameplay',456),('versions',208),('entry',48)]:
 folder=OUT/(stem+'_frames');folder.mkdir(exist_ok=True)
 for f in range(1,count+1):
  raw=Image.open(OUT/(stem+'_raw')/('%04d.png'%f)).convert('RGB');w,h=raw.size;im=Image.new('RGB',(w,h+64),'#111922');im.paste(raw,(0,0));d=ImageDraw.Draw(im)
  if stem in ['ab','gameplay']:
   row=meta['gaits']['Walk']['rows'][f-1];sp=meta['gaits']['Sprint']['rows'][f-1]
   d.text((16,h+5),f"{row['case']} | t={row['time']:.3f}s | local turn {row['signed_weight']:+.2f} | 24 FPS / 1.0x",font=font,fill='white')
   d.text((16,h+34),f"A: straight V2 + path    B: same clock/path + V2 turning | Walk phase {row['phase']:.2f} / Sprint phase {sp['phase']:.2f}",font=small,fill='#a7dfec')
  elif stem=='versions':
   for x,label in [(16,'Walk TurnLeft V1'),(336,'Walk TurnLeft V2'),(656,'Sprint TurnLeft V1'),(976,'Sprint TurnLeft V2')]:d.text((x,h+5),label,font=font,fill='white')
   d.text((16,h+34),f'24 FPS / 1.0x | independent gait periods | t={(f-1)/24:.3f}s | sustained local left',font=small,fill='#a7dfec')
  else:
   for x,label in [(210,'Entry 0%'),(466,'Entry 25%'),(722,'Entry 50%'),(978,'Entry 75%')]:d.text((x,h+5),label,font=font,fill='white')
   d.text((16,h+34),f'Walk upper / Sprint lower | local left | entry .25s, full .65s, exit 1.10-1.50s | t={(f-1)/24:.3f}s',font=small,fill='#a7dfec')
  im.save(folder/('%04d.png'%f))
 manifest.append({'stem':stem,'folder':folder.name,'frames':count,'size':[w,h+64],'fps':24})
 Image.open(folder/('%04d.png'%(289 if count==456 else 19))).save(OUT/(stem+'_poster.jpg'),quality=94)
# Midpoint evidence: three transition rows, all three requested weights.
for gait in ['Walk','Sprint']:
 for phi in [0,.25]:
  sheet=Image.new('RGB',(960,1464),'#111922');d=ImageDraw.Draw(sheet)
  for j,label in enumerate(['StraightLeft','StraightRight','LeftRight']):
   for i,w in enumerate([.25,.5,.75]):
    x=i*320;y=j*488;sheet.paste(Image.open(OUT/'midpoints'/(gait+'_'+label+'_'+str(phi)+'_'+str(w)+'.png')),(x,y+42));d.text((x+8,y+7),f'{label} {w:.0%}',font=font,fill='white')
  sheet.save(OUT/(gait.lower()+'_midpoints_'+str(phi)+'.jpg'),quality=94)
# Four views of the same continuous circle: shared crop per A/B pair.
for gait,row in [('Walk',0),('Sprint',1)]:
 sheet=Image.new('RGB',(1280,1100),'#111922');d=ImageDraw.Draw(sheet)
 for j,f in enumerate([265,289,313,337,373,397,421,445]):
  im=Image.open(OUT/'ab_raw'/('%04d.png'%f));crop=im.crop((0,row*500,1280,(row+1)*500));crop.thumbnail((640,250))
  x=(j%2)*640;y=(j//2)*275;sheet.paste(crop,(x,y+25));rr=meta['gaits'][gait]['rows'][f-1];d.text((x+8,y+3),f"{gait} {rr['case']} t={rr['time']:.2f}s phase={rr['phase']:.2f} | A / B",font=small,fill='white')
 sheet.save(OUT/(gait.lower()+'_circle_sequence.jpg'),quality=94)
(OUT/'video_manifest.json').write_text(json.dumps(manifest,indent=2))
def video(stem,caption):return f'<figure><video controls loop playsinline preload="metadata" src="{stem}.mp4" poster="{stem}_poster.jpg"></video><figcaption>{caption}</figcaption></figure>'
page='''<!doctype html><html><head><meta charset="utf-8"><title>R3-T | Turning V2 rebase</title><style>body{max-width:1300px;margin:30px auto;padding:24px;background:#111922;color:#e5eef5;font:16px system-ui;line-height:1.55}h1{font-size:32px}h2{margin-top:40px}video,img{max-width:100%}video{max-height:85vh}a{color:#8ad7ee}figure{margin:20px 0}figcaption{color:#b9cbd9}button{margin:4px;padding:10px;border:0;background:#294959;color:white;cursor:pointer}.grid{display:flex;flex-wrap:wrap;gap:20px}.grid>div{flex:1;min-width:330px}details{margin:20px 0}</style></head><body><h1>R3-T — Turning V2, first pass</h1><p>Four sustained turns rebased directly onto the approved straight V2 gaits. Walk: 0.666667 s. Sprint: 0.541667 s. All previews 24 FPS / 1.0×; no 1.60 multiplier. Technical checks are not artistic approval.</p><p><a href="R3_REPORT.txt">Full report</a> · <a href="validation.json">Action / midpoint checks</a> · <a href="preview_validation.json">Path, entry and sliding checks</a></p><p>Review normal speed first. The assistant inspected ordered images and numerical traces; continuous real-time playback was not directly observed.</p>'''
page+=video('ab','Walk upper row; Sprint lower. A left = V2 gait + path/heading. B right = same path/clock + V2 turning blend. Fixed world camera; deliberate cuts between five independent paths. Circle exits include recovery to straight.')
for case in meta['cases']:page+=f'<button onclick="let v=document.querySelector(\'video\');v.currentTime={case["start_seconds"]};v.playbackRate=1;v.play()">{html.escape(case["name"])}</button>'
page+='<h2>Turning V1 / V2</h2>'+video('versions','Left-to-right: Walk V1 / V2, Sprint V1 / V2. Front-like camera; same period and normalized phase within each gait. V2 retains its deeper recovery and stronger forward arm.')
page+='<h2>Four turn-entry phases</h2>'+video('entry','Each column enters at the named normalized phase at t=.25s. Gait clocks keep running through entry, hold and recovery. Both signs also passed numerical entry checks.')
page+='<h2>Project gameplay camera</h2>'+video('gameplay','Fixed project camera orientation; 14.5 vertical units at 1280×720 before the caption band. Same world tracks as the A/B reel. Inspect at 100% scale.')
page+='<h2>Supplied turning reference</h2><div class="grid"><div><video controls preload="metadata" src="../../../../../references/animation/minecraft_turning_reference/originals/Screen%20Recording%202026-10-07%20102829.mp4"></video><p>Original 30 FPS recording. Not time-synchronized to our test paths. Useful windows: 1.267–1.733s Walk entry; 8.333–8.833s Sprint entry; 14–15.9s circles; 17.6–18.233s recovery/deceleration.</p></div><div><img src="source_fullframe_evidence.jpg"><p>Full-frame context. Source camera, inputs, rig topology and turn angles are not calibrated. The blend architecture is our implementation choice.</p></div></div>'
page+='<h2>Frame diagnosis</h2>'
for gait in ['walk','sprint']:
 page+=f'<details><summary>{gait.title()}: circle directions and blend midpoints</summary><img src="{gait}_detail_sequence.jpg"><p>Detail crops share scale within each A/B pair; use the movie to judge travel.</p><img src="{gait}_circle_sequence.jpg"><p>Columns below: 25%, 50%, 75%. Rows: Straight→Left, Straight→Right, Left→Right.</p>'
 for phi in [0,.25]:page+=f'<p>Gait phase {phi:.0%}</p><img src="{gait}_midpoints_{phi}.jpg">'
 page+='</details>'
page+='<p>Remaining limits: visible sliding on the tight preview circles, a rigid straight recovery segment in side view, and limited head counter-bank at the cuboid neck seam. See the report for exact poses and measurements. No rig redesign or gameplay integration.</p></body></html>'
(OUT/'index.html').write_text(page,encoding='utf-8');print('R3_PACKAGE_DONE',flush=True)
