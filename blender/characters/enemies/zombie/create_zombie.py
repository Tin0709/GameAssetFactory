"""Original sparse-key movement foundation. No external animation implementation used."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/enemies/zombie')
OUT.mkdir(parents=True,exist_ok=True)
SOURCE=OUT.parents[1]/'player/cuboid/player_cuboid_v5.blend';TARGET=OUT/'zombie_cuboid_v1.blend'
if TARGET.exists() and not globals().get('REBUILD_MOVEMENT',False):raise RuntimeError('Refuse to overwrite existing movement foundation')
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];player=bpy.data.objects['Player_Cuboid_Base']
source_sha=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parts=json.loads(player['rigid_parts'])
player.name='Zombie_Cuboid_Base';player.data.name='Zombie_Cuboid_Mesh'
rig.name='Zombie_Cuboid_Rig';rig.data.name='Zombie_Cuboid_Skeleton'
scene.name='Zombie_Cuboid_Asset'
for collection in bpy.data.collections:
    collection.name=collection.name.replace('Player','Zombie')
for obj in scene.objects:
    if obj.name.startswith('V3 '):obj.name=obj.name.replace('V3 ','Zombie ')
# Original pixel atlas: broad deliberate patches, an open work jacket and torn cuffs.
layouts={
'Head':[(8,8,8,8),(0,8,8,8),(24,8,8,8),(16,8,8,8),(8,0,8,8),(16,0,8,8)],
'Torso':[(20,20,8,12),(16,20,4,12),(32,20,8,12),(28,20,4,12),(20,16,8,4),(28,16,8,4)],
'Arm.R':[(44,20,4,12),(40,20,4,12),(52,20,4,12),(48,20,4,12),(44,16,4,4),(48,16,4,4)],
'Arm.L':[(36,52,4,12),(32,52,4,12),(44,52,4,12),(40,52,4,12),(36,48,4,4),(40,48,4,4)],
'Leg.R':[(4,20,4,12),(0,20,4,12),(12,20,4,12),(8,20,4,12),(4,16,4,4),(8,16,4,4)],
'Leg.L':[(20,52,4,12),(16,52,4,12),(28,52,4,12),(24,52,4,12),(20,48,4,4),(24,48,4,4)]}
skin=(105,132,78);shade=(83,109,62);light=(121,145,91);dark=(45,57,39)
jacket=(64,91,99);seam=(43,65,73);jlight=(77,105,111);undershirt=(122,119,90)
pants=(54,59,58);pedge=(43,47,45);boots=(72,55,43);bootlight=(87,66,48)
pixels=[0.0]*16384
def pixel(x,y,color):
    i=((63-y)*64+x)*4;pixels[i:i+4]=[v/255 for v in color]+[1]
for part,faces in layouts.items():
    for face,(x,y,w,h) in enumerate(faces):
        for v in range(h):
            for u in range(w):
                if part=='Head':
                    col=light if face==4 else shade if face in (2,5) else skin
                    if face in (1,2,3) and ((1<=u<=3 and 1<=v<=2) or (u>=w-3 and 5<=v<=6)):col=shade
                    if face==4 and 2<=u<=4 and 2<=v<=3:col=skin
                    if face==0:
                        if (u in (1,2,5,6) and v==3):col=shade
                        if u in (1,2,5,6) and v==4:col=dark
                        if u in (3,4) and v==5:col=light
                        if u in (3,4) and v==6:col=(65,76,47)
                        if u==0 and v in (1,2):col=shade
                        if u==7 and v in (5,6):col=shade
                elif part=='Torso':
                    col=jacket if face in (0,1,3,4) else seam
                    if face==0:
                        if 3<=u<=4:col=undershirt if v<9 else pedge
                        if v<=1 and 2<=u<=5:col=skin
                        if u in (2,5) and 2<=v<=9:col=seam
                        if u<=1 and 5<=v<=6:col=(110,91,64)
                        if v==10 and u not in (3,4):col=seam
                        if v==11 and u in (0,2,5,7):col=pants
                    elif face in (1,3) and v>=10:col=seam
                    elif face==2:
                        if 3<=u<=4 and v<=2:col=jacket
                        if 1<=u<=3 and 7<=v<=8:col=jacket
                    elif face==4 and 2<=u<=5:col=skin
                elif part.startswith('Arm'):
                    col=jacket if v<8 or face==4 else skin
                    if face in (2,3):col=seam if v<8 else shade
                    if v==7 and u in ((0,2) if part.endswith('L') else (1,3)):col=skin
                    if v==6 and u in (1,2) and part.endswith('R') and face==0:col=(105,86,61)
                    if v in (10,11) and u==3:col=shade
                    if face==5:col=shade
                else:
                    col=pants if v<9 and face!=5 else boots
                    if face in (1,3) and u==0 and v<9:col=pedge
                    if v==5 and u in (1,2) and face==0:col=(66,70,64)
                    if v==9 and face==0:col=bootlight
                    if v==11 or face==5:col=(49,40,33)
                    if face==4:col=pants
                pixel(x+u,y+v,col)
image=bpy.data.images.new('Zombie_Original_Atlas_64',width=64,height=64,alpha=True)
image.pixels.foreach_set(pixels);image.update();image.file_format='PNG'
image.filepath_raw=str(OUT/'zombie_original_atlas_64.png');image.save();image.pack()
mat=player.data.materials[0];mat.name='Zombie_Atlas_Material'
for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE':node.image=image;node.interpolation='Closest'
    if node.type=='BSDF_PRINCIPLED':
        node.inputs['Roughness'].default_value=.59
        node.inputs['Metallic'].default_value=0
        node.inputs['Specular IOR Level'].default_value=.20
for old in list(bpy.data.images):
    if old!=image and old.users==0:bpy.data.images.remove(old)
static={'vertices':[list(v.co) for v in player.data.vertices],'uv':[list(d.uv) for d in player.data.uv_layers.active.data],'weights':[[(g.group,g.weight) for g in v.groups] for v in player.data.vertices],'bones':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local],b.use_deform) for b in rig.data.bones],'pixels':list(image.pixels)}
(OUT/'source_signature.json').write_text(json.dumps({'sha256':source_sha,'static':static}))
rig.animation_data_create()
# Authoring convenience only: same bones, parent structure, bind pose and skinning.
for n in ['Hips','Spine','Thigh.L','Thigh.R']:rig.pose.bones[n].lock_location=(False,False,False)
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
def direction_matrix(n,head,tail):
    q=Vector((0,0,-1)).rotation_difference((tail-head).normalized())
    return at(n,head,q.to_matrix().to_4x4())
def solve_leg(side,hip,phase,gait):
    ytable=[-.145,-.065,.015,.095,.14,.04,-.10,-.17]
    ztable=[0,0,0,0,.015,.075,.08,.025]
    y=sample(ytable,phase);clear=sample(ztable,phase)
    ankle=Vector((.1125 if side=='L' else -.1125,y,clear+.04))
    L=.3375
    def ik(ankle):
        delta=ankle-hip;d=min(delta.length,2*L-.00001);axis=delta.normalized()
        bend=Vector((0,-1,0));bend=(bend-axis*bend.dot(axis)).normalized()
        knee=hip+axis*(d/2)+bend*math.sqrt(max(0,L*L-(d/2)**2))
        return knee,direction_matrix('Thigh.'+side,hip,knee),direction_matrix('Shin.'+side,knee,ankle)
    if clear>=.08:
        ankle.z=clear+.08
        return ik(ankle)[1:]
    # Offline bounded contact solve accounts for the full shin cross-section.
    # Bracketing keeps the knee on a consistent branch throughout airborne poses.
    # The finished actions contain only ordinary TR keys, no runtime IK/constraint.
    lower=next(p for p in parts if p['bone']=='Shin.'+side)
    def evaluate(z):
        ankle.z=z
        knee,tm,sm=ik(ankle)
        xform=sm @ rest['Shin.'+side].inverted()
        floor=min((xform @ player.data.vertices[i].co).z for i in range(lower['first_vertex'],lower['first_vertex']+8))
        return floor,tm,sm
    low=clear-.08;high=max(low+.02,hip.z-.04)
    previous=low;best=(1e9,None,None)
    bracket=None
    for i in range(65):
        z=low+(high-low)*i/64;floor,tm,sm=evaluate(z)
        if abs(floor-clear)<best[0]:best=(abs(floor-clear),tm,sm)
        if floor>=clear and i>0:bracket=(previous,z);break
        previous=z
    if bracket:
        low,high=bracket
        for _ in range(28):
            z=(low+high)/2;floor,tm,sm=evaluate(z)
            if floor<clear:low=z
            else:high=z
        mix=min(1,clear/.08);mix=mix*mix*(3-2*mix)
        ankle.z=z*(1-mix)+(clear+.08)*mix
        return ik(ankle)[1:]
    return best[1],best[2]
def pose(gait,t):
    world={'Root':rest['Root'].copy()};s=math.sin(2*math.pi*t)
    idle=gait=='Idle'
    hip=Vector((.005*s if idle else .016*s,.0,.675 if idle else sample([.630,.613,.619,.638,.628,.606,.623,.641],t)))
    yaw=(.7 if idle else 2.8)*math.sin(2*math.pi*(t-.03))
    roll=(.65 if idle else 2.2)*math.sin(2*math.pi*(t+.06))
    lean=3 if idle else 4.5
    chestlean=(12 if idle else 15)+(1.0 if idle else 2.0)*math.sin(2*math.pi*(t-.11))
    chestyaw=-yaw*.65+.6*math.sin(2*math.pi*(t-.13))
    world['Hips']=at('Hips',hip,R(lean,roll,yaw))
    def parent_head(n,parent):return world[parent] @ rest[parent].inverted() @ rest[n].translation
    world['Spine']=at('Spine',parent_head('Spine','Hips')+Vector((0,0,.0015*math.sin(2*math.pi*(t-.12)))),R(chestlean*.5,roll*.45,chestyaw*.4))
    world['Chest']=at('Chest',parent_head('Chest','Spine'),R(chestlean,roll*.7,chestyaw))
    world['Neck']=world['Chest'] @ rest['Chest'].inverted() @ rest['Neck']
    world['Head']=at('Head',parent_head('Head','Neck'),R(7+1.2*math.sin(2*math.pi*(t-.19)),1.0*math.sin(2*math.pi*(t-.15)),1.0*math.sin(2*math.pi*(t-.20))))
    for side,sgn in [('L',1),('R',-1)]:
        phase=(t+(0 if side=='L' else .47))%1
        if idle:
            world['Thigh.'+side]=rest['Thigh.'+side].copy();world['Shin.'+side]=rest['Shin.'+side].copy()
        else:
            world['Thigh.'+side],world['Shin.'+side]=solve_leg(side,parent_head('Thigh.'+side,'Hips'),phase,gait)
        upper='UpperArm.'+side;fore='Forearm.'+side
        drift=(1.3 if idle else 3.3)*math.sin(2*math.pi*(t-.12-(.09 if side=='R' else 0)))
        pitch=(-68 if side=='L' else -60)+drift
        forepitch=pitch-(10 if side=='L' else 15)+(1 if idle else 2)*math.sin(2*math.pi*(t-.22))
        world[upper]=at(upper,parent_head(upper,'Chest'),R(pitch,-sgn*5,chestyaw*.5))
        world[fore]=at(fore,parent_head(fore,upper),R(forepitch,-sgn*5,chestyaw*.5))
        world['Hand.'+side]=world[fore] @ rest[fore].inverted() @ rest['Hand.'+side] @ R(.8*math.sin(2*math.pi*(t-.26)))
        world['Foot.'+side]=world['Shin.'+side] @ rest['Shin.'+side].inverted() @ rest['Foot.'+side]
    for pb in rig.pose.bones:
        n=pb.name
        if pb.parent:
            relative=rest[pb.parent.name].inverted() @ rest[n]
            basis=relative.inverted() @ world[pb.parent.name].inverted() @ world[n]
        else:basis=rest[n].inverted() @ world[n]
        pb.location=basis.to_translation();pb.rotation_euler=basis.to_euler('XYZ');pb.scale=(1,1,1)
    bpy.context.view_layer.update()
    return {pb.name:{'location':list(pb.location),'rotation_euler':list(pb.rotation_euler)} for pb in rig.pose.bones}
created=[]
for gait,N,step in [('Idle',48,6),('Walk',32,2)]:
    reset();rig.animation_data.action=None
    frames=list(range(1,N+2,step))
    if gait=='Run':frames=sorted(set(frames+[2,4,6,14,16,18]))
    samples=[pose(gait,(f-1)/N) for f in frames];samples[-1]=samples[0]
    action=bpy.data.actions.new('Zombie_'+gait);action.use_fake_user=True;rig.animation_data.action=action
    curves=[]
    for n in samples[0]:
        if n in ('Root','Neck','Foot.L','Foot.R'):continue
        for prop in ['location','rotation_euler']:
            for axis in range(3):
                vals=[v[n][prop][axis] for v in samples]
                threshold=1e-5
                dynamic=max(vals)-min(vals)>threshold
                if not dynamic and max(abs(v) for v in vals)<threshold:continue
                if prop=='location' and n not in ['Hips','Spine','Thigh.L','Thigh.R']:continue
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
    action['recommended_ground_speed_m_s']=0 if gait=='Idle' else .48
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
reset();rig.animation_data.action=bpy.data.actions['Zombie_Idle'];scene.frame_set(1)
rig['movement_notes']='Original zombie idle and shambling walk, independently authored pose tables. Both arms stay forward with asymmetric droop. Hips/chest/head overlap and hunched torso. Root is unkeyed and stationary. Contact solve was performed only during authoring; runtime uses TR keys without constraints/drivers/scaling. Hand rotation keys support future held items; visible hand lag is through forearm overlap. Idle leg matrices cancel the tiny body weight shift.'
scene.camera=bpy.data.objects['Zombie Isometric Camera'];scene.camera.data.ortho_scale=2.5
scene.render.filepath=str(OUT/'Zombie_Idle_preview.png')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
(OUT/'actions.json').write_text(json.dumps(created,indent=2))
result={'saved':str(TARGET),'actions':created,'rig_changes':'Same 18-bone structure as player. Only unlocked location authoring channels on Hips, Spine and both Thigh bones. Bind pose, hierarchy, weights, mesh, texture and material unchanged.'}

