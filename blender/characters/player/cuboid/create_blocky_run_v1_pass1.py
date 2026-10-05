"""Original rigid-blocky run, Pass 1 lower body only. Never overwrite an action.
All motion is authored independently; Mixamo actions are never read for pose values.
"""
import bpy,math,json,ast,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
assert scene.render.fps/scene.render.fps_base==24
NAME='Player_Run_Blocky_V1';assert bpy.data.actions.get(NAME) is None,'Never overwrite an existing original action'
tree=ast.parse((BASE/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'vv','mm','fcurves','action_signature','object_signature'}],type_ignores=[]),'pure_snapshot_helpers','exec'))
protected={a.name:action_signature(a) for a in bpy.data.actions}
geometry_before=object_signature(mesh);rig_before=object_signature(rig);rig_before.pop('pose');rig_before.pop('action')
production=BASE/'player_cuboid_v6.blend';production_hash=hashlib.sha256(production.read_bytes()).hexdigest()
old_frame=scene.frame_current;old_sub=scene.frame_subframe
other_armatures=[o for o in scene.objects if o.type=='ARMATURE' and o!=rig]
other_state={o.name:object_signature(o) for o in other_armatures}
assert not rig.animation_data.nla_tracks
animated=['Hips','Leg.L','Leg.R'];assert all(rig.pose.bones[n].rotation_mode=='XYZ' for n in animated)
# frame, label, right swing, left swing, lateral x, yaw, lateral lean, fore/aft y
poses=[(1,'Right-foot Contact',28,-38,-.011,2.0,1.0,-.004),(3,'Down',12,-12,-.018,.8,1.3,.002),(5,'Passing',-18,3,-.007,-1.4,.4,.007),(7,'Up',-32,22,.003,-2.4,-.3,.002),(9,'Left-foot Contact',-36,30,.012,-2.2,-1.0,-.003),(11,'Down',-14,11,.016,-.7,-1.2,.002),(13,'Passing',4,-19,.006,1.3,-.4,.006),(15,'Up',24,-34,-.002,2.1,.3,.001),(17,'Right-foot Contact / loop',28,-38,-.011,2.0,1.0,-.004)]
hipbone=rig.data.bones['Hips'];hipchannel=(rig.matrix_world@hipbone.matrix_local).to_3x3()
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
assert all(len(ids)==8 for ids in parts.values())
mesh_to_rig=rig.matrix_world.inverted()@mesh.matrix_world

def leg_bottom(name):
    b=rig.data.bones[name];p=rig.pose.bones[name]
    skin=rig.matrix_world@p.matrix@b.matrix_local.inverted()@mesh_to_rig
    return min((skin@mesh.data.vertices[i].co).z for i in parts[name])

def set_pose_tuple(t,z):
    frame,label,ar,al,x,yaw,lean,y=t
    for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
    hp=rig.pose.bones['Hips'];hp.location=hipchannel.inverted()@Vector((x,y,z))
    hp.rotation_euler=Euler(tuple(math.radians(v) for v in (1.2,yaw,lean)),'XYZ')
    rig.pose.bones['Leg.R'].rotation_euler=Euler((math.radians(ar),0,math.radians(-1.0)),'XYZ')
    rig.pose.bones['Leg.L'].rotation_euler=Euler((math.radians(al),0,math.radians(1.0)),'XYZ')
    bpy.context.view_layer.update()
# Contacts establish the natural floor height for the leading rigid leg.
rig.animation_data.action=None
contact_z={}
for t,leg in [(poses[0],'Leg.R'),(poses[4],'Leg.L')]:
    set_pose_tuple(t,0);contact_z[t[0]]=.003-leg_bottom(leg)
base_contact=sum(contact_z.values())/2;down=min(contact_z.values())-.018
heights={1:contact_z[1],3:down,5:base_contact+.025,7:base_contact+.061,9:contact_z[9],11:down+.001,13:base_contact+.024,15:base_contact+.059,17:contact_z[1]}
action=bpy.data.actions.new(NAME);action.use_fake_user=True;rig.animation_data.action=action
for t in poses:
    set_pose_tuple(t,heights[t[0]])
    for n in animated:
        p=rig.pose.bones[n];p.keyframe_insert(data_path='rotation_euler',frame=t[0],group=n)
        if n=='Hips':p.keyframe_insert(data_path='location',frame=t[0],group=n)
for c in fcurves(action):
    for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    mod=c.modifiers.new('CYCLES');mod.mode_before='REPEAT';mod.mode_after='REPEAT';c.update()
# Subtle hip-root sliding lets rigid blocks compress without scaling or knee simulation.
# Tops tuck inside the pelvis. No block is shortened and bone lengths stay untouched.
clearance={'Leg.R':[.003,.003,.003,.012,.012,.018,.026,.012,.003], 'Leg.L':[.012,.018,.028,.012,.003,.003,.003,.012,.012]}

def intended_clearance(name,frame):
    phase=(frame-1)/2;i=min(int(phase),7);u=phase-i
    if frame==17:return clearance[name][-1]
    smooth=u*u*(3-2*u)
    return clearance[name][i]*(1-smooth)+clearance[name][i+1]*smooth
lift_frames=[1+i*.25 for i in range(65)];lifts={};max_lift=0;max_downslide=0
for frame in lift_frames:
    scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame))
    for n in ['Leg.L','Leg.R']:rig.pose.bones[n].location=(0,0,0)
    bpy.context.view_layer.update()
    lifts[frame]={}
    for n in ['Leg.L','Leg.R']:
        p=rig.pose.bones[n];b=p.bone
        lift=max(0,intended_clearance(n,frame)-leg_bottom(n))
        max_lift=max(max_lift,lift)
        ref=b.convert_local_to_pose(Matrix.Identity(4),b.matrix_local,parent_matrix=p.parent.matrix,parent_matrix_local=p.parent.bone.matrix_local)
        local=(rig.matrix_world@ref).to_3x3().inverted()@Vector((0,0,lift))
        lifts[frame][n]=local.copy()
for n in ['Leg.L','Leg.R']:lifts[17][n]=lifts[1][n].copy()
for frame in lift_frames:
    for n in ['Leg.L','Leg.R']:
        rig.pose.bones[n].location=lifts[frame][n]
        rig.pose.bones[n].keyframe_insert(data_path='location',frame=frame,group=n)
for c in fcurves(action):
    for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    if not any(m.type=='CYCLES' for m in c.modifiers):
        mod=c.modifiers.new('CYCLES');mod.mode_before='REPEAT';mod.mode_after='REPEAT'
    c.update()
assert len(fcurves(action))==18
assert all(any('"'+n+'"' in c.data_path for n in animated) and 'scale' not in c.data_path for c in fcurves(action))
# Validate the complete continuous curve, including between blocking poses.
root_reference=rig.matrix_world@rig.data.bones['Root'].matrix_local
hip_positions=[];max_rigid=0;max_scale=0;roottravel=0;min_ground=1e9;pose_details=[];leg_anglemax={n:0 for n in ['Leg.L','Leg.R']}
rest_lengths={(part,i,j):(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length for part,ids in parts.items() for i in ids for j in ids if j>i}
for frame in [1+i*.0625 for i in range(257)]:
    scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame));bpy.context.view_layer.update()
    evrig=rig.evaluated_get(bpy.context.evaluated_depsgraph_get());evmesh=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());em=evmesh.to_mesh()
    points=[evmesh.matrix_world@v.co for v in em.vertices]
    hip_positions.append((rig.matrix_world@evrig.pose.bones['Hips'].head).copy())
    roottravel=max(roottravel,((rig.matrix_world@evrig.pose.bones['Root'].matrix).translation-root_reference.translation).length)
    for p in evrig.pose.bones:max_scale=max(max_scale,max(abs(v-1) for v in p.scale))
    for n in leg_anglemax:leg_anglemax[n]=max(leg_anglemax[n],abs(math.degrees(evrig.pose.bones[n].rotation_euler.x)))
    bottoms={n:min(points[i].z for i in parts[n]) for n in ['Leg.L','Leg.R']};min_ground=min(min_ground,min(bottoms.values()))
    for (part,i,j),length in rest_lengths.items():max_rigid=max(max_rigid,abs((points[i]-points[j]).length-length))
    if abs(frame-round(frame))<1e-7 and round(frame) in heights:
        t=next(t for t in poses if t[0]==round(frame));pose_details.append(dict(frame=frame,label=t[1],hips_world=vv(hip_positions[-1]),leg_bottoms_world_z_m=bottoms,leg_swing_degrees={n:math.degrees(evrig.pose.bones[n].rotation_euler.x) for n in ['Leg.L','Leg.R']}))
    evmesh.to_mesh_clear()

def snapshot(frame):
    scene.frame_set(frame);bpy.context.view_layer.update();ev=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return {p.name:(rig.matrix_world@ev.pose.bones[p.name].matrix).copy() for p in rig.pose.bones}
first=snapshot(1);last=snapshot(17)
loop_matrix=max(abs(first[n][i][j]-last[n][i][j]) for n in first for i in range(4) for j in range(4))
loophips=last['Hips'].translation-first['Hips'].translation
assert roottravel<1e-7 and loophips.length<1e-7 and loop_matrix<1e-7
assert max_rigid<1e-5 and max_scale<1e-7
assert min_ground>-.003,'Blocking ground penetration exceeds 3 mm: '+str(min_ground)
right_pose=next(p for p in pose_details if p['frame']==1);left_pose=next(p for p in pose_details if p['frame']==9)
assert right_pose['leg_swing_degrees']['Leg.R']>0 and right_pose['leg_swing_degrees']['Leg.L']<0
assert left_pose['leg_swing_degrees']['Leg.L']>0 and left_pose['leg_swing_degrees']['Leg.R']<0
for p in rig.pose.bones:
    if p.name not in animated:assert max(abs(p.matrix_basis[i][j]-Matrix.Identity(4)[i][j]) for i in range(4) for j in range(4))<1e-7
scene.frame_set(old_frame,subframe=old_sub);bpy.context.view_layer.update()
assert protected=={n:action_signature(bpy.data.actions[n]) for n in protected}
assert geometry_before==object_signature(mesh)
rig_after=object_signature(rig);rig_after.pop('pose');rig_after.pop('action');assert rig_before==rig_after
assert other_state=={o.name:object_signature(o) for o in other_armatures}
assert production_hash==hashlib.sha256(production.read_bytes()).hexdigest()
# Final live-review state persisted in the test file only.
rig.hide_set(False);mesh.hide_set(False)
for obj in bpy.context.selected_objects:obj.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
for name in ['Armature','Mixamo_Working']:
    if bpy.data.objects.get(name):bpy.data.objects[name].hide_set(True)
scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17;scene.frame_set(1)
report=dict(action=NAME,pass_name='Pass 1 lower-body blocking only',fps=24,frame_range=[1,17],duration_seconds=16/24,animated_bones=animated,key_poses=pose_details,hips_vertical_world_range_m=[min(p.z for p in hip_positions),max(p.z for p in hip_positions)],hips_vertical_excursion_m=max(p.z for p in hip_positions)-min(p.z for p in hip_positions),hips_lateral_world_range_m=[min(p.x for p in hip_positions),max(p.x for p in hip_positions)],hips_lateral_excursion_m=max(p.x for p in hip_positions)-min(p.x for p in hip_positions),max_leg_swing_degrees=leg_anglemax,root_travel_m=roottravel,hips_accumulated_horizontal_travel_m=math.hypot(loophips.x,loophips.y),loop_max_matrix_mismatch=loop_matrix,minimum_leg_bottom_z_m=min_ground,max_ground_penetration_m=max(0,-min_ground),max_vertical_leg_root_tuck_m=max_lift,ground_contact_method='Small vertical translation of rigid leg roots into pelvis; no scale, shortening, bone-length change or knee simulation',max_rigid_length_error_m=max_rigid,scale_animation_present=False,upper_body_independent_animation=False,protected_actions_unchanged=True,mesh_skinning_rest_hierarchy_unchanged=True,production_unchanged=True,interpolation='BEZIER AUTO_CLAMPED; CYCLES REPEAT',pose_rotation_key_frames=[t[0] for t in poses],ground_compensation_location_step_frames=.25,ready_for_visual_review=True)
backup=BASE/'blocky_character_mixamo_test_before_blocky_v1.blend';assert not backup.exists(),'Never overwrite a safety backup';shutil.copy2(TEST,backup)
(BASE/'player_run_blocky_v1_pass1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
text=bpy.data.texts.new('Player_Run_Blocky_V1_Pass1_Report.json');text.write(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
print('BLOCKY_PASS1_SAVED='+json.dumps({k:report[k] for k in ['action','hips_vertical_world_range_m','hips_vertical_excursion_m','hips_lateral_world_range_m','max_leg_swing_degrees','root_travel_m','hips_accumulated_horizontal_travel_m','loop_max_matrix_mismatch','max_ground_penetration_m','max_vertical_leg_root_tuck_m','max_rigid_length_error_m']}))



