import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
SOURCE=OUT/'animation/player_cuboid_v5_movement.blend';TARGET=OUT/'player_cuboid_v6.blend'
if TARGET.exists():raise RuntimeError('V6 exists; do not overwrite')
hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [SOURCE,OUT/'player_cuboid_v5.blend']}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene;player=bpy.data.objects['Player_Cuboid_Base'];rig=bpy.data.objects['Player_Cuboid_Rig']
texture=bpy.data.images['Player_Cuboid_V5_Face_Atlas_64'];pixels=list(texture.pixels)
mat=player.data.materials[0];oldmesh=player.data
rig.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_euler=(0,0,0);pb.scale=(1,1,1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for s in ['L','R']:
 for n in ['Hand.','Foot.','Forearm.','Shin.']:rig.data.edit_bones.remove(rig.data.edit_bones[n+s])
 a=rig.data.edit_bones['UpperArm.'+s];a.name='Arm.'+s;a.tail.z=.675
 l=rig.data.edit_bones['Thigh.'+s];l.name='Leg.'+s;l.tail.z=0
bpy.ops.object.mode_set(mode='OBJECT')
layouts={
'Head':[(8,8,8,8),(0,8,8,8),(24,8,8,8),(16,8,8,8),(8,0,8,8),(16,0,8,8)],
'Torso':[(20,20,8,12),(16,20,4,12),(32,20,8,12),(28,20,4,12),(20,16,8,4),(28,16,8,4)],
'Arm.R':[(44,20,4,12),(40,20,4,12),(52,20,4,12),(48,20,4,12),(44,16,4,4),(48,16,4,4)],
'Arm.L':[(36,52,4,12),(32,52,4,12),(44,52,4,12),(40,52,4,12),(36,48,4,4),(40,48,4,4)],
'Leg.R':[(4,20,4,12),(0,20,4,12),(12,20,4,12),(8,20,4,12),(4,16,4,4),(8,16,4,4)],
'Leg.L':[(20,52,4,12),(16,52,4,12),(28,52,4,12),(24,52,4,12),(20,48,4,4),(24,48,4,4)]}
verts=[];faces=[];rects=[];parts=[]
U=1.8/32
for part,bone,bounds in [('Head','Head',[-4,4,-4,4,24,32]),('Torso','Chest',[-4,4,-2,2,12,24]),('Arm.L','Arm.L',[4,8,-2,2,12,24]),('Arm.R','Arm.R',[-8,-4,-2,2,12,24]),('Leg.L','Leg.L',[0,4,-2,2,0,12]),('Leg.R','Leg.R',[-4,0,-2,2,0,12])]:
 x0,x1,y0,y1,z0,z1=[v*U for v in bounds];first=len(verts)
 verts.extend([(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)])
 for f in [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(3,2,1,0)]:faces.append(tuple(first+i for i in f))
 rects.extend(layouts[part]);parts.append({'part':part,'bone':bone,'first_vertex':first,'vertex_count':8,'bounds_model_units':bounds})
mesh=bpy.data.meshes.new('Player_Cuboid_V6_Seamless_Mesh');mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(mat)
player.data=mesh
uv=mesh.uv_layers.new(name='Classic_64_Skin_UV')
for poly,(x,y,w,h) in zip(mesh.polygons,rects):
 for li,(u,v) in zip(poly.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):
  e=.0001;uv.data[li].uv=((x+e+(w-2*e)*u)/64,1-(y+h-e-(h-2*e)*v)/64)
player.vertex_groups.clear()
for p in parts:
 g=player.vertex_groups.new(name=p['bone']);g.add(list(range(p['first_vertex'],p['first_vertex']+8)),1,'REPLACE')
player['rigid_parts']=json.dumps(parts);player['geometry_notes']='Six closed cuboids; each arm and leg is one unsplit block with eight vertices and six quads. No elbow/knee or rings.'
if oldmesh.users==0:bpy.data.meshes.remove(oldmesh)
for pb in rig.pose.bones:
 pb.rotation_mode='XYZ';pb.lock_scale=(True,True,True);pb.lock_location=(pb.name not in ['Root','Hips','Spine','Leg.L','Leg.R'],)*3
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
rig.animation_data_create()

def reset():
    for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_euler=(0,0,0);pb.scale=(1,1,1)

def R(x=0,y=0,z=0):
    return Matrix.Rotation(math.radians(z),4,'Z') @ Matrix.Rotation(math.radians(y),4,'Y') @ Matrix.Rotation(math.radians(x),4,'X')

def at(n,position,rot):return Matrix.Translation(position) @ rot @ rest[n].to_3x3().to_4x4()

def slope(a,b):return 0 if a*b<=0 else 2*a*b/(a+b)

def sample(values,t):
    # Periodic monotone cubic interpolation of our own authored key-pose tables.
    t=t%1;u=t*8;i=int(u);f=u-i;v=values[:8]
    a=v[i%8];b=v[(i+1)%8]
    m0=slope(a-v[(i-1)%8],b-a);m1=slope(b-a,v[(i+2)%8]-b)
    return (2*f**3-3*f**2+1)*a+(f**3-2*f**2+f)*m0+(-2*f**3+3*f**2)*b+(f**3-f**2)*m1

def action_curves(action):return list(action.layers[0].strips[0].channelbags[0].fcurves)

def pose(gait,t):
 world={'Root':rest['Root'].copy()};s=math.sin(2*math.pi*t);idle=gait=='Idle';run=gait=='Run'
 hip=Vector((.003*s if idle else .009*s,0,.675))
 yaw=(.45 if idle else 4 if run else 2.7)*s
 roll=(.18 if idle else 1.4 if run else .8)*math.sin(2*math.pi*(t+.08))
 lean=0 if idle else 4 if run else .8
 chestlean=(.35*math.sin(2*math.pi*(t-.08)) if idle else (8 if run else 2)+.6*math.sin(4*math.pi*(t-.04)))
 chestyaw=-(.3 if idle else 3.5 if run else 2.0)*math.sin(2*math.pi*(t-.07))
 world['Hips']=at('Hips',hip,R(lean,roll,yaw))
 def parent_head(n,p):return world[p] @ rest[p].inverted() @ rest[n].translation
 world['Spine']=at('Spine',parent_head('Spine','Hips')+Vector((0,0,.002*math.sin(2*math.pi*(t-.08)) if idle else 0)),R(chestlean*.45,roll*.3,chestyaw*.45))
 world['Chest']=at('Chest',parent_head('Chest','Spine'),R(chestlean,-roll*.25,chestyaw))
 world['Neck']=world['Chest'] @ rest['Chest'].inverted() @ rest['Neck']
 world['Head']=at('Head',parent_head('Head','Neck'),R(.2*math.sin(2*math.pi*(t-.13)) if idle else .7*math.sin(4*math.pi*(t-.08)),.12*s,.5*math.sin(2*math.pi*(t-.12))))
 for side,sgn in [('L',1),('R',-1)]:
  phase=t+(0 if side=='L' else .5)
  arm='Arm.'+side;leg='Leg.'+side
  swing=(1.0*math.sin(2*math.pi*(t-.10))*sgn if idle else (32 if run else 18)*math.cos(2*math.pi*(phase-.035))*(1 if side=='L' else .97))
  world[arm]=at(arm,parent_head(arm,'Chest'),R(swing,-sgn*(1.8 if idle else 4 if run else 2.6),chestyaw*.6))
  if idle:world[leg]=rest[leg].copy()
  else:
   pitch=-(37 if run else 24)*math.cos(2*math.pi*phase)
   world[leg]=at(leg,parent_head(leg,'Hips'),R(pitch,0,yaw*.3))
 if not idle:
  # Raise the body to the lowest full-block corner: no knee bend or limb scaling.
  floors=[]
  for p in parts:
   if p['part'].startswith('Leg'):
    transform=world[p['bone']] @ rest[p['bone']].inverted()
    floors.append(min((transform @ player.data.vertices[i].co).z for i in range(p['first_vertex'],p['first_vertex']+8)))
  offset=-min(floors)+.001
  # A short flight crest makes the run read faster; walk remains grounded.
  if run:offset+=.027*math.sin(2*math.pi*t)**4
  shift=Matrix.Translation((0,0,offset))
  for n in world:
   if n!='Root':world[n]=shift @ world[n]
 for pb in rig.pose.bones:
  n=pb.name
  if pb.parent:
   relative=rest[pb.parent.name].inverted() @ rest[n];basis=relative.inverted() @ world[pb.parent.name].inverted() @ world[n]
  else:basis=rest[n].inverted() @ world[n]
  pb.location=basis.to_translation();pb.rotation_euler=basis.to_euler('XYZ');pb.scale=(1,1,1)
 bpy.context.view_layer.update()
 return {pb.name:{'location':list(pb.location),'rotation_euler':list(pb.rotation_euler)} for pb in rig.pose.bones}
created=[]
for gait,N,step in [('Idle',48,6),('Walk',32,2),('Run',24,2)]:
    reset();rig.animation_data.action=None
    frames=list(range(1,N+2,step))
    if gait=='Run':frames=sorted(set(frames+[2,4,6,14,16,18]))
    samples=[pose(gait,(f-1)/N) for f in frames];samples[-1]=samples[0]
    action=bpy.data.actions.new('Player_'+gait);action.use_fake_user=True;rig.animation_data.action=action
    curves=[]
    for n in samples[0]:
        if n in ('Root','Neck','Foot.L','Foot.R'):continue
        for prop in ['location','rotation_euler']:
            for axis in range(3):
                vals=[v[n][prop][axis] for v in samples]
                threshold=1e-5
                dynamic=max(vals)-min(vals)>threshold
                if not dynamic and max(abs(v) for v in vals)<threshold:continue
                if prop=='location' and n not in ['Hips','Spine','Leg.L','Leg.R']:continue
                curve=action.fcurve_ensure_for_datablock(rig,f'pose.bones["{n}"].{prop}',index=axis,group_name=n)
                use=list(zip(frames,vals)) if dynamic else [(1,vals[0]),(N+1,vals[0])]
                curve.keyframe_points.add(len(use))
                for key,(f,v) in zip(curve.keyframe_points,use):key.co=(f,v);key.interpolation='BEZIER';key.handle_left_type='FREE';key.handle_right_type='FREE'
                unique=use[:-1]
                for i,key in enumerate(curve.keyframe_points):
                    j=i%len(unique);f,v=use[i]
                    if len(unique)==1:derivative=0;before=after=N
                    else:
                        prev=unique[(j-1)%len(unique)];nxt=unique[(j+1)%len(unique)]
                        before=(unique[j][0]-prev[0])%N;after=(nxt[0]-unique[j][0])%N
                        derivative=slope((v-prev[1])/before,(nxt[1]-v)/after)
                    key.handle_left=(f-before/3,v-derivative*before/3);key.handle_right=(f+after/3,v+derivative*after/3)
                curve.modifiers.new('CYCLES');curve.update();curves.append(curve)
    action.use_frame_range=True;action.frame_start=1;action.frame_end=N+1;action.use_cyclic=True
    action['playback_frames']=N;action['fps']=24;action['closure_frame']=N+1;action['in_place']=True;action['original_authorship']=True
    action['recommended_ground_speed_m_s']=0 if gait=='Idle' else .60 if gait=='Walk' else 1.68
    for label,f in [('L contact',1),('Down',1+N//8),('Passing',1+N//4),('Up',1+3*N//8),('R contact',1+N//2),('Closure',N+1)] if gait!='Idle' else [('Breathe in',1+N//4),('Breathe out',1+3*N//4),('Closure',N+1)]:
        marker=action.pose_markers.new(label);marker.frame=f
    created.append({'name':action.name,'playback':[1,N],'keys_and_export':[1,N+1],'fps':24,'duration_s':N/24,'curves':len(curves),'keys':sum(len(c.keyframe_points) for c in curves),'animated_bones':sorted({c.data_path.split('"')[1] for c in curves})})
# Common channel coverage prevents residual pose values when changing actions.
# Missing channels need only two constant rest keys, never Root or scale tracks.
def action_curves(action):return list(action.layers[0].strips[0].channelbags[0].fcurves)
coverage={(c.data_path,c.array_index) for info in created for c in action_curves(bpy.data.actions[info['name']])}
for info in created:
    a=bpy.data.actions[info['name']];rig.animation_data.action=a
    existing={(c.data_path,c.array_index) for c in action_curves(a)}
    for path,axis in sorted(coverage-existing):
        n=path.split('"')[1];curve=a.fcurve_ensure_for_datablock(rig,path,index=axis,group_name=n)
        for frame in info['keys_and_export']:curve.keyframe_points.insert(frame,0)
        curve.modifiers.new('CYCLES');curve.update()
    curves=action_curves(a);info['curves']=len(curves);info['keys']=sum(len(c.keyframe_points) for c in curves);info['animated_bones']=sorted({c.data_path.split('"')[1] for c in curves})
scene.render.fps=24;scene.render.fps_base=1;scene.frame_start=1;scene.frame_end=48
reset();rig.animation_data.action=bpy.data.actions['Player_Idle'];scene.frame_set(1)
rig['movement_notes']='V6 original whole-limb idle/walk/run, no elbow/knee chains. Same periods as V5; rebuilt for shoulder/hip-only articulation. Root stationary, all scales one, no constraints.'
rig['animation_notes']=rig['movement_notes']
scene.camera=bpy.data.objects['V3 Isometric Camera'];scene.camera.data.ortho_scale=2.5
scene.render.filepath=str(OUT/'player_cuboid_v6_isometric.png')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
(OUT/'asset_report_v6_actions.json').write_text(json.dumps(created,indent=2))
assert pixels==list(texture.pixels)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==v for p,v in hashes.items())
mesh.calc_loop_triangles()
report={'saved':str(TARGET),'triangles':len(mesh.loop_triangles),'vertices':len(mesh.vertices),'bones':len(rig.data.bones),'rigid_parts':6,'material_count':len(mesh.materials),'texture_unchanged':True,'earlier_files_unchanged':True,'source_hashes':hashes,'actions':created}
(OUT/'asset_report_v6.json').write_text(json.dumps(report,indent=2))
result=report
