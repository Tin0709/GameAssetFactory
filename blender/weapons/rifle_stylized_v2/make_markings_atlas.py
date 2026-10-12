"""Bake clean lettering into the existing palette layout; no runtime text meshes."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
OUT=Path(__file__).resolve().parent
source=Image.open(OUT/'rifle_v2_reference_atlas_256.png').convert('RGBA')
factor=4;im=source.resize((1024,512),Image.Resampling.NEAREST);draw=ImageDraw.Draw(im)
palette=[(42,48,57,255),(106,123,135,255),(143,159,170,255),(105,117,126,255),(25,31,40,255),(242,163,49,255),(239,242,242,255),(50,57,68,255)]
# Albedo is stored as sRGB. Keep steel and graphite distinct in ordinary viewport light.
for i,color in enumerate(palette):draw.rectangle((i*128,0,(i+1)*128-1,127),fill=color)
draw.rectangle((896,64,1023,127),fill=(205,25,21,255))
for text,y,color,bg,left in [('M4A1 CARBINE',2,6,2,0),('2003451',20,6,2,0),('5X56',38,6,2,0),('V4',56,5,1,0),('200134',74,6,0,0),('2003451',20,6,0,640)]:
 width=len(text)*12*factor;top=(128-y-16)*factor;bottom=(128-y)*factor
 draw.rectangle((left,top,left+width,bottom),fill=palette[bg])
 font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',64)
 # Fit the full glyph field rather than leaving the old pixel-font side padding.
 bb=draw.textbbox((0,0),text,font=font);tw=bb[2]-bb[0];th=bb[3]-bb[1]
 glyph=Image.new('RGBA',(tw,th),(0,0,0,0));ImageDraw.Draw(glyph).text((-bb[0],-bb[1]),text,font=font,fill=palette[color])
 glyph=glyph.resize((width-20,bottom-top-12),Image.Resampling.LANCZOS)
 im.alpha_composite(glyph,(left+10,top+6))
draw.rectangle((896,160,1023,223),fill=(77,94,106,255))
im.save(OUT/'rifle_v2_markings_atlas_1024.png',optimize=True)
print('MARKINGS_ATLAS',im.size,(OUT/'rifle_v2_markings_atlas_1024.png').stat().st_size)
