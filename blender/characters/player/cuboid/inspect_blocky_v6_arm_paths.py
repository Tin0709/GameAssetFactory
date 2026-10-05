import bpy,math,json
from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
s=(p/'create_blocky_run_v6_pass6.py').read_text(encoding='utf-8-sig').split('# Validation including')[0]
exec(compile(s,'v6_dry_candidate','exec'))
rows={};testframes=[1+i*.5 for i in range(33)]
for n in ['Arm.L','Arm.R']:
 cy=curve(n,'rotation_euler',1);cz=curve(n,'rotation_euler',2)
 ys=[k.co.y for k in cy.keyframe_points];zs=[k.co.y for k in cz.keyframe_points];rows[n]=[]
 for roll in [-1.5,-.75,0,.75,1.5]:
  for yaw in [-1.2,-.6,0,.6,1.2]:
   for k,v in zip(cy.keyframe_points,ys):k.co.y=v+math.radians(yaw)
   for k,v in zip(cz.keyframe_points,zs):k.co.y=v+math.radians(roll*(1 if n=='Arm.L' else -1))
   cy.update();cz.update();tangents(cy);tangents(cz)
   hc=tc=0
   for f in testframes:
    m,points=sample(f);hc=max(hc,overlap('Head',n,points));tc=max(tc,overlap('Chest',n,points))
   rows[n].append(dict(roll_add=roll,yaw_add=yaw,head_m=hc,chest_m=tc))
 for k,v in zip(cy.keyframe_points,ys):k.co.y=v
 for k,v in zip(cz.keyframe_points,zs):k.co.y=v
 cy.update();cz.update();tangents(cy);tangents(cz)
print('PATH_SEARCH='+json.dumps(rows));(p/'blocky_v6_arm_path_candidates.json').write_text(json.dumps(rows,indent=2))
