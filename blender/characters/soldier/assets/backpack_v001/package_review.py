"""Arrange actual Blender views of the standalone equipment, without retouching."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent
font='/System/Library/Fonts/Supplemental/Arial.ttf'
title=ImageFont.truetype(font,29);small=ImageFont.truetype(font,19)
views=['Front','Front_3Q','Left_Side','Back']
canvas=Image.new('RGB',(1920,650),(235,230,220));d=ImageDraw.Draw(canvas)
d.text((24,14),'SOLDIER / BACKPACK v001',font=title,fill=(63,47,32))
d.text((24,51),'Standalone equipment | Layered canvas / leather straps / metal buckles | PENDING',font=small,fill=(101,83,60))
for i,view in enumerate(views):
    im=Image.open(HERE/'renders'/f'{view}.png').convert('RGB').resize((480,540),Image.Resampling.LANCZOS)
    canvas.paste(im,(480*i,84))
    d.text((480*i+240,637),{'Front':'FRONT','Front_3Q':'FRONT 3/4','Left_Side':'SIDE','Back':'BACK'}[view],font=small,anchor='mm',fill=(63,47,32))
canvas.save(HERE/'review_four_views.jpg',quality=95)
print('Standalone backpack four-view review ready.')
