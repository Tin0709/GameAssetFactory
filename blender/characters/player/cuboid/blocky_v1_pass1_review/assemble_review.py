from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid\blocky_v1_pass1_review')
canvas=Image.new('RGB',(1500,694),(24,27,32));d=ImageDraw.Draw(canvas);font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',18);small=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',15)
d.text((14,10),'Player_Run_Blocky_V1 | Pass 1: Hips + rigid legs only | 24 FPS | 1-17',font=font,fill='white')
labels=['f1 Right Contact','f3 Down','f5 Passing','f7 Up','f9 Left Contact','f11 Down','f13 Passing','f15 Up','f17 Loop = f1']
for i,label in enumerate(labels):
    row,col=divmod(i,5);x=col*300;y=40+row*326
    im=Image.open(p/f'iso_{i:02d}.png').convert('RGBA');im.thumbnail((296,296));canvas.paste(im,(x+2,y+25),im);d.text((x+8,y),label,font=small,fill='white')
d.text((1210,416),'Upper body: neutral\nRoot: stationary\nLoop: exact\nGround penetration: 0',font=font,fill=(212,228,240),spacing=10)
canvas.save(p/'Player_Run_Blocky_V1_Pass1_review.png')
