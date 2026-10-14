"""Make original-Run review panels from our own 17 rendered native frames."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
OUT=Path(__file__).resolve().parent
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',22)
small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',18)
views=['front','three_quarter','side']
images={label:{v:[Image.open(OUT/'render'/label/v/f'{i:03d}.png').convert('RGB')for i in range(1,18)]for v in views}for label in ['approved','candidate']}
def panel(im,label):
 p=Image.new('RGB',(640,690),'#18222e');p.paste(im,(0,50));ImageDraw.Draw(p).text((16,15),label,font=font,fill='white');return p
def horizontal(panels):
 im=Image.new('RGB',(640*len(panels),690))
 for i,p in enumerate(panels):im.paste(p,(i*640,0))
 return im
contracts=[]
def frames(name,make,width):
 folder=OUT/'panels'/name;folder.mkdir(parents=True,exist_ok=True)
 for i in range(17):make(i).save(folder/f'{i+1:03d}.png')
 contracts.append({'name':name,'width':width,'height':690,'unique_frames':17,'cycles':6,'frames':102,'fps':30})
for v in views:
 frames('candidate_'+v+'_1x',lambda i,v=v:panel(images['candidate'][v][i],f'ORIGINAL RECOVERY v001 | PENDING | {v.replace("_"," ")} | 30 FPS'),640)
 frames('approved_vs_candidate_'+v+'_1x',lambda i,v=v:horizontal([panel(images['approved'][v][i],'APPROVED Run_Snappy_Test_v001 | 30 FPS'),panel(images['candidate'][v][i],'ORIGINAL RECOVERY v001 | PENDING | 30 FPS')]),1280)
 # Representative static render, with a readable open/gather relationship.
 panel(images['candidate'][v][10],f'PENDING | {v.replace("_"," ")} | native F11').save(OUT/f'candidate_{v}.png')
frames('candidate_three_views_1x',lambda i:horizontal([panel(images['candidate'][v][i],f'{v.replace("_"," ").upper()} | PENDING | 30 FPS')for v in views]),1920)
# All 17 native side frames, baseline above candidate for each column.
sheet=Image.new('RGB',(5*320,4*2*350+70),'#18222e');d=ImageDraw.Draw(sheet)
d.text((16,15),'Native 30 FPS side frames | approved above / candidate below | same 17-frame cadence',font=font,fill='white')
for i in range(17):
 col=i%5;row=i//5
 for j,label in enumerate(['approved','candidate']):
  im=images[label]['side'][i].resize((320,320));x=col*320;y=70+row*700+j*350
  sheet.paste(im,(x,y+30));d.text((x+10,y+6),f'{label} F{i+1}',font=small,fill='white')
sheet.save(OUT/'all_native_side_frames.jpg',quality=92)
# Focused same-time comparison, 4 poses through rear drive / gather / opening.
sheet=Image.new('RGB',(1280,4*420+60),'#18222e');d=ImageDraw.Draw(sheet)
d.text((18,18),'Same-time side comparison | approved left / candidate right',font=font,fill='white')
for row,i in enumerate([8,9,10,12]):
 for col,label in enumerate(['approved','candidate']):
  x=col*640;y=60+row*420
  sheet.paste(images[label]['side'][i].resize((400,400)),(x+220,y+20));d.text((x+12,y+26),f'{label}\nF{i+1}',font=font,fill='white')
sheet.save(OUT/'recovery_comparison.jpg',quality=92)
(OUT/'media_contract.json').write_text(json.dumps({'videos':contracts,'timing':'102 frames at30FPS, six uninterrupted17-frame cycles; closing18 excluded. No cadence retime or holds. Own approved/candidate renders only.'},indent=2))
print('REVIEW_PANELS_READY',len(contracts))
