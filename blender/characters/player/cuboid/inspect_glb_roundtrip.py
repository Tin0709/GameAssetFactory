import bpy,json
from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=24
bpy.ops.import_scene.gltf(filepath=str(p/'export/player_cuboid_animated_v1.glb'))
print('IMPORT',[(o.name,o.type) for o in bpy.data.objects],[(a.name,list(a.frame_range)) for a in bpy.data.actions],flush=True)
r=next(o for o in bpy.data.objects if o.type=='ARMATURE')
m=bpy.data.objects['Player_Cuboid_Base'];manifest=json.loads((p/'export/player_cuboid_export_validation_input.json').read_text())
for a in bpy.data.actions:
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];bpy.context.scene.frame_set(1);bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
 print('POSE',a.name,[(n,list(r.pose.bones[n].matrix.translation)) for n in ['Hips','Leg.L','Leg.R']],flush=True)
 ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();from mathutils import Vector
 verts=[ev.matrix_world@v.co for v in me.vertices];expected=[Vector(v) for v in manifest['baseline'][a.name]['samples'][0]['vertices']]
 print('ROUNDTRIP_DIFF',a.name,max(min((v-w).length for w in expected) for v in verts),flush=True);ev.to_mesh_clear()
