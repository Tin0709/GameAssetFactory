"""Package renders and preserve the user's three local references with hashes."""
from pathlib import Path
import json,shutil,hashlib
import cv2
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_set_v002'
M=json.loads((OUT/'manifest.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',26)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',21)
names={'stationary':'Đứng im một chỗ nhảy.mp4','walk':'Vừa đi bộ vừa nhảy.mp4','run':'Vừa chạy vừa nhảy.mp4'}
metadata={}
for kind,c in M['cases'].items():
    ref=OUT/'references'/kind;ref.mkdir(parents=True,exist_ok=True)
    src=Path('C:/Users/ADMIN/Videos/Screen Recordings')/names[kind]
    shutil.copy2(src,ref/'source.mp4')
    cap=cv2.VideoCapture(str(src));fps=cap.get(cv2.CAP_PROP_FPS);count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    metadata[kind]={'original_path':str(src),'copy':f'references/{kind}/source.mp4','sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
        'fps':fps,'frames':count,'width':int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),'height':int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),'seconds':count/fps}
    cap.release()
    for name in ['overview','detail']:
        shutil.copy2(TMP/f'{kind}_{name}.jpg',ref/f'{name}.jpg')
    apex=(c['take']+c['land'])//2
    def phase(f):
        if f<=c['take']:return 'Entry / last support' if f==c['take'] else 'Entry / prepare'
        if f<apex:return 'Rising'
        if f==apex:return 'Air pose'
        if f<c['land']:return 'Descending / prepare contact'
        if f==c['land']:return 'First contact'
        if f==c['end']:return 'Idle' if kind=='stationary' else 'Next stride'
        return 'Absorb / resume'
    folder=TMP/'encode'/kind;folder.mkdir(parents=True,exist_ok=True)
    per_take=15+c['end']+15
    timeline=([1]*15+list(range(1,c['end']+1))+[c['end']]*15)*3
    for i,f in enumerate(timeline,1):
        canvas=Image.new('RGB',(1440,650),(20,28,37));d=ImageDraw.Draw(canvas)
        for x,view in [(0,'gameplay'),(720,'side')]:canvas.paste(Image.open(TMP/'frames'/kind/view/f'{f:03d}.png'),(x,70))
        d.text((20,8),c['label'].upper()+'   /   3/4 + SIDE',font=font,fill='white')
        held=(i-1)%per_take<15 or (i-1)%per_take>=15+c['end']
        d.text((20,40),f"{'Review pause' if held else '1x speed'} | 30 FPS | take {(i-1)//per_take+1}/3 | new Blender study",font=small,fill=(141,218,208))
        d.text((20,617),f'F{f:02d} / {phase(f)}',font=small,fill='white')
        d.text((760,617),'Preview travel only; not a seamless loop',font=small,fill=(190,203,214))
        canvas.save(folder/f'{i:04d}.png')
    metadata[kind]['preview']={'file':f'jump_{kind}_1x.mp4','frames':len(timeline),'fps':30,'size':[1440,650],'source_motion_seconds':(c['end']-1)/30}
    phases=[1,c['take'],c['take']+2,apex,c['land']-2,c['land'],c['land']+2,c['end']]
    sheet=Image.new('RGB',(1440,730),(20,28,37));d=ImageDraw.Draw(sheet)
    d.text((18,10),c['label'].upper()+f" / 30 FPS / {(c['end']-1)/30:.3f} s",font=font,fill='white')
    for j,f in enumerate(phases):
        x=j%4*360;y=60+j//4*326
        d.text((x+8,y+4),f'F{f:02d} / {phase(f)}',font=small,fill=(141,218,208))
        sheet.paste(Image.open(TMP/'frames'/kind/'gameplay'/f'{f:03d}.png').resize((356,267),Image.Resampling.LANCZOS),(x+2,y+42))
    sheet.save(OUT/f'{kind}_contact_sheet.jpg',quality=93)
    shutil.copy2(TMP/'frames'/kind/'gameplay'/f'{apex:03d}.png',OUT/f'{kind}_apex.png')
(OUT/'references.json').write_text(json.dumps(metadata,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v['preview'] for k,v in metadata.items()},indent=2))
