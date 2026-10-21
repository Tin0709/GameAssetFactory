"""Arrange actual Blender renders without changing their character pixels."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent
font='/System/Library/Fonts/Supplemental/Arial.ttf'
F=ImageFont.truetype(font,22);SMALL=ImageFont.truetype(font,18);TITLE=ImageFont.truetype(font,28)
views=['Front','Front_3Q','Left_Side','Back','Right_Side','Back_3Q']
labels={'Front':'FRONT','Front_3Q':'FRONT 3/4','Left_Side':'SIDE','Back':'BACK','Right_Side':'OTHER SIDE','Back_3Q':'BACK 3/4'}
for names,file in [(views[:4],'review_four_views.jpg'),(views,'review_six_views.jpg')]:
 canvas=Image.new('RGB',(480*len(names),704),(236,232,225));d=ImageDraw.Draw(canvas)
 d.text((24,13),'SOLDIER / CHARACTER REVIEW',font=TITLE,fill=(52,43,35))
 d.text((24,47),'Original proportions + slim arms | Layered hair / stronger clothing relief | PENDING',font=SMALL,fill=(91,79,65))
 for i,name in enumerate(names):
  im=Image.open(OUT/'renders'/f'{name}.png').convert('RGB').resize((480,600),Image.Resampling.LANCZOS)
  canvas.paste(im,(480*i,80));d.text((480*i+240,686),labels[name],font=SMALL,anchor='mm',fill=(52,43,35))
 canvas.save(OUT/file,quality=95)
# Reference-versus-candidate face proportions: no warping or repainting.
reference=Image.open(OUT/'primary_reference.png').convert('RGB').crop((20,250,275,814))
candidate=Image.open(OUT/'renders'/'Front.png').convert('RGB').crop((160,40,640,965))
canvas=Image.new('RGB',(880,820),(236,232,225));d=ImageDraw.Draw(canvas)
for x,im,label in [(0,reference,'SUPPLIED REFERENCE'),(440,candidate,'SOLDIER / EXISTING PROPORTIONS')]:
 im=im.resize((round(im.width*710/im.height),710),Image.Resampling.LANCZOS)
 canvas.paste(im,(x+(440-im.width)//2,58));d.text((x+220,29),label,font=SMALL,anchor='mm',fill=(52,43,35))
d.text((440,795),'Body proportions follow the existing player, as requested.',font=SMALL,anchor='mm',fill=(91,79,65))
canvas.save(OUT/'reference_comparison.jpg',quality=95)
print('Actual render review sheets ready.')
