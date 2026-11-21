"""Compose the Forager render and review boards without changing the source concept."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent
PAST=ROOT/"private"
FINAL=PAST/"06-review"
FONT="C:/Windows/Fonts/segoeui.ttf"
BOLD="C:/Windows/Fonts/segoeuib.ttf"
TITLE=ImageFont.truetype(BOLD,36)
LABEL=ImageFont.truetype(BOLD,19)
FORE="#f1dfcb"
GOLD="#d6ab82"

def render_studio(file, size=None):
    art=Image.open(file).convert("RGBA")
    if size:
        art.thumbnail(size,Image.Resampling.LANCZOS)
    w,h=art.size
    yy,xx=np.mgrid[0:h,0:w]
    light=np.exp(-1.8*(((xx/w-.46)/.63)**2+((yy/h-.36)/.68)**2))
    background=np.uint8(np.array([21,17,24])+light[:,:,None]*np.array([18,13,15]))
    plate=Image.fromarray(background).convert("RGBA")
    plate.alpha_composite(art)
    return plate

def comparison():
    panel_w, panel_h, margin=465,501,16
    size=(margin*2+panel_w*2,99+2*(panel_h+38))
    page=Image.new("RGBA",size,"#1b1820")
    draw=ImageDraw.Draw(page)
    draw.text((margin+4,14),"The Forager · Đối chiếu thân trên",font=TITLE,fill=FORE)
    for j,(ref,key,label) in enumerate((("hero","hero","Góc 3/4"),("front","front","Chính diện"))):
        y=98+j*(panel_h+38)
        draw.text((margin+3,y-26),f"{label} · Concept",font=LABEL,fill=GOLD)
        draw.text((margin+panel_w+3,y-26),f"{label} · Blender",font=LABEL,fill=GOLD)
        concept=Image.open(PAST/f"concept-{ref}.jpg").convert("RGBA")
        # Small turnaround figures benefit from preserving their painted pixels.
        factor=min((panel_w-20)/concept.width,(panel_h-12)/concept.height)
        concept=concept.resize((round(concept.width*factor),round(concept.height*factor)),Image.Resampling.LANCZOS)
        draw.rounded_rectangle((margin,y,margin+panel_w-8,y+panel_h-4),radius=8,fill="#252029")
        page.alpha_composite(concept,(margin+(panel_w-concept.width)//2-4,y+(panel_h-concept.height)//2))
        art=render_studio(FINAL/f"{key}.png",(panel_w-10,panel_h-4))
        page.alpha_composite(art,(margin+panel_w+(panel_w-art.width)//2-4,y+(panel_h-art.height)//2))
    page.convert("RGB").save(FINAL/"Forager - Doi chieu.jpg",quality=95,subsampling=0)

def shapes():
    page=Image.new("RGBA",(1030,680),"#1b1820")
    draw=ImageDraw.Draw(page)
    draw.text((21,11),"The Forager · Kiểm tra hình khối",font=TITLE,fill=FORE)
    for i,(key,label) in enumerate((("front","Chính diện"),("hero","Góc 3/4"))):
        draw.text((28+i*509,64),label,font=LABEL,fill=GOLD)
        a=render_studio(FINAL/f"clay-{key}.png",(490,576))
        page.alpha_composite(a,(23+i*509+(488-a.width)//2,93))
    page.convert("RGB").save(FINAL/"Forager - Clay.jpg",quality=94)

render_studio(FINAL/"hero.png",(870,1025)).convert("RGB").save(FINAL/"Forager - Studio.jpg",quality=96,subsampling=0)
comparison()
shapes()


