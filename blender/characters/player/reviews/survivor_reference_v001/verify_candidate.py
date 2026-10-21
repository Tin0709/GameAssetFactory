"""Reopen the Pending candidate and compare it directly with read-only V6 source."""
import bpy,json,struct,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;R=OUT.parents[4]
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Survivor_Reference_v001.blend'),load_ui=False)
scene=bpy.context.scene
assert scene['review_status']=='Pending' and scene['non_arm_original_geometry_exact'] and scene['slim_arms']
asset=next(c for c in bpy.data.collections if c.name.startswith('ASSET'))
meshes=[o for o in asset.objects if o.type=='MESH'];assert len(meshes)==3
obj=next(o for o in meshes if o.get('body_source'))
hair=next(o for o in meshes if o.get('hair_voxel_m'))
clothes=next(o for o in meshes if o not in [obj,hair])
rig=next(o for o in asset.objects if o.type=='ARMATURE')
assert len(obj.data.vertices)==48 and len(obj.data.polygons)==36 and len(bpy.data.actions)==0
report=json.loads((OUT/'model_validation.json').read_text())
def geometry_hash(o):
 raw=b''.join(struct.pack('<3f',*v.co) for v in o.data.vertices)+b''.join(struct.pack('<I',len(p.vertices))+struct.pack('<'+'I'*len(p.vertices),*p.vertices) for p in o.data.polygons)
 return hashlib.sha256(raw).hexdigest()
assert geometry_hash(obj)==report['body_geometry_sha256']
assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for o in meshes for v in o.data.vertices)
assert all(o.vertex_groups[g.group].name in rig.data.bones for o in meshes for v in o.data.vertices for g in v.groups)
assert len(rig.data.bones)==10 and all(len(o.data.materials)==1 for o in meshes)
assert all(o.data.materials[0]==obj.data.materials[0] for o in meshes)
assert all(im.packed_file for im in bpy.data.images if im.type=='IMAGE')
assert report['requested_3d_clothing'] and report['volumetric_hair']
assert hair['outer_relief_multiplier']==.8
source=R/'blender/characters/player/cuboid/player_cuboid_v6.blend'
assert hashlib.sha256(source.read_bytes()).hexdigest()==report['body_source_sha256']
before_objects=set(bpy.data.objects);before_data={n:set(getattr(bpy.data,n)) for n in ['meshes','armatures','materials','images']}
with bpy.data.libraries.load(str(source),link=False) as (src,dst):dst.objects=['Player_Cuboid_Base','Player_Cuboid_Rig']
srcmesh=next(o for o in dst.objects if o.type=='MESH');srcrig=next(o for o in dst.objects if o.type=='ARMATURE')
assert geometry_hash(srcmesh)==report['original_geometry_sha256']
for v,s in zip(obj.data.vertices,srcmesh.data.vertices):
 name=obj.vertex_groups[v.groups[0].group].name
 assert [(g.group,g.weight) for g in v.groups]==[(g.group,g.weight) for g in s.groups]
 if not name.startswith('Arm.'):assert tuple(v.co)==tuple(s.co)
 else:
  sign=1 if name.endswith('.L') else -1
  assert abs(v.co.x-(sign*.225+(s.co.x-sign*.225)*.75))<1e-7
  assert v.co.y==s.co.y and v.co.z==s.co.z
for b in rig.data.bones:
 if not b.name.startswith('Arm.'):assert b.matrix_local==srcrig.data.bones[b.name].matrix_local
for side,sign in [('L',1),('R',-1)]:
 assert abs(rig.data.bones['Arm.'+side].head_local.x-sign*.309375)<1e-7
 b=report['rigid_bounds_m']['Arm.'+side]
 assert all(abs((b['max'][i]-b['min'][i])-v)<1e-7 for i,v in enumerate([.16875,.225,.675]))
for o in set(bpy.data.objects)-before_objects:bpy.data.objects.remove(o,do_unlink=True)
for name,old in before_data.items():
 for block in set(getattr(bpy.data,name))-old:
  if block.users==0:getattr(bpy.data,name).remove(block)
assert abs(report['rigid_bounds_m']['Head']['min'][2]-report['rigid_bounds_m']['Chest']['max'][2])<1e-7
for o in meshes:
 if o.asset_data:o.asset_clear()
asset.asset_mark();asset.asset_data.description='Pending Soldier skin: original head/torso/legs,3x12x4 slim arms, layered brown hair, stronger3D clothing, large eyes and brows. Blender review only.'
asset['review_status']='Pending';asset['non_arm_geometry_unchanged']=True
review=bpy.data.images.load(str(OUT/'review_four_views.jpg'));review.name='REVIEW — front / three-quarter / side / back';review.pack();review.use_fake_user=True
scene['review_output']='review_four_views.jpg'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Survivor_Reference_v001.blend'),compress=True)
result={'passed':True,'fresh_reopen':True,'direct_source_comparison':True,'non_arm_geometry_exact':True,'documented_slim_arms_exact':True,'rigid_weights_exact':True,'non_arm_rest_skeleton_exact':True,'head_touches_torso':True,'base_mesh_vertices':48,'base_mesh_quads':36,'character_meshes':3,'clothing_triangles':report['clothing_triangles'],'hair_triangles':report['hair_triangles'],'hair_outer_relief_multiplier':.8,'actions':0,'whole_character_collection_registered':True,'shared_material':True,'packed_review':True,'candidate_only_saved':str(OUT/'Survivor_Reference_v001.blend')}
(OUT/'reopen_validation.json').write_text(json.dumps(result,indent=2));print('REOPEN_VALIDATION',json.dumps(result))
