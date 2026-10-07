import bpy,json,math,numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene;a=bpy.data.actions['Draw_LongGun_V3_Final'];rig.animation_data.action=a
changes=json.loads(a['production_changes_json'])
script=(BASE/'polish_draw_d4_v3.py').read_text()
exec(script[script.index('def curves(a)'):script.index('assert \'Draw_LongGun_V3_Final\'')])
exec(script[script.index('def retime('):script.index('# Preserve short alert')])
exec(script[script.index('data=json.loads('):script.index('contact=[]')].replace("+.025","+.01").replace("-.025","-.01").replace("hi[1]-=.12","hi[1]-=.04"))
contacts=[]
for n,f in [('Arm.L',10.9),('Arm.L',11.8),('Arm.L',13.1)]:
 frame(f);p=rig.pose.bones[n];original=p.rotation_euler.copy();before=score(n);best=(before,0,original.copy(),(0,0,0))
 for axis in range(3):
  for deg in [-2,-1,-.5,.5,1,2]:
   q=original.copy();q[axis]+=math.radians(deg);p.rotation_euler=q;bpy.context.view_layer.update();s=score(n)
   if (s,abs(deg))<best[:2]:best=(s,abs(deg),q.copy(),tuple(deg if i==axis else 0 for i in range(3)))
 for i in range(3):
  if abs(best[2][i]-original[i])>1e-7:value(n,'rotation_euler',i,f,best[2][i])
 contacts.append({'bone':n,'frame':f,'triangles_before':before,'triangles_after':best[0],'delta_degrees':best[3],'terminal_exclusion_m':.04})
# Slightly tighten the outward sweep arc without changing pull-clearance or catch.
c=next(c for c in curves(a) if c.data_path=='pose.bones["WeaponCarrier"].location' and c.array_index==0)
value('WeaponCarrier','location',0,8.2,c.evaluate(8.2)-.012)
a['production_changes_json']=json.dumps(changes);a['catch_cleanup_json']=json.dumps(contacts)
(BASE/'draw_d4_v3_changes.json').write_text(json.dumps({'changes':changes,'grip_cleanup':json.loads(a['contact_cleanup_json']),'catch_cleanup':contacts},indent=2))
frame(1)
result={'catch_cleanup':contacts}
