import bpy,json,ast
from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
t=ast.parse((p/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name=='fcurves'],type_ignores=[]),'helpers','exec'))
r=bpy.data.objects['Player_Cuboid_Rig'];s=bpy.context.scene
for name in ['Idle','Run']:
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 for b in r.pose.bones:b.location=(0,0,0);b.rotation_euler=(0,0,0)
 s.frame_set(2);s.frame_set(1);bpy.context.view_layer.update()
 print(name,'POSE',[(n,list(r.pose.bones[n].rotation_euler),list(r.pose.bones[n].location)) for n in ['Hips','Leg.L','Leg.R']],flush=True)
 print(name,'CURVES',[(c.data_path,c.array_index,c.evaluate(1)) for c in fcurves(a) if 'Leg.' in c.data_path],flush=True)
exec(compile((p/'reexport_game_glb_v1.py').read_text(),'exp','exec'))
for name in ['Idle','Run']:
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s.frame_set(2);s.frame_set(1);bpy.context.view_layer.update()
 print(name,'AFTER',[(n,list(r.pose.bones[n].rotation_euler),list(r.pose.bones[n].location)) for n in ['Hips','Leg.L','Leg.R']],flush=True)
