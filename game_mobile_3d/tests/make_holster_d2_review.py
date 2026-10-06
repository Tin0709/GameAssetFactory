from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).parents[1]/'.validation/holster_d2'
rows=[('M4 Idle','1_-1_0'),('M4 Run 0%','1_0_0'),('M4 Run 25%','1_0_25'),('M4 Run 50%','1_0_5'),('M4 Run 75%','1_0_75'),('Shotgun Run 50%','2_0_5')]
cols=[('Start','begin'),('Entry blend','step8'),('Shoulder pass','step20'),('Back contact','step35'),('Handoff','step38'),('Free arms','done')]
font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',16)
out=Image.new('RGB',(6*220,6*274+40),'#152028');draw=ImageDraw.Draw(out)
for col,(name,key) in enumerate(cols):draw.text((col*220+5,8),name,font=font,fill='white')
for row,(name,label) in enumerate(rows):
 for col,(title,key) in enumerate(cols):
  im=Image.open(BASE/f'd2_{label}_{key}.png').convert('RGB').crop((350,100,850,680)).resize((214,248))
  x=col*220+3;y=row*274+40;out.paste(im,(x,y));draw.text((x+4,y+250),name,font=font,fill='#c3e5f4')
out.save(BASE/'holster_d2_review.png')
print(BASE/'holster_d2_review.png')
