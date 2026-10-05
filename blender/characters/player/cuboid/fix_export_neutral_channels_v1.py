import bpy,json
from pathlib import Path
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
assert Path(bpy.data.filepath)==BASE/'player_cuboid_game_export_v1.blend'
fixes={}
for a in bpy.data.actions:
 bag=a.layers[0].strips[0].channelbags[0];existing={(c.data_path,c.array_index) for c in bag.fcurves};added=[]
 for n in bpy.data.objects['Player_Cuboid_Rig'].pose.bones.keys():
  if n=='Root':continue
  for prop in ['location','rotation_euler']:
   path=f'pose.bones["{n}"].{prop}'
   for axis in range(3):
    if (path,axis) in existing:continue
    c=bag.fcurves.new(path,index=axis)
    for f in a.frame_range:c.keyframe_points.insert(f,0).interpolation='LINEAR'
    added.append((path,axis))
 fixes[a.name]=added
rig=bpy.data.objects['Player_Cuboid_Rig']
for p in rig.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,check_existing=False)
inputfile=BASE/'export/player_cuboid_export_validation_input.json';m=json.loads(inputfile.read_text());m['technical_export_fix_constant_neutral_channels']=fixes;inputfile.write_text(json.dumps(m),encoding='utf-8')
exec(compile((BASE/'reexport_game_glb_v1.py').read_text(),'reexport','exec'))
