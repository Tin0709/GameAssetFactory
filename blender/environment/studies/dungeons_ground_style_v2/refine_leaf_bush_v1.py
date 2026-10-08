"""Live-only revision: denser olive leaf mosaic and compact offset cuboid silhouette."""
import bpy,json,sys,hashlib,random,importlib
from pathlib import Path
assert not bpy.app.background
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
baseline=json.loads((EVIDENCE/'before_leaf_bush_refinement_fingerprints.json').read_text())
assert set(compare(baseline['data']))<={('meshes','ENV_LeafBush_3x3x2m_V1_UnitBlockMesh'),('images','IMG_LeafBush_V1_OriginalClusterAtlas'),('objects','REVIEW_LeafBush_Dimensions_Label')},'Only this captured bush correction may be resumed'
# Share the updated canonical builder's deterministic authoring parameters.
builder=(HERE/'add_leaf_bush_v1.py').read_text();ns={'random':random}
exec(builder[builder.index('palette='):builder.index("image=bpy.data.images.new")],ns)
image=bpy.data.images['IMG_LeafBush_V1_OriginalClusterAtlas'];image.pixels.foreach_set(ns['pixels']);image.update();image.save();packed_bytes=Path(image.filepath_raw).read_bytes();image.pack(data=packed_bytes,data_len=len(packed_bytes))
exec(builder[builder.index('cells='):builder.index("m=bpy.data.meshes.new")],ns)
obj=bpy.data.objects['ENV_LeafBush_3x3x2m_V1'];m=obj.data;m.clear_geometry();m.from_pydata(ns['verts'],[],ns['faces']);m.update()
uv=m.uv_layers.get('UV_Leaf_32TexelsPerMetre')or m.uv_layers.new(name='UV_Leaf_32TexelsPerMetre')
for name in ('block_index','face_axis'):
    if not m.attributes.get(name):m.attributes.new(name=name,type='INT',domain='FACE')
for p,values,cell,axis in zip(m.polygons,ns['face_uvs'],ns['cell_ids'],ns['face_axes']):
    m.attributes['block_index'].data[p.index].value=cell;m.attributes['face_axis'].data[p.index].value=axis
    for li,value in zip(p.loop_indices,values):uv.data[li].uv=value
label=bpy.data.objects['REVIEW_LeafBush_Dimensions_Label'];label.location=(26.2,.9,.05);label.data.size=.14;label.data.body='LEAF BUSH 3 x 3 m / HEIGHT 2 m\n1 BLOCK = 1 m / PLAYER = 1.8 m'
manifest_path=HERE/'leaf_bush_v1_manifest.json';manifest=json.loads(manifest_path.read_text());manifest.update({'palette_srgb':['#'+x for x in ns['palette']],'cell_coordinates':sorted(ns['cells']),'silhouette':'Contiguous2×2 upper mass with offset back shoulder; inset front corners avoid a full-width staircase ledge','texture_generation':'Original dense layered smaller angular olive leaf marks; restrained pale gold;32texels/m unchanged','texture_sha256':hashlib.sha256(Path(image.filepath_raw).read_bytes()).hexdigest(),'current_refinement':'refine_leaf_bush_v1.py'})
for o in list(bpy.context.selected_objects):o.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj;location=obj.location.copy();obj.location=(0,0,0);bpy.context.view_layer.update();export=HERE/'exports/leaf_bush_3x3x2m_v1.glb'
try:bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
finally:obj.location=location;bpy.context.view_layer.update()
manifest['sha256']=hashlib.sha256(export.read_bytes()).hexdigest();manifest_path.write_text(json.dumps(manifest,indent=2))
import validate_leaf_bush_v1;importlib.reload(validate_leaf_bush_v1);report=validate_leaf_bush_v1.audit_export();manifest['audit']=report;manifest_path.write_text(json.dumps(manifest,indent=2))
allowed={('meshes',m.name),('images',image.name),('objects',label.name)};changes=compare(baseline['data']);assert set(changes)==allowed,str(changes)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result={'status':'Refined bush visible and saved LIVE','audit':report,'authorized_refinement_changes':changes}

