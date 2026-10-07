"""Connected Blender only: duplicate approved V1; sparse motion/weight polish."""
import bpy,json,math,hashlib,shutil,datetime
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV and not bpy.data.is_dirty
assert 'Draw_LongGun_V2' not in bpy.data.actions
backup=DEV.with_name('player_cuboid_weapon_animation_dev_before_draw_v2_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend');shutil.copy2(DEV,backup)
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene
def curves(a):return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
def digest(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)]+[(m.name,m.frame) for m in a.pose_markers]).encode()).hexdigest()
def geometry():return {o.name:hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest() for o in bpy.data.objects if o.type=='MESH'}
def bones():return {b.name:([list(row) for row in b.matrix_local],list(b.head_local),list(b.tail_local),b.parent.name if b.parent else None,b.use_deform) for b in rig.data.bones}
protected={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'bones':bones(),'backup':str(backup)}
(BASE/'draw_d4_v2_protection.json').write_text(json.dumps(protected,indent=2))
source=bpy.data.actions['Draw_LongGun_V1'];rig.animation_data.action=source
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
scene.frame_set(1);bpy.context.view_layer.update();secured=rig.pose.bones['WeaponCarrier'].matrix_basis.copy()
a=source.copy();a.name='Draw_LongGun_V2';a.use_fake_user=True;a['pass']='D4 Pass 2 weight/reaction/catch polish';a['comparison_source']=source.name
rig.animation_data.action=a
def retime(n,old,new):
 for c in curves(a):
  if c.data_path.startswith('pose.bones["'+n+'"]'):
   for k in c.keyframe_points:
    if abs(k.co.x-old)<.001:
     delta=new-old;k.co.x+=delta;k.handle_left.x+=delta;k.handle_right.x+=delta
   c.update()
for n,old,new in [('Chest',2,1.8),('Chest',7,7.35),('Chest',9,9.2),('Chest',11,11.2),('Chest',13,13.25),('Spine',5.5,5.8),('Spine',8,8.35),('Spine',11.5,11.75),('Arm.R',2.4,2.15),('Arm.R',4,3.85),('Arm.R',7,6.9),('Arm.R',9,9.05),('Arm.R',11,10.95),('Arm.R',13,12.9),('Arm.L',7.6,8.05),('Arm.L',9.3,9.4),('Arm.L',11,10.9),('Arm.L',13,13.1),('Neck',4.5,4.35),('Neck',8.5,8.7),('Head',5,4.8),('Head',9,9.4)]:retime(n,old,new)
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def tr(b,p):m=b.to_4x4();m.translation=Vector(p);return m
def visual(g):return tr(D@g.to_3x3()@D.inverted(),D@g.translation)
def chest_g():p=rig.pose.bones['Chest'];return tr(D.inverted()@p.matrix.to_3x3(),D.inverted()@p.matrix.translation)
def frame(f):scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
angle=math.radians(20);z=Vector((math.cos(angle),math.sin(angle),0));y=Vector((math.sin(angle),-math.cos(angle),0));back=tr(Matrix((y.cross(z),y,z)).transposed(),(.025,.110,-.180))
ready=Matrix(json.loads(rig['d1_ready_godot_matrix']));q0=back.to_quaternion();q1=ready.to_quaternion()
for c in curves(a):
 if c.data_path.startswith('pose.bones["WeaponCarrier"]'):c.keyframe_points.clear()
# Carrier remains locked to Chest through contact; no pre-grab local drift.
weapon={1:None,5.25:None,5.55:'resist',6.35:((-.31,1.13,-.41),.07),7.1:((-.48,1.10,-.57),.18),8.2:((-.72,1.07,-.20),.43),9.15:((-.69,1.025,.34),.82),10.9:((-.245,1.0,.485),.97),12.15:'overshoot',13.15:'settle',14:'ready'}
previous=None
for f,spec in weapon.items():
 frame(f);p=rig.pose.bones['WeaponCarrier']
 if spec is None:p.matrix_basis=secured
 else:
  if spec=='resist':
   g=chest_g()@back;g.translation+=chest_g().to_3x3()@Vector((-.015,-.004,-.012))
  elif spec in ['overshoot','settle','ready']:
   pitch=math.radians(1.0 if spec=='overshoot' else .20 if spec=='settle' else 0)
   offset=Vector((.009,-.003,.010)) if spec=='overshoot' else Vector((-.002,.001,.001)) if spec=='settle' else Vector((0,0,0))
   g=tr(ready.to_3x3()@Matrix.Rotation(pitch,3,'X'),ready.translation+offset)
  else:point,weight=spec;g=tr(q0.slerp(q1,weight).to_matrix(),point)
  p.matrix=visual(g);bpy.context.view_layer.update();p.scale=(1,1,1)
 if previous is not None and p.rotation_quaternion.dot(previous)<0:p.rotation_quaternion.negate()
 previous=p.rotation_quaternion.copy()
 p.keyframe_insert('location',frame=f,group=p.name);p.keyframe_insert('rotation_quaternion',frame=f,group=p.name)
# Keep a brief accurate acquire before the rifle starts responding.
frame(5);right=rig.pose.bones['Arm.R'];contact=right.matrix_basis.copy()
frame(5.25);right.matrix_basis=contact;right.keyframe_insert('location',frame=5.25,group=right.name);right.keyframe_insert('rotation_euler',frame=5.25,group=right.name)
# Catch interception uses the actual posed forward weapon, rather than a fixed
# waiting pose. Blend toward the approved hold, without altering that endpoint.
for n,f,blend in [('Arm.L',9.4,.08),('Arm.L',10.9,.42),('Arm.L',11.8,.75),('Arm.R',10.95,.50),('Arm.R',12.2,.92)]:
 frame(f);p=rig.pose.bones[n];old=p.matrix.copy();ch=chest_g();root=D.inverted()@old.translation
 w=rig.pose.bones['WeaponCarrier'].matrix;g=tr(D.inverted()@w.to_3x3()@D,D.inverted()@w.translation)
 target=g@Vector((0,.14,-.34)) if n=='Arm.L' else g.translation
 rest=D.inverted()@rig.data.bones[n].matrix_local.to_3x3();palm=Vector((.10,.635,.065)) if n=='Arm.L' else Vector((-.10,.656,.055))
 rotation=(rest@palm).normalized().rotation_difference((target-root).normalized()).to_matrix()@rest
 aim=tr(D@rotation,D@root)
 q=aim.to_quaternion().slerp(old.to_quaternion(),blend);m=q.to_matrix().to_4x4();m.translation=old.translation;p.matrix=m;bpy.context.view_layer.update();p.scale=(1,1,1)
 p.rotation_euler=p.matrix_basis.to_euler('XYZ',p.rotation_euler);p.keyframe_insert('location',frame=f,group=n);p.keyframe_insert('rotation_euler',frame=f,group=n)
# Arms absorb a tiny residual motion after catch, before exact unchanged READY.
for n,f,delta in [('Arm.R',12.9,.65),('Arm.L',13.1,.50),('Chest',11.75,.18)]:
 frame(f);p=rig.pose.bones[n];p.rotation_euler.x+=math.radians(delta);p.keyframe_insert('rotation_euler',frame=f,group=n)
for c in curves(a):
 for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
 c.update()
# Deliberate zero carrier tangents while secured, and measured catch/Ready.
for c in curves(a):
 if c.data_path.startswith('pose.bones["WeaponCarrier"]'):
  for k in c.keyframe_points:
   if abs(k.co.x-5.25)<.001 or abs(k.co.x-14)<.001:
    k.handle_left_type='FREE';k.handle_right_type='FREE';k.handle_left=(k.co.x-.10,k.co.y);k.handle_right=(k.co.x+.10,k.co.y)
  c.update()
exec((BASE/'refine_draw_d4_v2_sweep.py').read_text())
events={'DRAW_BEGIN':1.0,'WEAPON_GRAB':5.0,'WEAPON_BACK_RELEASE':5.25,'SUPPORT_HAND_CATCH':10.9,'DRAW_READY':14.0}
for m in list(a.pose_markers):a.pose_markers.remove(m)
for n,f in events.items():a.pose_markers.new(n).frame=round(f)
a['event_subframes_json']=json.dumps(events);a['event_frames_json']=json.dumps(events)
a['marker_note']='event_subframes_json is authoritative; Blender pose markers display nearest integer frame.'
a['duration_seconds']=13/24;a['weapon_settle_rotation_degrees']=1.0;a['arm_settle_degrees']=json.dumps({'Arm.R':.65,'Arm.L':.50})
scene.frame_start=1;scene.frame_end=14;scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=14;scene.render.fps=24
frame(1)
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert geometry()==protected['geometry'] and bones()==protected['bones']
result={'created':a.name,'backup':str(backup),'markers_subframes':events,'saved':False}
