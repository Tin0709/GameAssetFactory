from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
out=Path('blender/characters/enemies/zombie')
frames=[1,5,9,13,17,21,25,29]
sheet=Image.new('RGB',(1024,560),(24,32,40));draw=ImageDraw.Draw(sheet)
for i,f in enumerate(frames):
 im=Image.open(out/'v2_walk_pose_review'/f'{f:02d}.png').convert('RGBA');bg=Image.new('RGBA',im.size,(24,32,40,255));bg.alpha_composite(im)
 x=i%4*256;y=i//4*280;sheet.paste(bg.convert('RGB').resize((256,256)),(x,y));draw.text((x+8,y+260),f'Zombie V2 walk / {f}',fill=(220,230,235))
sheet.save(out/'zombie_cuboid_v2_walk_pose_review.jpg',quality=94)
for angle in ['front','isometric','side']:
 with Image.open(out/f'zombie_cuboid_v2_{angle}.png') as im:assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
report=json.loads((out/'zombie_v2_report.json').read_text())
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in report['source_hashes'].items())
(out/'zombie_cuboid_v2_notes.txt').write_text('Zombie Cuboid V2\n\nSix closed cuboids: cube head, box torso, one unsplit cuboid per arm and leg. Each limb has eight vertices, six quads, and no intermediate loops, caps or elbow/knee joints. 48 vertices, 72 triangles (V1: 120), 10 bones (V1: 18).\n\nRest mesh, UVs, bone hierarchy and rest matrices match player V6 exactly. Height 1.80 m; head 0.45 x 0.45 x 0.45 m; torso 0.45 x 0.225 x 0.675 m; each limb 0.225 x 0.225 x 0.675 m. Root/Hips/Spine/Chest/Neck/Head, Arm.L/R, Leg.L/R. Single full-weight bone binding per cuboid; all scales remain one.\n\nOriginal zombie V1 packed 64x64 atlas and material retained, including green skin, sunken eyes, slate worn jacket, faded undershirt, distressed cuffs, dark trousers and brown shoes. One material, nearest sampling, nonmetallic. Limb UVs cover full original 12-pixel rectangles.\n\nZombie_Idle (48 frames plus closing key 49) and Zombie_Walk (32 frames plus closing key 33), 24 FPS, adapted to whole-limb movement. Arms stay raised with asymmetric droop; hips/chest/head retain delayed sway and hunch. Walk uses modest uneven hip swings with full-block floor correction baked into ordinary transforms. Root stationary, no constraints/simulation, no elbow/knee bending. Runtime Godot playback has not been tested.\n\nQuarter-frame checks: rigid edges maintained below 0.000001 m error; loop closing vertices exactly match; idle feet planted with negligible numeric drift; walk minimum clearance approximately 1.4 mm. Static transparent front/isometric/side previews and eight walk key-pose previews visually reviewed. Detailed validation: zombie_v2_validation.json.\n\nZombie V1 and player V6 files unchanged (hash-checked).\n')
print('Transparent previews verified; source hashes unchanged.')
