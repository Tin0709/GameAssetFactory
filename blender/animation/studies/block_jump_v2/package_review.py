from pathlib import Path
import json
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent;V1=OUT.parent/'block_jump_v1'
frames=[18,21,22,25,28,32,75,79,83,87,126,183]
labels={18:'A / approach',21:'A / quick stride entry',22:'A / UP held split',25:'A / UP flight',28:'A / UP held split',32:'A / UP contact',75:'A / edge exit',79:'A / DOWN held split',83:'A / DOWN held split',87:'A / DOWN contact',126:'B / opposite UP split',183:'B / opposite DOWN split'}
for camera,stem in [('Gameplay_Oblique_FIXED','gameplay_contact_sheet'),('Side_Diagnostic_FIXED','side_contact_sheet')]:
    sheet=Image.new('RGB',(480*3,294*4),(20,24,30));d=ImageDraw.Draw(sheet)
    for i,f in enumerate(frames):
        im=Image.open(OUT/'.validation'/camera/f'{f:04d}.png').convert('RGB');im.thumbnail((480,270));x=i%3*480;y=i//3*294;sheet.paste(im,(x,y));d.text((x+8,y+274),f'f{f:03d}  {labels[f]}',fill=(235,239,242))
    sheet.save(OUT/(stem+'.jpg'),quality=93)
# Compare real fixed-side renders; timings aligned by semantic phase, not claimed reference contact.
sheet=Image.new('RGB',(480*3,294*4),(20,24,30));d=ImageDraw.Draw(sheet)
for row,(title,old,new) in enumerate([('UP entry',21,22),('UP held split',28,28),('DOWN held split',75,79),('DOWN contact',85,87)]):
    for col,(folder,f,label) in enumerate([(V1,old,'V1'),(OUT,new,'V2 A'),(OUT,new+104,'V2 B')]):
        im=Image.open(folder/'.validation/Side_Diagnostic_FIXED'/f'{f:04d}.png').convert('RGB');im.thumbnail((480,270));x=col*480;y=row*294;sheet.paste(im,(x,y));d.text((x+8,y+274),f'{label}  f{f:03d} / {title}',fill=(235,239,242))
sheet.save(OUT/'v1_v2_side_comparison.jpg',quality=93)
print('V2_CONTACT_SHEETS_SAVED')
