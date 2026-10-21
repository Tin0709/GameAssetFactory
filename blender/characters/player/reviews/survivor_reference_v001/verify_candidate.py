import bpy,json,struct,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;R=OUT.parents[4]
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Survivor_Reference_v001.blend'),load_ui=False)
scene=bpy.context.scene;assert scene['review_status']=='Pending' and scene['original_body_unchanged']
asset=next(c for c in bpy.data.collections if c.name.startswith('ASSET'))
meshes=[o for o in asset.objects if o.type=='MESH'];assert len(meshes)==2
obj=next(o for o in meshes if o.get('original_body_unchanged'));clothes=next(o for o in meshes if o!=obj)
rig=next(o for o in asset.objects if o.type=='ARMATURE')
assert len(obj.data.vertices)==48 and len(obj.data.polygons)==36 and len(bpy.data.actions)==0
report=json.loads((OUT/'model_validation.json').read_text())
raw=b''.join(struct.pack('<3f',*v.co) for v in obj.data.vertices)+b''.join(struct.pack('<I',len(p.vertices))+struct.pack('<'+'I'*len(p.vertices),*p.vertices) for p in obj.data.polygons)
assert hashlib.sha256(raw).hexdigest()==report['body_geometry_sha256']
assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for o in meshes for v in o.data.vertices)
assert all(o.vertex_groups[g.group].name in rig.data.bones for o in meshes for v in o.data.vertices for g in v.groups)
assert abs(report['rigid_bounds_m']['Head']['min'][2]-report['rigid_bounds_m']['Chest']['max'][2])<1e-7
assert len(obj.data.materials)==1 and len(clothes.data.materials)==1 and obj.data.materials[0]==clothes.data.materials[0]
assert len(rig.data.bones)==10
assert all(im.packed_file for im in bpy.data.images if im.type=='IMAGE')
assert report['added_3d_clothing_only'] and not report['volumetric_hair']
# Asset Browser registration includes the original body, rig AND clothing.
obj.asset_clear();asset.asset_mark();asset.asset_data.description='Pending reference skin with requested3D clothing on the exact original V6 body. No neck/nose/mouth. Blender-only review.'
asset['review_status']='Pending';asset['base_geometry_unchanged']=True
review=bpy.data.images.load(str(OUT/'review_four_views.jpg'));review.name='REVIEW — front / three-quarter / side / back';review.pack();review.use_fake_user=True
scene['review_output']='review_four_views.jpg'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Survivor_Reference_v001.blend'),compress=True)
result={'passed':True,'fresh_reopen':True,'original_geometry_exact':True,'rigid_weights_exact':True,'head_touches_torso':True,'base_mesh_vertices':48,'base_mesh_quads':36,'clothing_vertices':len(clothes.data.vertices),'clothing_triangles':report['clothing_triangles'],'actions':0,'whole_character_collection_registered':True,'shared_material':True,'packed_review':True,'candidate_only_saved':str(OUT/'Survivor_Reference_v001.blend')}
(OUT/'reopen_validation.json').write_text(json.dumps(result,indent=2));print('REOPEN_VALIDATION',json.dumps(result))
