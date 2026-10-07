import ast
from living_r9w2_common import *
tree=ast.parse((BASE/'probe_living_r9w2.py').read_text(encoding='utf-8-sig'));exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'<contact solver>','exec'))
s=bpy.data.scenes['R9W2_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W2_Probe_Rig'];w=gun(s);m=next(o for o in s.objects if o.type=='MESH' and 'Author_Mesh' in o.name);boxes=boxes_for(r,m,.005)
sample(r,s,bpy.data.actions['LongGunAimAround_LeftRight_V1'],73,True,True);pose={p.name:p.matrix_basis.copy() for p in r.pose.bones};gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy();socket=r.pose.bones['WeaponCarrier'].matrix.inverted()@gm;poles0={side:r.pose.bones['ForeArm.'+side].head.copy() for side in ['R','L']}
rows=[]
for x,y in [(0,0),(.025,0),(.05,0),(.075,0),(.05,-.025),(.05,.025),(0,-.025),(0,-.05)]:
 for back in [0,.10,.20]:
  apply_pose(r,pose);g=gm.copy();g.translation+=Vector((x,y,0));r.pose.bones['WeaponCarrier'].matrix=g@socket.inverted();bpy.context.view_layer.update();poles={k:v.copy() for k,v in poles0.items()};poles['R']+=Vector((0,back,0))
  try:targets=solve_contacts(r,g,poles)
  except ValueError:continue
  c={n:contact(r,w,n,boxes) for n in ['Head','Chest','UpperArm.R','ForeArm.R','ForeArm.L']}
  rows.append({'offset':[x,y,0],'pole_back':back,'contacts':c,'cost':c['UpperArm.R']['depth_m']+c['Chest']['depth_m']*10+c['Head']['depth_m']*10+.06*math.hypot(x,y)})
rows.sort(key=lambda x:x['cost']);(OUT/'stock_search.json').write_text(json.dumps(rows,indent=2))
best=rows[0];apply_pose(r,pose);g=gm.copy();g.translation+=Vector(best['offset']);r.pose.bones['WeaponCarrier'].matrix=g@socket.inverted();bpy.context.view_layer.update();poles={k:v.copy() for k,v in poles0.items()};poles['R']+=Vector((0,best['pole_back'],0));solve_contacts(r,g,poles)
for view in ['Gameplay','Close','Side','Opposite']:
 s.camera=bpy.data.objects['R9W2_'+view];s.render.filepath=str(OUT/f'stock_best_{view}.png');bpy.ops.render.render(write_still=True)
