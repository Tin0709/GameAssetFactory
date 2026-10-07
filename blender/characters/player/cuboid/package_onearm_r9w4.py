"""Package real Blender renders; decode the complete explicit movie inventory."""
from pathlib import Path
import argparse, hashlib, html, json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory')
BASE = ROOT/'blender/characters/player/cuboid'
OUT = BASE/'living_r9w4_review'
CATEGORIES = ['Rifle', 'Pistol', 'Shotgun']
EXPECTED = {f'{c}_{m}': n for c in CATEGORIES for m,n in [('Hold',96),('Move',64),('AimAround',288),('Turn',456)]}
EXPECTED['Sprint_All'] = 208
FONT = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 22)
SMALL = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)

def caption(draw, xy, text, small=False):
    draw.text(xy, text, font=SMALL if small else FONT, fill='#e5ecf2')

def still_boards():
    boards=[]
    for cat in CATEGORIES:
        for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
            board=Image.new('RGB',(1440,1560),'#111c25'); d=ImageDraw.Draw(board)
            caption(d,(20,12),f'{cat} / {mode} / frame {f} / {(f-1)/24:.3f}s — R9-W4')
            caption(d,(20,48),'A — exact W3 rifle' if cat=='Rifle' else 'A — previous compact hold adapted to '+cat.lower(),True)
            caption(d,(740,48),'B — left carries / right hovers',True)
            for row,view in enumerate(['Front','Side','Rear']):
                for col,label in enumerate(['A','B']):
                    p=OUT/f'{cat}_{mode}_f{f}_{label}_{view}.png'
                    im=Image.open(p).convert('RGB').resize((720,480))
                    board.paste(im,(col*720,100+row*486))
                caption(d,(12,104+row*486),view+' 3/4' if view!='Side' else view,True)
            p=OUT/f'{cat}_{mode}_f{f}_three_views_AB.jpg';board.save(p,quality=92);boards.append(p.name)
    return boards

def movies():
    import cv2
    rows={};sheets=[]
    for job,count in EXPECTED.items():
        p=OUT/(job+'_AB_24fps.mp4')
        if not p.is_file(): raise FileNotFoundError(p)
        if job.endswith('_Turn'): wanted=[1,25,49,73,109,145,193,241,301,349,409,456]
        elif job.endswith('_AimAround'): wanted=[1,49,73,145,217,288]
        elif job.endswith('_Move'): wanted=[1,9,17,33,49,64]
        elif job=='Sprint_All': wanted=[1,14,52,104,156,208]
        else: wanted=[1,17,33,49,73,96]
        cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);meta_count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));frames={};decoded=0;dims=None
        while True:
            ok,frame=cap.read()
            if not ok:break
            decoded+=1;dims=(frame.shape[1],frame.shape[0])
            if decoded in wanted:frames[decoded]=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
        cap.release()
        if decoded!=count or meta_count!=count or abs(fps-24)>1e-4 or len(frames)!=len(wanted):
            raise AssertionError((job,decoded,meta_count,fps,len(frames),count))
        # Full A/B frames are retained; contact sheets show chronological, real poses.
        cell_w=960;cell_h=720 if job=='Sprint_All' else 320
        sheet=Image.new('RGB',(cell_w*2,(cell_h+34)*((len(wanted)+1)//2)+72),'#111c25');d=ImageDraw.Draw(sheet)
        caption(d,(12,12),job+' — ordered frames, A left / B right')
        caption(d,(12,43),'Sprint rows: rifle / pistol / shotgun' if job=='Sprint_All' else 'Native 24 fps; view the movie to judge timing.',True)
        for idx,f in enumerate(wanted):
            x=(idx%2)*cell_w;y=72+(idx//2)*(cell_h+34)
            sheet.paste(frames[f].resize((cell_w,cell_h)),(x,y))
            caption(d,(x+12,y+cell_h+6),f'frame {f} / {(f-1)/24:.3f}s',True)
        name=job+'_ordered_AB.jpg';sheet.save(OUT/name,quality=92);sheets.append(name)
        rows[job]={'file':p.name,'decoded_frames':decoded,'metadata_frames':meta_count,'fps':fps,'width':dims[0],'height':dims[1],'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'loop':job!='Sprint_All' and not job.endswith('_Turn')}
    result={'passed':True,'required_movies':len(EXPECTED),'movies':rows,'ordered_sheets':sheets}
    (OUT/'media_validation.json').write_text(json.dumps(result,indent=2));return result

def protection():
    original=json.loads((OUT/'protected_files.json').read_text());changed=[];missing=[]
    for rel,sha in original.items():
        p=ROOT/rel
        if not p.is_file():missing.append(rel)
        elif hashlib.sha256(p.read_bytes()).hexdigest()!=sha:changed.append(rel)
    result={'passed':not changed and not missing,'checked_files':len(original),'changed':changed,'missing':missing}
    (OUT/'file_preservation.json').write_text(json.dumps(result,indent=2))
    if not result['passed']:raise AssertionError(result)
    return result

def review_page(boards,media):
    blocks=[]
    for cat in CATEGORIES:
        blocks.append(f'<section id="{cat}"><h2>{cat}</h2><p>A: '+('exact W3 actions' if cat=='Rifle' else 'previous compact hold adapted to this native asset; no prior category living study existed')+'. B: new one-arm study.</p>')
        for mode in ['Hold','Move','AimAround','Turn']:
            job=cat+'_'+mode;row=media['movies'][job];loop=' loop' if row['loop'] else ''
            blocks.append(f'<h3>{mode} — A left / B right</h3><video controls muted preload="metadata"{loop} src="{row["file"]}"></video><p><a href="{job}_ordered_AB.jpg">Ordered frames</a></p>')
        for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
            name=f'{cat}_{mode}_f{f}_three_views_AB.jpg';blocks.append(f'<details><summary>{mode} frame {f}: front / side / rear</summary><a href="{name}"><img loading="lazy" src="{name}"></a></details>')
        blocks.append('</section>')
    blocks.append('<section id="Sprint"><h2>Sprint composition</h2><p>Rows: rifle, pistol, shotgun. A left / B right. This 208-frame excerpt is not a loop; the Blender scene contains the full 832-frame joint loop.</p><video controls muted preload="metadata" src="Sprint_All_AB_24fps.mp4"></video><p><a href="Sprint_All_ordered_AB.jpg">Ordered sprint frames</a></p></section>')
    page='''<!doctype html><html><head><meta charset="utf-8"><title>R9-W4 One-arm hold review</title><style>body{background:#111c25;color:#e5ecf2;font:17px Arial;margin:24px auto;max-width:1280px;padding:0 20px}a{color:#8fcaff}nav{position:sticky;top:0;background:#172a37;padding:14px;z-index:2}nav a{margin-right:25px}section{border-top:1px solid #385063;margin-top:35px;padding-top:15px}video,img{width:100%;background:#0b1118}summary{cursor:pointer;padding:12px}h1{font-size:30px}p{line-height:1.5}.status{color:#f4ce83}</style></head><body><h1>R9-W4 — One-arm weapon-hold study</h1><p class="status">ARTISTIC STATUS: AWAITING HUMAN REVIEW</p><p>Left arm carries; right block hand hovers near the receiver. Both arms extend forward. Blender study only. The supplied crossbow board is the artistic direction.</p><nav><a href="#Rifle">Rifle</a><a href="#Pistol">Pistol</a><a href="#Shotgun">Shotgun</a><a href="#Sprint">Sprint</a><a href="R9W4_REPORT.txt">Report</a></nav><p>Compare silhouette, visible gap and body coordination in the movies. Turning reels preserve the original path-case cuts and should not be looped. Occlusion can hide the gap in some views; geometry checks do not establish artistic approval.</p>'''+''.join(blocks)+'</body></html>'
    (OUT/'index.html').write_text(page,encoding='utf-8')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--stills-only',action='store_true');args=parser.parse_args()
    boards=still_boards()
    if args.stills_only:print(json.dumps({'boards':len(boards)}))
    else:
        media=movies();preserved=protection();review_page(boards,media)
        print(json.dumps({'movies':len(media['movies']),'boards':len(boards),'preservation':preserved}))
