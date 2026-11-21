"""Paint reusable 64×64 palettes and the Forager's front facial expression."""
from pathlib import Path
import random

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent / "private" / "textures"
OUT.mkdir(exist_ok=True, parents=True)

# Midtones and swatches are authored in sRGB. Larger patches have priority
# over grain, leaving the lighting to describe the volume.
palettes = {
    "olive": ["373724","413f2b","4d482e","574f33","635939","6b6140","7a6e45"],
    "gold": ["824c20","9a642f","aa7537","b5803a","c48e47","d19b52","d9a860"],
    "lining": ["282620","302c21","3a3427","453b2b","51462f","615336","6b5f3b"],
    "hair": ["231819","2b2021","332527","3c2a2c","453031","503536","5d3e3e"],
    "rust": ["682c1a","793622","8b3b24","9d4729","ac502e","b75530","c36339"],
    "saddle": ["422a24","50332a","603b2c","704733","7b4e36","87573c","996647"],
    "darkleather": ["332422","432c26","503229","5f3d2c","6a412e","764831","89553b"],
    "linen": ["8c6b53","a28062","ae8b6c","ba9877","c5a485","d0b397","dac2a5"],
    "skin": ["92634f","b77c60","c8896a","d69877","e2a383","e9af90","ebb397"],
    "metal": ["6c5850","85736a","9c877a","b4a093","c4b1a3","d5c2b5","decbbe"],
    "thread": ["9d7756","b88d65","d1aa7e","e2bf94","e7c59e","ebccaa","f0d3b2"],
}

def write(name, img):
    img.save(OUT / f"{name}.png", optimize=True)

for index,(name,palette) in enumerate(palettes.items()):
    img = Image.new("RGB",(64,64),"#"+palette[3])
    draw = ImageDraw.Draw(img)
    rng = random.Random(187 + index * 59)
    for row in range(13):
        left = 0
        while left < 64:
            width = rng.choice([4,5,6,8,10,13])
            weights = [7,23,39,24,7] if name in ("olive","rust","gold") else [3,16,50,25,6]
            color = rng.choices([1,2,3,4,5], weights)[0]
            draw.rectangle((left,row*5,left+width-1,row*5+4),fill="#"+palette[color])
            left += width
    for x,y,dx,dy,color in ((8,15,8,10,2),(35,25,9,5,2),(47,6,11,10,4),(25,49,9,10,1),(12,37,12,6,4)):
        draw.rectangle((x,y,x+dx-1,y+dy-1),fill="#"+palette[color])
    write(name,img)

hood = Image.open(OUT/"olive.png").convert("RGB")
for y in range(64):
    # Lower hood folds carry muted olive shadow. Leave the top panels warm.
    band = min(1,max(0,(y-26)/33))
    for x in range(64):
        r,g,b = hood.getpixel((x,y))
        hood.putpixel((x,y),(int(r*(.985-.105*band)),int(g*(1-.068*band)),int(b*(.96-.08*band))))
write("hood-olive",hood)

face = Image.new("RGB",(64,64),"#da9571")
d = ImageDraw.Draw(face)
def rect(box,color):
    d.rectangle(box, fill="#"+color)
# Thin temple shadows and profile warmth, with a quiet area between the eyes.
rect((0,0,6,63),"bb785a")
rect((7,0,11,63),"cb9073")
rect((55,0,63,63),"bf8269")
rect((48,0,54,11),"c78c6e")
rect((10,0,53,13),"c0866b")
rect((13,36,49,54),"eba57e")
rect((10,44,20,52),"e49a76")
rect((47,44,54,52),"de936e")
rect((12,46,22,54),"d89779")
rect((44,45,54,54),"dc9a7d")
rect((26,18,38,35),"dd956f")
rect((29,32,37,43),"eda67f")
rect((29,43,37,44),"ce8e72")
rect((31,50,35,51),"ae735e")
rect((31,52,34,52),"dfa182")
rect((0,57,63,63),"cc8d70")
# Four generous pixels across the whites and a tall brown pupil.
for a,b,white_left in ((12,25,True),(40,53,False)):
    rect((a,23,b,42),"402a2a")
    rect((a,26,b,42),"eed3bd")
    if white_left:
        rect((a+5,24,b,42),"2c2024")
        rect((a+5,37,b,42),"472e30")
        rect((a,25,a+4,29),"a78073")
    else:
        rect((a,24,b-5,42),"2c2024")
        rect((a,37,b-5,42),"472e30")
        rect((b-4,25,b,29),"a78073")
# The brows are slightly staggered, widening the expression as it turns.
rect((10,17,20,20),"392529")
rect((19,19,26,22),"332226")
rect((38,19,45,22),"352326")
rect((45,17,54,20),"40292a")
write("face",face)

