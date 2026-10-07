"""Package actual normal-camera A/B captures without changing animation timing."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
PROJECT=Path(__file__).resolve().parents[3]
OUT=PROJECT/'.validation/locomotion_r6p'
REVIEW=OUT/'review'; REVIEW.mkdir(exist_ok=True)
metrics=json.loads((OUT/'rendered/metrics.json').read_text())
manifest={name:len(rows) for name,rows in metrics.items()}
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
def center(row):
    x,y,z=row['position'];y+=0.95
    pitch=math.radians(-36.31588642394517);yaw=math.radians(36.86989764584402)
    right=(math.cos(yaw),0,-math.sin(yaw))
    up=(math.sin(yaw)*math.sin(pitch),math.cos(pitch),math.cos(yaw)*math.sin(pitch))
    delta=(x-12,y-15,z-16)
    return (640+sum(a*b for a,b in zip(delta,right))*720/14.5,360-sum(a*b for a,b in zip(delta,up))*720/14.5)
summary={}
for name,rows in metrics.items():
    settled=rows[12:]
    summary[name]={'frames':len(rows),'duration_seconds':len(rows)/24,
        'speed_min':min(x['speed'] for x in settled),'speed_max':max(x['speed'] for x in settled),
        'turn_min':min(x['turn'] for x in settled),'turn_max':max(x['turn'] for x in settled),
        'weapon_states':list(dict.fromkeys(x['state'] for x in rows)),
        'last_phase':rows[-1]['phase'],'final_turn':rows[-1]['turn']}
    for i,row in enumerate(rows):
        row['screen']=center(row)
        assert (OUT/'rendered'/f'{name}_{i:03}.jpg').exists()
    indices=[round((len(rows)-1)*fraction) for fraction in [0.2,0.4,0.65,0.9]]
    sheet=Image.new('RGB',(1000,4*300),'#101c25');draw=ImageDraw.Draw(sheet)
    for r,i in enumerate(indices):
        image=Image.open(OUT/'rendered'/f'{name}_{i:03}.jpg');cx,cy=rows[i]['screen']
        for mode in range(2):
            crop=image.crop((mode*1280+cx-150,cy-85,mode*1280+cx+150,cy+85)).resize((500,280),Image.Resampling.LANCZOS)
            sheet.paste(crop,(mode*500,r*300+20))
            draw.text((mode*500+8,r*300),f'{"Reference" if mode else "Legacy"} | {name} | {i/24:.2f}s',font=font,fill='white')
    sheet.save(REVIEW/f'{name}.jpg',quality=93)
(OUT/'capture_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
html='''<!doctype html><html lang="en"><meta charset="utf-8"><title>R6-P production locomotion review</title>
<style>body{background:#101c25;color:#e9f1f5;max-width:1450px;margin:24px auto;padding:0 16px;font:16px system-ui;line-height:1.5}button,select{font:inherit;background:#244555;color:white;padding:8px;margin:5px;border:1px solid #71919d;border-radius:4px}button{cursor:pointer}canvas{width:100%;background:#15222c}input{width:100%}a{color:#8de3d3}.muted{color:#bdcdd7}</style>
<h1>R6-P production locomotion review</h1><p><b>ARTISTIC STATUS: AWAITING HUMAN REVIEW.</b> Left: retained Legacy. Right: approved reference Walk V2 / Sprint V2 with turning V3 and R5 C response.</p>
<p>Actual production controller and normal gameplay camera. Both images share the same world, facing, weapon state and clock snapshot. Simulation freezes only while taking each A/B pair. Playback follows 24 captured frames per second, with five active 120 Hz physics ticks per frame. Enlargements below come from the same pixels.</p>
<select id="case"></select><button id="play">Play at 1.0×</button><button id="restart">Restart</button><button id="full">Full screen</button><div id="status">Loading…</div>
<canvas id="screen" width="1600" height="900"></canvas><input type="range" id="seek" min="0" value="0" step="1">
<p class="muted">Scripted rendered gameplay QA; human manual and artistic approval remain pending. Circles include CW and CCW, S paths and reversals in both gaits, armed circles/S, and real Draw/Holster/Sprint release. Foot sliding is retained; no stride correction was introduced. Ignore startup facing acquisition when judging straight movement. The capture HUD FPS is not a mobile benchmark.</p>
<p><a href="../capture_summary.json">Capture measurements</a> · <a href="../focused_validation.json">Focused regression</a> · <a href="../live_validation.json">Live weapons regression</a> · <a href="../performance.json">Desktop visual CPU measurement</a></p>
<script>
const metrics=METRICS,select=document.querySelector('#case'),screen=document.querySelector('#screen'),ctx=screen.getContext('2d'),seek=document.querySelector('#seek'),status=document.querySelector('#status'),play=document.querySelector('#play');
for(const key of Object.keys(metrics)){const o=document.createElement('option');o.value=key;o.textContent=key.replaceAll('_',' · ');select.append(o)}select.value='Sprint_CW';
let frames=[],index=0,running=false,start=0,token=0,last=-1;
function draw(){const im=frames[index];if(!im)return;const row=metrics[select.value][index];ctx.fillStyle='#101c25';ctx.fillRect(0,0,1600,900);ctx.fillStyle='#e9f1f5';ctx.font='22px system-ui';ctx.fillText(`${select.value.replaceAll('_',' · ')} | ${(index/24).toFixed(3)}s | ${row.speed.toFixed(2)} m/s | ${row.state} | phase ${row.phase.toFixed(3)} | turn ${row.turn.toFixed(2)}`,14,28);for(let mode=0;mode<2;mode++){ctx.fillStyle=mode?'#83e9d3':'#d8e1e6';ctx.fillText(mode?'REFERENCE_LOCOMOTION':'LEGACY_LOCOMOTION',mode*800+12,62);ctx.drawImage(im,mode*1280,0,1280,720,mode*800,75,800,450);const [cx,cy]=row.screen;ctx.drawImage(im,mode*1280+cx-150,cy-85,300,170,mode*800+100,540,600,340)}seek.value=index;last=index}
async function load(){const mine=++token;running=false;play.textContent='Play at 1.0×';play.disabled=true;index=0;last=-1;frames=[];const key=select.value,count=metrics[key].length;seek.max=count-1;status.textContent=`Loading ${count} frames…`;try{const ready=await Promise.all(Array.from({length:count},(_,i)=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>reject(new Error('Missing frame '+i));im.src=`../rendered/${key}_${String(i).padStart(3,'0')}.jpg`})));if(mine!==token)return;frames=ready;status.textContent=`${count} frames ready · ${(count/24).toFixed(2)} seconds · 24 FPS / 1.0×`;play.disabled=false;draw()}catch(e){status.textContent=e.message}}
function tick(now){if(running&&frames.length){index=Math.floor((now-start)*24/1000)%frames.length;if(index!==last)draw()}requestAnimationFrame(tick)}
play.onclick=()=>{running=!running;start=performance.now()-index/24*1000;play.textContent=running?'Pause':'Play at 1.0×'};seek.oninput=()=>{index=Number(seek.value);start=performance.now()-index/24*1000;draw()};document.querySelector('#restart').onclick=()=>{index=0;start=performance.now();draw()};document.querySelector('#full').onclick=()=>screen.requestFullscreen();select.onchange=load;load();requestAnimationFrame(tick);
</script></html>'''.replace('METRICS',json.dumps(metrics,separators=(',',':')))
(REVIEW/'index.html').write_text(html,encoding='utf-8')
print('R6P_REVIEW_PACKAGED',len(manifest),'cases',sum(manifest.values()),'paired frames')
print(json.dumps(summary,indent=2))
