"""Place the concept and two Scout builds in identical review frames."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from sourcefit_boards import pixels

ROOT = Path(__file__).resolve().parent / "private"
OUT = ROOT / "blocks-fit"
GROUPS = [("Concept",ROOT/"inputs"),
          ("Vòng 17",ROOT/"source-fit"/"review17-hd"),
          ("Vòng 22",OUT/"22-hd")]
FONT = "C:/Windows/Fonts/segoeui.ttf"
BOLD = "C:/Windows/Fonts/segoeuib.ttf"
TITLE = ImageFont.truetype(BOLD,34)
LABEL = ImageFont.truetype(BOLD,17)
TEXT = "#f2e7d8"
GOLD = "#e2b982"
BG = "#1c1920"
PANEL = "#29242c"

def board(title, cards, row_height, width, output):
    margin = 18
    row_start = 106
    stride = row_height+32
    canvas = Image.new("RGBA",(2*margin+width*len(cards),row_start+stride*len(GROUPS)+8),BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((margin,14), title, fill=TEXT,font=TITLE)
    for i,(_,caption,_) in enumerate(cards):
        draw.text((margin+i*width+8,66),caption,fill=TEXT,font=LABEL)
    for j,(label,folder) in enumerate(GROUPS):
        y = row_start+stride*j
        draw.text((margin+7,y-9),label,fill=GOLD,font=LABEL)
        for i,(view,_,box) in enumerate(cards):
            x=margin+i*width
            base=y+16
            draw.rounded_rectangle((x+2,base,x+width-4,base+row_height),radius=6,fill=PANEL)
            file=folder/(view+".png")
            if box is None:
                art = pixels(file,(width,row_height),row_height-18,9)
            else:
                art = pixels(file,(620,1100),1060,10).crop(box)
                max_width,max_height=width-12,row_height-12
                art.thumbnail((max_width,max_height),Image.Resampling.LANCZOS)
            canvas.alpha_composite(art,(x+(width-art.width)//2,base+(row_height-art.height)//2))
    canvas.convert("RGB").save(OUT/output,optimize=True)

board("Scout · Đối chiếu năm góc nhìn",[
    ("front","Chính diện",None),("hero","Góc 3/4",None),("right","Bên phải",None),
    ("back","Mặt sau",None),("left","Bên trái",None)],305,205,"Scout - Nam goc.png")
board("Scout · Chi tiết ghép khối vuông",[
    ("front","Viền mũ và tóc mái",(108,4,536,435)),
    ("hero","Viền mũ góc 3/4",(86,4,520,438)),
    ("back","Mép mũ và tóc gáy",(116,0,536,461)),
    ("back","Gấu áo choàng",(128,518,516,952)),
],211,239,"Scout - Chi tiet khoi vuong.png")

