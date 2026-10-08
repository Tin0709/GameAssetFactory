"""Live MCP outward fan using canonical original coordinates; no cumulative transforms."""
import bpy
assert not bpy.app.background, 'Source writes require the connected foreground Blender session'
import hashlib
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector,Quaternion

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
EVIDENCE=ROOT/'.validation/flower_patch_v1'
sys.path.insert(0,str(HERE))
from flower_preservation import compare,digest
from tall_golden_fan_revision_audit import audit_tall_fan

assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve() and bpy.context.mode=='OBJECT'
baseline=json.loads((EVIDENCE/'before_tall_fan_revision_fingerprints.json').read_text())
obj=bpy.data.objects['ENV_TallGoldenGrass_1m_V1'];mesh=obj.data
changes=compare(baseline['data'])
assert not changes or set(changes)=={('objects',obj.name),('meshes',mesh.name)}, 'Preserve unrelated current user changes'
spec_path=HERE/'tall_golden_fan_revision_v1.json'
if not spec_path.exists():
    assert not changes
    rng=random.Random(72119);stems=[]
    for fid in range(28):
        green=[p for p in mesh.polygons if mesh.attributes['stem_index'].data[p.index].value==fid and mesh.attributes['part'].data[p.index].value==0]
        gold=[p for p in mesh.polygons if mesh.attributes['stem_index'].data[p.index].value==fid and mesh.attributes['part'].data[p.index].value==1]
        root=(Vector(baseline['tall_mesh']['vertices'][green[0].vertices[0]])+Vector(baseline['tall_mesh']['vertices'][green[0].vertices[1]]))*.5
        pivot=(Vector(baseline['tall_mesh']['vertices'][green[-1].vertices[2]])+Vector(baseline['tall_mesh']['vertices'][green[-1].vertices[3]]))*.5
        radius=root.xy.length
        amplitude=.023+.19*min(radius/.45,1)**1.4+rng.uniform(-.004,.004)
        direction=math.atan2(root.y,root.x)+rng.uniform(-.13,.13)
        fan=Vector((math.cos(direction)*amplitude,math.sin(direction)*amplitude,0))
        angle=math.atan(1.65*fan.length/pivot.z)
        stems.append({'stem':fid,'tip_outward_offset_xyz':list(fan),'seed_head_tilt_radians':angle,
                      'original_head_pivot_xyz':list(pivot),'green_faces':[p.index for p in green],
                      'gold_vertices':sorted({vi for p in gold for vi in p.vertices})})
    spec={'status':'User requested bushier outward tall grass silhouette; authoring parameters pending art review',
          'root_reserve_m':[1,1],'upper_canopy_span_cap_m':[1.3,1.3],'profile':'offset=tip_outward_offset*normalized_height^2',
          'stems':stems,'canonical_original_vertices':baseline['tall_mesh']['vertices'],
          'preservation_allowlist':'Tall mesh rest geometry/normals + derived object bounds only; all root vertices/heights/UV/albedo/material and revised white mesh unchanged',
          'before_fan_fingerprint':digest(baseline['data']),'baseline_tall_glb_sha256':baseline['tall_glb_sha256_before']}
    spec_path.write_text(json.dumps(spec,indent=2))
spec=json.loads(spec_path.read_text());original=[Vector(v) for v in spec['canonical_original_vertices']]
for stem in spec['stems']:
    fan=Vector(stem['tip_outward_offset_xyz']);pivot=Vector(stem['original_head_pivot_xyz'])
    for face_index in stem['green_faces']:
        p=mesh.polygons[face_index]
        for li in p.loop_indices:
            vi=mesh.loops[li].vertex_index;t=mesh.uv_layers[0].data[li].uv.x
            mesh.vertices[vi].co=original[vi]+fan*(t*t)
    rotation=Quaternion(Vector((0,0,1)).cross(fan).normalized(),stem['seed_head_tilt_radians'])
    for vi in stem['gold_vertices']:mesh.vertices[vi].co=pivot+fan+rotation@(original[vi]-pivot)
mesh.update();bpy.context.view_layer.update()
audit=audit_tall_fan()
display_location=obj.location.copy()
for selected in list(bpy.context.selected_objects):selected.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj;obj.location=(0,0,0);bpy.context.view_layer.update()
export_path=HERE/'exports/tall_golden_grass_1m_v1.glb'
try:
    bpy.ops.export_scene.gltf(filepath=str(export_path),export_format='GLB',use_selection=True,
        export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',
        export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,
        export_animations=False,export_morph=False,export_skins=False,export_cameras=False,
        export_lights=False,export_extras=False,export_apply=False)
finally:obj.location=display_location;bpy.context.view_layer.update()
assert audit_tall_fan()['status']=='PASS'
manifest_path=HERE/'tall_golden_grass_v1_manifest.json';manifest=json.loads(manifest_path.read_text())
manifest['bounds_blender']=audit['bounds_blender'];manifest['height_m']=audit['bounds_blender'][1][2]
manifest['height_above_player_rest_m']=manifest['height_m']-1.8
manifest['placement_footprint_m']=[1,1];manifest['placement_footprint_scope']='Reserved planted roots/base only; user-requested upper canopy may modestly overhang'
manifest['upper_canopy_span_xy_m']=audit['upper_canopy_span_xy_m'];manifest['upper_canopy_span_cap_m']=[1.3,1.3]
manifest['user_requested_fan_revision']={'profile':'Quadratic over4rings; exterior fan stronger, centre mostly upright','tip_offset_range_m':audit['tip_rest_offset_range_m'],
                                          'gold_heads':'Per-stem rigid translation and tilt; all UV masks/heights/root channels/albedo remain unchanged',
                                          'canonical_coordinates':'tall_golden_fan_revision_v1.json; idempotent, no cumulative fan'}
manifest['glb']=str(export_path.relative_to(ROOT));manifest['glb_sha256']=hashlib.sha256(export_path.read_bytes()).hexdigest()
manifest['export_scope']='Blender study only; user requested review before game integration'
manifest['blender_diagnostic_images']=['.validation/flower_patch_v1/blender_tall_fanned_grass_detail.png','.validation/flower_patch_v1/blender_all_four_plants_revised.png']
manifest_path.write_text(json.dumps(manifest,indent=2))
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_lights=False;space.shading.use_scene_world=False;space.overlay.show_overlays=False
        region=space.region_3d;region.view_location=(20,3.2,1.65)
        region.view_rotation=bpy.data.objects['CAM_TallGolden_V1_Diagnostic'].rotation_euler.to_quaternion();region.view_distance=6.1;region.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
(EVIDENCE/'validation_tall_fan_revision_live.json').write_text(json.dumps(audit,indent=2))
result={'status':'Saved live fan revision viaMCP','glb_sha256':manifest['glb_sha256'],'bounds_blender':manifest['bounds_blender'],'audit':audit,'export_scope':manifest['export_scope']}

