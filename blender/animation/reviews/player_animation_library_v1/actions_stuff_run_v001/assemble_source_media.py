"""Private source/video comparisons; no per-cycle resets or reference retiming."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,shutil
HERE=Path(__file__).resolve().parent
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',18)
small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',15)
contracts=[]
def panel(path,title,sub):
 p=Image.new('RGB',(512,578),'#17212d');im=Image.open(path).convert('RGB');im.thumbnail((512,512),Image.Resampling.LANCZOS)
 p.paste(im,((512-im.width)//2,66+(512-im.height)//2));d=ImageDraw.Draw(p)
 d.text((12,10),title,font=font,fill='white');d.text((12,36),sub,font=small,fill='#c1cfdb');return p
def source(view,i):
 return HERE/'renders'/('source_full/three_quarter'if view=='three_quarter'else'source/'+view)/f'{66+i if view=="three_quarter" else i+1:03d}.png'
def previous(view,i):return HERE/'renders/approved'/view/f'{i%17+1:03d}.png'
def original(i):return HERE/'video_research/native_frames'/f'frame_{30+i:04d}.png'
def horizontal(items):
 im=Image.new('RGB',(512*len(items),578))
 for n,item in enumerate(items):im.paste(item,(n*512,0))
 return im
def frames(name,count,columns,make,description):
 folder=HERE/'panels'/name;folder.mkdir(parents=True,exist_ok=True)
 for i in range(count):make(i).save(folder/f'{i+1:03d}.png')
 contracts.append({'name':name,'frames':count,'fps':30,'width':512*columns,'height':578,'description':description})
for view in ['front','three_quarter','side']:
 frames('source_'+view+'_1x',68,1,lambda i,v=view:panel(source(v,i),'SOURCE RUN | RESEARCH ONLY',f'{v.replace("_"," ")} | pack clock1.6Hz + lifetime bob |30FPS'),'Canonical source clocks, continuous68 samples')
 frames('reference_source_approved_'+view+'_1x',68,3,lambda i,v=view:horizontal([
  panel(original(i),'ORIGINAL Running.mp4',f'F{30+i:03d} | recorded30FPS | original camera'),
  panel(source(v,i),'SOURCE RECONSTRUCTION | RESEARCH',f'{v.replace("_"," ")} | canonical1.6Hz + bob |30FPS'),
  panel(previous(v,i),'PREVIOUS APPROVED RUN',f'{v.replace("_"," ")} | original17-frame clock |30FPS')]),'Original recorded camera differs from fixed native model camera; no temporal retime')
 panel(source(view,10),'SOURCE RUN | PENDING RESEARCH',f'{view.replace("_"," ")} | source phase0, t2.5s').save(HERE/f'source_{view}.png')
frames('source_three_views_1x',68,3,lambda i:horizontal([panel(source(v,i),v.replace('_',' ').upper()+' | SOURCE RESEARCH','canonical1.6Hz + independent bob |30FPS')for v in ['front','three_quarter','side']]),'Three fixed views of the same canonical take,68 continuous samples')
frames('source_full_take_1x',180,1,lambda i:panel(HERE/'renders/source_full/three_quarter'/f'{i+1:03d}.png','SOURCE RUN | RESEARCH ONLY','6s continuous take | independent bob |30FPS'),'Full continuous6-second source study; not a short seamless loop')
frames('video_cadence_diagnostic_front',68,3,lambda i:horizontal([
 panel(original(i),'ORIGINAL Running.mp4','recorded30FPS; no retime'),
 panel(source('front',i),'CANONICAL SOURCE CLOCK','1.6cycles/s + independent lifetime bob'),
 panel(HERE/'renders/video_cadence_diagnostic/front'/f'{i+1:03d}.png','VIDEO-CADENCE DIAGNOSTIC','30/17cycles/s; changed gaitclock ONLY')]),'Diagnostic changes forwardphaseclock only, not source-authentic Action; bob retains nativeclock')
sheet=Image.new('RGB',(1536,4*430+66),'#17212d');draw=ImageDraw.Draw(sheet)
draw.text((15,16),'Recorded reference / canonical source reconstruction / previous approved Run',font=font,fill='white')
draw.text((15,42),'Same-time samples after provisional F40 alignment; different clocks and cameras are preserved.',font=small,fill='#c1cfdb')
for row,i in enumerate([10,13,17,27]):
 for col,path in enumerate([original(i),source('front',i),previous('front',i)]):
  im=Image.open(path).convert('RGB');im.thumbnail((440,380));x=col*512+(512-im.width)//2;y=66+row*430
  sheet.paste(im,(x,y+30));draw.text((col*512+16,y+7),f'video F{30+i:03d} / comparison sample{i}',font=small,fill='white')
sheet.save(HERE/'reference_source_approved_phase_sheet.jpg',quality=92)
shutil.copy2(HERE/'renders/source_full/three_quarter/076.png',HERE/'source_preview.png')
(HERE/'media_contract.json').write_text(json.dumps({'videos':contracts,'research_only':True,'reference_window_zero_based':[30,97],'reference_fps':30,'no_reference_retime':True,'canonical_source_phase_rate':1.6,'reference_local_period_frames':17,'reference_pack_version':'unknown','no_full_runtime_equality_claim':True},indent=2))
print('SOURCE_COMPARISON_PANELS_READY',len(contracts),flush=True)
