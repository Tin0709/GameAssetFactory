"""Paint the Forager's region-specific pixel materials."""
from pathlib import Path
import random
from PIL import Image,ImageDraw

D=Path(__file__).resolve().parent/"private"/"paint"
D.mkdir(parents=True,exist_ok=True)
palettes={
"moss":("343622","40412a","4a472f","544e33","62583a","6d603b","7b6a48"),
"mossDark":("2c291c","363423","3e3d28","45402b","4c462e","555034","5d5538"),
"lining":("211c19","2a241c","322c21","3b3425","433b28","4a412c","534830"),
"gold":("885622","9c6528","b07835","c08a40","ce974b","dda652","e3ac62"),
"rust":("5b2c1e","723723","834027","96472a","ad512e","bd5e35","cb6b40"),
"hair":("24191b","312022","3b282b","452f31","513639","5e3c40","694345"),
"leather":("3d261e","503223","5e3b2a","6b442f","7c4e34","8b5639","9a6646"),
"warmLeather":("532c21","653823","75452b","864c2e","965536","a9643d","b9724a"),
"boot":("2c201b","37261e","462e23","4e3528","5e3b2d","714835","84523d"),
"coal":("322922","3b3229","43382f","4b4035","57473a","645242","736052"),
"linen":("92715e","aa8570","b8997e","c8a88a","d5b195","dfbfa3","e7cbb1"),
"cream":("9d7c64","b78f71","c6a081","d8b393","e1bc9b","edc9a7","f2d3b7"),
"skin":("a46b52","bd7d5e","ce8a67","db956f","e7a078","f1ac83","f2b48d"),
"iron":("65514b","7a655d","907d76","a18e83","b2a096","c2b0a6","d3c0b3"),
"leaf":("42442a","515435","626339","747443","82874b","90955a","a4a26c"),
"purple":("613d62","764774","8e5684","a16595","b075a6","c087b7","d6a2c9"),
"wood":("4a291e","623a28","73432c","854b2f","925535","a66941","b47a50"),
"stone":("594b52","6a5a64","7b6971","907c82","a18b8e","ad9598","bca8a8"),
}
def save(img,name):
    img.save(D/(name+".png"),optimize=True)

for i,(name,colors) in enumerate(palettes.items()):
    rng=random.Random(542+91*i)
    img=Image.new("RGB",(64,64),"#"+colors[3])
    draw=ImageDraw.Draw(img)
    for y in range(0,64,5 if name in ("hair","linen","iron") else 6):
        x=0
        while x<64:
            w=rng.choice((4,5,6,7,9,10,12))
            col=rng.choices(range(7),[1,7,22,46,18,5,1] if name in ("boot","warmLeather","leather","coal") else [3,12,22,36,19,7,1])[0]
            draw.rectangle((x,y,x+w-1,y+(4 if name in ("hair","linen","iron") else 5)),fill="#"+colors[col])
            x+=w
    for x,y,side,color in ((8,15,8,2),(34,24,10,2),(46,37,9,4),(24,48,11,1),(15,6,9,4)):
        draw.rectangle((x,y,x+side-1,y+5),fill="#"+colors[color])
    save(img,name)

face=Image.new("RGB",(64,64),"#e09469")
d=ImageDraw.Draw(face)
def pix(x0,y0,x1,y1,hex):
    d.rectangle((x0,y0,x1,y1),fill="#"+hex)

pix(0,0,8,63,"aa6c51")
pix(9,0,15,52,"c48061")
pix(55,0,63,63,"b77659")
pix(46,0,55,19,"c58565")
pix(15,0,52,17,"be7d60")
pix(13,38,52,58,"ed9d72")
pix(15,49,22,53,"e69b76")
pix(47,47,54,53,"da906f")
pix(26,31,39,45,"ec9f73")
pix(29,43,35,48,"efa77a")
pix(30,51,34,52,"b97a5e")
pix(30,53,34,53,"eda57b")
# Dark pupils are compact on the inner edges; sclera appears on the outside.
for x,w,flip in ((13,12,False),(40,11,True)):
    pix(x-1,25,x+w,28,"3c2928")
    pix(x,28,x+w-1,43,"ead0bb")
    if not flip:
        pix(x+5,26,x+w-1,43,"2b2021")
        pix(x+5,39,x+w-1,43,"382526")
        pix(x,28,x+4,30,"a78375")
    else:
        pix(x,26,x+w-6,43,"2b2021")
        pix(x,39,x+w-6,43,"382526")
        pix(x+w-5,28,x+w-1,30,"a78375")
pix(10,20,21,23,"362321")
pix(20,21,26,24,"2b1d1d")
pix(38,21,45,24,"2b1d1d")
pix(44,19,52,22,"352321")
save(face,"face")

