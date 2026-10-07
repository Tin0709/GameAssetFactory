"""Extend the W1 local review format with matched A/B/C evidence."""
from pathlib import Path
import json,re,cv2
import numpy as np
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;OUT=BASE/'living_r9w2_review';font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
media={}
for mode,N in [('ready',96),('move',64),('sweep',288),('walk_local',288),('figure8',288)]:
 path=OUT/(mode+'_ABC_24fps.mp4');cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS);count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));assert count==N and fps==24,(mode,count,fps)
 selected=[0,N//6,N//3,N//2,2*N//3,5*N//6];frames={};decoded=0
 while True:
  ok,bgr=cap.read()
  if not ok:break
  if decoded in selected:frames[decoded]=Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB))
  decoded+=1
 assert decoded==N
 media[mode]={'frames':decoded,'fps':fps,'duration_s':N/fps,'size':[int(cap.get(3)),int(cap.get(4))]};cap.release();frames[selected[1]].save(OUT/(mode+'_poster.jpg'))
 sheet=Image.new('RGB',(1440,6*348),(17,28,38));draw=ImageDraw.Draw(sheet)
 for row,index in enumerate(selected):
  im=frames[index];im.thumbnail((1440,320));sheet.paste(im,((1440-im.width)//2,row*348+28));draw.text((14,row*348+4),f'{mode.upper()} — frame {index+1} — {index/24:.2f}s | A original / B contact / C support',font=font,fill='white')
 sheet.save(OUT/(mode+'_sequence.jpg'))
(OUT/'media_validation.json').write_text(json.dumps(media,indent=2))
for view in ['Gameplay','Distance','Close','Side','Opposite']:
 sheet=Image.new('RGB',(1440,4*350),(17,28,38));draw=ImageDraw.Draw(sheet)
 for row,case in enumerate(['Ready','Left','Reversal','Right']):
  for col,abc in enumerate(['A','B','C']):
   im=Image.open(OUT/f'{case}_{abc}_{view}.png');im.thumbnail((480,320));sheet.paste(im,(col*480+(480-im.width)//2,row*350+30));draw.text((col*480+10,row*350+5),f'{case} / {abc}',font=font,fill='white')
 sheet.save(OUT/f'ABC_{view}.jpg')
v=json.loads((OUT/'validation.json').read_text());pres=json.loads((OUT/'file_preservation_validation.json').read_text());loop=json.loads((OUT/'loop_velocity.json').read_text());c=v['studies']['Steering_C'];b=v['studies']['Steering_B'];a=v['studies']['Steering_A']
report=f'''R9-W2 — SUPPORT-ARM READABILITY + WEAPON CONTACT POLISH
2026-10-07 | BLENDER-ONLY RIGV2 STUDY | ARTISTIC STATUS: AWAITING HUMAN REVIEW

1. ACTUAL CAUSES
Inspected W1 centered Ready, left/right steering, reversal, and the same
moments over the existing Walk, using fixed inspection cameras. Before
frames are retained. Reference interpretation is reused from W1; no exact
reference angles or timing have been inferred from its moving camera.

A: W1's elbow-pole variation was small. B: from the gameplay camera the
far-side left elbow was largely superimposed on the rifle/torso. C: the
previous left internal hand-center target (weapon local y about 0.25m,
z about 0.02m) was near the magazine, not a defined handguard surface.
The primary grip also ran through the solid right terminal block. The stock
crossed the right upper-arm volume. This explains why tiny center-target
drift in W1 did not establish good contact. These findings correct the
overbroad 'fore-end contact' wording in the W1 report.

2. CONTACT CORRECTIONS AND REMAINING INTERSECTIONS
The rifle sweep, placement, scale and orientation are unchanged. The right
elbow configuration moves rearward to clear the stock while a side surface
of the terminal block meets the grip. The left block approaches the rear
handguard underside instead of enclosing the magazine. Both corrections
are shared by B and C. No mesh, hand size, segment length or weapon scaling.

Targets stored in design.json are INTERNAL block control points, not contact
markers. The surface diagnostics use terminal rigid-block bounds and patches
on the actual grip side (x=-0.033) and handguard underside (z=0.122), plus
weapon-triangle/rigid-box intersection checks. A probe caught a 7mm floating
support before final surface fitting; the rejected pose is not the V2.

Final C surface-patch gaps across half-frames: right <=
{c['patch_gap_max_m']['R']*1000:.3f}mm; left <= {c['patch_gap_max_m']['L']*1000:.3f}mm.
The terminal hand boxes do not intersect in the sampled steering sweep.
Stock butt-pad samples retain body contact, but contact can include embedding.

Remaining visible stock/upper-arm penetration: Steering frame 191.5,
t=7.9375s, Side and Close views (StockWorst_C_Side.png / Close.png).
Maximum weapon-vertex depth against a 5mm inset upper-arm box is
{c['max_contact']['UpperArm.R']['depth_m']*1000:.2f}mm, versus W1's roughly 64mm
for that region. This is a lower-bound proxy, not exact penetration volume.
Right forearm retains 4 intersecting triangles in the inset-box test;
left forearm reaches 4 during steering. Their sampled vertex-depth proxy is
zero, which DOES NOT establish zero intersection. Small corner/edge overlaps
remain around the grip/stock, visible in the same close side diagnosis.
The support's worst sampled surface gap is frame 256.5 / 10.6458s; inspect
SupportGapWorst_C_Close.png and Opposite.png. No conspicuous detachment is
visible there, but the broad block still makes an edge contact, not a
fingered wrap. This is contact polish, not fully clean weapon-body geometry.

3. LEFT SHOULDER / ELBOW / FOREARM
The shoulder joint stays fixed. Upper-arm and forearm rotations coordinate
around the unchanged two-link chain; the elbow remains connected. C rotates
the elbow-plane configuration through an authored 30-degree bias plus a
30-degree response to W1's existing support-drive sample. That sample already
contains the chosen 125ms history. No extra whole-hand lag was added.
This configuration was chosen from actual geometry, not a universal rule
mapping left aim to elbow opening. A negative-direction probe hid the elbow
more; a moderate positive orbit gave the clearer silhouette without a
horizontal 'airplane' arm. Support x/y stay fixed in weapon space while its
internal center height adjusts to keep a terminal surface at the handguard.
Most motion comes from the elbow/upper arm, not sliding the contact away.

At the fixed 960x640 Gameplay inspection camera, horizontal elbow travel is
{np.ptp(np.array(a['screen_elbow_points']),axis=0)[0]:.1f}px for A,
{np.ptp(np.array(b['screen_elbow_points']),axis=0)[0]:.1f}px for B and
{np.ptp(np.array(c['screen_elbow_points']),axis=0)[0]:.1f}px for C.
These are projected joint ranges, not visibility percentages or artistic
scores. Occlusion remains at several headings and at native distance.

4. RIGHT-GRIP / WEAPON RELATIONSHIP
Weapon authority is unchanged: WeaponCarrier bone -> COPY_TRANSFORMS on
M4A1_Reference_CarrierMount -> M4A1_Blocky_Root -> M4A1_Blocky_Base.
Actual bones are UpperArm.L/R and ForeArm.L/R; no hand bones exist.
Right contact is identical between B and C. It no longer pins the center
inside the grip; it fits a block side surface beside the grip. Across the
steering half-frame samples, authored right internal-target fit error is
{c['grip_center_fit_error_m']*1000:.3f}mm; left is
{c['support_center_fit_error_m']*1000:.3f}mm. These are bake/interpolation
errors around the per-frame intended target, not claims of identical rigid
hand-to-gun transforms. The arm pivots as the pose changes.

5. CHEST / HEAD
No Chest, Spine, Neck, Head or WeaponCarrier curve changes versus V1.
No increased head tilt and no new weapon path or competing driver.

6. CREATED FILE / ACTIONS
../player_longgun_living_r9w2_study.blend
LongGunAimAround_LeftRight_V2: 288-frame cycle / 12 seconds.
LongGunReady_LivingRef_V2: 96-frame cycle / 4 seconds.
LongGunReady_Move_V2: 64-frame cycle / 2.667 seconds.
All are upper-body/helper only, 39 curves, no Root/Hips/leg tracks.
Ready and Move V2 are needed because they share the corrected contact.
Six PREVIEW_ONLY_R9W2_A/B Actions hold upper-only W1/reference comparisons.
Existing V1 lower-body/path Actions are used directly in NLA, with no new
lower-body animation tracks, clock remap, 1.60x multiplier or Run V7 clock.

7. MATCHED A/B/C REVIEW
A original W1; B corrected contact with W1 gesture; C same corrected contact
plus the clearer support response. Matched camera, orthographic size, input,
timing and locomotion phase in each triptych. Uniform directional lighting
removes the positional lighting differences of W1's shared-scene previews.
All comparison clips are 24fps at 1x default. Five complete videos: stationary
sweep/reversal, same sweep over Walk with root removed, actual figure-eight,
Ready and Move. The figure-eight remains an authored diagnostic scenario.
Gameplay framing comes first, then native-distance and close/side diagnosis.
Blender opens on R9W2_REVIEW_SWEEP, frame 49, with C selected and the original
crossbow frame board beside the viewport. Scene selector exposes other cases.

8. PRESERVATION / VALIDATION
{pres['protected_files']} protected files unchanged; {v['preserved_actions']} pre-existing Actions
unchanged, including every V1 and the Walk source. Geometry/weights, rest
matrices, hierarchy, bone lengths and 13-bone RigV2 remain unchanged.
No new persistent IK, no bone constraints, no added bones, scale or stretching.
Shoulder shifts are below 0.001mm and connected elbow gap is zero in samples.
No head/chest weapon triangles intersect the 5mm inset boxes at half-frames.
Sampled A/B/C lower-body matrices match the original NLA source exactly;
Chest/head/weapon matrices agree exactly between variants. NLA uses the
original frame range with scale/repeat 1, so no gait clock restart is inserted.
Loop endpoint matrices agree below 0.000001. Finite-difference upper-body
rotation-velocity mismatch at the seam is <=
{max(x['rotation_velocity_delta_rad_s'] for row in loop.values() for x in row.values()):.6f}rad/s;
new arm quaternion curves use periodic endpoint tangents. This is sampled
numerical continuity, not proof of artistic smoothness or all-time collision
freedom. Full video streams were decoded, and ordered rendered frames were
inspected. I do NOT claim a continuous perceptual playback review.

9. ARTISTIC LIMITATIONS / STOP
C has a clearer elbow configuration and more visible open/settle motion;
the major contact improvement is already apparent in B. The rifle still
occludes the far elbow at some headings. At native-distance framing the
difference is smaller than close inspection suggests. The diagonal rifle
still foreshortens in the opposite view. The fingerless blocks give edge
support rather than a convincing wrapped grip, and residual stock/corner
penetration above remains. Review the arm sweep in real-time playback before
accepting it artistically. Planted turning weight and foot sliding remain
separate unresolved W1 issues; they were not redesigned here.
No Godot, production migration, gameplay, recoil/reload or Draw/Holster edits.
No further pass is started automatically.

ARTISTIC STATUS: AWAITING HUMAN REVIEW.
'''
(OUT/'R9_W2_REPORT.txt').write_text(report,encoding='utf-8')
old=(BASE/'living_r9w1_review/index.html').read_text(encoding='utf-8');style=re.search(r'<style>(.*?)</style>',old,re.S).group(1)
html=f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>R9-W2 — Support and contact</title><style>{style}</style></head><body><main><div class="badge">BLENDER-ONLY · AWAITING HUMAN REVIEW</div><h1>Support-arm readability & contact</h1><p>A — original W1 · B — corrected contact · C — corrected contact + support response.<br>Identical framing, timing and lighting within each comparison. V1 is preserved.</p><p><a href="../player_longgun_living_r9w2_study.blend">Blender study</a> · <a href="R9_W2_REPORT.txt">Full findings</a> · <a href="validation.json">Motion checks</a> · <a href="contact_audit.json">Contact audit</a></p><label>Playback speed <select id="speed"><option value="1">1× authored timing</option><option value="0.5">0.5× diagnosis</option><option value="0.25">0.25× diagnosis</option></select></label>'''
for mode,title,note in [('sweep','Stationary sweep and continuous reversal','Gameplay comparison first. All three use the same weapon sweep; only the arm treatment differs.'),('walk_local','Same sweep over the original Walk','Original Walk cadence; root travel removed equally for upper-body inspection.'),('figure8','Unchanged moving figure-eight','Original 12-second path, speed and Walk phase. Diagnostic path, not measured reference motion.'),('ready','Living Ready','Shared contact correction, same four-second duration.'),('move','Moving Ready','Four original Walk cycles, same 2.667-second duration.')]:
 html+=f'<h2>{title}</h2><video src="{mode}_ABC_24fps.mp4" poster="{mode}_poster.jpg" controls loop preload="metadata"></video><p>{note}</p>'
html+='<p class="note">Contact is substantially cleaner; stock overlap remains at frame 191.5 / 7.94s. The elbow reads more clearly in C but remains partly occluded. Ordered-frame inspection and numerical checks do not replace human playback approval.</p>'
for view in ['Gameplay','Distance','Close','Side','Opposite']:html+=f'<h2>{view} — same camera and scale across A/B/C</h2><img src="ABC_{view}.jpg" loading="lazy"><p>Rows: Ready / left-arc sample / reversal / right-arc sample. Columns: A / B / C.</p>'
html+='<h2>Remaining stock contact — frame 191.5 / 7.94s</h2><div class="cards"><img src="StockWorst_C_Side.png"><img src="StockWorst_C_Close.png"></div><p>Residual stock/upper-arm overlap. A zero vertex-depth result on other edges would not establish fully clean geometry.</p><h2>Support surface — frame 256.5 / 10.65s</h2><div class="cards"><img src="SupportGapWorst_C_Close.png"><img src="SupportGapWorst_C_Opposite.png"></div><h2>Original reference</h2><video src="../living_r9w1_review/minecraft_crossbow_hold_turning.mp4" controls loop preload="metadata"></video><p><a href="../living_r9w1_review/R9_W1_REPORT.txt">Existing reference analysis</a>. Camera movement prevents recovery of exact response timing or a world path.</p></main><script>document.querySelector("#speed").onchange=e=>document.querySelectorAll("video").forEach(v=>v.playbackRate=Number(e.target.value));</script></body></html>'
(OUT/'index.html').write_text(html,encoding='utf-8');print(json.dumps(media,indent=2))
