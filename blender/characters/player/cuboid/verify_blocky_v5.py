import bpy,ast,json,hashlib
from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
t=ast.parse((p/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in {'vv','mm','fcurves','action_signature'}],type_ignores=[]),'helpers','exec'))
def sig(a):
 s=action_signature(a);s.pop('name');return s
old={a.name:sig(a) for a in bpy.data.actions if a.name!='Player_Run_Blocky_V5'}
a=bpy.data.actions['Player_Run_Blocky_V5'];r=bpy.data.objects['Player_Cuboid_Rig'];s=bpy.context.scene
assert r.animation_data.action==a and s.render.fps/s.render.fps_base==24
assert s.use_preview_range and s.frame_preview_start==1 and s.frame_preview_end==17
assert r==bpy.context.view_layer.objects.active and r.select_get() and r.mode=='OBJECT'
with bpy.data.libraries.load(str(p/'blocky_character_mixamo_test_before_blocky_v5.blend'),link=False) as (src,dst):
 names=tuple(src.actions);dst.actions=list(names)
assert all(old[n]==sig(a) for n,a in zip(names,dst.actions)), 'Protected action changed versus backup'
assert hashlib.sha256((p/'player_cuboid_v6.blend').read_bytes()).hexdigest()=='cc2344b6c5fe00ec6a0f50f18997977206644c0d6037ed0dd0f0a9e338342cdd'
print('SAVED_V5_VERIFIED='+json.dumps({'action':'Player_Run_Blocky_V5','protected_actions_unchanged':names,'fps':24,'preview':[1,17],'frame':s.frame_current,'keys':sum(len(c.keyframe_points) for c in fcurves(a)),'production_unchanged':True}))

