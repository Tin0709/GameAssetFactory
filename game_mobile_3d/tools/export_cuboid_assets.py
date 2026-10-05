"""Run through Blender MCP; selected actors only, embedded textures, all named actions."""
import bpy,json,hashlib,struct
from pathlib import Path
ROOT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory')
OUT=ROOT/'game_mobile_3d/assets/characters'
records=[]
for name,source,rig_name,mesh_name,expected in [
 ('player_cuboid_v6','blender/characters/player/cuboid/player_cuboid_v6.blend','Player_Cuboid_Rig','Player_Cuboid_Base',['Player_Idle','Player_Walk','Player_Run']),
 ('zombie_cuboid_v2','blender/characters/enemies/zombie/zombie_cuboid_v2.blend','Zombie_Cuboid_Rig','Zombie_Cuboid_Base',['Zombie_Idle','Zombie_Walk'])]:
 path=ROOT/source;sha=hashlib.sha256(path.read_bytes()).hexdigest()
 bpy.ops.wm.open_mainfile(filepath=str(path));rig=bpy.data.objects[rig_name];mesh=bpy.data.objects[mesh_name]
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_frame_step=1,export_force_sampling=True,export_anim_slide_to_zero=True,export_def_bones=False,export_rest_position_armature=True,export_reset_pose_bones=True,export_anim_single_armature=True,export_cameras=False,export_lights=False,export_extras=False,export_morph=False,export_original_specular=True)
 raw=(OUT/(name+'.glb')).read_bytes();length,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length])
 assert sorted(a['name'] for a in doc['animations'])==sorted(expected)
 assert len(doc['skins'][0]['joints'])==10 and len(doc['materials'])==1
 assert sha==hashlib.sha256(path.read_bytes()).hexdigest()
 records.append({'source':source,'source_sha256':sha,'runtime_file':name+'.glb','bytes':len(raw),'actions':expected,'joints':10,'materials':1,'samplers':doc.get('samplers'), 'animations_seconds':{a['name']:max(doc['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in doc['animations']}})
(OUT/'export_manifest.json').write_text(json.dumps(records,indent=2))
result={'assets':records}

