"""Package native Blender previews; no generated or retouched pose imagery."""
from pathlib import Path
import json,hashlib,cv2
from PIL import Image,ImageDraw,ImageFont
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid');OUT=BASE/'weapon_hold_r11_review'
CATS=['Pistol','Rifle','Shotgun'];VIEWS=['FrontReference','ReferenceAngle','ReverseTop','UnderReference','FrontThreeQuarter','Front','Side','Overhead'];MODES={'Hold':96,'Move':64,'AimAround':288,'Sprint':208,'Turn':456}
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',26)
for view in VIEWS:
    board=Image.new('RGB',(1500,1030),'#151e25');draw=ImageDraw.Draw(board)
    draw.text((20,8),'A  Previous WH2 development',font=font,fill='white');draw.text((20,520),'B  R11 · supplied straight-arm layout',font=font,fill='white')
    for i,cat in enumerate(CATS):
        for j,tag in enumerate(['A','B']):
            im=Image.open(OUT/f'{cat}_{tag}_{view}.png').convert('RGB');im.thumbnail((490,460));board.paste(im,(i*500+5,j*512+45));draw.text((i*500+15,j*512+45),cat,font=font,fill='white')
    board.save(OUT/f'AB_{view}.jpg',quality=94)
movies={}
for mode,N in MODES.items():
    p=OUT/f'{mode}_24fps.mp4';cap=cv2.VideoCapture(str(p));count=0;previews=[]
    while True:
        ok,frame=cap.read()
        if not ok:break
        if count in [0,N//4,N//2,3*N//4,N-1]:
            dest=OUT/f'{mode}_frame{count+1}.jpg';cv2.imwrite(str(dest),frame);previews.append(str(dest))
        count+=1
    fps=cap.get(cv2.CAP_PROP_FPS);cap.release();assert count==N and abs(fps-24)<.01,(mode,count,N,fps)
    movies[mode]={'decoded_frames':count,'fps':fps,'seconds':count/fps,'previews':previews}
(OUT/'media_validation.json').write_text(json.dumps(movies,indent=2))
protected=json.loads((BASE/'weapon_hold_r10wh2_review/protected_files.json').read_text());root=BASE.parents[3];changed=[n for n,h in protected.items() if hashlib.sha256((root/n).read_bytes()).hexdigest()!=h];assert not changed,changed
(OUT/'file_preservation.json').write_text(json.dumps({'passed':True,'unchanged_tracked_files':len(protected)},indent=2))
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>R11 — simple blocky hold</title>
<style>body{margin:0;background:#111b23;color:#e5edf0;font:16px system-ui}main{max-width:1450px;margin:auto;padding:28px}h1{font-size:32px;margin:0 0 8px}.muted{color:#9eafb9}nav{display:flex;gap:10px;flex-wrap:wrap;margin:22px 0}button,select,a{color:#e5edf0;background:#263a47;border:1px solid #426072;padding:10px 15px;border-radius:6px;font:inherit}button{cursor:pointer}button.active{background:#376857}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.card{background:#1a2933;border-radius:10px;overflow:hidden}.card h2{padding:10px 16px;margin:0;font-size:19px}.card img{width:100%;display:block}.wide{width:100%;border-radius:8px}video{width:100%;background:#18212a;border-radius:8px}.ref{display:flex;flex-wrap:wrap;gap:20px;align-items:center;margin:24px 0}.ref img{width:184px;image-rendering:pixelated}.ref p{max-width:660px}footer{margin:24px 0}a{display:inline-block;text-decoration:none}@media(max-width:800px){.cards{grid-template-columns:1fr}.ref{align-items:start}}</style>
<main><h1>R11 — simple blocky hold</h1><p class="muted">Straight right arm carries the weapon. Straight left arm reaches diagonally, leaving a visible gap. Forward barrel, slight head tilt. Study only · human review pending.</p>
<div class="ref"><img src="reference_overhead.png" alt="Supplied overhead pose"><img src="reference_front.png" alt="Supplied front pose"><img src="reference_under.png" alt="Supplied underside pose"><img src="reference_top_reverse.png" alt="Supplied reverse overhead pose"><p>The supplied overhead image defines the arm layout. Both arms reach inward as straight cuboids; the right hand reaches farther forward. The left arm reaches toward the primary side without touching either the other arm or the weapon. Each firearm uses this same layout.</p></div>
<nav><button id="new" class="active" onclick="version('B')">B · R11</button><button id="old" onclick="version('A')">A · previous WH2</button><label>View <select id="angle" onchange="update()"><option value="FrontReference">New front reference</option><option value="ReferenceAngle">Reference overhead</option><option value="ReverseTop">Reverse overhead reference</option><option value="UnderReference">Underside reference</option><option value="FrontThreeQuarter">Front three-quarter</option><option value="Front">Front</option><option value="Side">Side</option><option value="Overhead">Direct overhead</option></select></label></nav>
<div class="cards">'''
for cat in CATS:html+=f'<article class="card"><h2>{cat}</h2><img id="{cat}" src="{cat}_B_FrontReference.png" alt="{cat} R11 hold"></article>'
html+='''</div><p class="muted">A/B views use the same character, weapon geometry, camera and lighting. R11 dev long guns are sized to keep stocks clear at the raised reference height. A is the stopped WH2 development pose.</p><img id="ab" class="wide" src="AB_FrontReference.jpg" alt="Three-weapon matched A/B comparison">
<h2>Living showcase</h2><nav id="motion">'''
for mode,label in [('Hold','Ready / breathe'),('Move','Walk'),('AimAround','Look around'),('Sprint','Sprint'),('Turn','Turn / change direction')]:html+=f'<button onclick="motion(\'{mode}\')">{label}</button>'
html+='''</nav><video id="movie" src="Hold_24fps.mp4" controls loop playsinline preload="metadata"></video><p id="note" class="muted">Ready breathing · 4 seconds · loop.</p>
<footer><a href="../player_weapon_hold_r11_study.blend">Blender study</a> <a href="ThreeWeapon_R11.png">Three-weapon still</a> <a href="validation.json">Verification</a></footer>
<p class="muted">Existing Walk, Sprint and turn path are retained. Turn preview includes the original separate direction test cases. No production migration.</p></main>
<script>let tag='B';const cats=['Pistol','Rifle','Shotgun'];function version(t){tag=t;document.getElementById('new').classList.toggle('active',t==='B');document.getElementById('old').classList.toggle('active',t==='A');update()}function update(){const v=document.getElementById('angle').value;cats.forEach(c=>{const im=document.getElementById(c);im.src=c+'_'+tag+'_'+v+'.png';im.alt=c+' '+tag+' '+v});document.getElementById('ab').src='AB_'+v+'.jpg'}function motion(m){const v=document.getElementById('movie');v.src=m+'_24fps.mp4';v.loop=['Hold','Move','AimAround'].includes(m);v.load();document.getElementById('note').textContent={Hold:'Ready breathing · 4 seconds · loop.',Move:'Original Walk phase · 2.67 seconds · loop.',AimAround:'Simple continuous look-around · 12 seconds · loop.',Sprint:'Original Sprint phase · 8.67 seconds · excerpt.',Turn:'Original direction-change test path · 19 seconds · separate test cases.'}[m]}</script></html>'''
(OUT/'index.html').write_text(html,encoding='utf-8')
print(json.dumps({'media':movies,'protected_files':len(protected),'page':str(OUT/'index.html')}))
