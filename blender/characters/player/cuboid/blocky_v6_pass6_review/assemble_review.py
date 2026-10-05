from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid\blocky_v6_pass6_review')
a=Image.new('RGB',(1800,950),(24,27,32));d=ImageDraw.Draw(a);font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',16)
labels=['1 Contact R','3 Down','5 Passing','7 Up','9 Contact L','11 Down','13 Passing','15 Up','17 Loop']
for row,v in enumerate(['iso','front','side']):
 for i,label in enumerate(labels):
  x=i*200;y=row*315;im=Image.open(p/f'{v}_{i:02d}.png').convert('RGBA');im.thumbnail((198,280));a.paste(im,(x,y+30),im);d.text((x+5,y+7),label,font=font,fill='white')
a.save(p/'Player_Run_Blocky_V6_review.png')
