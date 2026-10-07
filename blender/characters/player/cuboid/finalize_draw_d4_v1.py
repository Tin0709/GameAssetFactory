import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene;a=bpy.data.actions['Draw_LongGun_V1']
def curves(a):return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
def digest(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)] + [(m.name,m.frame) for m in a.pose_markers]).encode()).hexdigest()
def geometry():return {o.name:hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest() for o in bpy.data.objects if o.type=='MESH'}
def bones():return {b.name:([list(row) for row in b.matrix_local],list(b.head_local),list(b.tail_local),b.parent.name if b.parent else None,b.use_deform) for b in rig.data.bones}
protected=json.loads((BASE/'draw_d4_protection.json').read_text())
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert geometry()==protected['geometry'] and json.dumps(bones(),sort_keys=True)==json.dumps(protected['bones'],sort_keys=True)
validation=json.loads((BASE/'draw_d4_v1_validation.json').read_text());assert validation['passed']
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
report={'action':a.name,'frames':[1,14],'fps':24,'duration_seconds':13/24,'markers':{m.name:m.frame for m in a.pose_markers},'key_beats':[1,2,4,5,7,9,11,13,14],'right_arm_timing':{'prepare':2.4,'reach':4,'grab':5,'pull':7,'sweep':9,'control':11,'settle':13,'ready':14},'left_arm_timing':{'neutral_until':7.6,'receive_begins':9.3,'catch':11,'ready':14},'chest_degrees':{'pitch':[0,3],'yaw':[-8,2],'roll':[-.3,.5]},'spine_degrees':{'pitch':[0,.4],'yaw':[-1,0]},'neck_max_degrees':2,'head_max_degrees':1,'lower_keys':lower,'scale_keys':0,'endpoint_matrix_max_errors':errors,'previous_actions_unchanged':len(protected['actions']),'geometry_weights_rest_hierarchy_unchanged':True,'weapon_carrier_non_deforming':not rig.data.bones['WeaponCarrier'].use_deform,'overlays':{'Idle':'passed','Run_phases_percent':[0,25,50,75],'Run_speed_scale':1.6,'lower_pose_max_error':validation['lower_overlay_error']},'clipping':'No head/deep chest weapon penetration in 630 sampled poses. Visible rigid-arm/gun overlap remains, especially acquisition and catch; grip fit is blocking, not final polish.','Godot_modified':False,'preview_ready':True}
(BASE/'draw_d4_v1_final_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
print(json.dumps(report))
