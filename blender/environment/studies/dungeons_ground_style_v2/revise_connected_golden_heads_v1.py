"""Run through the live Blender MCP only: continuous union outline per gold head."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector,Quaternion
assert not bpy.app.background, 'Source mutations require the current foreground Blender session'
HERE=Path(__file__).resolve().parent
EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1'
sys.path.insert(0,str(HERE))
from flower_preservation import compare
from golden_connected_head_audit import audit_connected_source
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
baseline=json.loads((EVIDENCE/'before_connected_golden_heads_fingerprints.json').read_text());assert not compare(baseline['data'])
old=baseline['gold_mesh'];spec=json.loads((HERE/'golden_shoulder_revision_v1.json').read_text())
obj=bpy.data.objects['ENV_TallGoldenGrass_1m_V1'];m=obj.data;vertices=[Vector(v)for v in old['vertices']];faces=[];ids=[];parts=[]
for s in spec['stems']:
    fid=s['stem'];base=fid*48;u=Vector(s['blade_width_direction_xyz']);pivot=Vector(s['head_pivot_xyz']);rot=Quaternion(Vector(s['head_tilt_axis_xyz']),s['head_tilt_radians'])
    for k in range(8):
        vi=base+16+k*4;side=-1 if k%2==0 else 1;local=rot.inverted()@(vertices[vi]-pivot)
        vertices[vi]=pivot+rot@(local+u*(side*.011-local.dot(u)))
    for ring in range(3):faces.append(old['faces'][fid*12+ring][0]);ids.append(fid);parts.append(0)
    # Traverse the union's exterior boundary. Each leaflet shares a finite shaft edge.
    boundary=[base+12,base+13]
    for tier in range(4):boundary.extend(base+16+(tier*2+1)*4+k for k in (0,1,2,3))
    boundary.extend((base+14,base+15))
    for tier in reversed(range(4)):boundary.extend(base+16+tier*8+k for k in (3,2,1,0))
    faces.append(boundary);ids.append(fid);parts.append(1)
m.clear_geometry();m.from_pydata(vertices,[],faces);m.update()
color=m.color_attributes.get('Color')or m.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
for name in ('UV_Stem_Height','UV_Stem_Root'):
    if not m.uv_layers.get(name):m.uv_layers.new(name=name)
for name in ('stem_index','part','gold_tier'):
    if not m.attributes.get(name):m.attributes.new(name=name,type='INT',domain='FACE')
for p,fid,part in zip(m.polygons,ids,parts):
    m.attributes['stem_index'].data[p.index].value=fid;m.attributes['part'].data[p.index].value=part;m.attributes['gold_tier'].data[p.index].value=-3 if part else -1;p.use_smooth=False
    for li in p.loop_indices:
        vi=m.loops[li].vertex_index;color.data[li].color=old['colors']['Color']['values'][vi]
        for name in ('UV_Stem_Height','UV_Stem_Root'):m.uv_layers[name].data[li].uv=old['uv'][name][vi]
m.color_attributes.active_color=color;m.uv_layers.active_index=0;bpy.context.view_layer.update()
report=audit_connected_source()
for selected in list(bpy.context.selected_objects):selected.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj;location=obj.location.copy();obj.location=(0,0,0)
export=HERE/'exports/tall_golden_grass_1m_v1.glb'
try:
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
finally:obj.location=location;bpy.context.view_layer.update()
manifest_path=HERE/'tall_golden_grass_v1_manifest.json';manifest=json.loads(manifest_path.read_text())
manifest.update({'triangles':1120,'quads':84,'ngons':28,'source_faces':112,'authored_vertices':1344,'gold_seed_quads_per_stem':0,'gold_connected_planar_heads':28,'head_arrangement':'One continuous planar outline per stem; original four paired tier tips retained; narrow finite shaft attachment, no overlapping interior faces','connected_head_revision':'revise_connected_golden_heads_v1.py','glb_sha256':hashlib.sha256(export.read_bytes()).hexdigest()})
manifest_path.write_text(json.dumps(manifest,indent=2))
(HERE/'golden_connected_head_revision_v1.json').write_text(json.dumps({'status':'User-requested single connected planar gold head; review pending','report':report,'sha256':manifest['glb_sha256']},indent=2))
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_location=(21,3.2,1.6);area.spaces.active.region_3d.view_distance=2.8;area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result={**report,'status':'Updated and saved LIVE in the existing window','study_export_sha256':manifest['glb_sha256']}
