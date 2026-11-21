"""Create a readable before/after sheet and four main detail comparisons."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
import cv2

ROOT=Path(__file__).resolve().parent/"private"
OUT=ROOT/"source-fit"
FINAL=OUT/"review17-hd"
work=OUT/"16-balanced"
TEXT="#f3ebdc"
GOLD="#e4ad72"
BG="#1c191f"
CARD="#282329"
REGULAR=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",16)
BOLD=ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf",19)
TITLE=ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf",32)

def pixels(path, dims, height, top):
    image=Image.open(path).convert("RGBA")
    rgb=np.asarray(image)
    ys,xs=np.where(rgb[:,:,3]>110)
    low,high=ys.min(),ys.max()
    feet=xs[ys>high-.07*(high-low)]
    center=(feet.min()+feet.max())/2
    scale=height/(high-low+1)
    m=np.float32([[scale,0,dims[0]/2-center*scale],[0,scale,top-low*scale]])
    return Image.fromarray(cv2.warpAffine(rgb,m,dims,flags=cv2.INTER_LANCZOS4))

def overview():
    views=[("front","Chính diện"),("hero","Góc 3/4"),("right","Nhìn nghiêng"),("back","Mặt sau")]
    groups=[("Concept",ROOT/"inputs"),("Bản trước",ROOT/"square-refine/06-scout"),("Scout · Vòng 17",FINAL)]
    height,width=363,252
    margin=18
    board=Image.new("RGBA",(margin*2+len(views)*width,124+len(groups)*(height+31)),BG)
    draw=ImageDraw.Draw(board)
    draw.text((margin,13),"Scout · Đối chiếu sau khi chỉnh dáng",font=TITLE,fill=TEXT)
    draw.text((margin,59),"Concept, vòng 6 và vòng 17",font=REGULAR,fill=GOLD)
    for i,(_,label) in enumerate(views):
        draw.text((margin+i*width+9,91),label,font=BOLD,fill=TEXT)
    for j,(label,folder) in enumerate(groups):
        y=124+j*(height+31)
        draw.text((margin+9,y-7),label,font=REGULAR,fill=GOLD if j!=1 else TEXT)
        for i,(name,_) in enumerate(views):
            x=margin+width*i
            draw.rounded_rectangle((x+2,y+18,x+width-4,y+18+height),radius=6,fill=CARD)
            board.alpha_composite(pixels(folder/(name+".png"),(width,height),335,13),(x,y+18))
    board.convert("RGB").save(OUT/"Scout - Doi chieu.png",optimize=True)

def details():
    cards=[
        ("Mũ, viền và khuôn mặt","front",(100,2,522,420)),
        ("Vai áo, khóa và túi","hero",(33,317,585,733)),
        ("Bốt và khóa cổ chân","hero",(83,777,559,1110)),
        ("Mép mũ, tóc và áo choàng","back",(81,0,541,897)),
    ]
    width,height=305,330
    board=Image.new("RGBA",(24+width*4,103+2*(height+30)),BG)
    draw=ImageDraw.Draw(board)
    draw.text((16,14),"Scout · Chi tiết hình học và pixel",font=TITLE,fill=TEXT)
    for col,(title,key,box) in enumerate(cards):
        x=12+width*col
        draw.text((x+5,59),title,font=REGULAR,fill=TEXT)
        for row,(label,folder) in enumerate((("Concept",ROOT/"inputs"),("Scout · Vòng 17",FINAL))):
            y=93+row*(height+30)
            draw.text((x+5,y),label,font=REGULAR,fill=GOLD)
            draw.rounded_rectangle((x+2,y+23,x+width-4,y+height+22),radius=6,fill=CARD)
            im=pixels(folder/(key+".png"),(622,1120),1090,15).crop(box)
            im.thumbnail((width-15,height-12),Image.Resampling.LANCZOS)
            board.alpha_composite(im,(x+(width-im.width)//2,y+23+(height-im.height)//2))
    board.convert("RGB").save(OUT/"Scout - Chi tiet.png",optimize=True)

if __name__=="__main__":
    overview()
    details()




