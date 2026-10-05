"""Original sparse-key movement foundation. No external animation implementation used."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/animation')
OUT.mkdir(parents=True,exist_ok=True)
SOURCE=OUT.parent/'player_cuboid_v5.blend';TARGET=OUT/'player_cuboid_v5_movement.blend'
if TARGET.exists() and not globals().get('REBUILD_MOVEMENT',False):raise RuntimeError('Refuse to overwrite existing movement foundation')
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];player=bpy.data.objects['Player_Cuboid_Base']
source_sha=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parts=json.loads(player['rigid_parts'])
static={'vertices':[list(v.co) for v in player.data.vertices],'uv':[list(d.uv) for d in player.data.uv_layers.active.data],'weights':[[(g.group,g.weight) for g in v.groups] for v in player.data.vertices],'bones':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local],b.use_deform) for b in rig.data.bones],'pixels':list(bpy.data.images['Player_Cuboid_V5_Face_Atlas_64'].pixels)}
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
    ytable=[-.20,-.10,0,.10,.20,.09,-.06,-.235] if gait=='Walk' else [-.34,-.13,.08,.27,.32,.16,-.07,-.39]
    ztable=[0,0,0,0,.012,.10,.105,.035] if gait=='Walk' else [0,0,.025,.12,.21,.24,.16,.04]
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
    world={'Root':rest['Root'].copy()};s=math.sin(2*math.pi*t);c=math.cos(2*math.pi*t)
    if gait=='Idle':
        hip=Vector((.003*s,0,.675));yaw=.45*s;roll=.18*math.sin(2*math.pi*(t-.08));lean=0
        breath=.0025*math.sin(2*math.pi*(t-.08));chestyaw=-.3*math.sin(2*math.pi*(t-.1));chestlean=.35*math.sin(2*math.pi*(t-.08))
    else:
        run=gait=='Run'
        heights=[.626,.613,.629,.646,.626,.616,.632,.644] if not run else [.585,.56,.655,.638,.585,.565,.66,.640]
        hip=Vector(((.008 if not run else .011)*s,0,sample(heights,t)))
        yaw=(3.6 if not run else 5.0)*s;roll=(.8 if not run else 1.2)*math.sin(2*math.pi*(t+.1));lean=1.1 if not run else 4
        breath=0;chestyaw=-(2.6 if not run else 4)*math.sin(2*math.pi*(t-.055));chestlean=(2.3 if not run else 10)+( .6 if not run else 1.2)*math.sin(4*math.pi*(t-.045))
    world['Hips']=at('Hips',hip,R(lean,roll,yaw))
    def parent_head(n,parent):return world[parent] @ rest[parent].inverted() @ rest[n].translation
    spinepos=parent_head('Spine','Hips')+Vector((0,0,breath))
    world['Spine']=at('Spine',spinepos,R(chestlean*.45,roll*.3,chestyaw*.45))
    world['Chest']=at('Chest',parent_head('Chest','Spine'),R(chestlean,-roll*.25,chestyaw))
    world['Neck']=world['Chest'] @ rest['Chest'].inverted() @ rest['Neck']
    world['Head']=at('Head',parent_head('Head','Neck'),R(.2*math.sin(2*math.pi*(t-.13)) if gait=='Idle' else .6*math.sin(4*math.pi*(t-.06)),.12*s,.6*math.sin(2*math.pi*(t-.09))))
    for side,sgn in [('L',1),('R',-1)]:
        phase=(t+(0 if side=='L' else .5))%1
        if gait=='Idle':
            # Cancel tiny body-weight shift at the leg roots: both leg boxes and feet stay exactly planted.
            world['Thigh.'+side]=rest['Thigh.'+side].copy();world['Shin.'+side]=rest['Shin.'+side].copy()
            swing=1.05*math.sin(2*math.pi*(t-.1))*(1 if side=='L' else -.86);bend=2.2+.45*math.sin(2*math.pi*(t-.16));spread=2.1
        else:
            h=parent_head('Thigh.'+side,'Hips')
            world['Thigh.'+side],world['Shin.'+side]=solve_leg(side,h,phase,gait)
            armphase=(phase+(.0 if side=='L' else -.015))%1
            swings=[-18,-14,-4,12,18,14,3,-12] if gait=='Walk' else [-42,-28,2,32,42,28,-2,-32]
            bends=[7,9,13,17,14,10,6,5] if gait=='Walk' else [50,55,64,78,76,66,55,48]
            swing=sample(swings,armphase)*(1 if side=='L' else .97)
            bend=sample(bends,armphase-.065);spread=3.5 if gait=='Walk' else 8
        upper='UpperArm.'+side;fore='Forearm.'+side
        world[upper]=at(upper,parent_head(upper,'Chest'),R(chestlean-swing,-sgn*spread,chestyaw*.6))
        world[fore]=at(fore,parent_head(fore,upper),R(chestlean-swing-bend,-sgn*spread,chestyaw*.6))
        world['Hand.'+side]=world[fore] @ rest[fore].inverted() @ rest['Hand.'+side] @ R((.45 if gait=='Idle' else 2 if gait=='Walk' else 4)*math.sin(2*math.pi*(phase-.11)))
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
rig['movement_notes']='Original idle/walk/run. Root is unkeyed and stationary. Contact solve was performed only during authoring; runtime uses TR keys without constraints/drivers/scaling. Hand rotation keys support future held items; visible hand lag is through forearm overlap. Idle leg matrices cancel the tiny body weight shift.'
scene.camera=bpy.data.objects['V3 Isometric Camera'];scene.camera.data.ortho_scale=2.5
scene.render.filepath=str(OUT/'Player_Idle_preview.png')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
(OUT/'actions.json').write_text(json.dumps(created,indent=2))
result={'saved':str(TARGET),'actions':created,'rig_changes':'Only unlocked location authoring channels on Hips, Spine and both Thigh bones. Bind pose, hierarchy, weights, mesh, texture and material unchanged.'}
