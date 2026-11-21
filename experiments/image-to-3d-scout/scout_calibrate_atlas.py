"""Targeted palette calibration using only existing nearest-filtered atlas cells."""
from pathlib import Path
import numpy as np
from PIL import Image

R=Path(__file__).resolve().parent/"private"/"source-fit"/"tones"
IN=R/"original"
OUT=R/"calibrated"
OUT.mkdir(exist_ok=True)

def get(name):
    return np.array(Image.open(IN/(name+".png")).convert("RGBA")).astype(float)

def save(a,n):
    Image.fromarray(np.clip(np.rint(a),0,255).astype("uint8"),"RGBA").save(OUT/(n+".png"))

def rgb_adjust(pixel,scale,bias=(0,0,0)):
    pixel[...,:3]*=np.array(scale)
    pixel[...,:3]+=np.array(bias)

def cell(a,i,scale,bias=(0,0,0)):
    # Atlas addressing in Blender is bottom-up.
    top=48-(i//4)*16; left=(i%4)*16
    rgb_adjust(a[top:top+16,left:left+16],scale,bias)

hood=get("hood")
rgb_adjust(hood,(.76,.80,.87))
save(hood,"hood")
older=get("older_hood")
olive=older[:,:,0]<153
older[olive,:3]*=np.array((.76,.81,.89))
save(older,"older_hood")
outer=get("outer")
# Existing cloth UV islands cover the yoke, front and back panel, liner and hem.
# Preserve the separate shoulder badge tile and reduce yellow bias in the olive.
iscloth=np.ones((64,64),bool)
iscloth[16:26,16:26]=False
outer[iscloth,:3]*=np.array((.91,.95,1.00))
save(outer,"outer")
body=get("body")
cell(body,5,(1.02,1.01,1.00),(8,4,2))  # base arms, cheeks and fingers
cell(body,7,(1.11,1.08,1.12),(5,4,7))  # plum-charcoal trousers
cell(body,3,(1.10,1.11,1.10),(2,2,2))  # lighter fold in scarf
cell(body,4,(1.04,1.02,.97),(8,2,1))   # warm linen underlayer
cell(body,14,(.90,.87,.91),(0,0,1))    # nape hair shadow
cell(body,15,(.90,.88,.89),(0,0,1))
save(body,"body")
trim=get("trim")
cell(trim,3,(1.07,1.09,1.14),(5,5,5)) # olive face wrap
cell(trim,4,(.86,.86,.90),(0,0,1))    # shade at the roots of the fringe
cell(trim,5,(.78,.79,.86),(1,1,2))    # chestnut locks, less red on the back
cell(trim,6,(1.04,1.02,1.00),(8,4,1)) # skin chips / fingers
cell(trim,8,(.94,.94,1.00))           # brown leather distinct from gold
cell(trim,11,(.95,.91,.90))          # linen wraps
cell(trim,12,(1.11,1.09,1.14),(2,2,4)) # fingerless glove shadow
cell(trim,15,(.93,.90,.91))           # soft sclera
save(trim,"trim")
boot=trim.copy()
cell(boot,8,(.80,.82,.92),(2,3,4))
cell(boot,9,(.94,.91,.97),(0,0,2))
cell(boot,10,(.88,.89,.94))
save(boot,"boot")

