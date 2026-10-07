from pathlib import Path
from PIL import Image,ImageDraw
OUT=Path(__file__).parent/'slim_arm_width_review'
def pair_showcase():
 a=Image.open(OUT/'before_three_weapon_showcase.png').convert('RGB');b=Image.open(OUT/'after_three_weapon_showcase.png').convert('RGB')
 sheet=Image.new('RGB',(a.width,a.height*2+80),(30,34,40));draw=ImageDraw.Draw(sheet)
 draw.text((20,12),'BEFORE — Wide arms: 4 x 12 x 4',fill='white');sheet.paste(a,(0,40))
 draw.text((20,a.height+52),'AFTER — Slim arms: 3 x 12 x 4. Same pose, camera and weapon placement.',fill='white');sheet.paste(b,(0,a.height+80))
 sheet.save(OUT/'before_after_showcase.png')
pair_showcase()
for view in ['ReferenceAngle','FrontReference','UnderReference']:
 sheet=Image.new('RGB',(1800,1180),(30,34,40));draw=ImageDraw.Draw(sheet)
 for row,tag in enumerate(['before','after']):
  for col,cat in enumerate(['Pistol','Rifle','Shotgun']):
   img=Image.open(OUT/f'{tag}_{cat}_{view}.png').convert('RGB');img.thumbnail((600,550))
   draw.text((600*col+12,590*row+10),f'{tag.upper()} — {cat}',fill='white');sheet.paste(img,(600*col,590*row+35))
 sheet.save(OUT/f'before_after_{view}.jpg',quality=94)
print('Matched showcase and three detailed comparison sheets created.')
