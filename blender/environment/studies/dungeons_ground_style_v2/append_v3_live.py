"""Run once in the user's existing Blender console. No scene reload or window creation."""
import bpy, json, hashlib
from pathlib import Path
ROOT=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/environment/studies/dungeons_ground_style_v2')
VALID=ROOT.parents[3]/'.validation/dungeons_ground_v3'
assert Path(bpy.data.filepath).name=='dungeons_ground_style_v2.blend','Wrong Blender window'
assert bpy.context.scene.name=='REVIEW_DungeonsGround_Style_V2','Wrong active scene'
assert not bpy.data.collections.get('REVIEW_DungeonsII_V3'),'Already appended; do not duplicate'
def fingerprint(o):
    d={'matrix':[list(row) for row in o.matrix_world],'type':o.type,'parent':o.parent.name if o.parent else None,'data':o.data.name if o.data else None,'materials':[m.name if m else None for m in getattr(o.data,'materials',[])]}
    if o.type=='MESH':d.update(v=[list(v.co) for v in o.data.vertices],p=[list(p.vertices) for p in o.data.polygons],uv=[[list(u.uv) for u in l.data] for l in o.data.uv_layers])
    return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
before={o.name:fingerprint(o) for o in bpy.context.scene.objects}
bpy.ops.wm.save_as_mainfile(filepath=str(VALID/'before_live.blend'),copy=True)
with bpy.data.libraries.load(str(ROOT/'v3_asset_library.blend'),link=False) as (src,dst):
    assert 'REVIEW_DungeonsII_V3' in src.collections
    dst.collections=['REVIEW_DungeonsII_V3']
col=dst.collections[0];bpy.context.scene.collection.children.link(col)
bpy.context.view_layer.update()
changed=[n for n,v in before.items() if fingerprint(bpy.data.objects[n])!=v]
assert not changed,'Existing object changed: '+str(changed)
scene=bpy.context.scene;scene.camera=bpy.data.objects['CAM_V3_Showcase']
# Keep the live window, restore its viewport with the newly added camera.
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':
        area.type='VIEW_3D';sp=area.spaces.active;sp.region_3d.view_perspective='CAMERA';sp.shading.type='MATERIAL';sp.shading.use_scene_lights=True;sp.shading.use_scene_world=True;sp.overlay.show_overlays=False
scene.render.resolution_x=1500;scene.render.resolution_y=1050
scene['V3_review_notes']='Original assets preserved at original locations. New V3 objects at X7..11; tiling patch Y6.5..10.5. No Godot migration.'
scene['V3_artistic_status']='AWAITING HUMAN REVIEW'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'dungeons_ground_style_v3_review.blend'))
(VALID/'live_append_result.json').write_text(json.dumps({'status':'PASS','active_file':bpy.data.filepath,'scene':scene.name,'old_objects_checked':len(before),'old_object_mismatches':changed,'collection':col.name,'camera':scene.camera.name,'new_asset_names':[o.name for o in col.all_objects if o.name.startswith('ENV_')],'same_live_window':True},indent=2))
