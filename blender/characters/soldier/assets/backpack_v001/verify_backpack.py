"""Fresh-reopen scope/preservation check for the standalone backpack asset."""
import bpy,bmesh,json,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
LIB=HERE.parents[1]/'showcase/SOLDIER_Asset_Library.blend'
bpy.ops.wm.open_mainfile(filepath=str(LIB),load_ui=True)
library=bpy.data.scenes['SOLDIER_ASSET_LIBRARY']
registry=json.loads(library['soldier_registry'])
entry=next(e for e in registry['entries'] if e['id']=='SOLDIER_Backpack_v001')
asset=bpy.data.collections[entry['collection']]
assert entry['status']=='Pending' and asset['review_status']=='Pending' and asset.asset_data
assert asset.asset_data.catalog_id and asset.preview.image_size[0]>0
assert len(asset.objects)==1
obj=asset.objects[0]
assert obj.type=='MESH' and obj.parent is None and len(obj.modifiers)==0 and len(obj.vertex_groups)==0
assert len(obj.data.materials)==1
assert all(abs(obj.scale[i]-1)<1e-8 and abs(obj.location[i])<1e-8 for i in range(3))
bm=bmesh.new();bm.from_mesh(obj.data)
assert all(e.is_manifold for e in bm.edges),'Open seam on a solid equipment part'
bm.free()
assert len(bpy.data.actions)==0
scene=bpy.data.scenes[entry['review_scene']]
assert all(o.name.startswith('BPK_') for o in scene.objects),'Character leaked into equipment review'
assert not any(o.type=='ARMATURE' for o in scene.objects)
assert scene.camera.name=='BPK_Front_3Q'
assert entry['standalone'] and not entry['attached_to_character']
assert all(im.packed_file for im in bpy.data.images if im.type=='IMAGE')
assert all((HERE/'renders'/(v+'.png')).exists() for v in ['Front','Front_3Q','Left_Side','Back','Right_Side','Back_3Q'])
def digest(o):
    data={'matrix':[list(r) for r in o.matrix_local],'type':o.type}
    if o.type=='MESH':
        data.update(vertices=[list(v.co) for v in o.data.vertices],faces=[list(p.vertices) for p in o.data.polygons],uv=[[list(t.uv) for t in u.data] for u in o.data.uv_layers],weights=[[(g.group,g.weight) for g in v.groups] for v in o.data.vertices],groups=[g.name for g in o.vertex_groups],materials=[m.name for m in o.data.materials])
    elif o.type=='ARMATURE':data['bones']={b.name:[list(r) for r in b.matrix_local] for b in o.data.bones}
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()
original=json.loads((HERE/'validation.json').read_text())
assert original['skin_fingerprints']=={name:digest(bpy.data.objects[name]) for name in original['skin_fingerprints']}
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.ui_type=='ASSETS':assert area.spaces.active.asset_params,'Unsafe uninitialized Asset Browser'
# Pack the actual four-view review without altering any character data.
references=[im for im in bpy.data.images if im.name.startswith('BPK_PRIMARY')]
for duplicate in references[1:]:
    assert duplicate.users==1 and duplicate.use_fake_user
    bpy.data.images.remove(duplicate)
for previous in list(bpy.data.images):
    if previous.name.startswith('BPK_REVIEW') and previous.users==1 and previous.use_fake_user:
        bpy.data.images.remove(previous)
im=bpy.data.images.load(str(HERE/'review_four_views.jpg'));im.name='BPK_REVIEW front three-quarter side back';im.pack();im.use_fake_user=True
for window in bpy.context.window_manager.windows:window.scene=scene
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.shading.type='MATERIAL'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(LIB),compress=True)
result={'passed':True,'fresh_reopen':True,'standalone_equipment':True,'not_attached_or_worn':True,'skin_geometry_uv_weights_rig_unchanged':True,'closed_parts':True,'one_mesh_one_material':True,'packed_reference_atlas_review':True,'actions_added':0,'review_scene':scene.name,'registered_assets':len(registry['entries']),'native_asset_thumbnail':True,'safe_saved_layout':True}
(HERE/'reopen_validation.json').write_text(json.dumps(result,indent=2))
print('BACKPACK_REOPEN_VALIDATION',json.dumps(result))
