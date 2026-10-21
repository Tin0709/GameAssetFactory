"""Caption native renders without retiming; encode one review clip."""
from pathlib import Path
import json
import subprocess
from PIL import Image,ImageDraw,ImageFont

D=Path(__file__).resolve().parent;R=D.parents[4];E=R/'.validation/md2_grass_interaction_v001'
FFMPEG=Path('/Users/tin/.cache/uv/archive-v0/pJlw181rtWaLtZsw/lib/python3.13/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1')
source=E/'frames';dest=E/'frames_captioned';dest.mkdir(exist_ok=True);review=D/'review'
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',16)
small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',12)
def phase(t):
    if t<5.1:return 'WALK / SHORT GRASS'
    if t<8.4:return 'RUN / TALL GRASS'
    if t<10.5:return 'DENSE PATCH'
    if t<13.5:return 'STANDING / CONTACT'
    if t<18:return 'LEAVING / RECOVERY'
    return 'RECOVERY / WIND CONTINUES'
files=sorted(source.glob('*.png'));assert len(files)==480
for i,path in enumerate(files,1):
    frame=Image.open(path).convert('RGB');out=Image.new('RGB',(800,544),(19,23,23));out.paste(frame,(0,44))
    draw=ImageDraw.Draw(out);draw.text((14,4),phase(i/24),font=font,fill=(225,237,221))
    draw.text((14,25),'MD2 Grass Interaction v001 | Pending | fixed camera | 1x',font=small,fill=(154,174,160))
    draw.text((735,9),f'{i/24:04.1f}s',font=font,fill=(225,237,221));out.save(dest/path.name)
output=review/'MD2_Grass_Interaction_20s_1x.mp4'
command=[str(FFMPEG),'-y','-hide_banner','-loglevel','warning','-framerate','24','-i',str(dest/'%04d.png'),'-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(output)]
subprocess.run(command,check=True)
# Decoder counts all frames, proving the actual encoded length and no corruption.
result=subprocess.run([str(FFMPEG),'-hide_banner','-i',str(output),'-f','null','-'],capture_output=True,text=True,check=True)
(E/'encoded_video_validation.txt').write_text(result.stderr)
assert 'frame=  480' in result.stderr and '00:00:20.00' in result.stderr,result.stderr[-1500:]
# One ordered strip for examining approach/contact/exit/recovery, no optical-flow claims.
indices=[156,162,168,174,180,186,192,198]
sheet=Image.new('RGB',(1600,1088),(19,23,23))
for index,f in enumerate(indices):
    image=Image.open(dest/('%04d.png'%f));image.thumbnail((400,544))
    sheet.paste(image,((index%4)*400,(index//4)*544))
sheet.save(review/'Run_Contact_Recovery_Strip.jpg',quality=93)
(E/'video.json').write_text(json.dumps({'frames':480,'fps':24,'duration_s':20.,'retiming':False,'native_fixed_camera':True,'output':str(output),'decoded_all_frames':True},indent=2)+'\n')
print('INTERACTION_VIDEO_READY',str(output),flush=True)
