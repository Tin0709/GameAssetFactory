"""Run in connected Blender MCP; original D4 blocking, never reverse Holster."""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion, Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV
assert 'Draw_LongGun_V1' not in bpy.data.actions
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene
def curves(a):return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
def digest(a):
 return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)] + [(m.name,m.frame) for m in a.pose_markers]).encode()).hexdigest()
def geometry():
 return {o.name:hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest() for o in bpy.data.objects if o.type=='MESH'}
def bones():return {b.name:([list(row) for row in b.matrix_local],list(b.head_local),list(b.tail_local),b.parent.name if b.parent else None,b.use_deform) for b in rig.data.bones}
protected={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'bones':bones()}
(BASE/'draw_d4_protection.json').write_text(json.dumps(protected,indent=2))
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def tr(b,p):m=b.to_4x4();m.translation=Vector(p);return m
def joint(g):return tr(D@g.to_3x3(),D@g.translation)
def visual(g):return tr(D@g.to_3x3()@D.inverted(),D@g.translation)
def godot_joint(p):return tr(D.inverted()@p.matrix.to_3x3(),D.inverted()@p.matrix.translation)
angle=math.radians(20);stock=Vector((math.cos(angle),math.sin(angle),0));up=Vector((math.sin(angle),-math.cos(angle),0))
back_basis=Matrix((up.cross(stock),up,stock)).transposed()
back_local=tr(back_basis,(.025,.110,-.180))
ready=Matrix(json.loads(rig['d1_ready_godot_matrix']))
chest_ready=Matrix(json.loads(rig['d1_chest_ready_matrix']))
arm_ready={'Arm.R':((-.33749998,.2662499,.035),(-.24987753,-2.5984479e-8,.44454947,.86019593)),'Arm.L':((.33749998,.24624991,.145),(.1558697,-2.581006e-8,.47511396,.8660089))}
a=bpy.data.actions.new('Draw_LongGun_V1');a.use_fake_user=True
a['pass']='D4 Pass 1 original urgency/reach/pull/catch blocking'
a['authoring_fps']=24;a['duration_seconds']=13/24
a['reference_back_carry']='D3.1 M4A1 Chest space: 20deg, (0.025,0.110,-0.180), scale 1.12'
a['reference_ready']='LongGunHold_V2; existing d1 Ready matrices and same Godot pose resource'
a['not_reverse_holster']=True
rig.animation_data.action=a
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
chest_keys={1:(0,0,0),2:(.8,-1,0),4:(2,-6,0),5:(2.5,-8,.5),7:(3,-5,-.3),9:(3,2,-.3),11:(2.6,0,0),13:(2.1,-3.5,0),14:(2,-4,0)}
for name,keys in [('Chest',chest_keys),('Spine',{1:(0,0,0),3:(.15,0,0),5.5:(.4,-1,0),8:(.3,-.4,0),11.5:(.1,0,0),14:(0,0,0)}),('Neck',{1:(0,0,0),4.5:(0,2,0),8.5:(0,-.6,0),12:(0,.2,0),14:(0,0,0)}),('Head',{1:(0,0,0),5:(0,1,0),9:(0,-.4,0),14:(0,0,0)})]:
 for f,degs in keys.items():
  p=rig.pose.bones[name];p.rotation_euler=Euler(tuple(math.radians(x) for x in degs),'XYZ');p.keyframe_insert('rotation_euler',frame=f,group=name)
# Weapon is authored independently, with delayed rotation after clearing back.
weapon_keys={1:(None,0),2:(None,0),4:(None,0),5:((.010,1.155,-.205),.015),7:((-.48,1.10,-.57),.18),9:((-.70,1.025,.34),.82),11:((-.25,1.0,.485),.97),13:((-.100,.977,.455),.996),14:(tuple(ready.translation),1)}
start_rotation=back_basis.to_quaternion();end_rotation=ready.to_quaternion()
prev=None
for f,(point,weight) in weapon_keys.items():
 scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 if point is None:g=godot_joint(rig.pose.bones['Chest'])@back_local
 else:g=tr(start_rotation.slerp(end_rotation,weight).to_matrix(),point)
 p=rig.pose.bones['WeaponCarrier'];p.matrix=visual(g);bpy.context.view_layer.update();p.scale=(1,1,1)
 if prev is not None and p.rotation_quaternion.dot(prev)<0:p.rotation_quaternion.negate()
 prev=p.rotation_quaternion.copy()
 p.keyframe_insert('location',frame=f,group=p.name);p.keyframe_insert('rotation_quaternion',frame=f,group=p.name)
# Primary acquire first; support stays relaxed until the forward sweep.
for name,frames in [('Arm.R',[1,2.4,4,5,7,9,11,13,14]),('Arm.L',[1,5,7.6,9.3,11,13,14])]:
 prev=None
 for f in frames:
  scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
  chest=godot_joint(rig.pose.bones['Chest']);rest_g=D.inverted()@rig.data.bones[name].matrix_local.to_3x3()
  root=chest@Vector((-.33749998 if name=='Arm.R' else .33749998,.28124988,0))
  if f==14:
   point,q=arm_ready[name];world=chest@tr(Quaternion(q).to_matrix(),point)
  elif (name=='Arm.R' and f==1) or (name=='Arm.L' and f<=7.6):
   world=tr(chest.to_3x3()@rest_g,root)
  else:
   weapon=tr(D.inverted()@rig.pose.bones['WeaponCarrier'].matrix.to_3x3()@D,D.inverted()@rig.pose.bones['WeaponCarrier'].matrix.translation)
   if name=='Arm.R':
    stock_grab=.30 if f<=5 else (.12 if f==7 else 0)
    target=weapon@Vector((0,0,stock_grab*1.12))
    if f<=5:root+=chest.to_3x3()@Vector((0,-.025,-.10 if f>=4 else -.025))
    if f==2.4:target=root+Vector((.04,-.57,-.22))
   else:
    # Existing support offset intentionally sits on fore-end underside.
    target=weapon@Vector((0,.125,-.375))*1.0
   toward=target-root
   palm=Vector((-.10,.656,.055)) if name=='Arm.R' else Vector((.10,.635,.065))
   rotation=(rest_g@palm).normalized().rotation_difference(toward.normalized()).to_matrix()@rest_g
   world=tr(rotation,root)
   if f>=11:
    point,q=arm_ready[name];final=chest@tr(Quaternion(q).to_matrix(),point)
    t=.30 if f==11 else .93
    world=tr(world.to_quaternion().slerp(final.to_quaternion(),t).to_matrix(),world.translation.lerp(final.translation,t))
  p=rig.pose.bones[name];p.matrix=joint(world);bpy.context.view_layer.update();p.scale=(1,1,1)
  p.rotation_euler=p.matrix_basis.to_euler('XYZ',prev) if prev is not None else p.matrix_basis.to_euler('XYZ');prev=p.rotation_euler.copy()
  p.keyframe_insert('location',frame=f,group=name);p.keyframe_insert('rotation_euler',frame=f,group=name)
for c in curves(a):
 for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
 c.update()
events={'DRAW_BEGIN':1,'WEAPON_GRAB':5,'WEAPON_BACK_RELEASE':5,'SUPPORT_HAND_CATCH':11,'DRAW_READY':14}
for name,f in events.items():a.pose_markers.new(name).frame=f;scene.timeline_markers.new(name,frame=f)
a['event_frames_json']=json.dumps(events)
scene.render.fps=24;scene.render.fps_base=1
scene.frame_start=1;scene.frame_end=14;scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=14
scene.camera=bpy.data.objects['D1_Gameplay'];scene.frame_set(1)
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert geometry()==protected['geometry'] and bones()==protected['bones']
print(json.dumps({'created':a.name,'frames':list(a.frame_range),'saved':False,'protected_actions':len(protected['actions'])}))
