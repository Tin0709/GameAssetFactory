import bpy,ast,json,math
from pathlib import Path
from mathutils import Vector
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];scene=bpy.context.scene
for file,names in [('prepare_mixamo_run.py',{'vv','fcurves'}),('create_blocky_run_v2_pass2.py',{'sample'})]:
 t=ast.parse((BASE/file).read_text(encoding='utf-8-sig'));exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),'helpers','exec'))
a=bpy.data.actions['Player_Run_Blocky_V4'];rig.animation_data.action=a
if a.slots:rig.animation_data.action_slot=a.slots[0]
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
out={'curves':[{ 'path':c.data_path,'i':c.array_index,'keys':[[round(k.co.x,3),round(k.co.y,5),k.handle_left_type,k.handle_right_type] for k in c.keyframe_points]} for c in fcurves(a)],'poses':[]}
for f in [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17]:
 m,p=sample(f);out['poses'].append({'f':f,'hip':list(m['Hips'].translation),'legbottoms':{n:min(p[i].z for i in parts[n]) for n in ['Leg.L','Leg.R']}})
(BASE/'blocky_v5_prepolish_audit.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out))
