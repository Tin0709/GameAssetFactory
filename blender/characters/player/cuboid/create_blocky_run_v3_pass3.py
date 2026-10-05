import bpy,math,json,ast,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
assert scene.render.fps/scene.render.fps_base==24
if not bpy.app.background and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
assert bpy.data.actions.get('Player_Run_Blocky_V3') is None,'V3 exists; never overwrite'
for file,names in [('prepare_mixamo_run.py',{'vv','mm','fcurves','action_signature','object_signature'}),('create_blocky_run_v2_pass2.py',{'sample','box_axes','overlap'})]:
    tree=ast.parse((BASE/file).read_text(encoding='utf-8-sig'))
    exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),'snapshot_and_eval_helpers','exec'))
v2=bpy.data.actions['Player_Run_Blocky_V2'];protected={a.name:action_signature(a) for a in bpy.data.actions}
geom=object_signature(mesh);structure=object_signature(rig);structure.pop('pose');structure.pop('action')
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
assert not rig.animation_data.nla_tracks and not any(p.constraints for p in rig.pose.bones)
if not bpy.app.background and bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
axes={n:[vv((rig.matrix_world@rig.data.bones[n].matrix_local).to_3x3().col[i]) for i in range(3)] for n in ['Arm.L','Arm.R']}
for n in axes:
    assert Vector(axes[n][0]).dot(Vector((-1,0,0)))>.999
    assert rig.pose.bones[n].rotation_mode=='XYZ'
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
frames=[1+i*.125 for i in range(129)]
rig.animation_data.action=v2
if v2.slots:rig.animation_data.action_slot=v2.slots[0]
for n in ['Root','Arm.L','Arm.R','Neck','Head']:rig.pose.bones[n].matrix_basis=Matrix.Identity(4)
baseline={f:sample(f) for f in frames}
v3=v2.copy();v3.name='Player_Run_Blocky_V3';v3.use_fake_user=True
rig.animation_data.action=v3
if v3.slots:rig.animation_data.action_slot=v3.slots[0]
# Local X=-world X: positive swing carries downward arm toward character forward (-Y).
# Independent authored paths; delayed extremes follow Chest (.95-frame offset).
profiles={
'Arm.L':[[27,14,-5,-29,-32,-18,3,24],[1.2,.2,-.8,-1.4,-1.0,-.2,.7,1.1],[6.2,5.5,4.8,6.7,7.2,6.1,5.1,5.8]],
'Arm.R':[[-31,-17,3,25,29,16,-4,-28],[-1.1,-.1,.7,1.3,.9,.1,-.8,-1.2],[-7.0,-5.9,-5.0,-5.7,-6.4,-5.6,-4.9,-6.5]]}
offsets={'Arm.L':1.15,'Arm.R':1.35}
def wrapped(f):return 1+(f-1)%16
def profile_at(values,phase):
    u=(wrapped(phase)-1)/2;i=int(u)%8;t=u-int(u);s=t*t*(3-2*t)
    return values[i]*(1-s)+values[(i+1)%8]*s
for n in profiles:
    p=rig.pose.bones[n];assert tuple(p.location)==(0,0,0) and tuple(p.scale)==(1,1,1)
    for f in sorted({1.,17.}|{1+2*i+offsets[n] for i in range(8)}):
        p.rotation_euler=Euler(tuple(math.radians(profile_at(values,wrapped(f-offsets[n]))) for values in profiles[n]),'XYZ')
        p.keyframe_insert(data_path='rotation_euler',frame=f,group=n)
# Smooth sparse curves. Periodic tangents at duplicate boundaries preserve velocity as well as pose.
for c in fcurves(v3):
    if not any('"'+n+'"' in c.data_path for n in profiles):continue
    for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    c.update();keys=c.keyframe_points;first,last=keys[0],keys[-1];last.co.y=first.co.y
    prev,nxt=keys[-2],keys[1];dt0=first.co.x-(prev.co.x-16);dt1=nxt.co.x-first.co.x
    slope=(nxt.co.y-prev.co.y)/(dt0+dt1)
    # Clamp boundary tangent if adjacent secants oppose, to avoid a wobble.
    if (first.co.y-prev.co.y)*(nxt.co.y-first.co.y)<=0:slope=0
    for k in [first,last]:
        k.handle_left_type='FREE';k.handle_right_type='FREE'
        k.handle_left=(k.co.x-dt0/3,k.co.y-slope*dt0/3)
        k.handle_right=(k.co.x+dt1/3,k.co.y+slope*dt1/3)
    m=c.modifiers.new('CYCLES');m.mode_before='REPEAT';m.mode_after='REPEAT';c.update()
for n in ['Root','Neck','Head']:rig.pose.bones[n].matrix_basis=Matrix.Identity(4)
assert [c for c in action_signature(v3)['curves'] if not any('"'+n+'"' in c['path'] for n in profiles)]==action_signature(v2)['curves']
assert len(fcurves(v3))==30
rest_lengths={(n,i,j):(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length for n,ids in parts.items() for i in ids for j in ids if j>i}
ranges={n:[[1e9,-1e9] for i in range(3)] for n in profiles};unchanged_error=0;root_travel=0;rigid_error=0;groundmin=1e9;clip={};angles=[];details=[];opposition=[]
for f in frames:
    mats,points=sample(f);bm,bp=baseline[f]
    for n in ['Root','Hips','Leg.L','Leg.R','Spine','Chest','Neck','Head']:
        unchanged_error=max(unchanged_error,max(abs(mats[n][i][j]-bm[n][i][j]) for i in range(4) for j in range(4)))
    root_ref=rig.matrix_world@rig.data.bones['Root'].matrix_local
    root_travel=max(root_travel,(mats['Root'].translation-root_ref.translation).length)
    ground=min(points[i].z for n in ['Leg.L','Leg.R'] for i in parts[n]);groundmin=min(groundmin,ground)
    for (n,i,j),length in rest_lengths.items():rigid_error=max(rigid_error,abs((points[i]-points[j]).length-length))
    assert all(max(abs(v-1) for v in p.scale)<1e-7 for p in rig.pose.bones)
    for n in ranges:
        for i,v in enumerate(rig.pose.bones[n].rotation_euler):
            d=math.degrees(v);ranges[n][i][0]=min(ranges[n][i][0],d);ranges[n][i][1]=max(ranges[n][i][1],d)
        for body in ['Chest','Head','Leg.L','Leg.R']:
            d=overlap(n,body,points);bd=overlap(n,body,bp)
            key=n+' / '+body
            if d:
                s=clip.setdefault(key,dict(sample_count=0,max_overlap_m=0,baseline_max_overlap_m=0));s['sample_count']+=1;s['max_overlap_m']=max(s['max_overlap_m'],d);s['baseline_max_overlap_m']=max(s['baseline_max_overlap_m'],bd)
    angles.append({n:mats[n].to_quaternion() for n in profiles})
    if f in [1,3,5,7,9,11,13,15,17]:
        def reach(n):return (mats[n].to_3x3()@Vector((0,1,0))).normalized().dot(Vector((0,-1,0)))
        details.append(dict(frame=f,arm_rotation_degrees={n:[math.degrees(v) for v in rig.pose.bones[n].rotation_euler] for n in profiles},forward_direction_component={n:reach(n) for n in ['Arm.L','Arm.R','Leg.L','Leg.R']}))
        if f==1:opposition.append(reach('Arm.L')>0 and reach('Arm.R')<0 and reach('Leg.R')>0 and reach('Leg.L')<0)
        if f==9:opposition.append(reach('Arm.R')>0 and reach('Arm.L')<0 and reach('Leg.L')>0 and reach('Leg.R')<0)
first,_=sample(1);last,_=sample(17)
loop_error=max(abs(first[n][i][j]-last[n][i][j]) for n in first for i in range(4) for j in range(4))
h=last['Hips'].translation-first['Hips'].translation;horizontal=math.hypot(h.x,h.y)
max_step=max(min(math.degrees(a[n].rotation_difference(b[n]).angle),360-math.degrees(a[n].rotation_difference(b[n]).angle)) for a,b in zip(angles,angles[1:]) for n in profiles)
assert unchanged_error<1e-7 and root_travel<1e-7 and horizontal<1e-7 and loop_error<1e-7
assert all(opposition) and max_step<6 and groundmin>0 and rigid_error<1e-5
assert not any('.scale' in c.data_path for c in fcurves(v3))
assert protected=={n:action_signature(bpy.data.actions[n]) for n in protected}
assert geom==object_signature(mesh)
s=object_signature(rig);s.pop('pose');s.pop('action');assert s==structure
assert production_hash==hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
report=dict(action=v3.name,bones_added=list(profiles),local_axes=axes,local_rotation_ranges_degrees=ranges,timing_offsets_frames=offsets,keys_per_arm=10,interpolation='BEZIER AUTO_CLAMPED, periodic boundary tangents, CYCLES REPEAT',root_travel_m=root_travel,hips_accumulated_horizontal_travel_m=horizontal,existing_bone_matrix_max_difference=unchanged_error,loop_matrix_mismatch=loop_error,minimum_leg_bottom_z_m=groundmin,ground_penetration_m=max(0,-groundmin),max_rigid_length_error_m=rigid_error,max_rotation_change_per_eighth_frame_degrees=max_step,arm_intersections=clip,contact_opposition_correct=all(opposition),key_poses=details,support_edits=[],all_previous_actions_unchanged=True,mesh_weights_rest_hierarchy_unchanged=True,neck_head_local_neutral=True,production_unchanged=True,preview=[1,17],fps=24)
(BASE/'player_run_blocky_v3_pass3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS3_VALIDATION='+json.dumps(report),flush=True)
scene.frame_set(1);scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17
for n in ['Armature','Mixamo_Working']:
    if bpy.data.objects.get(n):bpy.data.objects[n].hide_set(True)
if bpy.app.background:
    out=BASE/'blocky_v3_pass3_review';out.mkdir(exist_ok=True)
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    for view,camera in [('iso','V3 Isometric Camera'),('side','V3 Side Camera')]:
        scene.camera=bpy.data.objects[camera]
        for i,f in enumerate([1,3,5,7,9,11,13,15,17]):
            scene.frame_set(f);scene.render.filepath=str(out/f'{view}_{i:02d}.png');bpy.ops.render.render(write_still=True)
else:
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
    backup=BASE/'blocky_character_mixamo_test_before_blocky_v3.blend';assert not backup.exists(),'Never overwrite backup';shutil.copy2(TEST,backup)
    text=bpy.data.texts.new('Player_Run_Blocky_V3_Pass3_Report.json');text.write(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
    print('PASS3_SAVED_PREVIEW_READY',flush=True)
