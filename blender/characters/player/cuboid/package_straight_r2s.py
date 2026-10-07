"""Read originals and fresh renders; package normal-speed evidence without retiming."""
import cv2,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;OUT=BASE/'straight_study_r2s_review';REF=BASE.parents[3]/'references/animation/minecraft_locomotion_reference'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
meta=json.loads((REF/'notes/reference_metadata.json').read_text());videos={}
for tag in ['093200','093249']:
 path=REF/'originals'/meta[tag]['file'];assert hashlib.sha256(path.read_bytes()).hexdigest()==meta['analysis']['source_sha256'][path.name]
 cap=cv2.VideoCapture(str(path));fs=[]
 while True:
  ok,f=cap.read()
  if not ok:break
  fs.append(Image.fromarray(cv2.cvtColor(f,cv2.COLOR_BGR2RGB)))
 assert len(fs)==meta[tag]['nframes'];cap.release();videos[tag]=fs
def panel(im,w=322,h=480):
 im=im.copy();im.thumbnail((w,h),Image.Resampling.LANCZOS);o=Image.new('RGB',(w,h),'#1a2027');o.paste(im,((w-im.width)//2,(h-im.height)//2));return o
cache={}
def candidate(g,v,view,i):
 k=(g,v,view,i)
 if k not in cache:cache[k]=Image.open(OUT/(g+'_'+v+'_'+view)/('%03d.png'%i)).convert('RGB')
 return cache[k]
manifest=[]
for gait,period,anchors in [('walk',16,{'front':25,'rear':65}),('sprint',13,{'front':90,'rear':205})]:
 for view in ['front','rear','gameclose']:
  sourceview='front' if view=='gameclose' else view;tag='093249' if sourceview=='front' else '093200';start=anchors[sourceview];stem=gait+'_'+view;folder=OUT/(stem+'_frames');folder.mkdir(exist_ok=True);N=32 if gait=='walk' and sourceview=='front' else 48
  frames=[]
  for i in range(N):
   sf=start+round(i*30/24);ci=(i+(8 if gait=='walk' else 0))%period
   o=Image.new('RGB',(1002,554),'#111922');d=ImageDraw.Draw(o)
   for j,im in enumerate([videos[tag][sf],candidate(gait,'v1',view,ci),candidate(gait,'v2',view,ci)]):o.paste(panel(im),(j*334+6,44))
   d.text((12,10),gait.title()+' | Reference',font=font,fill='white');d.text((346,10),'V1',font=font,fill='white');d.text((680,10),'V2',font=font,fill='white')
   d.text((12,531),f'{sourceview} f{sf} / {sf/30:.3f}s',font=small,fill='white');d.text((346,531),f'f{ci+1} | 24 FPS / 1.0x',font=small,fill='white');d.text((680,531),f'f{ci+1} | '+('game angle, enlarged' if view=='gameclose' else view),font=small,fill='white')
   o.save(folder/('%04d.png'%(i+1)));frames.append(o)
  manifest.append({'stem':stem,'folder':folder.name,'frames':N,'size':[1002,554],'fps':24,'source_take':tag,'source_start':start,'candidate_start':9 if gait=='walk' else 1,'source_sampling':'nearest source 30 FPS at real-time 24 FPS output; no intentional speed change'})
  # Six consecutive output samples, including source timestamps and candidate phase.
  sheet=Image.new('RGB',(1002,554*6),'#111922')
  for i in range(6):sheet.paste(frames[i],(0,554*i))
  sheet.save(OUT/(stem+'_consecutive.jpg'),quality=94)
  frames[0].save(OUT/(stem+'_poster.jpg'),quality=94)
  # First/opposite peaks plus passing and rise, independent of reference contact claims.
  sheet=Image.new('RGB',(1002,554*4),'#111922')
  for j,i in enumerate([0,period//4,period//2,3*period//4]):sheet.paste(frames[i],(0,554*j))
  sheet.save(OUT/(stem+'_phases.jpg'),quality=94)
# Full front comparison at native independent periods. No duplicated terminal frames.
folder=OUT/'overview_frames';folder.mkdir(exist_ok=True)
for i in range(208):
 o=Image.new('RGB',(1288,544),'#111922');d=ImageDraw.Draw(o)
 for j,(g,v,p) in enumerate([('walk','v1',16),('walk','v2',16),('sprint','v1',13),('sprint','v2',13)]):
  o.paste(candidate(g,v,'front',i%p),(j*322,34));d.text((j*322+14,7),g.title()+' '+v.upper(),font=font,fill='white')
 d.text((14,521),'24 FPS / 1.0x | Walk 0.667 s | Sprint 0.542 s | independent clocks',font=small,fill='white');o.save(folder/('%04d.png'%(i+1)))
manifest.append({'stem':'overview','folder':folder.name,'frames':208,'size':[1288,544],'fps':24})
folder=OUT/'gameplay_frames';folder.mkdir(exist_ok=True)
for i in range(208):
 o=Image.open(OUT/'gameplay_raw'/('%04d.png'%(i+1))).convert('RGB');d=ImageDraw.Draw(o)
 d.rectangle((0,0,1280,56),fill='#111922');d.text((20,9),'Project camera / 14.5 vertical units / 1280 x 720 / 24 FPS / 1.0x',font=font,fill='white')
 d.text((20,35),'Left to right: Walk V1, Walk V2, Sprint V1, Sprint V2',font=small,fill='white');o.save(folder/('%04d.png'%(i+1)))
manifest.append({'stem':'gameplay','folder':folder.name,'frames':208,'size':[1280,720],'fps':24})
(OUT/'video_manifest.json').write_text(json.dumps(manifest,indent=2))
body='''<!doctype html><html><head><meta charset="utf-8"><title>R2-S | Straight V2 review</title><style>body{max-width:1300px;margin:32px auto;padding:24px;background:#111922;color:#e5edf4;font:16px system-ui;line-height:1.5}h1{font-size:32px}h2{margin-top:38px}video,img{max-width:100%;background:#1a2027}a{color:#8fd0ff}button{padding:10px;background:#294559;color:white;border:0;cursor:pointer;margin:5px}figure{margin:16px 0}figcaption{color:#b4c5d4}details{margin:20px 0}p{max-width:1000px}</style></head><body><h1>R2-S — Walk / Sprint V2, first pass</h1><p>Normal speed first: 24 FPS, 1.0×. Walk: 0.666667 s. Sprint: 0.541667 s. V1 remains unchanged. Technical validation is not artistic approval.</p><p>Review evidence was decoded and inspected as ordered images; continuous real-time motion was not directly observed by the assistant. Use these videos to judge feel, weight and any distracting hovering.</p><button onclick="document.querySelectorAll('video').forEach(v=>{v.pause();v.playbackRate=1;v.currentTime=0});document.querySelector('video').play()">Restart overview at 1.0×</button><p><a href="R2S_REPORT.txt">Full findings and limitations</a> · <a href="validation.json">Technical checks</a></p>'''
def video(stem,caption):return f'<figure><video controls loop playsinline preload="metadata" src="{stem}.mp4"></video><figcaption>{caption}</figcaption></figure>'
body+=video('overview','Walk V1 / Walk V2 / Sprint V1 / Sprint V2. Independent cycles, duplicated endpoint excluded.')
for gait in ['walk','sprint']:
 body+='<h2>'+gait.title()+': Reference / V1 / V2</h2>'
 for view in ['front','rear','gameclose']:
  stem=gait+'_'+view;caption=view.title()+'. Front and rear are separate takes, independently anchored; approximate framing, not reconstructed source cameras.'
  if view=='gameclose':caption='Project camera angle, enlarged for diagnosis. Reference column remains the original front take; no source footage exists from our project camera.'
  body+=video(stem,caption)
  body+=f'<details><summary>Frame diagnosis: {view}</summary><p><a href="{stem}_consecutive.jpg">Six consecutive samples</a> · <a href="{stem}_phases.jpg">Quarter-cycle poses</a></p></details>'
body+='<h2>Actual project gameplay scale</h2>'+video('gameplay','14.5 vertical units, 1280×720. View at 100% to judge character readability; enlarged comparisons above serve a different purpose.')
body+='<h2>Rigid-leg limitation</h2><p>Sprint V2 f1 (0.000 s) gathers in front projection, but side view retains a long straight rear segment. The source topology is unknown. A knee could fold the lower silhouette independently; this first pass does not establish that a rig change is worth its cost.</p><img src="sprint_v2_side/000.png"><p>Blender: R2S_Front_V1_V2 or R2S_Gameplay_V1_V2. Space plays 24 FPS; frame range 1–208. All existing Actions and source assets preserved. Stop for human review.</p></body></html>'
(OUT/'index.html').write_text(body,encoding='utf-8');print('R2S_PACKAGE_DONE',flush=True)
