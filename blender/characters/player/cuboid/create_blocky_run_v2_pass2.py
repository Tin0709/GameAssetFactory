"""Pass 2: duplicate V1 and add ONLY Spine/Chest rotations.
Background execution validates without saving. Live execution saves test and sets preview.
"""
import bpy,math,json,ast,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
assert scene.render.fps/scene.render.fps_base==24
if not bpy.app.background and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
assert bpy.data.actions.get('Player_Run_Blocky_V2') is None,'V2 already exists; never overwrite'
tree=ast.parse((BASE/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'vv','mm','fcurves','action_signature','object_signature'}],type_ignores=[]),'pure_snapshot_helpers','exec'))
v1=bpy.data.actions['Player_Run_Blocky_V1']
protected={a.name:action_signature(a) for a in bpy.data.actions}
geom=object_signature(mesh);structure=object_signature(rig);structure.pop('pose');structure.pop('action')
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
assert not rig.animation_data.nla_tracks
assert not any(p.constraints for p in rig.pose.bones)
if not bpy.app.background and bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
# Actual target bone bases: local X world +X (forward lean), Y world +Z (yaw), Z world -Y (side lean).
axes={n:dict(local_x_world=vv((rig.matrix_world@rig.data.bones[n].matrix_local).to_3x3().col[0]),local_y_world=vv((rig.matrix_world@rig.data.bones[n].matrix_local).to_3x3().col[1]),local_z_world=vv((rig.matrix_world@rig.data.bones[n].matrix_local).to_3x3().col[2])) for n in ['Hips','Spine','Chest']}
for n in axes:
    assert Vector(axes[n]['local_x_world']).dot(Vector((1,0,0)))>.999
    assert Vector(axes[n]['local_y_world']).dot(Vector((0,0,1)))>.999
    assert rig.pose.bones[n].rotation_mode=='XYZ'
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
frames=[1+i*.125 for i in range(129)]
rig.animation_data.action=v1
if v1.slots:rig.animation_data.action_slot=v1.slots[0]
for p in rig.pose.bones:
    if p.name not in ['Hips','Leg.L','Leg.R']:p.matrix_basis=Matrix.Identity(4)

def sample(frame):
    scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame));bpy.context.view_layer.update()
    er=rig.evaluated_get(bpy.context.evaluated_depsgraph_get());emobj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());em=emobj.to_mesh()
    points=[emobj.matrix_world@v.co for v in em.vertices]
    matrices={p.name:(rig.matrix_world@er.pose.bones[p.name].matrix).copy() for p in rig.pose.bones}
    emobj.to_mesh_clear()
    return matrices,points
baseline={frame:sample(frame) for frame in frames}
v2=v1.copy();v2.name='Player_Run_Blocky_V2';v2.use_fake_user=True
rig.animation_data.action=v2
if v2.slots:rig.animation_data.action_slot=v2.slots[0]
hipcurves={c.array_index:c for c in fcurves(v1) if c.data_path=='pose.bones["Hips"].rotation_euler'}
# Original posture profile, not Mixamo-derived. Down absorbs impact; Up opens.
pitch_profiles={'Spine':[3.5,4.35,3.45,3.0,3.6,4.25,3.4,2.9], 'Chest':[2.1,2.7,1.7,1.35,2.15,2.6,1.65,1.4]}
offsets={'Spine':.55,'Chest':.95};yaw_gain={'Spine':-1.15,'Chest':-1.6};side_gain={'Spine':-.45,'Chest':-1.75}

def wrapped(frame):return 1+(frame-1)%16

def pitch_at(n,phase):
    u=(wrapped(phase)-1)/2;i=int(u)%8;t=u-int(u);s=t*t*(3-2*t)
    return pitch_profiles[n][i]*(1-s)+pitch_profiles[n][(i+1)%8]*s

for n in ['Spine','Chest']:
    p=rig.pose.bones[n];p.location=(0,0,0);p.scale=(1,1,1)
    keyframes=sorted({1.0,17.0}|{1+2*i+offsets[n] for i in range(8)})
    first_value=None
    for frame in keyframes:
        phase=wrapped(frame-offsets[n])
        e=Euler((math.radians(pitch_at(n,phase)),hipcurves[1].evaluate(phase)*yaw_gain[n],hipcurves[2].evaluate(phase)*side_gain[n]),'XYZ')
        if frame==1:first_value=e.copy()
        if frame==17:e=first_value.copy()
        p.rotation_euler=e;p.keyframe_insert(data_path='rotation_euler',frame=frame,group=n)
# Existing copied lower-body curves are never edited, even their handles/modifiers.
for c in fcurves(v2):
    if not any('"'+n+'"' in c.data_path for n in ['Spine','Chest']):continue
    for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    m=c.modifiers.new('CYCLES');m.mode_before='REPEAT';m.mode_after='REPEAT';c.update()
for n in ['Root','Arm.L','Arm.R','Neck','Head']:rig.pose.bones[n].matrix_basis=Matrix.Identity(4)
# Exact key/handle/modifier preservation for all 18 V1 curves.
v2_old_curves=[c for c in action_signature(v2)['curves'] if not any('"'+n+'"' in c['path'] for n in ['Spine','Chest'])]
assert v2_old_curves==action_signature(v1)['curves']
assert len(fcurves(v2))==24

rest_lengths={(n,i,j):(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length for n,ids in parts.items() for i in ids for j in ids if j>i}
# SAT overlap is a diagnostic for actual rigid boxes, not a collider modification.
def box_axes(n,points):
    ids=set(parts[n]);out=[]
    for edge in mesh.data.edges:
        i,j=edge.vertices
        if i not in ids or j not in ids:continue
        v=(points[j]-points[i]).normalized()
        if not any(abs(v.dot(a))>.99999 for a in out):out.append(v)
    return out

def overlap(a,b,points):
    aa=box_axes(a,points);bb=box_axes(b,points);axes=aa+bb
    for x in aa:
        for y in bb:
            c=x.cross(y)
            if c.length>1e-6:axes.append(c.normalized())
    depth=1e9
    for axis in axes:
        ap=[points[i].dot(axis) for i in parts[a]];bp=[points[i].dot(axis) for i in parts[b]]
        d=min(max(ap),max(bp))-max(min(ap),min(bp))
        if d<=1e-5:return 0.0
        depth=min(depth,d)
    return depth
ranges={n:[[1e9,-1e9] for i in range(3)] for n in ['Spine','Chest']};forward=[];side=[];groundmin=1e9;lower_error=0;root_travel=0;rigid_error=0;scale_error=0;clip={};details=[];angles=[]
for frame in frames:
    mats,points=sample(frame);base_mats,base_points=baseline[frame]
    for n in ['Root','Hips','Leg.L','Leg.R']:
        lower_error=max(lower_error,max(abs(mats[n][i][j]-base_mats[n][i][j]) for i in range(4) for j in range(4)))
    root_ref=rig.matrix_world@rig.data.bones['Root'].matrix_local;root_travel=max(root_travel,(mats['Root'].translation-root_ref.translation).length)
    ground=min(points[i].z for n in ['Leg.L','Leg.R'] for i in parts[n]);groundmin=min(groundmin,ground)
    assert abs(ground-min(base_points[i].z for n in ['Leg.L','Leg.R'] for i in parts[n]))<1e-6
    for (n,i,j),length in rest_lengths.items():rigid_error=max(rigid_error,abs((points[i]-points[j]).length-length))
    for p in rig.pose.bones:scale_error=max(scale_error,max(abs(v-1) for v in p.scale))
    for n in ranges:
        for i,v in enumerate(rig.pose.bones[n].rotation_euler):
            deg=math.degrees(v);ranges[n][i][0]=min(ranges[n][i][0],deg);ranges[n][i][1]=max(ranges[n][i][1],deg)
    up=(mats['Chest'].to_3x3()@Vector((0,1,0))).normalized()
    lean=math.degrees(math.atan2(-up.y,up.z));balance=math.degrees(math.atan2(up.x,up.z));forward.append(lean);side.append(balance)
    angles.append((frame,{n:mats[n].to_quaternion() for n in ['Spine','Chest']}))
    intersections=[]
    for leg in ['Leg.L','Leg.R']:
        d=overlap('Chest',leg,points);bd=overlap('Chest',leg,base_points)
        if d:
            s=clip.setdefault('Chest / '+leg,dict(sample_count=0,max_overlap_m=0,baseline_max_overlap_m=0,max_increase_from_v1_m=0))
            s['sample_count']+=1;s['max_overlap_m']=max(s['max_overlap_m'],d);s['baseline_max_overlap_m']=max(s['baseline_max_overlap_m'],bd);s['max_increase_from_v1_m']=max(s['max_increase_from_v1_m'],d-bd)
            intersections.append(dict(pair='Chest / '+leg,overlap_m=d,baseline_overlap_m=bd))
    if frame in [1,3,5,7,9,11,13,15,17]:details.append(dict(frame=frame,forward_lean_degrees=lean,side_lean_degrees=balance,spine_rotation_degrees=[math.degrees(v) for v in rig.pose.bones['Spine'].rotation_euler],chest_rotation_degrees=[math.degrees(v) for v in rig.pose.bones['Chest'].rotation_euler],intersections=intersections))
first,_=sample(1);last,_=sample(17)
loop_error=max(abs(first[n][i][j]-last[n][i][j]) for n in first for i in range(4) for j in range(4))
horizontal=(last['Hips'].translation-first['Hips'].translation);horizontal_travel=math.hypot(horizontal.x,horizontal.y)
max_step=max(min(math.degrees(a[n].rotation_difference(b[n]).angle),360-math.degrees(a[n].rotation_difference(b[n]).angle)) for (_,a),(_,b) in zip(angles,angles[1:]) for n in ['Spine','Chest'])
assert lower_error<1e-7 and root_travel<1e-7 and horizontal_travel<1e-7 and loop_error<1e-7
assert rigid_error<1e-5 and scale_error<1e-7 and groundmin>0
assert min(forward)>4.9 and max(forward)<9.1,(min(forward),max(forward))
assert max_step<1.0,max_step
assert protected=={n:action_signature(bpy.data.actions[n]) for n in protected}
assert geom==object_signature(mesh)
structure_after=object_signature(rig);structure_after.pop('pose');structure_after.pop('action');assert structure==structure_after
assert production_hash==hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
scene.frame_set(1);rig.select_set(True);bpy.context.view_layer.objects.active=rig
scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17
for name in ['Armature','Mixamo_Working']:
    if bpy.data.objects.get(name):bpy.data.objects[name].hide_set(True)
report=dict(action=v2.name,source_action=v1.name,pass_name='Pass 2 torso/body mechanics only',bones_added=['Spine','Chest'],local_axes=axes,local_rotation_ranges_degrees=ranges,forward_lean_range_degrees=[min(forward),max(forward)],side_lean_range_degrees=[min(side),max(side)],timing_offsets_frames=offsets,additional_chest_delay_frames=offsets['Chest']-offsets['Spine'],rotation_keyframes_per_added_bone=10,interpolation='BEZIER AUTO_CLAMPED; CYCLES REPEAT',root_travel_m=root_travel,hips_horizontal_accumulated_travel_m=horizontal_travel,lower_body_max_matrix_difference=lower_error,loop_max_matrix_mismatch=loop_error,minimum_leg_bottom_z_m=groundmin,ground_penetration_m=max(0,-groundmin),max_rigid_length_error_m=rigid_error,scale_animation_present=False,max_rotation_change_per_eighth_frame_degrees=max_step,torso_leg_intersections=clip,key_pose_validation=details,v1_unchanged=True,all_existing_actions_unchanged=True,mesh_weights_rest_hierarchy_unchanged=True,arms_neck_head_local_neutral=True,production_unchanged=True,preview_range=[1,17],fps=24)
(BASE/'player_run_blocky_v2_pass2_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS2_VALIDATION='+json.dumps({k:report[k] for k in ['action','local_rotation_ranges_degrees','forward_lean_range_degrees','side_lean_range_degrees','lower_body_max_matrix_difference','loop_max_matrix_mismatch','minimum_leg_bottom_z_m','torso_leg_intersections']}),flush=True)
if bpy.app.background:
    # Dry-run renders only; do not save or replace any scene/action on disk.
    out=BASE/'blocky_v2_pass2_review';out.mkdir(exist_ok=True)
    saved_camera=scene.camera;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    for view,camera in [('iso','V3 Isometric Camera'),('side','V3 Side Camera')]:
        scene.camera=bpy.data.objects[camera]
        for i,frame in enumerate([1,3,5,7,9,11,13,15,17]):
            scene.frame_set(frame);scene.render.filepath=str(out/f'{view}_{i:02d}.png');bpy.ops.render.render(write_still=True)
else:
    # Live session: preview setup, backup, save only the test file.
    area=bpy.context.area
    for obj in bpy.context.selected_objects:obj.select_set(False)
    rig.hide_set(False);mesh.hide_set(False);rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
    if area and area.type=='CONSOLE':area.type='VIEW_3D'
    for view in bpy.context.screen.areas:
        region=next((r for r in view.regions if r.type=='WINDOW'),None)
        if region and view.type=='VIEW_3D':
            view.spaces.active.shading.type='MATERIAL';view.spaces.active.overlay.show_overlays=False
            with bpy.context.temp_override(area=view,region=region):bpy.ops.view3d.view_selected(use_all_regions=False)
    mesh.select_set(False)
    text=bpy.data.texts.new('Player_Run_Blocky_V2_Pass2_Report.json');text.write(json.dumps(report,indent=2))
    backup=BASE/'blocky_character_mixamo_test_before_blocky_v2.blend';assert not backup.exists(),'Never overwrite safety backup';shutil.copy2(TEST,backup)
    bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
    print('PASS2_SAVED_PREVIEW_READY',flush=True)

