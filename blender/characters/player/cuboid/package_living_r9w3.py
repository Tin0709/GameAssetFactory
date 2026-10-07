"""Package live-rendered evidence; no Blender authoring or synthetic animation."""
from pathlib import Path
import json,hashlib
import cv2
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;OUT=BASE/'living_r9w3_review';ROOT=BASE.parents[3]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
def board(path,f):
    im=Image.open(path).convert('RGB');out=Image.new('RGB',(im.width,im.height+60),(20,26,33));out.paste(im,(0,60));dr=ImageDraw.Draw(out)
    dr.text((24,8),'A  R9-W2',font=font,fill='white');dr.text((im.width//2+24,8),'B  CANDIDATE V3',font=font,fill='white')
    dr.text((24,36),f'Source frame {f:g}  |  {(f-1)/24:.4f} s  |  matched camera / lighting / phase',font=small,fill=(185,199,214))
    p=OUT/f'contact_timestamp_f{str(f).replace(".","_")}_AB.png';out.save(p);return p.name
stills=[board(OUT/f'contact_AB_f{str(f).replace(".","_")}.png',f) for f in [189,191.5,194,244.5,256.5]]
# Inspect actual decoded frames, including reversal and contact times, as ordered sheets.
media={}
required={'contact_AB_24fps.mp4':36,'figure8_AB_24fps.mp4':288,'sweep_AB_24fps.mp4':288,'walk_local_AB_24fps.mp4':288}
for filename,expected in required.items():
    p=OUT/filename;assert p.is_file(),('Missing required preview',filename)
    cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);advertised=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));count=0;selected={}
    assert advertised==expected,(filename,'Frame range does not match required source interval',advertised,expected)
    start=176 if p.name.startswith('contact') else 1
    wanted={max(0,int(f-start)):f for f in [1,73,145,176,187,191,194,196,211,217,244,256,288] if start<=f<start+expected}
    while True:
        ok,frame=cap.read()
        if not ok:break
        if count in wanted:selected[wanted[count]]=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
        count+=1
    cap.release();assert count==expected and fps==24,(p.name,count,expected,fps)
    media[p.name]={'fps':fps,'decoded_frames':count,'duration_seconds':count/fps,'source_start_frame':start}
    thumb_w=720;thumb_h=round(next(iter(selected.values())).height*thumb_w/next(iter(selected.values())).width)
    sheet=Image.new('RGB',(thumb_w*2,(thumb_h+32)*((len(selected)+1)//2)),(20,26,33));dr=ImageDraw.Draw(sheet)
    for i,(f,im) in enumerate(selected.items()):
        x=(i%2)*thumb_w;y=(i//2)*(thumb_h+32);sheet.paste(im.resize((thumb_w,thumb_h)),(x,y+32));dr.text((x+8,y+4),f'Frame {f} | {(f-1)/24:.3f} s',font=small,fill='white')
    sheet.save(OUT/(p.stem+'_ordered.png'))
(OUT/'media_validation.json').write_text(json.dumps(media,indent=2))
before=json.loads((OUT/'protected_files.json').read_text());changed=[];missing=[]
for name,digest in before.items():
    p=ROOT/name
    if not p.is_file():missing.append(name)
    elif hashlib.sha256(p.read_bytes()).hexdigest()!=digest:changed.append(name)
protection={'checked_files':len(before),'changed':changed,'missing':missing,'passed':not changed and not missing}
(OUT/'file_preservation.json').write_text(json.dumps(protection,indent=2));assert protection['passed'],protection
sections=[('Complete stationary sweep','sweep_AB_24fps.mp4',1),('Close side contact interval','contact_AB_24fps.mp4',176),('Walk composition — original gait phase','walk_local_AB_24fps.mp4',1),('Figure-eight — original path and gait','figure8_AB_24fps.mp4',1)]
html='''<!doctype html><html><meta charset="utf-8"><title>R9-W3 contact review</title><style>body{background:#141a21;color:#e8edf3;font:17px system-ui;margin:30px auto;max-width:1440px;padding:0 24px}h1{font-size:28px}h2{font-size:21px;margin-top:32px}p{max-width:1000px;line-height:1.5}video,img{width:100%;background:#202933;border-radius:5px}.labels{display:grid;grid-template-columns:1fr 1fr;font-weight:600;padding:12px}a{color:#91c9ff}.time{font-variant-numeric:tabular-nums;color:#b5c6d9;padding:8px}button{padding:8px;margin-right:8px;cursor:pointer}</style><h1>R9-W3 — targeted stock / right upper-arm review</h1><p>A = R9-W2. B = candidate V3. Same camera projection, timing, path and lower-body phase. Only the right upper-arm and forearm rotation curves changed. Rifle and support-arm motion are preserved.</p><p><b>ARTISTIC STATUS: AWAITING HUMAN REVIEW.</b> The reported overlap is reduced, with residual edge contact elsewhere. Numerical checks are sampled evidence. Inspection here used ordered frames, not continuous perceptual playback.</p><p><a href="R9_W3_REPORT.txt">Focused report</a> · <a href="validation.json">Contact validation</a> · <a href="review_validation.json">Composition / temporal validation</a></p>'''
for title,filename,start in sections:
    html+=f'<h2>{title}</h2><div class="labels"><span>A · R9-W2</span><span>B · CANDIDATE V3</span></div><video controls loop preload="metadata" data-start="{start}" src="{filename}"></video><div class="time"></div>'
    if start==1:html+='<button data-frame="191.5">Reported contact · 7.94 s</button><button data-frame="145">Reversal · 6.00 s</button><button data-frame="244.5">Second interval · 10.15 s</button>'
html+='<h2>Timestamped contact stills</h2>'+''.join(f'<p><img src="{name}" loading="lazy"></p>' for name in stills)
html+='''<script>document.querySelectorAll('video').forEach(v=>{const t=v.nextElementSibling;function stamp(){const f=+v.dataset.start+v.currentTime*24;t.textContent=`Source frame ${f.toFixed(1)} · ${((f-1)/24).toFixed(3)} s · 24 fps`;};v.addEventListener('timeupdate',stamp);v.addEventListener('loadedmetadata',stamp);let b=t.nextElementSibling;while(b?.tagName==='BUTTON'){b.addEventListener('click',()=>{v.pause();v.currentTime=(+b.dataset.frame-+v.dataset.start)/24});b=b.nextElementSibling}});</script></html>'''
# Capture each button's frame value, rather than the advancing loop binding.
html=html.replace("b.addEventListener('click',()=>{v.pause();v.currentTime=(+b.dataset.frame-+v.dataset.start)/24});", "{const target=+b.dataset.frame;b.addEventListener('click',()=>{v.pause();v.currentTime=(target-+v.dataset.start)/24});}")
(OUT/'index.html').write_text(html,encoding='utf8')
print(json.dumps({'media':media,'preservation':protection,'stills':stills}))
