"""Paint the face, iris and eyelid pixels in a native 64 x 64 atlas."""
from pathlib import Path
from PIL import Image,ImageDraw

out=Path(__file__).resolve().parent/"private/source-fit/tones/calibrated/face.png"
palette={
   "l":"#efa57d","p":"#ea9b72","s":"#dc8c66","c":"#cc7e5b","r":"#b16c52","o":"#9e5e48",
   "i":"#291d20","k":"#35272b","v":"#433230","z":"#49332d",
   "u":"#aa8073","w":"#e6c4b1","y":"#f4d5bc"
}
# 32px face island, with explicit band changes and a film-warm cheek tint.
face=[
  "oolllpoo", "ocplppco", "cslplpsc", "csppllsc",
  "slplllps", "spplllps", "psplllpp", "cspplpss",
]
img=Image.new("RGB",(64,64),palette["p"])
d=ImageDraw.Draw(img)
for j,row in enumerate(face):
    for i,key in enumerate(row):
        d.rectangle((i*4,j*4,i*4+3,j*4+3), fill=palette[key])
for y,key in enumerate("uuwwyyww"):
    d.rectangle((32,y*4,63,y*4+3),fill=palette[key])
for y,key in enumerate("iikkvvkk"):
    d.rectangle((0,32+y*4,31,35+y*4),fill=palette[key])
d.rectangle((32,32,63,63), fill=palette["o"])
img.save(out)

