"""Isolated rigid-segment FK arm study. Run with the R7-W1 blend loaded."""
import bpy,sys,math,json,hashlib,subprocess,shutil
from pathlib import Path
from mathutils import Matrix,Vector,Euler
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'arm_r8a1_review';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,geometry,bone_signature
SOURCE=BASE/'player_longgun_hold_reference_study_v1.blend';TARGET=BASE/'player_longgun_arm_rig_v2_study.blend'
assert Path(bpy.data.filepath)==SOURCE
protected={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'},'files':{}}
if not (OUT/'preservation.json').exists():
 for n in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0'):
  if n and (ROOT/n).is_file():protected['files'][n]=hashlib.sha256((ROOT/n).read_bytes()).hexdigest()
 (OUT/'preservation.json').write_text(json.dumps(protected,indent=2))
for n in ['reference_1.png','reference_2.jpg','reference_3.jpg','reference_board.png']:shutil.copy2(BASE/'hold_r7w1_review'/n,OUT/n)
oldrig=bpy.data.objects['Player_Cuboid_Rig'];oldmesh=bpy.data.objects['Player_Cuboid_Base'];original=bpy.data.scenes['R7W1_AUTHORING']
source_objects=[oldrig,oldmesh]+list(bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].objects)
def clone(label,scene,objects=source_objects,source_rig=oldrig):
 mapping={}
 for old in objects:
  ob=old.copy();ob.name='R8A1_'+label+'_'+old.name;ob.animation_data_clear()
  if old.type in {'ARMATURE','MESH'}:ob.data=old.data.copy()
  scene.collection.objects.link(ob);mapping[old]=ob;ob.hide_render=False;ob.hide_viewport=False
 for old,ob in mapping.items():
  if old.parent in mapping:ob.parent=mapping[old.parent]
  for md in ob.modifiers:
   if md.type=='ARMATURE' and md.object in mapping:md.object=mapping[md.object]
  for con in ob.constraints:
   if hasattr(con,'target') and con.target in mapping:con.target=mapping[con.target]
 return mapping[source_rig],mapping
def setup(s):
 s.world=original.world;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1200;s.render.resolution_y=720;s.render.resolution_percentage=100;s.render.fps=24;s.frame_start=1;s.frame_end=48
 s.render.image_settings.file_format='PNG';s.view_settings.view_transform='Standard';s.view_settings.look='None'
 for ob in original.objects:
  if ob.type=='LIGHT':s.collection.objects.link(ob)
def camera(s,name,pos,target,scale):
 d=bpy.data.cameras.new('R8A1_'+name);d.type='ORTHO';d.ortho_scale=scale;ob=bpy.data.objects.new(d.name,d);s.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob
def assign(r,a):
 r.animation_data_create();r.animation_data.action=a
 if a and len(a.slots):r.animation_data.action_slot=a.slots[0]
def reset(r):
 for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
s=bpy.data.scenes.new('R8A1_AUTHORING');setup(s);bpy.context.window.scene=s
r,mapping=clone('Author',s);mesh=mapping[oldmesh];weapon=mapping[bpy.data.objects['M4A1_Blocky_Base']]
r.name='R8A1_RigV2_Author';r.data.name='R8A1_RigV2_Skeleton';mesh.name='R8A1_RigV2_Mesh'
# Capture established weapon socket offset before editing the armature.
assign(r,bpy.data.actions['LongGunHold_V2']);reset(r);s.frame_set(1);bpy.context.view_layer.update()
weapon_matrix=weapon.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy();weapon_relative=r.pose.bones['WeaponCarrier'].matrix.inverted()@weapon_matrix
r.animation_data_clear();reset(r)
for o in bpy.context.selected_objects:o.select_set(False)
r.select_set(True);bpy.context.view_layer.objects.active=r;bpy.ops.object.mode_set(mode='EDIT')
for side in ['L','R']:
 b=r.data.edit_bones['Arm.'+side];end=b.tail.copy();mid=b.head.lerp(end,.5);b.name='UpperArm.'+side;b.tail=mid
 f=r.data.edit_bones.new('ForeArm.'+side);f.head=mid;f.tail=end;f.roll=b.roll;f.parent=b;f.use_connect=True
bpy.ops.object.mode_set(mode='OBJECT')
print('R8_ARM_GROUPS',list(mesh.vertex_groups.keys()),flush=True)
# Rebuild only arm islands as two rigid cubes each. Non-arm vertices/faces/UVs
# retain their source values; side UVs are interpolated along the original atlas.
src=mesh.data;armsets={side:{v.index for v in src.vertices if any(g.group==mesh.vertex_groups['UpperArm.'+side].index and g.weight>.999 for g in v.groups)} for side in ['L','R']}
allarm=set.union(*armsets.values());keep=[v.index for v in src.vertices if v.index not in allarm];remap={v:i for i,v in enumerate(keep)}
verts=[tuple(src.vertices[i].co) for i in keep];weights=[[(g.group,g.weight) for g in src.vertices[i].groups] for i in keep];faces=[];materials=[];uvs={u.name:[] for u in src.uv_layers}
for p in src.polygons:
 if not any(i in allarm for i in p.vertices):
  faces.append([remap[i] for i in p.vertices]);materials.append(p.material_index)
  for u in src.uv_layers:uvs[u.name].append([tuple(u.data[li].uv) for li in p.loop_indices])
for side,ids in armsets.items():
 fg=mesh.vertex_groups.new(name='ForeArm.'+side)
 order=sorted(ids);pts=[src.vertices[i].co.copy() for i in order];zmin=min(v.z for v in pts);zmax=max(v.z for v in pts);mid=(zmin+zmax)/2
 for name,lo,hi in [('UpperArm.'+side,mid,zmax),('ForeArm.'+side,zmin,mid)]:
  off=len(verts);lookup={i:off+j for j,i in enumerate(order)};group=mesh.vertex_groups[name].index
  np=[Vector((v.x,v.y,lo+(v.z-zmin)/(zmax-zmin)*(hi-lo))) for v in pts];verts.extend(map(tuple,np));weights.extend([[(group,1.0)] for _ in order])
  for p in src.polygons:
   if set(p.vertices)<=ids:
    faces.append([lookup[i] for i in p.vertices]);materials.append(p.material_index)
    for u in src.uv_layers:
     row=[]
     for li in p.loop_indices:
      vi=src.loops[li].vertex_index;v=src.vertices[vi].co;nv=np[order.index(vi)];uv=u.data[li].uv.copy()
      mate=next((lj for lj in p.loop_indices if (src.vertices[src.loops[lj].vertex_index].co-v).xy.length<1e-6 and abs(src.vertices[src.loops[lj].vertex_index].co.z-v.z)>1e-5),None)
      if mate is not None:
       other=src.vertices[src.loops[mate].vertex_index].co;uv=uv.lerp(u.data[mate].uv,(nv.z-v.z)/(other.z-v.z))
      row.append(tuple(uv))
     uvs[u.name].append(row)
newmesh=bpy.data.meshes.new('R8A1_Articulated_Block_Mesh');newmesh.from_pydata(verts,[],faces);newmesh.update()
for mat in src.materials:newmesh.materials.append(mat)
group_names=[g.name for g in mesh.vertex_groups]
mesh.data=newmesh
for name in group_names:
 if name not in mesh.vertex_groups:mesh.vertex_groups.new(name=name)
for i,ws in enumerate(weights):
 for g,w in ws:mesh.vertex_groups[g].add([i],w,'REPLACE')
for p,mat in zip(newmesh.polygons,materials):p.material_index=mat;p.use_smooth=False
for name,rows in uvs.items():
 u=newmesh.uv_layers.new(name=name)
 for p,row in zip(newmesh.polygons,rows):
  for li,uv in zip(p.loop_indices,row):u.data[li].uv=uv
for p in r.pose.bones:p.rotation_mode='QUATERNION'
def rot(n,degrees):r.pose.bones[n].rotation_quaternion=Euler(tuple(math.radians(v) for v in degrees),'XYZ').to_quaternion()
rot('Spine',(1,-3,0));rot('Chest',(3,-9,0));rot('Neck',(1,8,-1));rot('Head',(2,27,-2))
bpy.context.view_layer.update()
desired=Matrix.LocRotScale(Vector((-.18,-.34,1.16)),Euler(tuple(math.radians(v) for v in (2,0,225)),'XYZ').to_quaternion(),weapon_matrix.to_scale())
r.pose.bones['WeaponCarrier'].matrix=desired@weapon_relative.inverted();bpy.context.view_layer.update()
# Offline two-link construction authors FK rotations; no IK nodes/constraints,
# no persistent controls, no stretch, and no shoulder translation.
measure={}
def arm(side,target,pole):
 upper=r.pose.bones['UpperArm.'+side];fore=r.pose.bones['ForeArm.'+side];shoulder=upper.head.copy();a=upper.length;b=fore.length-.075
 delta=target-shoulder;d=delta.length;axis=delta.normalized();assert abs(a-b)<d<a+b,(side,d,a+b)
 along=(a*a-b*b+d*d)/(2*d);height=math.sqrt(max(0,a*a-along*along));bend=Vector(pole)-shoulder;bend=(bend-axis*bend.dot(axis)).normalized();elbow=shoulder+axis*along+bend*height
 def place(p,head,tail):
  y=(tail-head).normalized();x=Vector((1,0,0));x=(x-y*x.dot(y)).normalized();z=x.cross(y).normalized();m=Matrix((x,y,z)).transposed().to_4x4();m.translation=head;p.matrix=m;bpy.context.view_layer.update()
 place(upper,shoulder,elbow);place(fore,elbow,elbow+(target-elbow).normalized()*fore.length)
 measure[side]={'shoulder':list(shoulder),'elbow':list(elbow),'hand_center':list(target),'reach':d,'bend_deg':180-math.degrees((shoulder-elbow).angle(target-elbow))}
grip=desired@Vector((0,0,0));support=desired@Vector((0,.25,.02))
arm('R',grip,(-.6,.15,.70));arm('L',support,(.45,-.05,.70))
newpose={p.name:p.matrix_basis.copy() for p in r.pose.bones};UPPER=['Spine','Chest','Neck','Head','UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']
def apply(ps):
 r.animation_data_clear()
 for n,m in ps.items():r.pose.bones[n].matrix_basis=m
 bpy.context.view_layer.update()
def key(a,f,ps):
 apply(ps);assign(r,a)
 for n in UPPER:r.pose.bones[n].keyframe_insert('rotation_quaternion',frame=f,group=n)
 r.pose.bones['WeaponCarrier'].keyframe_insert('location',frame=f,group='WeaponCarrier')
hold=bpy.data.actions.new('LongGunHold_RigV2_Study_V1');hold.use_fake_user=True
for f in [1,49]:key(hold,f,newpose)
for c in curves(hold):
 for k in c.keyframe_points:k.interpolation='CONSTANT'
aim=bpy.data.actions.new('LongGunAimBias_RigV2_Study_V1');aim.use_fake_user=True
for f,w in [(1,0),(7,0),(15,.78),(20,1),(23,.88),(31,.3),(43,0),(49,0)]:
 apply(newpose)
 for n,delta in [('Neck',(.25,.4,-.5)),('Head',(1.2,1.0,-1.1)),('Chest',(.25,0,0))]:r.pose.bones[n].matrix_basis=newpose[n]@Euler(tuple(math.radians(v*w) for v in delta),'XYZ').to_matrix().to_4x4()
 key(aim,f,{p.name:p.matrix_basis.copy() for p in r.pose.bones})
for c in curves(aim):
 for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='AUTO_CLAMPED'
 c.modifiers.new('CYCLES')
for name,f in [('HOLD',1),('FOCUS',15),('EMPHASIS',20),('SETTLED',43)]:aim.pose_markers.new(name).frame=f
for a in [hold,aim]:a['scope']='R8-A1 isolated FK rig and pose study, no production export';a['fps']=24
assign(r,hold);s.frame_set(1)
views={'Gameplay':((-3,-5,4.4),(0,-.25,.95),3.8),'Front':((-3,-5,2.5),(0,-.25,1.0),3.4),'Side':((-5,-.25,1.9),(0,-.25,1.0),3.4),'Rear':((-3,5,2.9),(0,-.2,1.0),3.4),'GameplayDistance':((-3,-5,4.4),(0,-.25,.95),17.77778),'CloseGun':((-3,-5,2.65),(0,-.30,1.36),2.45),'GameplayOpposite':((3,-5,4.4),(0,-.25,.95),3.8)}
for name,(pos,target,scale) in views.items():camera(s,name,pos,target,scale)
s.camera=bpy.data.objects['R8A1_Front']
# Original-rig A/B sample scene uses the same cameras/lighting as C/D.
legacy=bpy.data.scenes.new('R8A1_LEGACY');setup(legacy);lr,lmap=clone('Legacy',legacy);lr.name='R8A1_Legacy_Rig';assign(lr,bpy.data.actions['LongGunHold_V2'])
for cam in [o for o in s.objects if o.type=='CAMERA']:legacy.collection.objects.link(cam)
comp=bpy.data.scenes.new('R8A1_COMPARISON');setup(comp);bpy.context.window.scene=comp
q=Vector((-3,-5,3.45)).to_track_quat('Z','Y');right=q@Vector((1,0,0))
for i,(label,a) in enumerate([('A ORIGINAL',bpy.data.actions['LongGunHold_V2']),('B RIGID STUDY',bpy.data.actions['LongGunHold_ReferenceStudy_V1']),('C RIG V2 HOLD',hold),('D RIG V2 FOCUS',aim)]):
 if i<2:rr,mp=clone('ABCD_'+str(i),comp)
 else:rr,mp=clone('ABCD_'+str(i),comp,list(mapping.values()),r)
 rr.name='R8A1_Comparison_'+str(i)+'_Rig';assign(rr,a);offset=right*((i-1.5)*1.95)
 for old,ob in mp.items():
  if old.parent is None and not ob.constraints:ob.location+=offset
 font=bpy.data.curves.new('R8A1_Label','FONT');font.body=label;font.align_x='CENTER';font.size=.11;ob=bpy.data.objects.new(font.name,font);comp.collection.objects.link(ob);ob.location=offset+Vector((0,0,2.05));ob.rotation_euler=q.to_euler()
comp.camera=camera(comp,'ABCD_Camera',Vector((0,-.2,1.0))+q@Vector((0,0,10)),(0,-.2,1.0),8.7);comp.frame_set(20)
(OUT/'construction.json').write_text(json.dumps({'bones':list(r.data.bones.keys()),'arm_lengths':{n:r.data.bones[n].length for n in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R']},'pose':measure,'grip':list(grip),'support_contact_weapon_local':[0,.25,.02],'support':list(support),'notes':'Two-link math baked to FK rotations only. No runtime helpers, hand bones, constraints, stretching or arm translation. Support target is a selected fore-end contact, not old far support helper.'},indent=2))
txt=bpy.data.texts.new('R8A1_README');txt.write('R8-A1 BLENDER-ONLY ARTICULATED ARM STUDY\nA original / B rigid study / C RigV2 hold / D RigV2 focus. Frames1–48 at24fps.\nFour rigid upper/forearm blocks. No hand/finger bones, IK constraints, stretch or shoulder translations.\nAuthoring/Legacy scenes provide identical inspection cameras. References inherited packed from R7-W1.\nARTISTIC STATUS: AWAITING HUMAN REVIEW\n')
for n,h in protected['actions'].items():assert digest(bpy.data.actions[n])==h,n
geo=geometry()
for n,h in protected['geometry'].items():assert geo[n]==h,n
for n,sig in protected['rigs'].items():assert bone_signature(bpy.data.objects[n])==sig,n
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET),check_existing=False)
print('R8A1_CREATED',str(TARGET),json.dumps(measure),flush=True)
