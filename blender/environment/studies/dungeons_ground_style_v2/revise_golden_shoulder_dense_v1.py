"""Latest live-only golden bush: shoulder-height tips, outward fan, four paired seed tiers."""
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
from golden_shoulder_revision_audit import audit_shoulder_source

assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve() and bpy.context.mode=='OBJECT'
baseline=json.loads((EVIDENCE/'before_shoulder_dense_golden_grass_fingerprints.json').read_text())
assert not compare(baseline['data']), 'Apply latest correction once to its preserved live baseline'
measurement=json.loads((EVIDENCE/'player_shoulder_measurement.json').read_text())
shoulder=measurement['shoulder_top_height_m']
original=json.loads((HERE/'tall_golden_fan_revision_v1.json').read_text())['canonical_original_vertices']
obj=bpy.data.objects['ENV_TallGoldenGrass_1m_V1'];mesh=obj.data;material=mesh.materials[0]
before=baseline['gold_mesh'];rng=random.Random(419321)
roots=[(Vector(original[fid*28])+Vector(original[fid*28+1]))*.5 for fid in range(28)]
radii=[r.xy.length for r in roots];rmin,rmax=min(radii),max(radii)
vertices,faces,colors,uv0s,uv2s,ids,parts,tiers=[],[],[],[],[],[],[],[]
spec_stems=[]
def quad(points,color,masks,h,rootuv,fid,part,tier):
    start=len(vertices);vertices.extend(tuple(p)for p in points);faces.append(tuple(range(start,start+4)))
    colors.append(color);uv0s.extend((t,h)for t in masks);uv2s.extend(tuple(rootuv)for _ in points)
    ids.append(fid);parts.append(part);tiers.append(tier)

for fid in range(28):
    root=roots[fid];orig=Vector(original[fid*28+1])-Vector(original[fid*28]);width=orig.length;u=orig.normalized()
    old_pivot=(Vector(original[fid*28+10])+Vector(original[fid*28+11]))*.5
    lean=Vector((old_pivot.x-root.x,old_pivot.y-root.y,0))
    spread=(radii[fid]-rmin)/(rmax-rmin)
    fan_amount=.045+.195*spread**1.1+rng.uniform(-.005,.005)
    direction=math.atan2(root.y,root.x)+rng.uniform(-.12,.12)
    fan=Vector((math.cos(direction)*fan_amount,math.sin(direction)*fan_amount,0))
    axis=Vector((0,0,1)).cross(fan).normalized()
    tip=shoulder*(1-.29*spread+rng.uniform(-.023,.023))
    tip=min(shoulder,tip)
    if radii[fid]==rmin:tip=shoulder
    shaft_half=.011
    lengths=[.095,.080,.065,.050];bases=[.018+i*.035 for i in range(4)];half_width=.013;up=math.radians(28)
    relative=[(-u*shaft_half, u*shaft_half, u*shaft_half+Vector((0,0,.165)), -u*shaft_half+Vector((0,0,.165)))]
    for tier in range(4):
        for side in(-1,1):
            along=u*(side*math.cos(up))+Vector((0,0,math.sin(up)))
            across=-u*(side*math.sin(up))+Vector((0,0,math.cos(up)))
            p0=u*side*(shaft_half+half_width*math.sin(up))+Vector((0,0,bases[tier]));p1=p0+along*lengths[tier]
            relative.append((p0-across*half_width,p1-across*half_width,p1+across*half_width,p0+across*half_width))
    def top_height(h):
        rotation=Quaternion(axis,math.atan(1.65*fan.length/h))
        return h+max((rotation@p).z for points in relative for p in points)
    low,high=.4,shoulder
    for _ in range(45):
        mid=(low+high)*.5
        if top_height(mid)>tip:high=mid
        else:low=mid
    h=(low+high)*.5
    pivot=root+lean+fan+Vector((0,0,h));angle=math.atan(1.65*fan.length/h);rotation=Quaternion(axis,angle)
    rootuv=before['uv']['UV_Stem_Root'][(fid*7)*4]
    for ring in range(3):
        old_fi=fid*7+ring;old_indices=before['faces'][old_fi][0]
        masks=[before['uv']['UV_Stem_Height'][old_fi*4+c][0]for c in range(4)]
        points=[]
        for corner,t in enumerate(masks):
            p=Vector(original[fid*28+ring*4+corner])
            if t!=0:
                p+=fan*(t*t);p.z=h*t
            points.append(p)
        color=before['colors']['Color']['values'][old_fi*4]
        quad(points,color,masks,h,rootuv,fid,0,-1)
    gold=before['colors']['Color']['values'][(fid*7+3)*4]
    for index,points in enumerate(relative):
        quad([pivot+rotation@p for p in points],gold,(1,)*4,h,rootuv,fid,1,-2 if index==0 else (index-1)//2)
    spec_stems.append({'stem':fid,'root_xyz':list(root),'blade_width_m':width,'blade_width_direction_xyz':list(u),
                       'fan_xyz':list(fan),'head_pivot_xyz':list(pivot),'head_tilt_axis_xyz':list(axis),'head_tilt_radians':angle,
                       'head_base_height_m':h,'seed_tip_height_m':tip,'tier_lengths_m':lengths,'tier_base_heights_m':bases})

# Preserve the same editable mesh ID/material. Topology changes only for the explicitly requested dense seed heads.
mesh.clear_geometry();mesh.from_pydata(vertices,[],faces);mesh.update()
assert len(mesh.materials)==1 and mesh.materials[0]==material
color=mesh.color_attributes.get('Color') or mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
uv0=mesh.uv_layers.get('UV_Stem_Height') or mesh.uv_layers.new(name='UV_Stem_Height')
uv2=mesh.uv_layers.get('UV_Stem_Root') or mesh.uv_layers.new(name='UV_Stem_Root')
stem_attr=mesh.attributes.get('stem_index') or mesh.attributes.new(name='stem_index',type='INT',domain='FACE')
part_attr=mesh.attributes.get('part') or mesh.attributes.new(name='part',type='INT',domain='FACE')
tier_attr=mesh.attributes.get('gold_tier') or mesh.attributes.new(name='gold_tier',type='INT',domain='FACE')
for p,c,fid,part,tier in zip(mesh.polygons,colors,ids,parts,tiers):
    p.use_smooth=False;stem_attr.data[p.index].value=fid;part_attr.data[p.index].value=part;tier_attr.data[p.index].value=tier
    for li in p.loop_indices:
        vi=mesh.loops[li].vertex_index;color.data[li].color=c;uv0.data[li].uv=uv0s[vi];uv2.data[li].uv=uv2s[vi]
mesh.color_attributes.active_color=color;mesh.uv_layers.active_index=0
status='Original shoulder-height golden meadow bush; dense ordered four-paired seed tiers; awaiting user art review'
contract='UV0.x normalized green rings, all seed planes1; UV0.y actual head-pivot height metres; imported height=1-UV.y; UV2 rootXZ=UV2-.5'
obj['authoring_status']=status;obj['wind_contract']=contract
label=f'GOLDEN MEADOW GRASS / {shoulder:.2f} m\nPLAYER SHOULDER / {shoulder:.2f} m'
bpy.data.objects['REVIEW_TallGolden_Actual_Height_Label'].data.body=label
bpy.context.view_layer.update()
spec={'status':'Latest requested shoulder-height bush with dense ordered seed heads; artistic review pending',
      'measured_player_shoulder_m':shoulder,'player_stature_m':1.8,'measurement_method':measurement['method'],
      'stems':spec_stems,'current_display_label':label,'current_authoring_status':status,'current_wind_contract':contract,
      'seed_geometry':'One narrow central shaft +4 paired mirrored tiers, even .035m spacing,28deg upward; lower tiers wider, upper narrower',
      'source_topology':{'stems':28,'green_quads_per_stem':3,'seed_quads_per_stem':9,'triangles':672},
      'authorized_updates':'Golden geometry/ring heights/head topology/UV0.y + accurate source metadata/display label; white heads and all other data unchanged',
      'pre_revision_fingerprint':digest(baseline['data'])}
(HERE/'golden_shoulder_revision_v1.json').write_text(json.dumps(spec,indent=2))
mesh.calc_loop_triangles();lo=[min(v.co[k]for v in mesh.vertices)for k in range(3)];hi=[max(v.co[k]for v in mesh.vertices)for k in range(3)]
assert abs(hi[2]-shoulder)<2e-6 and all(-.65<=lo[k]<hi[k]<=.65 for k in(0,1)) and len(mesh.loop_triangles)==672
for selected in list(bpy.context.selected_objects):selected.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj;display_location=obj.location.copy();obj.location=(0,0,0);bpy.context.view_layer.update()
export_path=HERE/'exports/tall_golden_grass_1m_v1.glb'
try:
    bpy.ops.export_scene.gltf(filepath=str(export_path),export_format='GLB',use_selection=True,
        export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',
        export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,
        export_animations=False,export_morph=False,export_skins=False,export_cameras=False,
        export_lights=False,export_extras=False,export_apply=False)
finally:obj.location=display_location;bpy.context.view_layer.update()
manifest_path=HERE/'tall_golden_grass_v1_manifest.json';manifest=json.loads(manifest_path.read_text())
manifest.update({'status':status,'height_m':hi[2],'bounds_blender':[lo,hi],'player_shoulder_height_m':shoulder,
                 'height_relation':'Seed tips capped at measured player shoulder, supersedes earlier taller-than-player request',
                 'triangles':672,'quads':336,'authored_vertices':1344,'gold_seed_quads_per_stem':9,
                 'head_base_height_range_m':[min(s['head_base_height_m']for s in spec_stems),max(s['head_base_height_m']for s in spec_stems)],
                 'upper_canopy_span_xy_m':[hi[0]-lo[0],hi[1]-lo[1]],'head_arrangement':spec['seed_geometry'],
                 'current_shoulder_dense_revision':'golden_shoulder_revision_v1.json','glb_sha256':hashlib.sha256(export_path.read_bytes()).hexdigest(),
                 'UV0_source':['normalized ring height; rigid seed head planes1','actual head-pivot metres, may be below or above1'],
                 'UV0_gltf':['same normalized ring mask','1-height; positive/negative values preserved, decode1-UV.y'],
                 'stems':spec_stems,'blender_diagnostic_images':['.validation/flower_patch_v1/blender_golden_shoulder_dense_detail.png','.validation/flower_patch_v1/blender_current_plants_player_reference.png']})
manifest.pop('height_above_player_rest_m',None)
manifest_path.write_text(json.dumps(manifest,indent=2))
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_lights=False;space.shading.use_scene_world=False;space.overlay.show_overlays=False
        region=space.region_3d;region.view_location=(21,3.2,1.52)
        region.view_rotation=bpy.data.objects['CAM_TallGolden_V1_Diagnostic'].rotation_euler.to_quaternion();region.view_distance=3.1;region.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result={'status':'Latest model now visible and saved LIVE','golden_height_m':hi[2],'shoulder_m':shoulder,'golden_quads':336,'golden_triangles':672,
        'bounds_blender':[lo,hi],'study_export_sha256':manifest['glb_sha256'],'white_export_unchanged_sha256':baseline['white_glb_sha256']}

