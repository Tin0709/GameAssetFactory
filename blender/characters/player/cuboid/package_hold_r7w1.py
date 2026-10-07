"""Review contact sheets and supplied-reference board; no changes to rendered poses."""
from pathlib import Path
import json,cv2
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent/'hold_r7w1_review'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
labels=['A — current Hold V2','B — reference study','C — aim / focus peak']
for view in ['Front','Side','Gameplay','Rear','CloseGun']:
 sheet=Image.new('RGB',(1800,440),'#111c27');d=ImageDraw.Draw(sheet)
 for i,label in enumerate(labels):
  d.text((i*600+14,10),label,font=font,fill='white')
  im=Image.open(OUT/f'{"ABC"[i]}_{view}.png').convert('RGB').resize((600,360),Image.Resampling.LANCZOS);sheet.paste(im,(i*600,48))
 d.text((14,410),f'{view}: matched camera and scale · Blender-only study · AWAITING HUMAN REVIEW',font=small,fill='#a5c8d8')
 sheet.save(OUT/f'comparison_{view}.jpg',quality=94)
# Keep the true rendered pixel scale in this sheet; do not enlarge the tiny characters.
sheet=Image.new('RGB',(1200,2280),'#111c27');d=ImageDraw.Draw(sheet)
for i,label in enumerate(labels):
 d.text((15,i*760+10),label+' — gameplay distance / native pixels',font=font,fill='white')
 sheet.paste(Image.open(OUT/f'{"ABC"[i]}_GameplayDistance.png').convert('RGB'),(0,i*760+40))
sheet.save(OUT/'comparison_GameplayDistance.png')
board=Image.new('RGB',(720,1500),'#111c27');d=ImageDraw.Draw(board)
ref1=Image.open(OUT/'reference_1.png').convert('RGB').crop((450,35,990,700));ref1.thumbnail((690,630));board.paste(ref1,((720-ref1.width)//2,40));d.text((15,8),'REFERENCE 1 — cropped for inspection',font=small,fill='white')
for name,y,title in [('reference_2.jpg',710,'REFERENCE 2 — full image'),('reference_3.jpg',1090,'REFERENCE 3 — full image')]:
 d.text((15,y-30),title,font=small,fill='white');im=Image.open(OUT/name).convert('RGB');im.thumbnail((700,375));board.paste(im,((720-im.width)//2,y))
board.save(OUT/'reference_board.png')
cap=cv2.VideoCapture(str(OUT/'ABC_aim_24fps.mp4'));fps=cap.get(cv2.CAP_PROP_FPS);count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));assert abs(fps-24)<1e-5 and count==48,(fps,count)
frames=[]
for idx in [0,14,19,30,42]:
 cap.set(cv2.CAP_PROP_POS_FRAMES,idx);ok,arr=cap.read();assert ok
 im=Image.fromarray(cv2.cvtColor(arr,cv2.COLOR_BGR2RGB));frames.append(im)
frames[2].save(OUT/'ABC_poster.jpg',quality=95)
cap.release();(OUT/'media_validation.json').write_text(json.dumps({'fps':fps,'frames':count,'duration_s':count/fps,'decoded_review_frames':[1,15,20,31,43],'views':['Front','Side','Gameplay','Rear','GameplayDistance','CloseGun']},indent=2))
page='''<!doctype html><html><meta charset="utf-8"><title>R7-W1 Hold and aim study</title><style>body{max-width:1450px;margin:30px auto;padding:20px;background:#111c27;color:#e6eef5;font:17px system-ui;line-height:1.55}img,video{max-width:100%}a{color:#8ed6e9}h1{font-size:30px}figure{margin:30px 0}.refs{display:flex;gap:20px;align-items:center}.refs img{max-width:32%}</style><h1>R7-W1 — Long-gun hold + subtle aim bias</h1><p><b>ARTISTIC STATUS: AWAITING HUMAN REVIEW.</b> Blender-only study on the current rigid-arm rig. A: approved hold. B: new braced hold. C: small focus/emphasis/settle sequence.</p><p><a href="R7_W1_REPORT.txt">Full artistic report and recommendation</a> · <a href="validation.json">Preservation and pose measurements</a> · <a href="contact_evidence.json">Contact/overlap evidence</a></p><video controls loop playsinline preload="metadata" poster="ABC_poster.jpg" src="ABC_aim_24fps.mp4"></video><p>2 seconds, 24 FPS / 1.0×. Frame1 ready; 15 focus; 20 tiny emphasis; 43 settled. This is not a recoil or firing system.</p>'''
for view in ['Gameplay','Front','Side','CloseGun','Rear']:
 page+=f'<figure><img src="comparison_{view}.jpg"><figcaption>{view} — matched A/B/C views.</figcaption></figure>'
page+='<details><summary>Gameplay distance — inspect at native size</summary><img src="comparison_GameplayDistance.png"></details><h2>Supplied references</h2><div class="refs"><img src="reference_1.png"><img src="reference_2.jpg"><img src="reference_3.jpg"></div><p>The first reference shows a compact bent-arm silhouette. Perspective and images do not establish the source rig or exact joint angles. All originals are retained; no reference content was regenerated.</p></html>'
(OUT/'index.html').write_text(page,encoding='utf-8')
print('R7W1_REVIEW_PACKAGED',count,'frames at',fps)
