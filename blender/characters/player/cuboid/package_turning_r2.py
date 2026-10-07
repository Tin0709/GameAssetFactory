import json,math,sys
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;OUT=BASE/'turning_study_r2_review'
meta=json.loads((OUT/'preview_metadata.json').read_text());bounds=json.loads((OUT/'pose_detail_bounds.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
def frame(gait,v,f):return Image.open(OUT/(gait.lower()+'_'+v.lower())/('%04d.png'%f)).convert('RGB')
folder=OUT/'ab_frames';folder.mkdir(exist_ok=True)
gif=[]
for f in ([] if '--sheets-only' in sys.argv else range(1,457)):
    im=Image.new('RGB',(960,1080),(19,25,32));d=ImageDraw.Draw(im)
    for gait,y in [('Walk',0),('Sprint',540)]:
        row=meta['gaits'][gait]['rows'][f-1]
        for variant,x in [('A',0),('B',480)]:
            im.paste(frame(gait,variant,f),(x,y+28))
            d.text((x+10,y+5),gait+' '+variant+' — '+('R1 + path' if variant=='A' else 'same phase/path + turn pose'),font=font,fill='#e9eef3' if variant=='A' else '#80d9ed')
            d.text((x+10,y+511),f"{row['case']} | t={row['time']:.3f}s | phase {row['phase']:.2f} | turn {row['signed_weight']:+.2f}",font=small,fill='#d7e0e8')
    im.save(folder/('%04d.png'%f))
    if f<=144:gif.append(im.resize((640,720),Image.Resampling.LANCZOS))
# Compact fallback excerpt; the H.264 reel contains all five tests at 24 FPS.
if gif:gif[0].save(OUT/'turning_AB_excerpt.gif',save_all=True,append_images=gif[1:],duration=[(40,40,50,40,40,40)[i%6] for i in range(len(gif))],loop=0,optimize=False)

def posepair(gait,f):
    aa=bounds[gait+'_A_'+str(f)];bb=bounds[gait+'_B_'+str(f)]
    box=[math.floor(min(aa[0],bb[0]))-15,math.floor(min(aa[1],bb[1]))-15,math.ceil(max(aa[2],bb[2]))+15,math.ceil(max(aa[3],bb[3]))+15]
    out=Image.new('RGB',(480,330),(19,25,32));d=ImageDraw.Draw(out)
    for v,x in [('A',0),('B',240)]:
        im=frame(gait,v,f).crop(box);scale=min(236/im.width,265/im.height);im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
        out.paste(im,(x+(240-im.width)//2,35));d.text((x+8,9),gait+' '+v,font=font,fill='#80d9ed' if v=='B' else 'white')
    row=meta['gaits'][gait]['rows'][f-1];d.text((8,305),f"{row['case']} | f{f} t={row['time']:.3f}s | turn {row['signed_weight']:+.2f}",font=small,fill='white')
    return out
for gait in ['Walk','Sprint']:
    for label,fs in [('entry_circle_recovery',[13,37,61,265,289,337]),('right_and_s',[85,109,145,181,397,445])]:
        im=Image.new('RGB',(1440,660),(19,25,32))
        for j,f in enumerate(fs):im.paste(posepair(gait,f),((j%3)*480,(j//3)*330))
        im.save(OUT/(gait.lower()+'_'+label+'_poses.jpg'),quality=95)
html='''<!doctype html><html><head><meta charset="utf-8"><title>R2-T Turning study</title><style>body{background:#121a23;color:#e7eef5;font:16px system-ui;max-width:1100px;margin:30px auto;padding:20px}video{width:min(100%,720px)}img{max-width:100%}a{color:#8fd7ec}button{padding:10px;margin:4px;cursor:pointer}p{line-height:1.55}.note{color:#afc3d3}</style></head><body><h1>R2-T — Walk / Sprint turning study</h1><p>A = preserved R1 gait with path/heading only. B = identical phase, path, cadence and camera with absolute turning-pose blending. Walk above; Sprint below.</p><video id="reel" src="turning_AB_24fps.mp4" controls loop preload="metadata" poster="ab_frames/0289.png"></video><p>24 FPS · 1.0× · 19 seconds · fixed world camera · hard cuts between path tests</p><div>'''
for case in meta['cases']:
    html+=f'<button onclick="let v=document.getElementById(\'reel\');v.currentTime={case["start_seconds"]};v.play()">{case["name"]}</button>'
html+='''</div><p class="note">These are sustained turning cycles. A separate preview parent carries world translation and yaw. Turn entry/exit does not restart the gait. The circle turn sign stays consistent through every heading.</p><p><a href="turning_AB_24fps.mp4">Open/download full H.264 preview</a> · <a href="turning_AB_excerpt.gif">GIF fallback: left/right bends, first six seconds</a> · <a href="R2_REPORT.txt">Full report</a></p><h2>Pose detail sheets</h2><p class="note">Each A/B pair uses one shared crop and scale. These detail crops remove travel from the sheet only; use the fixed-camera movie to judge world motion. Times refer to the preview, not the source recording.</p>'''
for gait in ['walk','sprint']:
    for label in ['entry_circle_recovery','right_and_s']:
        name=gait+'_'+label+'_poses.jpg';html+=f'<p><a href="{name}">{gait.title()} — {label.replace("_"," ")}</a></p><img src="{name}">'
html+='''<h2>Elevated gameplay camera</h2><p class="note">Project camera orientation and 14.5-unit vertical scale. The labeled A/B stages carry identical trajectories. This camera is fixed, not orbiting.</p>'''
for f in [37,289,397,445]:html+=f'<p>Preview t={(f-1)/24:.3f}s</p><img src="gameplay_{f:04d}.png">'
html+='''<h2>Source evidence</h2><p>589 original frames decoded and SHA256 verified. Supplied overviews and dense sheets plus additional full-frame samples were inspected. Continuous native playback was not observed. The recording does not establish exact banking angles, head-lead timing or the source algorithm.</p><img src="source_fullframe_evidence.jpg"><p>Technical checks are not artistic approval. Foot sliding remains; no perfect planting is claimed. Original R1 and weapon assets are preserved; no Godot changes.</p></body></html>'''
(OUT/'index.html').write_text(html,encoding='utf-8')
print('R2_PACKAGE_DONE',flush=True)
