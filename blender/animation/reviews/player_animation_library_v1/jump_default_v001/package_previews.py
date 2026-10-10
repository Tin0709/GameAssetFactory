"""Package the rendered frames without retiming the 30 FPS source motion.

Run with regular Python/Pillow, then run encode_previews.py in background Blender.
"""
from pathlib import Path
import json, shutil, hashlib
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
TMP=ROOT/'.validation/jump_default_v001'
font=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',25)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
phases={1:'Ready',2:'Ready / shoulder clearance',3:'Anticipation',5:'Push / last support',6:'Lift-off',9:'Air pose',12:'Apex',14:'Apex to descent',16:'Descent',18:'Prepare contact',19:'Contact',21:'Absorb',22:'Follow-through',23:'Recover',24:'Recover',25:'Idle'}

def phase(f):return phases[max(k for k in phases if k<=f)]

for label in ['gameplay','side']:
    source=TMP/'frames'/label
    sequence=TMP/'encode'/label;sequence.mkdir(parents=True,exist_ok=True)
    timeline=([1]*15+list(range(1,26))+[25]*15)*3
    for i,f in enumerate(timeline,1):
        canvas=Image.new('RGB',(960,1024),(20,28,37));canvas.paste(Image.open(source/f'{f:03d}.png'),(0,72))
        draw=ImageDraw.Draw(canvas)
        title='JUMP DEFAULT V001   /   '+('3/4 REVIEW CAMERA' if label=='gameplay' else 'SIDE REVIEW')
        draw.text((24,10),title,font=font,fill=(241,246,250))
        draw.text((24,43),f'1x speed  |  30 FPS  |  take {(i-1)//55+1}/3  |  Blender-only',font=small,fill=(141,218,208))
        draw.text((24,986),f'F{f:02d}  /  {phase(f)}',font=small,fill='white')
        draw.text((580,986),'Pose 0.80 s  /  preview height 0.63 m',font=small,fill=(190,203,214))
        canvas.save(sequence/f'{i:04d}.png')

frames=[3,5,9,12,16,19,21,25]
sheet=Image.new('RGB',(1440,896),(20,28,37));draw=ImageDraw.Draw(sheet)
draw.text((20,14),'JUMP DEFAULT V001  /  30 FPS  /  0.80 s',font=font,fill='white')
draw.text((20,47),'New flat-ground jump · current character · awaiting review',font=small,fill=(141,218,208))
for i,f in enumerate(frames):
    x=i%4*360;y=84+i//4*394
    img=Image.open(TMP/'frames/gameplay'/f'{f:03d}.png').resize((356,334),Image.Resampling.LANCZOS)
    sheet.paste(img,(x+2,y+49))
    draw.text((x+12,y+4),f'F{f:02d}  /  {phase(f)}',font=small,fill='white')
draw.text((20,869),'Rigid legs: absorption uses torso/arms. Pose Action and preview travel are separate.',font=small,fill=(185,199,213))
sheet.save(OUT/'contact_sheet.png')
# A readable small actor is checked separately; this is not a phone/FPS test.
sheet2=Image.new('RGB',(960,380),(20,28,37));draw=ImageDraw.Draw(sheet2)
draw.text((20,10),'SMALL ACTOR READABILITY / 3/4 camera / not a phone performance test',font=small,fill='white')
for i,f in enumerate([5,9,12,19]):
    img=Image.open(TMP/'frames/gameplay'/f'{f:03d}.png').resize((240,225),Image.Resampling.LANCZOS)
    sheet2.paste(img,(i*240,70));draw.text((i*240+16,310),f'F{f:02d} / {phase(f)}',font=small,fill='white')
sheet2.save(OUT/'small_actor_check.png')
shutil.copy2(TMP/'frames/gameplay/012.png',OUT/'apex_gameplay.png')
shutil.copy2(TMP/'frames/side/012.png',OUT/'apex_side.png')
print(json.dumps({'frames_per_video':165,'fps':30,'video_seconds':5.5,'motion_seconds':.8,'repeats':3,'holds_each_side_s':.5}))
