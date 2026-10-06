import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV
rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];scene=bpy.context.scene
existing=bpy.data.actions.get('Holster_LongGun_V1')
if existing:assert existing.get('pass')=='D1 Pass 1 rig support and blocking'
protected=json.loads((BASE/'holster_d1_protection.json').read_text())
def curves(a):return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
def digest(a):return hashlib.sha256(json.dumps([(c.data_path,c.array_index,[(list(k.co),list(k.handle_left),list(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)],sort_keys=True).encode()).hexdigest()
def mesh_digest():return hashlib.sha256(json.dumps({'v':[list(v.co) for v in mesh.data.vertices],'f':[list(p.vertices) for p in mesh.data.polygons],'w':[[(g.group,g.weight) for g in v.groups] for v in mesh.data.vertices],'groups':[g.name for g in mesh.vertex_groups]},sort_keys=True).encode()).hexdigest()
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def tr(b,p):m=b.to_4x4();m.translation=Vector(p);return m
def joint(g):return tr(D@g.to_3x3(),D@g.translation)
def visual(g):return tr(D@g.to_3x3()@D.inverted(),D@g.translation)
ready=Matrix(json.loads(rig['d1_ready_godot_matrix']));stowed=Matrix(json.loads(rig['d1_stowed_godot_matrix']))
chest_ready=Matrix(json.loads(rig['d1_chest_ready_matrix']))
arm_ready={'Arm.R':((-0.33749998,.2662499,.035),(-.24987753,-2.5984479e-8,.44454947,.86019593)), 'Arm.L':((.33749998,.24624991,.145),(.1558697,-2.581006e-8,.47511396,.8660089))}
chest_keys={1:(2,-4,0),2.5:(1.5,-6,0),5:(2,-8,0),8:(3,-11,.5),11:(3.5,-12,1),13:(2,-8,.5),15:(1,-4,0),18:(0,0,0)}
weapon_keys={1:(tuple(ready.translation),9,0),3.5:((-.13,1.0,.44),8,0),4.5:((-.32,1.01,.44),7,-8),5:((-.31,1.01,.37),6,-12),8:((-.61,1.16,.43),24,-38),11:((-.68,1.57,-.21),50,-90),13:((-.34,1.25,-.42),76,-135),15:(tuple(stowed.translation),90,-162),18:(tuple(stowed.translation),90,-162)}
right_keys={1:None,3.5:(.43,-.52,.738),5:(.08,-.72,.69),8:(-.44,-.30,.848),11:(-.67,.50,-.55),13:(-.08,-.22,-.972),15:(-.14,-.93,-.34),18:(0,-1,0)}
left_keys={1:None,4.5:None,5:(-.18,-.66,.73),8:(.17,-.88,.44),11:(.18,-.976,.115),13:(.12,-.985,-.12),15:(.05,-.998,0),18:(0,-1,0)}
action=existing or bpy.data.actions.new('Holster_LongGun_V1');action.use_fake_user=True
for c in curves(action):c.keyframe_points.clear()
action['pass']='D1 Pass 1 rig support and blocking';action['authoring_fps']=24;action['duration_seconds']=17/24
action['weapon_reference']='M4A1_v4';action['future_stow_handoff_frame']=15
rig.animation_data.action=action;rig.pose.bones['WeaponCarrier'].rotation_mode='QUATERNION'
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
for f,angles in chest_keys.items():
 p=rig.pose.bones['Chest'];p.rotation_euler=Euler(tuple(math.radians(v) for v in angles),p.rotation_mode)
 p.keyframe_insert('rotation_euler',frame=f,group='Chest')
# Re-evaluate Chest first, then author local transforms against its posed basis.
for name,keys in [('Arm.R',right_keys),('Arm.L',left_keys)]:
 prev=None
 for f,direction in keys.items():
  scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
  chest_g=tr(D.inverted()@rig.pose.bones['Chest'].matrix.to_3x3(),D.inverted()@rig.pose.bones['Chest'].matrix.translation)
  if direction is None:
   position,q=arm_ready[name];local=tr(Quaternion(q).to_matrix(),position)
  else:
   rest=rig.data.bones[name].matrix_local;rest_g=D.inverted()@rest.to_3x3()
   rotation=Vector((0,-1,0)).rotation_difference(Vector(direction).normalized()).to_matrix()@rest_g
   root=Vector((-.33749998 if name=='Arm.R' else .33749998,.28124988,0))
   fade=max(0,(18-f)/17)
   root+=Vector((0,(-.015 if name=='Arm.R' else -.035)*fade,(.035 if name=='Arm.R' else .145)*fade))
   local=tr(rotation,root)
  p=rig.pose.bones[name];p.matrix=joint(chest_g@local);bpy.context.view_layer.update()
  if prev is not None:p.rotation_euler=p.matrix_basis.to_euler(p.rotation_mode,prev)
  prev=p.rotation_euler.copy()
  p.scale=(1,1,1)
  p.keyframe_insert('location',frame=f,group=name);p.keyframe_insert('rotation_euler',frame=f,group=name)
for f,(point,pitch,roll) in weapon_keys.items():
 scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 if f==1:world=ready
 elif f>=15:world=stowed
 else:
  a=math.radians(pitch);direction=Vector((0,-math.sin(a),math.cos(a)))
  z=-direction;x=Vector((-1,0,0));y=z.cross(x)
  basis=Matrix((x,y,z)).transposed()
  basis=Quaternion(direction,math.radians(roll)).to_matrix()@basis
  world=tr(basis,point)
 p=rig.pose.bones['WeaponCarrier'];p.matrix=visual(world);bpy.context.view_layer.update()
 p.scale=(1,1,1)
 # Keep quaternion hemisphere continuous; no instantaneous equivalent-sign flip.
 q=p.rotation_quaternion.copy()
 if f!=1 and q.dot(previous_q)<0:q.negate();p.rotation_quaternion=q
 previous_q=q.copy()
 p.keyframe_insert('location',frame=f,group='WeaponCarrier');p.keyframe_insert('rotation_quaternion',frame=f,group='WeaponCarrier')
for c in curves(action):
 for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
 c.update()
scene.render.fps=24;scene.render.fps_base=1;scene.frame_start=1;scene.frame_end=18
scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=18
for marker in list(scene.timeline_markers):scene.timeline_markers.remove(marker)
for f,label in [(1,'READY'),(3,'PREPARE'),(5,'SUPPORT RELEASE'),(8,'SWEEP START'),(11,'OVER SHOULDER'),(13,'BACK ALIGN'),(15,'STOW HANDOFF / RELEASE'),(18,'EXIT')]:scene.timeline_markers.new(label,frame=f)
ref_meshes=[o for o in bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].all_objects if o.type=='MESH']
for obj in ref_meshes:obj.data.calc_loop_triangles()
def part_box(name):
 idx=mesh.vertex_groups[name].index;inv=rig.data.bones[name].matrix_local.inverted()
 points=[inv@(mesh.matrix_world@v.co) for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
 return Vector(tuple(min(p[i] for p in points) for i in range(3))),Vector(tuple(max(p[i] for p in points) for i in range(3)))
boxes={n:part_box(n) for n in ['Head','Chest']}
def tri_box(points,low,high):
 center=(low+high)*.5;extent=(high-low)*.5;v=[p-center for p in points]
 edges=[v[1]-v[0],v[2]-v[1],v[0]-v[2]]
 axes=[Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)),edges[0].cross(edges[1])]
 axes += [e.cross(a) for e in edges for a in axes[:3]]
 for a in axes:
  if a.length_squared<1e-12:continue
  p=[a.dot(q) for q in v];r=sum(extent[i]*abs(a[i]) for i in range(3))
  if min(p)>r or max(p)<-r:return False
 return True
hits=[];samples=[]
for step in range(69):
 f=1+step*.25;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 matrices={n:(rig.matrix_world@rig.pose.bones[n].matrix).inverted() for n in boxes}
 counts={n:0 for n in boxes}
 deps=bpy.context.evaluated_depsgraph_get()
 for obj in ref_meshes:
  evaluated=obj.evaluated_get(deps);world=evaluated.matrix_world
  for n,(low,high) in boxes.items():
   margin=.010 if n=='Head' else .035
   verts=[matrices[n]@(world@v.co) for v in obj.data.vertices]
   for t in obj.data.loop_triangles:
    if tri_box([verts[i] for i in t.vertices],low+Vector((margin,)*3),high-Vector((margin,)*3)):counts[n]+=1
 if any(counts.values()):hits.append({'frame':f,'triangles':counts})
 samples.append({'frame':f,'carrier_position':list(rig.pose.bones['WeaponCarrier'].matrix.translation),'poses':{n:{'location':list(rig.pose.bones[n].location),'rotation':list(rig.pose.bones[n].rotation_euler)} for n in ['Chest','Arm.L','Arm.R']}})
out=BASE/'holster_d1_review';out.mkdir(exist_ok=True)
for f in [1,3,5,8,11,13,15,18]:
 scene.frame_set(f);bpy.context.view_layer.update()
 for view in ['Gameplay','Front','Side']:
  scene.camera=bpy.data.objects['D1_'+view];scene.render.filepath=str(out/('pose_%02d_%s.png'%(f,view.lower())))
  bpy.ops.render.render(write_still=True)
newcurves=curves(action)
assert all(c.data_path.split('"')[1] in ['Chest','Arm.L','Arm.R','WeaponCarrier'] for c in newcurves)
assert not any(c.data_path.endswith('.scale') for c in newcurves)
assert mesh_digest()==protected['mesh']
assert all(digest(bpy.data.actions[name])==value for name,value in protected['actions'].items())
assert all({'matrix':[list(row) for row in rig.data.bones[name].matrix_local],'head':list(rig.data.bones[name].head_local),'tail':list(rig.data.bones[name].tail_local),'deform':rig.data.bones[name].use_deform,'parent':rig.data.bones[name].parent.name if rig.data.bones[name].parent else None}==sig for name,sig in protected['bones'].items())
report={'action':action.name,'path':str(DEV),'frames':[1,18],'fps':24,'duration_seconds':17/24,'carrier_parent':'Chest','carrier_deform':False,'original_actions_unchanged':True,'original_rest_and_weights_unchanged':True,'keyed_bones':['Chest','Arm.L','Arm.R','WeaponCarrier'],'lower_body_keys':0,'root_keys':0,'scale_keys':0,'spine_neck_head_keys':0,'collision_samples':69,'collision_hits':hits,'samples':samples,'ready_blender_matrix':[list(row) for row in visual(ready)],'stowed_blender_matrix':[list(row) for row in visual(stowed)],'blocking_only':True}
(BASE/'holster_d1_validation.json').write_text(json.dumps(report,indent=2))
assert not hits,'Weapon/head or deep-chest intersection remains; inspect validation report before saving.'
scene.frame_set(1);scene.camera=bpy.data.objects['D1_Gameplay']
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
rig.show_in_front=False
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   s=area.spaces.active;s.region_3d.view_distance=3.5;s.region_3d.view_location=Vector((0,0,1));s.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion();s.shading.type='MATERIAL';s.overlay.show_relationship_lines=False
# No source/protected files are saved; only this development file.
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
print('D1_BLOCKING='+json.dumps({k:v for k,v in report.items() if k not in ['samples','ready_blender_matrix','stowed_blender_matrix']}))
