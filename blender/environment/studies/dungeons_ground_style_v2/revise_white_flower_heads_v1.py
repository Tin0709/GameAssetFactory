"""Live MCP head-only revision; uses canonical original coordinates, never multiplies cumulatively."""
import bpy
assert not bpy.app.background, 'Source writes require the connected foreground Blender session'
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
EVIDENCE=ROOT/'.validation/flower_patch_v1'
sys.path.insert(0,str(HERE))
from flower_preservation import compare,digest
from white_flower_head_revision_audit import audit_revision

assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve() and bpy.context.mode=='OBJECT'
baseline=json.loads((EVIDENCE/'before_white_head_revision_fingerprints.json').read_text())
obj=bpy.data.objects['ENV_WhiteFlowerPatch_1m_V1'];mesh=obj.data
changes=compare(baseline['data'])
assert not changes or changes==[('objects',obj.name),('meshes',mesh.name)], 'Do not replace unrelated current user edits'
spec_path=HERE/'white_flower_head_revision_v1.json'
if not spec_path.exists():
    assert not changes
    flowers=[];canonical={}
    for fid in range(5):
        centre=next(p for p in mesh.polygons if mesh.attributes['flower_index'].data[p.index].value==fid and mesh.attributes['flower_part'].data[p.index].value==2)
        petals=[p for p in mesh.polygons if mesh.attributes['flower_index'].data[p.index].value==fid and mesh.attributes['flower_part'].data[p.index].value==1]
        flowers.append({'flower':fid,'centre_vertices':list(centre.vertices),'petal_vertices':[list(p.vertices) for p in petals]})
        for polygon in [centre]+petals:
            for vi in polygon.vertices:canonical[str(vi)]=baseline['white_mesh']['vertices'][vi]
    spec={'status':'User requested 1.5x heads and slightly upward petals;12-degree authoring interpretation awaiting art review',
          'head_scale_factor':1.5,'petal_upward_cup_degrees':12,'flowers':flowers,'canonical_original_head_vertices':canonical,
          'allowed_change':'Only 100 white head vertices and derived normals; yellow centre scales about same centre; stems/leaves/UV/colour/material unchanged',
          'pre_revision_fingerprint':digest(baseline['data']),'baseline_white_glb_sha256':baseline['white_glb_sha256_before']}
    spec_path.write_text(json.dumps(spec,indent=2))
spec=json.loads(spec_path.read_text())
original={int(k):Vector(v) for k,v in spec['canonical_original_head_vertices'].items()}
factor=spec['head_scale_factor'];cup=math.radians(spec['petal_upward_cup_degrees'])
for flower in spec['flowers']:
    centre_indices=flower['centre_vertices']
    centre=sum((original[i] for i in centre_indices),Vector())/4
    normal=(original[centre_indices[1]]-original[centre_indices[0]]).cross(original[centre_indices[3]]-original[centre_indices[0]]).normalized()
    for vi in centre_indices:mesh.vertices[vi].co=centre+(original[vi]-centre)*factor
    for indices in flower['petal_vertices']:
        old=[original[i] for i in indices]
        radial=((old[1]+old[2])-(old[0]+old[3]))*.5
        extension=(radial*math.cos(cup)+normal*radial.length*math.sin(cup))*factor
        inner_left=centre+(old[0]-centre)*factor
        inner_right=centre+(old[3]-centre)*factor
        for vi,point in zip(indices,(inner_left,inner_left+extension,inner_right+extension,inner_right)):
            mesh.vertices[vi].co=point
mesh.update();bpy.context.view_layer.update()
audit=audit_revision()
assert all(-.5<=v.co.x<=.5 and -.5<=v.co.y<=.5 for v in mesh.vertices)
display_location=obj.location.copy()
for selected in list(bpy.context.selected_objects):selected.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj
obj.location=(0,0,0);bpy.context.view_layer.update()
export_path=HERE/'exports/white_flower_patch_1m_v1.glb'
export_path.parent.mkdir(parents=True,exist_ok=True)
try:
    bpy.ops.export_scene.gltf(filepath=str(export_path),export_format='GLB',use_selection=True,
        export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',
        export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,
        export_animations=False,export_morph=False,export_skins=False,export_cameras=False,
        export_lights=False,export_extras=False,export_apply=False)
finally:
    obj.location=display_location;bpy.context.view_layer.update()
assert audit_revision()['status']=='PASS'
manifest_path=HERE/'white_flowers_v1_manifest.json';manifest=json.loads(manifest_path.read_text())
manifest['mesh_local_bounds_blender']=[[min(v.co[i] for v in mesh.vertices) for i in range(3)],[max(v.co[i] for v in mesh.vertices) for i in range(3)]]
manifest['glb_sha256']=hashlib.sha256(export_path.read_bytes()).hexdigest()
manifest['user_requested_head_revision']={'head_scale_factor':factor,'petal_upward_cup_degrees':spec['petal_upward_cup_degrees'],
                                         'unchanged':'Five roots, stems, leaves, head-centre heights, UV metadata, colours and material',
                                         'baseline_head_coordinates':'white_flower_head_revision_v1.json; canonical original heads make reapplication noncumulative',
                                         'pre_revision_fingerprint':digest(baseline['data']),'original_white_glb_sha256':baseline['white_glb_sha256_before']}
manifest['blender_diagnostic_images']=['.validation/flower_patch_v1/blender_flowers_enlarged_cupped_detail.png','.validation/flower_patch_v1/blender_all_four_plants_revised.png']
manifest_path.write_text(json.dumps(manifest,indent=2))
camera=bpy.data.objects['CAM_Flowers_Grass_V1_Diagnostic']
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_lights=False;space.shading.use_scene_world=False
        space.overlay.show_overlays=False;region=space.region_3d
        region.view_location=(15,3.2,.88);region.view_rotation=camera.rotation_euler.to_quaternion();region.view_distance=2.15;region.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
(EVIDENCE/'validation_white_head_revision_live.json').write_text(json.dumps(audit,indent=2))
result={'status':'Saved live viaMCP','glb_sha256':manifest['glb_sha256'],'bounds_blender':manifest['mesh_local_bounds_blender'],'head_scale_factor':factor,'petal_upward_cup_degrees':spec['petal_upward_cup_degrees'],'audit':audit}

