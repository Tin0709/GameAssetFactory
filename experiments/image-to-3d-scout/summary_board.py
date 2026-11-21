"""Compact side-by-side Scout comparison for the two primary views."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from compare import fit

root=Path(__file__).resolve().parent/"private"
sets=[
    ("Concept gốc","inputs"),
    ("Dựng thủ công trước đây","manual-studio"),
    ("Hunyuan bốn góc · đã chỉnh","multi-refined"),
    ("Blender mô-đun · UV 64 × 64","tailoring-3"),
]
views=[("front","Chính diện"),("hero","Góc 3/4"),("back","Mặt sau")]
w,h=229,352
board=Image.new("RGBA",(32+w*len(sets),64+h*len(views)),"#1e1a20")
draw=ImageDraw.Draw(board)
basic="C:/Windows/Fonts/segoeui.ttf"
bold="C:/Windows/Fonts/segoeuib.ttf"
def label(x,y,value,size,font,color):
    draw.text((x,y),value,font=ImageFont.truetype(font,size),fill=color)
for col,(title,section) in enumerate(sets):
    x=16+col*w
    label(x+6,15,title,15,bold,"#deac72" if col==0 else "#eaddd2")
    for row,(view,text) in enumerate(views):
        y=48+h*row
        draw.rounded_rectangle((x+2,y,x+w-3,y+h-13),radius=6,fill="#28232b")
        if col==0:
            label(x+12,y+8,text,13,basic,"#f1ddc9")
        image=fit(Image.open(root/section/f"{view}.png"),True)
        scale=.8
        resized=image.resize((int(image.width*scale),int(image.height*scale)),Image.Resampling.LANCZOS)
        board.alpha_composite(resized,(x+(w-resized.width)//2,y+27))
board.convert("RGB").save(root/"comparison/Scout - PoC overview.png",optimize=True)


