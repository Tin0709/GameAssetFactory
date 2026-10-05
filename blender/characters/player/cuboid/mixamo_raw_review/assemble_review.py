from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
base=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid\mixamo_raw_review')
canvas=Image.new('RGB',(1600,746),(24,27,32));draw=ImageDraw.Draw(canvas)
font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',20)
small=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',16)
draw.text((16,12),'Player_Run_Mixamo_RAW | 24 FPS | 0.633333 s | unstyled retarget',font=font,fill='white')
labels=['Start / f1','Quarter / f4.8','Half / f8.6','Three-quarter / f12.4','Loop end / f16.2']
for row,view in enumerate(['iso','side']):
    y=46+row*350
    for col,label in enumerate(labels):
        im=Image.open(base/f'{view}_{col:02d}.png').convert('RGBA');im.thumbnail((316,316))
        canvas.paste(im,(col*320+2,y+26),im)
        draw.text((col*320+8,y),label if row==0 else 'Side | '+label,font=small,fill=(225,232,240))
canvas.save(base/'Player_Run_Mixamo_RAW_review.png')
