"""Compare corresponding material landmarks in the registered concept and render."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import cv2
import numpy as np
import sys,json
from compare import fit

D=Path(sys.argv[1])
root=Path("private/source-fit")
ROIS={
 "front": {
   "upper olive cloth":(88,26,167,45), "bound gold":(101,48,147,56),
   "skin mid face":(116,84,138,98), "woven scarf":(97,101,151,112),
   "olive sleeve":(67,144,83,158), "arm":(61,171,74,177),
   "waist leather":(100,185,151,201), "pants":(92,217,120,241),
   "boot leather":(86,307,106,320), "toe cap":(81,329,109,348),
 },
 "hero": {
   "hood side olive":(69,63,101,95), "hood front gold":(131,45,162,55),
   "glove":(37,211,75,233), "jacket shoulder":(63,137,92,155),
   "leather purse":(88,195,110,213), "cap toe":(67,345,115,360),
 },
 "back":{
   "hood rear":(91,40,163,70), "hair":"", "cloak center":(109,234,139,255),
   "left sleeve":(64,139,85,158), "right boot":(144,315,168,345),
 }
}
ROIS["back"]["hair"]=(108,90,143,127)
result={}
font=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",14)
board=Image.new("RGB",(254*6,417),"#201b22")
draw=ImageDraw.Draw(board)
for i,(view,boxes) in enumerate(ROIS.items()):
    targets=[fit(Image.open(p/(view+".png")),True) for p in (Path("private/inputs"),D)]
    data=[np.array(v) for v in targets]
    by={}
    for name,r in boxes.items():
        x0,y0,x1,y1=r
        values=[]
        for im in data:
            crop=im[y0:y1,x0:x1]
            lab=cv2.cvtColor(crop[:,:,:3],cv2.COLOR_RGB2LAB)
            good=crop[:,:,3]>199
            use=lab[good]
            if not len(use):
                values.append([0,0,0])
            else:
                values.append([round(float(v),1) for v in np.median(use,axis=0)])
        by[name]=[values,[round(b-a,1) for a,b in zip(*values)]]
    result[view]=by
    for j,v in enumerate(targets):
        x=(i*2+j)*254
        board.paste(v,(x,26),v)
        draw.text((x+7,4),view+(" · Concept" if j==0 else " · Scout"),font=font,fill="white")
        for x0,y0,x1,y1 in boxes.values():
            draw.rectangle((x+x0,26+y0,x+x1,26+y1),outline="#eab273")
print(json.dumps(result,indent=None))
(root/(D.name+"-color.json")).write_text(json.dumps(result,indent=2),encoding="utf8")
board.save(root/(D.name+"-color.png"))

