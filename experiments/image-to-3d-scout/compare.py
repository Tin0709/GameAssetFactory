"""Compare a registered turnaround against transparent renders using the installed skill."""
from argparse import ArgumentParser
import importlib.util
import json
from pathlib import Path
import tempfile

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent
SIZE=(254,386)
HEIGHT=354
VIEWS={"front":"Chính diện","hero":"Góc 3/4","right":"Nghiêng phải","back":"Mặt sau","left":"Nghiêng trái"}

def fit(image, sole_center):
    image=image.convert("RGBA")
    m=np.asarray(image.getchannel("A"))>100
    yy,xx=np.where(m)
    bottom=yy.max()+1
    top=yy.min()
    if sole_center:
        feet=xx[yy>bottom-.075*(bottom-top)]
        center=(feet.min()+feet.max())/2
    else:
        center=(xx.min()+xx.max())/2
    ratio=HEIGHT/(bottom-top)
    transform=np.float32([[ratio,0,SIZE[0]/2-ratio*center],[0,ratio,12-ratio*top]])
    array=cv2.warpAffine(np.asarray(image),transform,SIZE,flags=cv2.INTER_LINEAR)
    return Image.fromarray(array)

def create(input_dir, runs, out):
    out.mkdir(parents=True,exist_ok=True)
    path=Path.home()/".codex/skills/create-3d-model/references/modules/multiview-fit-loop/scripts/multiview_fit_report.py"
    spec=importlib.util.spec_from_file_location("fit_report",path)
    fit_report=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fit_report)
    sources={}
    for view,label in VIEWS.items():
        image=Image.open(input_dir/f"{view}.png")
        sources[view]=fit(image,True)
    reports={}
    with tempfile.TemporaryDirectory(prefix="fit-",dir=out) as root:
        scratch=Path(root)
        for view,img in sources.items():
            img.save(scratch/f"reference-{view}.png")
        for title,folder in runs:
            parsed={}
            for view in VIEWS:
                candidate=fit(Image.open(folder/f"{view}.png"),True)
                candidate.save(scratch/f"{view}.png")
                dest=out/"overlays"/folder.name/f"{view}.png"
                parsed[view]=fit_report.compare(scratch/f"reference-{view}.png",scratch/f"{view}.png",dest,"alpha","alpha")
                parsed[view]["reference"]=str(input_dir/f"{view}.png")
                parsed[view]["render"]=str(folder/f"{view}.png")
            reports[title]=parsed
        for keys,filename in ((["front","hero"],"Scout - comparison.png"),(["right","back","left"],"Scout - other views.png")):
            rows=[("Concept",{v:sources[v] for v in keys})]
            for title,folder in runs:
                rows.append((title,{v:fit(Image.open(folder/f"{v}.png"),True) for v in keys}))
            margin=18
            board=Image.new("RGBA",(margin*2+len(keys)*SIZE[0],55+len(rows)*(SIZE[1]+27)), "#1e1a20")
            draw=ImageDraw.Draw(board)
            font=ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf",21)
            small=ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf",14)
            for col,view in enumerate(keys):
                draw.text((margin+col*SIZE[0]+9,14),VIEWS[view],font=font,fill="#f5e5d4")
            for r,(title,values) in enumerate(rows):
                y=48+r*(SIZE[1]+27)
                draw.text((margin+9,y),title,font=small,fill="#dbaf78" if r==0 else "#c6dbd8")
                for col,view in enumerate(keys):
                    x=margin+col*SIZE[0]
                    draw.rounded_rectangle((x+4,y+22,x+SIZE[0]-4,y+22+SIZE[1]),radius=7,fill="#28222b")
                    board.alpha_composite(values[view],(x,y+22))
            board.convert("RGB").save(out/filename,optimize=True)
    data={"alignment":"Same normalized height and sole center per image. Near-profile drawings and hero pose are estimates.", "runs":reports}
    (out/"silhouette.json").write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding="utf8")
    print({title:{v:round(m["iou"]*100,1) for v,m in views.items()} for title,views in reports.items()})

if __name__=="__main__":
    p=ArgumentParser(description=__doc__)
    p.add_argument("inputs",type=Path)
    p.add_argument("output",type=Path)
    p.add_argument("--run",nargs=2,action="append",required=True,metavar=("LABEL","RENDER_DIRECTORY"))
    a=p.parse_args()
    create(a.inputs,[(name,Path(path)) for name,path in a.run],a.output)

