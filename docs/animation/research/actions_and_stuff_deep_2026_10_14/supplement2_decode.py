from pathlib import Path
import hashlib, json
import cv2
import numpy as np
from PIL import Image, ImageDraw

BASE = Path(__file__).resolve().parent
from portable_inputs import source
SOURCE = source('supplement2')
cap = cv2.VideoCapture(str(SOURCE))
fps = cap.get(cv2.CAP_PROP_FPS)
reported = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
frames = []
timestamps = []
while True:
    ok, frame = cap.read()
    if not ok:
        break
    timestamps.append(cap.get(cv2.CAP_PROP_POS_MSEC))
    frames.append(Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)))
cap.release()
if not frames:
    raise RuntimeError('No frames decoded')
diffs = [float(np.abs(np.asarray(b, dtype=np.float32)-np.asarray(a, dtype=np.float32)).mean()) for a,b in zip(frames,frames[1:])]

def sheet(indices, name, cols=6, width=240, crop=None):
    if crop:
        fw,fh=crop[2]-crop[0],crop[3]-crop[1]
    else:
        fw,fh=frames[0].size
    height=round(fh*width/fw)
    rows=(len(indices)+cols-1)//cols
    canvas=Image.new('RGB',(cols*width,rows*(height+24)),(24,26,31))
    draw=ImageDraw.Draw(canvas)
    for j,i in enumerate(indices):
        x,y=(j%cols)*width,(j//cols)*(height+24)
        im=frames[i].crop(crop) if crop else frames[i]
        im=im.resize((width,height),Image.Resampling.LANCZOS)
        canvas.paste(im,(x,y+24))
        draw.text((x+5,y+5),f'F{i:03d}  {i/fps:.3f}s',(245,245,245))
    canvas.save(BASE/name,quality=94)

overview=list(range(0,len(frames),15))
if overview[-1]!=len(frames)-1: overview.append(len(frames)-1)
sheet(overview,'supplement2_overview.jpg',cols=4,width=360)
for start in range(0,len(frames),36):
    sheet(list(range(start,min(start+36,len(frames)))),f'supplement2_all_frames_{start:03d}.jpg')
for start,end,label in [(0,18,'primary_000_017'),(18,36,'primary_018_035'),(144,162,'late_144_161'),(162,179,'late_162_178')]:
    sheet(list(range(start,end)),f'supplement2_{label}.jpg',cols=6,width=300,crop=(220,175,610,625))
sheet(list(range(78,96)),'supplement2_camera_occlusion_078_095.jpg',cols=6,width=300)
frames[15].save(BASE/'supplement2_frame015.png')
report={'source':str(SOURCE),'sha256':hashlib.file_digest(SOURCE.open('rb'),'sha256').hexdigest(),'fps':fps,'reported_frame_count':reported,'decoded_frame_count':len(frames),'width':frames[0].width,'height':frames[0].height,'duration_from_count_s':len(frames)/fps,'first_to_last_sample_span_s':(len(frames)-1)/fps,'decode_backend':'OpenCV sequential decode','frame_numbering':'zero-based; nominal time = F/fps','timestamps_msec':timestamps,'adjacent_mean_absolute_rgb_difference':diffs,'exact_adjacent_repeats':[i+1 for i,d in enumerate(diffs) if d==0.0],'source_pack_version':'unknown','playback_speed_and_input':'unknown; encoded fps is not proof of original engine timing'}
old_path=BASE.parents[3]/'blender/animation/reviews/player_animation_library_v1/walk_snappy_test_v1/bounce_timing_v008/reference_analysis.json'
old=json.loads(old_path.read_text(encoding='utf-8-sig'))
report['comparison_to_previously_decoded_241_frame_reference']={'report':str(old_path),'source':old.get('video'),'sha256':old.get('sha256'),'decoded_frames':old.get('decoded_frames'),'byte_identical':old.get('sha256')==report['sha256'],'note':'Different files; no independent provenance or pack-version match established'}
report['crop_rectangles_xyxy']={'primary_and_late': [220,175,610,625]}
report['visual_inspection']={'overview_frames':overview,'all_consecutive_frames':[0,len(frames)-1],'dense_enlarged_intervals':[[0,17],[18,35],[144,161],[162,178]],'full_context_interval':[78,95],'first_villager_frame':179,'player_locomotion_frames':[0,178],'candidate_compact_gait_interval':[161,178],'timing_landmarks':{'broad_same_side_open_stride_pairs':[[6,23],[15,32]],'recorded_pair_difference_frames':17,'recorded_pair_difference_s':17/fps,'uncertainty_frames_at_least':1,'meaning':'Visual recurrence estimate only; not original clip duration, confirmed contact period, or engine speed'}}
(BASE/'supplement2_decode.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ('sha256','fps','decoded_frame_count','width','height','duration_from_count_s','exact_adjacent_repeats')},indent=2))
