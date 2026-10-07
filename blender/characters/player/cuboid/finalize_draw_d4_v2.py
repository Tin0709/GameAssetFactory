import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene;a=bpy.data.actions['Draw_LongGun_V2']
def curves(a):return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
def digest(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)] + [(m.name,m.frame) for m in a.pose_markers]).encode()).hexdigest()
def geometry():return {o.name:hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest() for o in bpy.data.objects if o.type=='MESH'}
def bones():return {b.name:([list(row) for row in b.matrix_local],list(b.head_local),list(b.tail_local),b.parent.name if b.parent else None,b.use_deform) for b in rig.data.bones}
protected=json.loads((BASE/'draw_d4_v2_protection.json').read_text())
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert geometry()==protected['geometry'] and json.dumps(bones(),sort_keys=True)==json.dumps(protected['bones'],sort_keys=True)
validation=json.loads((BASE/'draw_d4_v2_validation.json').read_text());assert validation['passed']
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def tr(b,p):m=b.to_4x4();m.translation=Vector(p);return m
def joint(g):return tr(D@g.to_3x3(),D@g.translation)
def visual(g):return tr(D@g.to_3x3()@D.inverted(),D@g.translation)
def reset():
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
rig.animation_data.action=a;reset();scene.frame_set(14);bpy.context.view_layer.update()
chest=Matrix(json.loads(rig['d1_chest_ready_matrix']));ready=Matrix(json.loads(rig['d1_ready_godot_matrix']))
arm_ready={'Arm.R':((-.33749998,.2662499,.035),(-.24987753,-2.5984479e-8,.44454947,.86019593)),'Arm.L':((.33749998,.24624991,.145),(.1558697,-2.581006e-8,.47511396,.8660089))}
expected={'Chest':joint(chest),'WeaponCarrier':visual(ready)}
for n,(p,q) in arm_ready.items():expected[n]=joint(chest@tr(Quaternion(q).to_matrix(),p))
errors={n:max(abs(rig.pose.bones[n].matrix[i][j]-m[i][j]) for i in range(4) for j in range(4)) for n,m in expected.items()}
assert max(errors.values())<.000002,errors
lower={n:sum(len(c.keyframe_points) for c in curves(a) if c.data_path.startswith('pose.bones["'+n+'"]')) for n in ['Root','Hips','Leg.L','Leg.R']}
assert not any(lower.values()) and not any(c.data_path.endswith('scale') for c in curves(a))
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:o.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
reset();scene.frame_set(1);bpy.context.view_layer.update()
scene.render.fps=24;scene.render.fps_base=1;scene.frame_start=1;scene.frame_end=14
scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=14
scene.camera=bpy.data.objects['D1_Gameplay']
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  sp=area.spaces.active;sp.overlay.show_overlays=False;sp.shading.type='MATERIAL'
  sp.region_3d.view_location=Vector((0,0,1));sp.region_3d.view_distance=3.4
  sp.region_3d.view_rotation=scene.camera.matrix_world.to_quaternion();sp.region_3d.view_perspective='ORTHO'
events=json.loads(a['event_subframes_json'])
report={'action':a.name,'source_preserved':'Draw_LongGun_V1','file':str(DEV),'backup':protected['backup'],'frames':[1,14],'fps':24,'duration_seconds':13/24,'markers_subframes':events,'marker_note':a['marker_note'],
 'notice_frame':1.8,'right_arm_timing':{'prepare':2.15,'reach':3.85,'grab':5,'contact_hold_end':5.25,'pull':6.9,'sweep':9.05,'control':10.95,'settle':12.9,'ready':14},
 'weapon_timing':{'secured_through':5.25,'resistance':5.55,'pull_acceleration':6.45,'clear_body':7.15,'sweep':[8.2,9.15],'catch':10.9,'overshoot':12.15,'settle':13.15,'ready':14},
 'chest_reaction_frame':7.35,'left_arm_timing':{'neutral_until':8.05,'interception_begins':9.4,'catch':10.9,'follow_through':11.8,'settle':13.1,'ready':14},
 'velocity_changes':'Chest-relative weapon remains secured through 5.25. Pull accelerates after delayed release. Peak Sweep angular speed 1472.6 -> 936.2 deg/s; translational peak 15.47 -> 15.74 m/s. Catch reduces angular speed to peak 274.9 deg/s; settle is brief.',
 'trajectory_changes':'Outward pull before forward sweep; rotation distributed across Pull/Sweep; delayed left-arm interception follows posed weapon, then both arms stabilize.',
 'weapon_settle_degrees':1.0,'arm_settle_degrees':{'Arm.R':.65,'Arm.L':.50},'chest_settle_degrees':.18,
 'chest_foundation_degrees':{'pitch':[0,3],'yaw':[-8,2]},'spine_degrees':{'pitch':[0,.4],'yaw':[-1,0]},'spine_lag_frames':[5.8,8.35,11.75],'neck_max_degrees':2,'head_max_degrees':1,
 'lower_keys':lower,'scale_keys':0,'endpoint_matrix_max_errors':errors,'previous_actions_unchanged':len(protected['actions']),'geometry_weights_rest_hierarchy_unchanged':True,'weapon_carrier_non_deforming':not rig.data.bones['WeaponCarrier'].use_deform,
 'overlays':{'Idle':'sampled and visually reviewed','Run_phases_percent':[0,25,50,75],'Run_speed_scale':1.6,'lower_pose_max_error':validation['lower_overlay_error']},
 'clipping':'No head/deep chest weapon penetration in 630 sampled poses, sampled every 0.125 frame. Rigid-arm/gun intersections persist through acquisition/catch and approved Ready grip; not a fully collision-free clip.',
 'Godot_modified':False,'preview_ready':True,'comparison':'Both V1/V2 retained in Action selector; review renders include V1 comparison frames 5, 11, 14.'}
(BASE/'draw_d4_v2_final_report.json').write_text(json.dumps(report,indent=2))
# Store an exact readable curve snapshot for deterministic reproduction/audit.
snapshot=[{'path':c.data_path,'index':c.array_index,'keys':[{'co':list(k.co),'left':list(k.handle_left),'right':list(k.handle_right),'interpolation':k.interpolation,'left_type':k.handle_left_type,'right_type':k.handle_right_type} for k in c.keyframe_points]} for c in curves(a)]
(BASE/'draw_d4_v2_curve_snapshot.json').write_text(json.dumps(snapshot,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result=report
