import bpy,ast,json,hashlib
from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
t=ast.parse((p/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in {'vv','mm','fcurves','action_signature'}],type_ignores=[]),'helpers','exec'))
a=bpy.data.actions['Player_Run_Blocky_V3'];b=bpy.data.actions['Player_Run_Blocky_V2'];r=bpy.data.objects['Player_Cuboid_Rig'];s=bpy.context.scene
assert [c for c in action_signature(a)['curves'] if not any('"'+n+'"' in c['path'] for n in ['Arm.L','Arm.R'])]==action_signature(b)['curves']
assert r.animation_data.action==a and len(fcurves(a))==30
assert s.use_preview_range and s.frame_preview_start==1 and s.frame_preview_end==17 and s.render.fps/s.render.fps_base==24
assert hashlib.sha256((p/'player_cuboid_v6.blend').read_bytes()).hexdigest()=='cc2344b6c5fe00ec6a0f50f18997977206644c0d6037ed0dd0f0a9e338342cdd'
print('SAVED_V3_VERIFIED='+json.dumps({'action':a.name,'curves':len(fcurves(a)),'fps':s.render.fps,'preview':[s.frame_preview_start,s.frame_preview_end],'unchanged_v2_curves':True,'production_hash':hashlib.sha256((p/'player_cuboid_v6.blend').read_bytes()).hexdigest()}))

