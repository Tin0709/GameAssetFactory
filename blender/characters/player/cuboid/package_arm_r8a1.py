from pathlib import Path
import json,cv2
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent/'arm_r8a1_review'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
labels=['A — original hold','B — rigid-arm study','C — RigV2 hold','D — RigV2 focus']
views=['Gameplay','Front','Side','Rear','CloseGun','GameplayOpposite']
for view in views:
 sheet=Image.new('RGB',(2000,378),'#111c27');draw=ImageDraw.Draw(sheet)
 for i,label in enumerate(labels):
  draw.text((i*500+12,9),label,font=font,fill='white');im=Image.open(OUT/f'{"ABCD"[i]}_{view}.png').convert('RGB').resize((500,300),Image.Resampling.LANCZOS);sheet.paste(im,(i*500,42))
 draw.text((12,349),f'{view} · matched cameras/scale · Blender study · AWAITING HUMAN REVIEW',font=small,fill='#a5c8d8');sheet.save(OUT/f'comparison_{view}.jpg',quality=95)
sheet=Image.new('RGB',(2400,1520),'#111c27');draw=ImageDraw.Draw(sheet)
for i,label in enumerate(labels):
 x=(i%2)*1200;y=(i//2)*760;draw.text((x+15,y+10),label+' — gameplay distance / native pixels',font=font,fill='white');sheet.paste(Image.open(OUT/f'{"ABCD"[i]}_GameplayDistance.png').convert('RGB'),(x,y+40))
sheet.save(OUT/'comparison_GameplayDistance.png')
media={}
for filename in ['ABCD_aim_24fps.mp4','aim_close_24fps.mp4']:
 cap=cv2.VideoCapture(str(OUT/filename));fps=cap.get(cv2.CAP_PROP_FPS);count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));assert fps==24 and count==48,(filename,fps,count)
 review=[]
 for idx in [0,14,19,30,42]:
  cap.set(cv2.CAP_PROP_POS_FRAMES,idx);ok,arr=cap.read();assert ok;im=Image.fromarray(cv2.cvtColor(arr,cv2.COLOR_BGR2RGB));review.append(im)
 review[2].save(OUT/(filename.replace('.mp4','_poster.jpg')),quality=95)
 if filename.startswith('aim_close'):
  seq=Image.new('RGB',(2000,280),'#111c27');d=ImageDraw.Draw(seq)
  for i,(f,im) in enumerate(zip([1,15,20,31,43],review)):d.text((i*400+10,6),'Frame '+str(f),font=small,fill='white');seq.paste(im.resize((400,240),Image.Resampling.LANCZOS),(i*400,32))
  seq.save(OUT/'focus_sequence.jpg',quality=95)
 media[filename]={'fps':fps,'frames':count,'duration_s':count/fps,'sampled_frames':[1,15,20,31,43]};cap.release()
(OUT/'media_validation.json').write_text(json.dumps(media,indent=2))
page='''<!doctype html><html><meta charset="utf-8"><title>R8-A1 articulated arm study</title><style>body{max-width:1650px;margin:30px auto;padding:20px;background:#111c27;color:#e6eef5;font:17px system-ui;line-height:1.55}img,video{max-width:100%}a{color:#8ed6e9}figure{margin:30px 0}.refs{display:flex;gap:20px;align-items:center}.refs img{max-width:32%}</style><h1>R8-A1 — Articulated arms / compact rifle hold</h1><p><b>AWAITING HUMAN REVIEW.</b> A original / B previous rigid-arm study / C RigV2 hold / D subtle focus. Two rigid FK segments per arm; no hand bones or rig constraints.</p><p><a href="R8_A1_REPORT.txt">Full artistic report</a> · <a href="validation.json">Preservation and contact measurements</a></p><video controls loop playsinline preload="metadata" poster="ABCD_aim_24fps_poster.jpg" src="ABCD_aim_24fps.mp4"></video><p>48 frames / 24 fps / 2 seconds. Focus 15, emphasis 20, settled 43.</p><details><summary>Closer aim-bias playback</summary><video controls loop playsinline preload="metadata" poster="aim_close_24fps_poster.jpg" src="aim_close_24fps.mp4"></video><img src="focus_sequence.jpg"></details>'''
for v in views:page+=f'<figure><img src="comparison_{v}.jpg"><figcaption>{v} — matched A/B/C/D. GameplayOpposite retains the previous R7-W1 elevated camera angle.</figcaption></figure>'
page+='<details><summary>Gameplay distance, native pixels</summary><img src="comparison_GameplayDistance.png"></details><h2>User references</h2><div class="refs"><img src="reference_1.png"><img src="reference_2.jpg"><img src="reference_3.jpg"></div><p>Original supplied images. No reference pixels or character renders were AI regenerated. Perspective does not establish the source rigs or motion.</p></html>'
(OUT/'index.html').write_text(page,encoding='utf-8');print('R8A1_PACKAGED',json.dumps(media))
