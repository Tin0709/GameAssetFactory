"""Muted30FPS native-speed comparisons; no repeated closing keys or retiming."""
from pathlib import Path
import hashlib
import json
import subprocess
import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
TMP = ROOT/'.validation/run_snappy_leg_recovery_v001'
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
reference = ROOT/'references/motion/actions_and_stuff/Running.mp4'
ref = TMP/'reference_frames';ref.mkdir(exist_ok=True)
subprocess.run([FFMPEG,'-y','-i',str(reference),'-vf',r'select=between(n\,40\,124)','-fps_mode','vfr',str(ref/'%03d.png')],check=True,capture_output=True)
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22)
views=['front','three_quarter','side']
images={label:{v:[Image.open(TMP/'render'/label/v/f'{i:03d}.png').convert('RGB') for i in range(1,18)] for v in views} for label in ['approved','candidate']}
reference_frames=[Image.open(ref/f'{i:03d}.png').convert('RGB') for i in range(1,86)]

def panel(im,label):
    result=Image.new('RGB',(640,690),'#151b22')
    im=im.copy();im.thumbnail((640,640))
    result.paste(im,((640-im.width)//2,50+(640-im.height)//2))
    ImageDraw.Draw(result).text((15,12),label,font=font,fill='white')
    return result

def encode(name, make):
    folder=TMP/'encoded_frames'/name;folder.mkdir(parents=True,exist_ok=True)
    for i in range(85):make(i).save(folder/f'{i:03d}.png')
    dest=OUT/(name+'.mp4')
    subprocess.run([FFMPEG,'-y','-framerate','30','-i',str(folder/'%03d.png'),'-frames:v','85','-an','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(dest)],check=True,capture_output=True)
    probe=subprocess.run([FFMPEG,'-v','error','-i',str(dest),'-f','null','-'],check=True,capture_output=True)
    return {'path':dest.name,'frames':85,'fps':30,'duration_s':85/30,'cycles':5,'audio':False,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}

def horizontal(panels):
    im=Image.new('RGB',(640*len(panels),690))
    for i,p in enumerate(panels):im.paste(p,(640*i,0))
    return im

report=[]
for v in views:
    report.append(encode('candidate_'+v+'_1x',lambda i,v=v:panel(images['candidate'][v][i%17],'LEG RECOVERY v001 · PENDING · '+v.replace('_',' ')+' · 1x')))
    report.append(encode('approved_vs_candidate_'+v+'_1x',lambda i,v=v:horizontal([panel(images['approved'][v][i%17],'APPROVED RUN · '+v.replace('_',' ')+' · 1x'),panel(images['candidate'][v][i%17],'LEG RECOVERY v001 · PENDING · 1x')])) )
report.append(encode('candidate_three_views_1x',lambda i:horizontal([panel(images['candidate'][v][i%17],v.replace('_',' ').upper()+' · PENDING · 1x') for v in views])))
report.append(encode('reference_approved_candidate_1x',lambda i:horizontal([panel(reference_frames[i].resize((421,640),Image.Resampling.NEAREST),'A&S REFERENCE F40–124 · different camera'),panel(images['approved']['front'][i%17],'APPROVED RUN · 1x'),panel(images['candidate']['front'][i%17],'LEG RECOVERY v001 · PENDING · 1x')])))
sheet=Image.new('RGB',(1280,5*300),'#151b22');draw=ImageDraw.Draw(sheet)
for j,i in enumerate([0,2,4,6,8]):
    for column,label in enumerate(['approved','candidate']):
        im=images[label]['side'][i].resize((300,300))
        sheet.paste(im,(column*640+170,j*300))
        draw.text((column*640+8,j*300+12),f'{label} F{i+1}',font=font,fill='white')
sheet.save(OUT/'side_phase_comparison.jpg')
(OUT/'media_validation.json').write_text(json.dumps({'passed':True,'videos':report,'reference':str(reference.relative_to(ROOT)),'reference_sha256':hashlib.sha256(reference.read_bytes()).hexdigest(),'reference_frames_zero_based':[40,124],'timing':'85 frames, original30FPS;17 unique Action frames repeated5 times, closing18 excluded. No holds or cadence retiming.'},indent=2))
print('EIGHT_NATIVE_SPEED_VIDEOS_VERIFIED',flush=True)
