"""Build a local frame-accurate review of actual Godot captures, plus evidence sheets."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parents[3]/'.validation/locomotion_r5'
review=OUT/'review';review.mkdir(exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
metrics=json.loads((OUT/'rendered/metrics.json').read_text())
manifest={key:len(rows) for key,rows in metrics.items()}
(review/'manifest.json').write_text(json.dumps(manifest,indent=2))
for tag,folder in [('remap','rendered'),('best','rendered_best')]:
 for label in manifest:
  if not (OUT/folder/f'{label}_{manifest[label]-1:03}.jpg').exists():continue
  indices=[24,42,60,78] if 'Circle' in label else ([66,72,75,80] if 'Reversal' in label else ([48,120,192,210] if 'Radius' in label else [24,72,120,168]))
  sheet=Image.new('RGB',(1200,4*320),'#101a24');d=ImageDraw.Draw(sheet)
  for row,idx in enumerate(indices):
   im=Image.open(OUT/folder/f'{label}_{idx:03}.jpg')
   for mode in range(3):
    crop=im.crop((mode*1280+480,210,mode*1280+800,450)).resize((400,300),Image.Resampling.LANCZOS)
    sheet.paste(crop,(mode*400,row*320+20))
    d.text((mode*400+8,row*320),f'{"ABC"[mode]} | {label} | {idx/24:.3f}s',font=small,fill='white')
  sheet.save(review/f'{tag}_{label}.jpg',quality=92)
html=r'''<!doctype html><html lang="en"><meta charset="utf-8"><title>R5 — measured turning review</title>
<style>body{margin:24px auto;max-width:1500px;padding:0 20px;background:#101923;color:#e7eef6;font:16px system-ui;line-height:1.5}h1{font-size:28px}button,select{font:inherit;padding:7px 10px;margin:4px;background:#234453;color:white;border:1px solid #517885;border-radius:5px}button{cursor:pointer}a{color:#8cdaed}canvas{width:100%;background:#273949}input{width:100%}.muted{color:#aebfce}details{margin:20px 0}img{max-width:100%}#status{min-height:24px}</style>
<h1>R5 — root cause, remap, then V3</h1><p><b>ARTISTIC STATUS: AWAITING HUMAN REVIEW.</b> Actual Godot lab frames at 24 FPS / 1.0×, with identical path, speed, facing, camera and gait phase across A/B/C.</p>
<p><a href="../R5_REPORT.txt">Full report and rollback</a> · <a href="../comparison_summary.json">Measured response</a> · <a href="../runtime_validation.json">Runtime checks</a> · <a href="../import_validation.json">Blender ↔ Godot pose checks</a></p>
<label>Experiment <select id="experiment"><option value="rendered_best">Final: C = remap + V3</option><option value="rendered">First experiment: C = remap + unchanged V2</option></select></label>
<label>Path <select id="scenario"></select></label><button id="play">Play at 1.0×</button><button id="restart">Restart</button><button id="full">Full screen</button>
<div id="status">Loading frames…</div><canvas id="screen" width="1920" height="860"></canvas><input id="seek" type="range" min="0" max="143" value="0" step="1">
<p class="muted">Top: unchanged lab camera, reduced to fit three columns. Bottom: enlarged crops from those same pixels. Use the live lab for full-size gameplay judgment. Frame playback follows elapsed time at 24 FPS; it never changes the gait cadence. Different paths start independently.</p>
<p>Mild bends: +0.55 rad/s for 2s → straight for 2s → −0.55 for 2s → straight. Reversal changes sign at 3s. Radius sweep: 4m / 2.5m / 1.5m, three seconds each. Default circle: 6m. Tight circle: 2.5m.</p>
<details><summary>Supplied reference and review limits</summary><video controls style="max-width:100%" src="../../../../references/animation/minecraft_turning_reference/originals/Screen%20Recording%202026-10-07%20102829.mp4"></video><p>Source camera, speed, rig and turn angles are not calibrated. Compare body response, shoulder participation and recovery; no exact angle match is claimed. The assistant inspected ordered rendered frames and numerical traces, not continuous human playback. Your live review is the artistic decision.</p></details>
<details><summary>Final Sprint circle — ordered frame evidence</summary><img src="best_Sprint_TightCircle.jpg"></details>
<script>
const manifest=MANIFEST;
const screen=document.querySelector('#screen'),ctx=screen.getContext('2d'),scenario=document.querySelector('#scenario'),experiment=document.querySelector('#experiment'),seek=document.querySelector('#seek'),play=document.querySelector('#play'),status=document.querySelector('#status');
for(const key of Object.keys(manifest)){const o=document.createElement('option');o.value=key;o.textContent=key.replaceAll('_',' · ');scenario.append(o)}
scenario.value='Sprint_DefaultCircle';let frames=[],index=0,running=false,start=0,token=0,last=-1;
function draw(){if(!frames[index])return;const im=frames[index];ctx.fillStyle='#101923';ctx.fillRect(0,0,1920,860);ctx.font='25px system-ui';ctx.fillStyle='#e7eef6';ctx.fillText(`${scenario.value.replaceAll('_',' · ')} | ${(index/24).toFixed(3)}s | 24 FPS / 1.0×`,18,32);const labels=['A — straight V2 / path only','B — turning V2 / original mapping',experiment.value==='rendered_best'?'C — turning V3 / calibrated mapping':'C — turning V2 / calibrated mapping'];for(let m=0;m<3;m++){ctx.font='22px system-ui';ctx.fillStyle=['#ccd7df','#e7bc82','#78e0ca'][m];ctx.fillText(labels[m],m*640+12,67);ctx.drawImage(im,m*1280,0,1280,720,m*640,80,640,360);ctx.drawImage(im,m*1280+480,210,320,260,m*640+80,450,480,390)}seek.value=index;last=index}
async function load(){const my=++token;running=false;play.textContent='Play at 1.0×';frames=[];index=0;last=-1;const count=manifest[scenario.value];seek.max=count-1;status.textContent=`Loading ${count} captured frames…`;play.disabled=true;const path=experiment.value,label=scenario.value;try{const loaded=await Promise.all(Array.from({length:count},(_,i)=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>reject(new Error('Missing frame '+i));im.src=`../${path}/${label}_${String(i).padStart(3,'0')}.jpg`})));if(my!==token)return;frames=loaded;status.textContent=`${count} frames ready · ${(count/24).toFixed(1)} seconds · unchanged speeds: Walk 4.25 / Sprint 6.25 m/s`;play.disabled=false;draw()}catch(e){status.textContent=e.message}}
function tick(now){if(running&&frames.length){index=Math.floor((now-start)*24/1000)%frames.length;if(index!==last)draw()}requestAnimationFrame(tick)}
play.onclick=()=>{running=!running;start=performance.now()-index/24*1000;play.textContent=running?'Pause':'Play at 1.0×'};seek.oninput=()=>{index=Number(seek.value);start=performance.now()-index/24*1000;draw()};document.querySelector('#restart').onclick=()=>{index=0;start=performance.now();draw()};document.querySelector('#full').onclick=()=>screen.requestFullscreen();scenario.onchange=load;experiment.onchange=load;load();requestAnimationFrame(tick);
</script></html>'''.replace('MANIFEST',json.dumps(manifest))
(review/'index.html').write_text(html,encoding='utf-8')
print('R5_REVIEW_PACKAGED',len(manifest),'paths; both experimental stages')
