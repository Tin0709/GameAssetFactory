"""Package decoded Blender playback and the actual reference clip for review."""
from pathlib import Path
import json,cv2,shutil,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'living_r9w1_review'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
source=ROOT/'references/animation/weapon_hold_living_reference/minecraft_crossbow_hold_turning.mp4'
shutil.copy2(source,OUT/'minecraft_crossbow_hold_turning.mp4')
media={}
for mode,N in [('ready',96),('move',64),('steering',288),('local',288)]:
 p=OUT/(mode+'_AB_24fps.mp4');c=cv2.VideoCapture(str(p));fps=c.get(cv2.CAP_PROP_FPS);count=int(c.get(cv2.CAP_PROP_FRAME_COUNT));assert count==N and fps==24,(p,count,fps)
 selected=[0,N//4,N//2,3*N//4];frames={};decoded=0
 while True:
  ok,f=c.read()
  if not ok:break
  if decoded in selected:frames[decoded]=Image.fromarray(cv2.cvtColor(f,cv2.COLOR_BGR2RGB))
  decoded+=1
 assert decoded==N
 media[p.name]={'fps':fps,'frames':decoded,'duration_s':N/fps,'width':int(c.get(3)),'height':int(c.get(4))}
 frames[0].save(OUT/(mode+'_poster.jpg'))
 sheet=Image.new('RGB',(1280,4*390),(17,28,38));d=ImageDraw.Draw(sheet)
 for j,f in enumerate(selected):
  im=frames[f];im.thumbnail((640,360));sheet.paste(im,(0,j*390));d.text((12,j*390+362),f'{mode.upper()}  frame {f+1} / {N}',font=font,fill='white')
  # Same decoded frame, enlarged without changing aspect ratio or scene content.
  c2=cv2.VideoCapture(str(p));c2.set(1,f);ok,bgr=c2.read();c2.release();crop=Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)).crop((640,80,1280,720));crop.thumbnail((620,360));sheet.paste(crop,(650+(620-crop.width)//2,j*390))
 sheet.save(OUT/(mode+'_sequence.jpg'))
 c.release()
v=json.loads((OUT/'validation.json').read_text());d=json.loads((OUT/'design.json').read_text())
for view in ['Front','Gameplay','Opposite','Side','Close','Distance']:
 sheet=Image.new('RGB',(1920,1360),(17,28,38));draw=ImageDraw.Draw(sheet)
 for j,name in enumerate(['Ready','Move','Left','Right']):
  im=Image.open(OUT/f'{name}_{view}.png');x=(j%2)*960;y=(j//2)*680;sheet.paste(im,(x,y+40));draw.text((x+16,y+10),name+(' — root path removed' if name in ['Left','Right'] else ''),font=font,fill='white')
 sheet.save(OUT/f'studies_{view}.jpg')
(OUT/'media_validation.json').write_text(json.dumps(media,indent=2))
head=max(a['max_sampled_contact']['Head']['triangles'] for a in v['actions'].values())
grip=max(a['half_frame_grip_error_m'] for a in v['actions'].values())
penetration=max(a['max_sampled_contact'][n]['vertex_depth_m'] for a in v['actions'].values() for n in ['UpperArm.R','ForeArm.R','ForeArm.L'])
positions=np.array(v['actions']['LongGunAimAround_LeftRight_V1']['root_positions']);speeds=np.linalg.norm(np.diff(positions,axis=0),axis=1)*24
report=f'''R9-W1 — LIVING WEAPON HOLD AND AIM-AROUND STUDY
2026-10-07 | Blender-only | AWAITING HUMAN REVIEW

1. REFERENCE ANALYSIS

Primary source: references/animation/weapon_hold_living_reference/
minecraft_crossbow_hold_turning.mp4. Decoded 463 frames, 30 fps, 426x528,
15.433 seconds. The original is preserved and copied into this review.
Inspected the full clip through ordered overview frames plus dense 15 fps
sequences at 3.2–4.133, 8.7–9.633, and 12.5–13.433 seconds.

0.0–2.2s: camera elevation changes substantially. The weapon remains close
to the upper torso, the hands occupy different roles, and the head continues
to present toward the apparent attention direction. The changing horizon
must not be mistaken for measured character lean.
3.2–3.467s: a comparatively quiet ready pose precedes the sweep.
3.533–3.933s: the crossbow traverses the silhouette; one side extends into
a longer horizontal shape while the opposite side becomes compressed.
4.0–4.133s: it resolves continuously into the new alignment, without a
visible return to a neutral arm pose between directions.
9.033–9.300s: the broad horizontal arm/weapon shape opens again.
9.367–9.633s: it closes back toward the compact ready arrangement.
12.833–13.100s and 13.167–13.433s show another open/resolve sequence.

The useful motion language is a controlled weapon with unequal arm roles,
changing shoulder/arm silhouettes, and attention that stays coherent while
the pose resolves. The clip supports those qualitative observations. Camera
orbit, elevation and framing changes prevent reliable separation of camera
motion from character world turning. It does not establish a measurable
world-space circle, locomotion speed, rig hierarchy, or exact arm time lag.
The firearm's right-grip anchor, left-support assignment, delay values and
figure-eight path below are authored interpretations, not recovered data.

2. STUDY RESULTS

File: ../player_longgun_living_r9w1_study.blend
Rig: R9W1_Author_Rig. It is an isolated copy of the R8 RigV2 skeleton and
rigid mesh. No new bones, hand rig, fingers, IK constraints or controllers.
Two-link geometry chooses arm poses offline, baked as editable FK keys.

LongGunReady_LivingRef_V1: 96 frames / 4 seconds at 24 fps. Restrained
chest breathing, small neck/head participation, unequal elbow paths and a
stable grip. The support hand stays on the fore-end with a small slide.

LongGunReady_Move_V1: 64 frames / 2.667 seconds. Four repetitions of the
established 16-frame Walk_ReferenceStudy_V2. Hips and both legs are sampled
from the existing Action, including its translations; upper arms are
re-authored for the weapon. Original lower-body poses match at integer
frames, with new quaternion interpolation between them. This is a walking
ready study, not a new sprint or locomotion design.

LongGunAimAround_LeftRight_V1: 288 frames / 12 seconds. Eighteen existing
walk cycles travel around a constant-speed figure eight, including both
turn directions and continuous reversals. The nominal full-body path and
the same motion with root travel removed are both available for review.

Compared with R8, the new study lowers the rifle by 20 mm and adds a 4-degree
head yaw bias, then a small steering offset. This was needed to keep the
moving head corner clear of the rear weapon. The A/B therefore compares the
R8 pose with the R9 pose-and-motion study, not two otherwise identical poses.

3. TURNING ANALYSIS

The body heading follows the trajectory tangent continuously. Arc-length
sampling gives approximately {speeds.min():.3f}–{speeds.max():.3f} m/s in this dev
path. Its two lobes exercise opposite circular steering directions; it is
an invented test path, not a recreation of a measured circle in the video.

Signed turn rate drives about 3.5 degrees of spine yaw and 10 degrees of
chest yaw, with restrained bank. The neck contributes up to 2.5 degrees;
the head adds up to 2.5 degrees around its new bias. The rifle stays tied
closely to the chest, with a small response based on a 45 ms earlier steering
sample. The left elbow uses a 125 ms earlier steering sample, opens/closes
through a shifted elbow pole, and resolves along a bounded support contact.
The support contact moves up to 12 mm along the fore-end and 3 mm vertically
in weapon-local coordinates. The right hand remains pinned at the grip.
These delays were chosen for this probe, not measured from the reference.

No pose-reset state machine is involved. Keys are continuous through both
lobes and the end returns to the starting pose. Loop endpoints agree to
floating-point precision. Half-frame sampling keeps grip drift below
{grip*1000:.3f} mm. Head and chest checks found {head} intersecting weapon triangles
at every sampled half-frame using 5 mm inset rigid boxes.

The path uses the original walk cadence without terrain contact or foot
locking. Tight-arc foot sliding and turn-weight transfer remain unproven.
This study demonstrates upper-body behavior; it is not runtime navigation
or a production-quality planted turning solution.

4. VISUAL VERDICT

The transfer is partial and useful, but not strong enough for production.
Close A/B playback is more attentive than the fixed R8 upper pose: chest,
head and elbows adjust as the character steers, and the hands retain their
different roles. It preserves the compact blocky silhouette and does not
use large rubbery motion. The idle is intentionally quiet.

At gameplay scale the chest/weapon direction changes read more clearly
than the delayed support elbow. The reference's opening-and-resolving arm
gesture is more obvious; our support-arm follow still feels restrained and
the hand blocks still read as a fairly rigid assembly in some views.
The gun is diagonally held, so opposite views foreshorten it substantially.
The figure-eight proves continuity, but wide framing reduces arm detail;
use the paired local inspection video as well as the actual path video.

Remaining contacts: the stock and fingerless hand blocks retain overlaps.
The largest sampled weapon-vertex depth is about {penetration*1000:.1f} mm in
the inset-box test. These counts are geometry-dependent proxies, not exact
penetration volumes. They are not all minor, and this is not a claim of
fully clean contact or exhaustive all-pairs collision validation.

Validation preserves {v['protected_files']:,} existing files, all {v['protected_actions']} Actions already in
the R8 source, source geometry and rig signatures. The unchanged walk Action
was appended from the existing locomotion study. Three deliverable Actions
and five explicitly named PREVIEW_ONLY_R9W1 comparison Actions are new.
RigV2 stays at 13 bones with rigid weights and unchanged proportions.
Production, Godot, existing draw/hold/holster, and locomotion files are intact.

5. RECOMMENDATION

MORE STUDY WORK IS NEEDED FIRST.

Next refine the support elbow's visible open/resolve gesture at gameplay
scale, reduce stock/hand burial, and assess planted turn weight transfer.
Keep the stable grip and restrained chest/head participation. A runtime
upper-body steering layer is a plausible eventual form, because these
responses depend on turn rate and history, but this baked probe does not
prove that implementation or justify production migration yet.

REVIEW SETUP

Blender opens on R9W1_REVIEW_LOCAL: A is R8 upper hold over the same gait;
B is the R9 steering motion. Root travel is removed only in this inspection
scene. Use R9W1_REVIEW_STEERING for the actual figure-eight path, and
R9W1_REVIEW_READY / R9W1_REVIEW_MOVE for the two smaller loops. All characters
are editable. The reference frame board is beside the viewport; the actual
reference clip and four 24 fps videos are in index.html. Shared-scene A/B
lighting varies spatially, so compare motion and silhouette rather than
brightness. The matched individual stills show front, gameplay, opposite,
side, close and native-distance views; Left/Right remove root travel.

ARTISTIC STATUS: AWAITING HUMAN REVIEW
'''
(OUT/'R9_W1_REPORT.txt').write_text(report,encoding='utf-8')
html='''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>R9-W1 Living Weapon Study</title><style>
body{margin:0;background:#111c26;color:#ecf0f3;font:16px/1.55 system-ui}main{max-width:1360px;margin:auto;padding:36px}h1{font-size:38px;margin:0}h2{margin:38px 0 12px}p{max-width:920px;color:#bacbd6}a{color:#7fd2e9}video,img{width:100%;background:#26303a;border-radius:7px}video{max-height:620px}section{display:grid;grid-template-columns:1fr 2fr;gap:24px}.cards{display:grid;grid-template-columns:1fr 1fr;gap:24px}.badge{color:#f4c886}button,select{padding:9px 16px;background:#263a49;color:white;border:1px solid #516d7c;border-radius:6px}.note{padding:16px;background:#20313e;border-left:3px solid #7fd2e9}@media(max-width:760px){section,.cards{display:block}main{padding:20px}}
</style></head><body><main><div class="badge">BLENDER STUDY · AWAITING HUMAN REVIEW</div><h1>Living weapon hold & aim-around</h1><p>Right-hand anchor, following support elbow, continuous steering. Verdict: more study work is needed before production integration.</p><p><a href="../player_longgun_living_r9w1_study.blend">Editable Blender study</a> · <a href="R9_W1_REPORT.txt">Full report</a> · <a href="validation.json">Validation</a></p>
<label>Playback speed <select id="speed"><option value="1">1× original timing</option><option value="0.5">0.5× inspection</option><option value="0.25">0.25× inspection</option></select></label>
<section><div><h2>Primary crossbow reference</h2><video src="minecraft_crossbow_hold_turning.mp4" controls loop preload="metadata"></video><p>Original 30 fps / 15.43 s. Camera movement prevents reliable recovery of world-space circles or exact response delays.</p></div><div><h2>Steering: close A/B inspection</h2><video src="local_AB_24fps.mp4" poster="local_poster.jpg" controls loop preload="metadata"></video><p>A: R8 hold with the same walk. B: R9 chest/head/elbow response. Root travel is removed here to make the upper body inspectable.</p></div></section>
<h2>Actual circular steering path</h2><video src="steering_AB_24fps.mp4" poster="steering_poster.jpg" controls loop preload="metadata"></video><p>12-second figure eight exercises both turning directions. The path is authored for this test. Ground contact and planted turning remain unproven.</p>
<div class="cards"><div><h2>Living ready</h2><video src="ready_AB_24fps.mp4" poster="ready_poster.jpg" controls loop preload="metadata"></video></div><div><h2>Moving ready</h2><video src="move_AB_24fps.mp4" poster="move_poster.jpg" controls loop preload="metadata"></video></div></div>
<p class="note">The support-arm follow reads in close view but is understated at gameplay scale. Stock/hand overlaps still need work. Technical continuity does not constitute artistic approval.</p>
'''
for view in ['Front','Gameplay','Opposite','Side','Close','Distance']:html+=f'<h2>{view} inspection</h2><img src="studies_{view}.jpg" loading="lazy"><p>Ready / Move / Left arc / Right arc. Left and right are shown with root travel removed.</p>'
html+='<h2>Reference sweep evidence</h2><img src="reference_sweep.jpg" loading="lazy"><img src="reference_reverse.jpg" loading="lazy"><img src="reference_return.jpg" loading="lazy"><p>Ordered, timestamped frames from the actual supplied video.</p></main><script>document.querySelector("#speed").onchange=e=>document.querySelectorAll("video").forEach(v=>v.playbackRate=Number(e.target.value));</script></body></html>'
(OUT/'index.html').write_text(html,encoding='utf-8')
print('PACKAGED',json.dumps(media),flush=True)
