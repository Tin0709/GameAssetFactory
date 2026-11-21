"""Create view sheets from the finished The Forager renders."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parent/"private"
SRC=ROOT/"04-final"
BG="#1e1821"
INK="#f0e1d0"
MUTED="#d7b188"
FONT="C:/Windows/Fonts/segoeui.ttf"
BOLD="C:/Windows/Fonts/segoeuib.ttf"

def font(size,bold=False):
    return ImageFont.truetype(BOLD if bold else FONT,size)

def place(canvas,picture,box):
    x,y,w,h=box
    picture.thumbnail((w,h),Image.Resampling.LANCZOS)
    canvas.paste(picture,(x+(w-picture.width)//2,y+(h-picture.height)//2))

def hero_comparison():
    d=Image.new("RGB",(1036,809),BG)
    draw=ImageDraw.Draw(d)
    draw.text((19,13),"The Forager · Góc 3/4",font=font(36,True),fill=INK)
    draw.text((23,66),"Concept mới",font=font(18,True),fill=MUTED)
    draw.text((537,66),"Bản dựng Blender",font=font(18,True),fill=MUTED)
    ref=Image.open(ROOT/"ref-hero.png").convert("RGB")
    # The last pixels at the lower-right belong to the detail table, outside the hero.
    pen=ImageDraw.Draw(ref)
    pen.rectangle((346,530,ref.width,ref.height),fill=ref.getpixel((345,540)))
    ref=ref.crop((0,0,404,600))
    new=Image.open(SRC/"hero.png").convert("RGB")
    h,w=new.height,new.width
    new=new.crop((int(w*.018),int(h*.058),int(w*.983),int(h*.961)))
    place(d,ref,(12,97,494,693))
    place(d,new,(530,97,494,693))
    d.save(SRC/"The Forager - Doi chieu.jpg",quality=96,subsampling=0)

def turnaround():
    tile_w,tile_h,m=234,365,16
    d=Image.new("RGB",(m*2+4*tile_w,101+tile_h),BG)
    draw=ImageDraw.Draw(d)
    draw.text((m,12),"The Forager · Toàn thân",font=font(34,True),fill=INK)
    for i,(view,label) in enumerate((("front","Chính diện"),("right","Bên phải"),
                                     ("back","Mặt sau"),("left","Bên trái"))):
        x=m+i*tile_w
        draw.text((x+5,64),label,font=font(18,True),fill=MUTED)
        image=Image.open(SRC/f"{view}.png").convert("RGB")
        place(d,image,(x+1,92,tile_w-4,tile_h))
    d.save(SRC/"The Forager - Turnaround.jpg",quality=96,subsampling=0)

hero_comparison()
turnaround()

