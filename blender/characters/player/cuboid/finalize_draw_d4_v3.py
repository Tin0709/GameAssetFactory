import bpy,json,math,hashlib,csv
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene;a=bpy.data.actions['Draw_LongGun_V3_Final']
script=(BASE/'polish_draw_d4_v3.py').read_text();exec(script[script.index('def curves(a)'):script.index("assert 'Draw_LongGun_V3_Final'")])
protected=json.loads((BASE/'draw_d4_v3_protection.json').read_text())
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert geometry()==protected['geometry'] and json.dumps(bones(),sort_keys=True)==json.dumps(protected['bones'],sort_keys=True)
def frame(f):
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
 scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
names=['Arm.R','Arm.L','Chest','Spine','Neck','Head','WeaponCarrier']
rig.animation_data.action=bpy.data.actions['Draw_LongGun_V2'];frame(14);endpoint={n:rig.pose.bones[n].matrix.copy() for n in names}
rig.animation_data.action=a;frame(14)
errors={n:max(abs(rig.pose.bones[n].matrix[i][j]-endpoint[n][i][j]) for i in range(4) for j in range(4)) for n in names}
assert max(errors.values())<2e-6
# Existing ready matrices originate from LongGunHold_V2. Check draw against them.
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def tr(b,p):m=b.to_4x4();m.translation=Vector(p);return m
def joint(g):return tr(D@g.to_3x3(),D@g.translation)
def visual(g):return tr(D@g.to_3x3()@D.inverted(),D@g.translation)
chest=Matrix(json.loads(rig['d1_chest_ready_matrix']));hold=Matrix(json.loads(rig['d1_ready_godot_matrix']))
arms={'Arm.R':((-.33749998,.2662499,.035),(-.24987753,-2.5984479e-8,.44454947,.86019593)),'Arm.L':((.33749998,.24624991,.145),(.1558697,-2.581006e-8,.47511396,.8660089))}
expected={'Chest':joint(chest),'WeaponCarrier':visual(hold)}
for n,(p,q) in arms.items():expected[n]=joint(chest@tr(Quaternion(q).to_matrix(),p))
hold_errors={n:max(abs(rig.pose.bones[n].matrix[i][j]-m[i][j]) for i in range(4) for j in range(4)) for n,m in expected.items()}
assert max(hold_errors.values())<2e-6
lower={n:sum(len(c.keyframe_points) for c in curves(a) if c.data_path.startswith('pose.bones["'+n+'"]')) for n in ['Root','Hips','Leg.L','Leg.R']}
assert not any(lower.values()) and not any(c.data_path.endswith('scale') for c in curves(a))
validation=json.loads((BASE/'draw_d4_v3_validation.json').read_text());assert validation['passed']
velocity=json.loads((BASE/'draw_d4_v3_velocity_comparison.json').read_text())
ranges={}
for n in ['Chest','Spine','Neck','Head']:
 ranges[n]={str(c.array_index):[math.degrees(min(c.evaluate(1+i/32) for i in range(417))),math.degrees(max(c.evaluate(1+i/32) for i in range(417)))] for c in curves(a) if c.data_path=='pose.bones["'+n+'"].rotation_euler'}
trajectory=[];last=None
for i in range(417):
 f=1+i/32;frame(f);m=rig.matrix_world@rig.pose.bones['WeaponCarrier'].matrix;p=m.translation;q=m.to_quaternion()
 if last:
  dp=(p-last[0]).length*32*24;dq=math.degrees(q.rotation_difference(last[1]).angle)*32*24
  if dq>180*32*24:dq=360*32*24-dq
 else:dp=dq=0
 trajectory.append([f,*p,*q,dp,dq]);last=(p.copy(),q.copy())
with (BASE/'draw_d4_v3_trajectory.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['frame','x','y','z','qw','qx','qy','qz','speed_m_s','angular_deg_s']);w.writerows(trajectory)
events=json.loads(a['event_subframes_json'])
report={'action':a.name,'file':str(DEV),'backup':protected['backup'],'frames':[1,14],'fps':24,'duration_seconds':13/24,
 'notice_frame':1.8,'reach_frames':[2.15,3.75,5.0],'grab_frame':5.0,'release_frame':5.25,'pull_frames':[6.45,7.15],'chest_reaction_frame':7.4,'spine_response_frame':7.7,'sweep_frames':[8.2,9.15],'left_intercept_frame':9.4,'catch_frame':10.9,'ready_frame':14,
 'changes':json.loads(a['production_changes_json']),'grip_cleanup':json.loads(a['contact_cleanup_json']),'catch_cleanup':json.loads(a['catch_cleanup_json']),
 'overlap_note':'Grip diagnostic improved locally (64 vs 66 triangles at grab, 45 vs 52 at sweep). Triangle counts are mesh-dependent, not penetration depth. Left-arm catch interior remains clear outside final 0.04m terminal contact zone. Remaining rigid-arm/gun contact and fixed Ready grip retained for hold compatibility; not collision-free.',
 'settle_authored_degrees':{'WeaponCarrier':.6,'Arm.R':.35,'Arm.L':.25,'Chest':.10},'ranges_degrees_xyz':ranges,
 'event_subframes':events,'marker_frames':{m.name:m.frame for m in a.pose_markers},'event_source':'Action event_subframes_json; markers are integer display references.',
 'curve_cleanup':'Preserved all meaningful keys and Bezier interpolation; AUTO_CLAMPED retained; existing secured/Ready carrier FREE horizontal tangents retained; sub-1e-6 arm translation noise set to zero. No aggressive simplification.',
 'curve_count':len(curves(a)),'key_count':sum(len(c.keyframe_points) for c in curves(a)),
 'trajectory':'Continuous outward clear, forward sweep, catch and Ready. Reviewed 417 carrier samples and four camera views; no head/deep chest penetration in 630 standalone/overlay poses at 0.125f increments.',
 'velocity_comparison':velocity,'endpoint_vs_v2_max_errors':errors,'endpoint_vs_hold_max_errors':hold_errors,
 'idle_overlay':'Numerically sampled and gameplay-size render sequence reviewed. Notice/reach/catch/Ready retained.',
 'run_overlay':{'phases_percent':[0,25,50,75],'cadence':1.6,'lower_pose_max_error':validation['lower_overlay_error'],'result':'Source lower-body clock progresses independently; source arm acquisition uses 3-frame smooth blend; no large visible acquisition snap in rendered preview sequences. Catch and Ready remain readable.','scope':'Blender preview harness only; runtime layer blending is not implemented or tested in Godot.'},
 'lower_key_counts':lower,'scale_keys':0,'protected_actions_unchanged':list(protected['actions']),'geometry_weights_rest_lengths_hierarchy_unchanged':True,'weapon_carrier_non_deforming':not rig.data.bones['WeaponCarrier'].use_deform,
 'ready_for_godot_integration':True,'Godot_modified':False,'preview_ready':True,'preview_comparison':'draw_d4_v3_review/V2_vs_V3.gif; V2 and V3_Final in Action selector.'}
assert report['weapon_carrier_non_deforming']
(BASE/'draw_d4_v3_final_report.json').write_text(json.dumps(report,indent=2))
snapshot=[{'path':c.data_path,'index':c.array_index,'keys':[{'co':list(k.co),'left':list(k.handle_left),'right':list(k.handle_right),'interpolation':k.interpolation,'left_type':k.handle_left_type,'right_type':k.handle_right_type} for k in c.keyframe_points]} for c in curves(a)]
(BASE/'draw_d4_v3_curve_snapshot.json').write_text(json.dumps(snapshot,indent=2))
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:o.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig;rig.animation_data.action=a
frame(1);scene.render.fps=24;scene.render.fps_base=1;scene.frame_start=1;scene.frame_end=14;scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=14;scene.camera=bpy.data.objects['D1_Gameplay']
scene.render.resolution_x=640;scene.render.resolution_y=640
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  sp=area.spaces.active;sp.overlay.show_overlays=False;sp.shading.type='MATERIAL';sp.region_3d.view_location=Vector((0,0,1));sp.region_3d.view_distance=3.4;sp.region_3d.view_rotation=scene.camera.matrix_world.to_quaternion();sp.region_3d.view_perspective='ORTHO'
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={k:report[k] for k in ['action','duration_seconds','endpoint_vs_v2_max_errors','endpoint_vs_hold_max_errors','ranges_degrees_xyz','lower_key_counts','protected_actions_unchanged','ready_for_godot_integration']}
