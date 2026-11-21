"""Measure aligned silhouette edge residuals without using colors as geometry."""
from pathlib import Path
import sys,json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from compare import fit,VIEWS
OUT=Path("private/source-fit")
OUT.mkdir(exist_ok=True)
D=Path(sys.argv[1])
font=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",13)
levels=(.028,.065,.105,.155,.21,.255,.30,.345,.385,.43,.475,.525,.58,.63,.68,.725,.775,.84,.91,.95)
summary={}
board=Image.new("RGB",(254*5,446),"#201b22")
draw=ImageDraw.Draw(board)
for i,(view,title) in enumerate(VIEWS.items()):
    masks=[]
    for folder in [Path("private/inputs"),D]:
        alpha=np.array(fit(Image.open(folder/(view+".png")),True).getchannel("A"))
        masks.append(alpha>127)
    a,b=masks
    pix=np.full((*a.shape,3),(37,31,41),np.uint8)
    pix[a]=(226,148,76)
    pix[b]=(83,188,202)
    pix[a&b]=(83,72,81)
    im=Image.fromarray(pix)
    table={}
    for frac in levels:
        j=12+round(frac*354)
        row=[]
        for mask in masks:
            values=np.flatnonzero(mask[j,:])
            row.append([int(values[0]),int(values[-1])] if len(values) else [0,0])
        table[str(frac)]=row
    summary[view]=table
    board.paste(im,(i*254,34))
    draw.text((i*254+10,12),title,font=font,fill="white")
    print(view, [(k,*row) for k,row in table.items()])
draw.text((10,422),"Vàng là phần concept rộng hơn · Xanh là phần model rộng hơn",font=font,fill="#ece0d5")
board.save(OUT/(D.name+"-edges.png"))
(OUT/(D.name+"-edges.json")).write_text(json.dumps(summary),encoding="utf8")

