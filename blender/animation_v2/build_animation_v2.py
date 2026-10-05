"""Original animation authoring. Run with Blender --background --python this_file.

Reads only our project assets. Never loads the external reference archives.
Authoring geometry solves are baked; no runtime IK, scale, or limb subdivisions.
"""
import bpy, math, json, hashlib, sys
from pathlib import Path
from mathutils import Vector, Matrix

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
FPS = 30
TAU = math.tau
WEAPONS = {
    'Pistol': ROOT/'blender/weapons/pistol/blocky_pistol_v4.blend',
    'M4A1': ROOT/'blender/weapons/m4a1_blocky/m4a1_blocky_v4.blend',
    'Shotgun': ROOT/'blender/weapons/shotgun/blocky_shotgun_v4.blend',
}
SOURCES = {
    'Player': ROOT/'blender/characters/player/cuboid/player_cuboid_v6.blend',
    'Zombie': ROOT/'blender/characters/enemies/zombie/zombie_cuboid_v2.blend',
}
HASHES = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in [*SOURCES.values(), *WEAPONS.values()]}

def R(x=0, y=0, z=0):
    return (Matrix.Rotation(math.radians(z), 4, 'Z') @
            Matrix.Rotation(math.radians(y), 4, 'Y') @
            Matrix.Rotation(math.radians(x), 4, 'X'))

def smooth(x):
    x = max(0, min(1, x))
    return x*x*(3-2*x)

def curves(a):
    return list(a.layers[0].strips[0].channelbags[0].fcurves)

def reset(rig):
    rig.animation_data.action = None
    for p in rig.pose.bones:
        p.matrix_basis = Matrix.Identity(4)

def load(kind):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCES[kind]))
    rig = bpy.data.objects[kind+'_Cuboid_Rig']
    mesh = bpy.data.objects[kind+'_Cuboid_Base']
    rig.animation_data_clear(); rig.animation_data_create()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    reset(rig)
    if kind == 'Player':
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode='EDIT')
        b = rig.data.edit_bones.new('WeaponSocket')
        b.head = (0,0,0); b.tail = (0,.1,0)
        b.parent = rig.data.edit_bones['Chest']; b.use_deform = False
        bpy.ops.object.mode_set(mode='OBJECT')
    for p in rig.pose.bones:
        p.rotation_mode = 'XYZ'; p.lock_scale = (True,)*3
        p.lock_location = (False,)*3
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 384; scene.render.resolution_y = 384
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = True
    scene.camera = bpy.data.objects['V3 Isometric Camera' if kind=='Player' else 'Zombie Isometric Camera']
    scene.camera.data.ortho_scale = 2.65
    scene.camera.location=(-3.4,-5,3.0)
    scene.camera.rotation_euler=(Vector((0,-.10,.92))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    return rig, mesh, {b.name:b.matrix_local.copy() for b in rig.data.bones}

def world_to_pose(rig, rest, world):
    for p in rig.pose.bones:
        n=p.name
        if n not in world:
            continue
        if p.parent:
            pn=p.parent.name
            basis=(rest[pn].inverted() @ rest[n]).inverted() @ world[pn].inverted() @ world[n]
        else:
            basis=rest[n].inverted() @ world[n]
        p.location=basis.to_translation(); p.rotation_euler=basis.to_euler('XYZ')
        p.scale=(1,1,1)
    bpy.context.view_layer.update()

def gait_world(rest, kind, gait, t):
    """Contact-travel authored from our cuboid dimensions, independent of references."""
    t=t%1; zombie=kind=='Zombie'; idle=gait=='Idle'; run=gait=='Run'
    s=math.sin(TAU*t)
    w={'Root':rest['Root'].copy()}
    def at(n,pos,rot): return Matrix.Translation(pos) @ rot @ rest[n].to_3x3().to_4x4()
    def head(n,p): return w[p] @ rest[p].inverted() @ rest[n].translation
    if idle:
        hip=Vector((.0045*s if not zombie else .008*s, .0015*math.sin(TAU*(t-.13)), .675))
        yaw=(.7 if not zombie else 1.4)*s
        roll=(.3 if not zombie else 1.1)*math.sin(TAU*(t+.1))
    else:
        hip=Vector(((.011 if not run else .015)*s if not zombie else .019*s,0,.675))
        yaw=(4.2 if not run else 6.3)*s if not zombie else 4.3*math.sin(TAU*(t-.05))
        roll=(1.0 if not run else 1.7)*math.sin(TAU*(t+.08)) if not zombie else 3*math.sin(TAU*(t+.08))
    lean=(.25 if idle else 2.5 if not run else 10.5) if not zombie else (12 if idle else 16)
    chestyaw=-(.45 if idle else 3.3 if not run else 5.1)*math.sin(TAU*(t-.055))
    chestpitch=lean+(.4 if idle else .75 if not run else 1.4)*math.sin(2*TAU*(t-.065))
    if zombie: chestpitch=lean+1.8*math.sin(TAU*(t-.09)); chestyaw=-yaw*.65
    w['Hips']=at('Hips',hip,R(0 if idle else 2 if not run else 4,roll,yaw))
    w['Spine']=at('Spine',head('Spine','Hips')+Vector((0,0,.0028*math.sin(TAU*(t-.08)) if idle else 0)),R(chestpitch*.4,roll*.3,chestyaw*.35))
    w['Chest']=at('Chest',head('Chest','Spine'),R(chestpitch,-roll*.32 if not zombie else roll*.65,chestyaw))
    w['Neck']=w['Chest'] @ rest['Chest'].inverted() @ rest['Neck']
    w['Head']=at('Head',head('Head','Neck'),R((.25 if idle else .65)*math.sin(2*TAU*(t-.12))+(5 if zombie else 0),(.18 if not zombie else 1.8)*math.sin(TAU*(t-.17)),(.5 if not zombie else 1.5)*math.sin(TAU*(t-.19))))
    floors={}; supports=[]
    for side,sign in [('L',1),('R',-1)]:
        arm='Arm.'+side; leg='Leg.'+side
        phase=(t+(0 if side=='L' else .5))%1
        swing=(1.15 if idle else 23 if not run else 42)*math.cos(TAU*(phase-.055))*(1 if side=='L' else .955)
        if zombie:
            swing=(-77 if side=='L' else -69)+(1.8 if idle else 4.0)*math.sin(TAU*(t-(.11 if side=='L' else .23)))
        w[arm]=at(arm,head(arm,'Chest'),R(swing,-sign*(2 if idle else 4 if not run else 7),chestyaw*.5))
        if idle:
            w[leg]=rest[leg].copy(); continue
        # Half-cycle ground travel has constant horizontal speed. Swing returns
        # with matching tangent, so velocity does not snap at contact/lift-off.
        # Slight timing imbalance is used only by zombies.
        duty=(.56 if side=='L' else .53) if zombie else .5
        d=.175 if zombie else .235 if not run else .400
        if phase<=duty:
            y=-d+2*d*phase/duty; lift=0
            supports.append(leg)
        else:
            u=(phase-duty)/(1-duty)
            tangent=2*d*(1-duty)/duty
            y=(2*u**3-3*u**2+1)*d + (u**3-2*u*u+u)*tangent + (-2*u**3+3*u*u)*(-d)+(u**3-u*u)*tangent
            lift=(.030 if zombie else .045 if not run else .075)*math.sin(math.pi*u)**2
        angle=math.degrees(math.asin(y/.675))
        pos=head(leg,'Hips'); pos.z+=lift
        # Counter body sway/yaw at the leg roots to keep the stance path straight.
        pos.x=rest[leg].translation.x + (.002*s if zombie else 0)
        pos.y=0
        w[leg]=at(leg,pos,R(angle,0,0))
        floors[leg]=pos.z-.675*math.cos(math.radians(angle))-.1125*abs(math.sin(math.radians(angle)))
    if not idle:
        support=min((floors[n] for n in supports),default=min(floors.values()))
        # Smooth flight crest is modest; contact correction is translation only.
        flight=.014*math.sin(2*TAU*t)**4 if run else 0
        shift=Matrix.Translation((0,0,-support+.004+flight))
        for n in w:
            if n!='Root': w[n]=shift @ w[n]
        for n,floor in floors.items():
            clearance=floor-support+.004+flight
            if clearance<.004: w[n].translation.z+=.004-clearance
    if 'WeaponSocket' in rest:
        w['WeaponSocket']=w['Chest'] @ rest['Chest'].inverted() @ rest['WeaponSocket']
    return w

def make_action(rig,rest,name,count,pose_fn,bones=None,loop=True,layer='base'):
    reset(rig); a=bpy.data.actions.new(name); a.use_fake_user=True
    rig.animation_data.action=a
    bones=bones or [n for n in rest if n not in ['Root','WeaponSocket']]
    samples=[]
    for f in range(count+1):
        world_to_pose(rig,rest,pose_fn(f/count))
        samples.append({n:(list(rig.pose.bones[n].location),list(rig.pose.bones[n].rotation_euler)) for n in bones})
    if loop: samples[-1]=samples[0]
    for n in bones:
        for j,prop in enumerate(['location','rotation_euler']):
            for axis in range(3):
                vals=[s[n][j][axis] for s in samples]
                fc=a.fcurve_ensure_for_datablock(rig,f'pose.bones["{n}"].{prop}',index=axis,group_name=n)
                use=list(enumerate(vals,1)) if max(vals)-min(vals)>1e-7 else [(1,vals[0]),(count+1,vals[0])]
                fc.keyframe_points.add(len(use))
                for k,(f,v) in zip(fc.keyframe_points,use):
                    k.co=(f,v); k.interpolation='LINEAR'
                if loop: fc.modifiers.new('CYCLES')
                fc.update()
    a.use_frame_range=True; a.frame_start=1; a.frame_end=count+1; a.use_cyclic=loop
    a['layer']=layer; a['fps']=FPS; a['playback_frames']=count
    a['original_authorship']=True; a['loop']=loop
    return a

def append_weapon(kind,rig):
    with bpy.data.libraries.load(str(WEAPONS[kind]),link=False) as (src,dst):
        dst.objects=[n for n in src.objects if n in ['Grip_Point','Support_Hand_Point','Muzzle_Point'] or n.endswith('_Base') or n=='Shotgun_Pump']
    objects=[o for o in dst.objects if o]
    marker={o.name:Vector(o.location) for o in objects if o.type=='EMPTY'}
    collection=bpy.data.collections.new(kind+'_Review'); bpy.context.scene.collection.children.link(collection)
    mount=bpy.data.objects.new(kind+'_Mount',None); collection.objects.link(mount)
    con=mount.constraints.new('COPY_TRANSFORMS'); con.target=rig; con.subtarget='WeaponSocket'
    for o in objects:
        # Appended objects are not dependency-graph evaluated until linked.
        # Preserve authored local transforms, especially the attachment empties.
        old=o.matrix_basis.copy(); collection.objects.link(o)
        o.parent=mount; o.matrix_parent_inverse=Matrix.Identity(4); o.matrix_basis=old
        o.name=kind+'_'+o.name
    return collection,marker,objects

def grip_solution(r,l,delta,z,length=.605):
    """Intersection of two fixed-length reach spheres with an authored height.
    Only shoulder rotations are required; arm geometry is never scaled.
    """
    a=Vector((r.x,r.y)); b=Vector((l.x-delta.x,l.y-delta.y))
    ra2=length**2-(z-r.z)**2
    rb2=length**2-(z+delta.z-l.z)**2
    axis=b-a; dist=axis.length; axis.normalize()
    along=(ra2-rb2+dist*dist)/(2*dist)
    h2=ra2-along*along
    if h2<0: raise ValueError(('Unreachable weapon pose',z,h2))
    center=a+axis*along; perpendicular=Vector((-axis.y,axis.x))
    candidates=[center+perpendicular*math.sqrt(h2),center-perpendicular*math.sqrt(h2)]
    p=min(candidates,key=lambda v:v.y)
    return Vector((p.x,p.y,z))

def weapon_world(rest,gait,t,kind,markers,aim=0,kick=0):
    w=gait_world(rest,'Player',gait,t)
    chest_delta=w['Chest'] @ rest['Chest'].inverted()
    # Shared long-gun states use marker-driven calibration per weapon, avoiding
    # full-body duplicated actions. Pistol converges on the existing grip helper.
    secondary=(.55 if gait=='Walk' else .9 if gait=='Run' else .15)*math.sin(TAU*(t-.12))
    gunpitch=(-19*(1-aim)) + secondary + kick*(5.5 if kind=='Shotgun' else 2.2 if kind=='M4A1' else 4.0)
    rotation=R(gunpitch,0,195 if kind!='Pistol' else 180)
    # Solve in neutral chest coordinates, then transport the entire grip system
    # through one body transform. Contacts therefore survive locomotion layering.
    right=rest['Arm.R'].translation; left=rest['Arm.L'].translation
    support=markers['Support_Hand_Point']-markers['Grip_Point']
    delta=rotation.to_3x3() @ support
    z=(1.02 if kind=='Pistol' else 1.035)*(1-aim)+(1.265 if kind=='Pistol' else 1.20)*aim
    if gait=='Run': z-=.042*(1-aim)
    z+=kick*.015+(.002 if gait=='Walk' else .003 if gait=='Run' else 0)*math.sin(2*TAU*(t-.10))
    grip=grip_solution(right,left,delta,z)
    weapon=Matrix.Translation(grip) @ rotation @ Matrix.Translation(-markers['Grip_Point'])
    w['WeaponSocket']=chest_delta @ weapon
    for side,target in [('R',grip),('L',grip+delta)]:
        n='Arm.'+side; shoulder=rest[n].translation
        q=Vector((0,0,-1)).rotation_difference((target-shoulder).normalized())
        w[n]=chest_delta @ Matrix.Translation(shoulder) @ q.to_matrix().to_4x4() @ rest[n].to_3x3().to_4x4()
    if kick:
        pivot=w['Chest'].translation.copy()
        amount=1.7 if kind=='Shotgun' else .55 if kind=='M4A1' else .85
        rear=.032 if kind=='Shotgun' else .007 if kind=='M4A1' else .012
        reaction=Matrix.Translation((0,rear*kick,0)) @ Matrix.Translation(pivot) @ R(-amount*kick) @ Matrix.Translation(-pivot)
        for n in ['Chest','Neck','Head','Arm.L','Arm.R','WeaponSocket']:
            w[n]=reaction @ w[n]
    return w

def static_signature(mesh):
    return {'vertices':[list(v.co) for v in mesh.data.vertices],
            'uv':[list(v.uv) for v in mesh.data.uv_layers.active.data],
            'weights':[[(g.group,g.weight) for g in v.groups] for v in mesh.data.vertices],
            'materials':[m.name for m in mesh.data.materials],
            'textures':{i.name:hashlib.sha256(bytes(str(list(i.pixels)),'utf8')).hexdigest() for i in bpy.data.images if i.type=='IMAGE'}}

def validate(rig,mesh,rest,actions,static):
    report={}; dg=bpy.context.evaluated_depsgraph_get()
    for a in actions:
        reset(rig); rig.animation_data.action=a
        n=int(a['playback_frames']); edge_error=0; minimum=1e6; closure=0; first=None
        for step in range(n*2+1):
            f=1+step/2; bpy.context.scene.frame_set(int(f),subframe=f%1)
            evaluated=mesh.evaluated_get(dg); verts=[v.co.copy() for v in evaluated.data.vertices]
            if first is None: first=verts
            if step==n*2 and a['loop']: closure=max((x-y).length for x,y in zip(first,verts))
            for e in mesh.data.edges:
                i,j=e.vertices
                edge_error=max(edge_error,abs((verts[i]-verts[j]).length-(mesh.data.vertices[i].co-mesh.data.vertices[j].co).length))
            minimum=min(minimum,min(v.z for v in verts))
        report[a.name]={'duration_s':n/FPS,'layer':a['layer'],'loop':bool(a['loop']),
                        'loop_vertex_error_m':closure,'rigid_edge_error_m':edge_error,'minimum_z_m':minimum,
                        'channels':len(curves(a)),'half_frame_samples':n*2+1}
        assert edge_error<1e-5,(a.name,edge_error)
        assert closure<1e-5,(a.name,closure)
        if a['layer']=='base': assert minimum>-.002,(a.name,minimum)
    assert static==static_signature(mesh),'Character mesh/material/texture changed'
    return report

def render(name,frame=1):
    bpy.context.scene.frame_set(frame)
    bpy.context.scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)

def build(kind):
    rig,mesh,rest=load(kind); static=static_signature(mesh)
    actions=[]
    for gait,n in [('Idle',90),('Walk',36 if kind=='Player' else 48),('Run',24)]:
        if kind=='Zombie' and gait=='Run':continue
        a=make_action(rig,rest,kind+'_'+gait,n,lambda t,g=gait:gait_world(rest,kind,g,t))
        a['nominal_speed_m_s']=0 if gait=='Idle' else ((.7833333 if gait=='Walk' else 2.0) if kind=='Player' else .41)
        actions.append(a)
    validation=validate(rig,mesh,rest,actions,static)
    if kind=='Player':
        weapon_data={}
        for weapon in WEAPONS:
            c,m,objs=append_weapon(weapon,rig); weapon_data[weapon]=(c,m,objs)
            c.hide_render=True; c.hide_viewport=True
        for weapon in WEAPONS:
            markers=weapon_data[weapon][1]
            prefix='Pistol' if weapon=='Pistol' else 'LongGun' if weapon=='M4A1' else 'Shotgun'
            upper=['Arm.L','Arm.R','WeaponSocket']
            for state,aim in [('LowReady',0),('Aim',1)]:
                a=make_action(rig,rest,prefix+'_'+state,1,lambda t,k=weapon,m=markers,v=aim:weapon_world(rest,'Idle',0,k,m,v),upper,True,'weapon override')
                a['weapon']=weapon; a['calibration']='fixed arm reach / weapon markers'
                actions.append(a)
            # Review transitions use the same small upper-body mask. The socket
            # and arms are solved together at every authored sample.
            a=make_action(rig,rest,prefix+'_Raise',4,lambda t,k=weapon,m=markers:weapon_world(rest,'Idle',0,k,m,smooth(t)),upper,False,'weapon transition')
            actions.append(a)
        # True local delta channels: use with ADD after the override stance.
        # Arm/socket deltas are baked against the weapon-specific aim reference.
        for weapon,name,n in [('Pistol','Pistol_Recoil',7),('M4A1','Rifle_Recoil',5),('Shotgun','Shotgun_Recoil',13)]:
            markers=weapon_data[weapon][1]
            reference=weapon_world(rest,'Idle',0,weapon,markers,1,0)
            def recoil(t,k=weapon,m=markers):
                pulse=smooth(t/.16) if t<.16 else (1-smooth((t-.16)/.84))
                return weapon_world(rest,'Idle',0,k,m,1,pulse)
            a=make_action(rig,rest,name,n,recoil,['Chest','Neck','Head','Arm.L','Arm.R','WeaponSocket'],False,'additive local delta')
            world_to_pose(rig,rest,reference)
            for fc in curves(a):
                bone=fc.data_path.split('"')[1]; prop=fc.data_path.rsplit('.',1)[1]
                base=getattr(rig.pose.bones[bone],prop)[fc.array_index]
                for key in fc.keyframe_points: key.co.y-=base
            a['reference_pose']='Pistol_Aim' if weapon=='Pistol' else 'LongGun_Aim' if weapon=='M4A1' else 'Shotgun_Aim'
            a['note']='Local translation/Euler deltas; convert to quaternion deltas for Godot import.'
            actions.append(a)
        # Full-body composite review clips are explicitly excluded from export
        # architecture. They show contact-preserving combinations and recovery.
        grip_report={}
        for weapon,(c,m,objs) in weapon_data.items():
            c.hide_render=False; c.hide_viewport=False
            for label,gait,aim in [('WalkLowReady','Walk',0),('RunLowReady','Run',0),('Aim','Idle',1)]:
                n=36 if gait=='Walk' else 24 if gait=='Run' else 60
                a=make_action(rig,rest,'REVIEW_'+weapon+'_'+label,n,lambda t,k=weapon,m=m,g=gait,v=aim:weapon_world(rest,g,t,k,m,v),[x for x in rest if x!='Root'],True,'review composite only')
                actions.append(a)
                maxerr=0
                for frame in range(1,n+2):
                    bpy.context.scene.frame_set(frame)
                    socket=rig.pose.bones['WeaponSocket'].matrix
                    for side,marker in [('R','Grip_Point'),('L','Support_Hand_Point')]:
                        # Contact center is 70 mm up from the flat arm end,
                        # inside the painted hand region of the existing cuboid.
                        hand=rig.pose.bones['Arm.'+side].matrix @ rest['Arm.'+side].inverted() @ (rest['Arm.'+side].translation+Vector((0,0,-.605)))
                        maxerr=max(maxerr,(hand-socket @ m[marker]).length)
                grip_report[a.name]=maxerr
                assert maxerr<.0001,(a.name,maxerr)
                if label in ['Aim','RunLowReady']: render(a.name,1 if label=='Aim' else 5)
            c.hide_render=True;c.hide_viewport=True
        validation['weapon_contact_max_errors_m']=grip_report
        # Include composite transition/firing demonstrations for visual review;
        # these do not replace the modular deliverable actions.
        for weapon,(c,m,objs) in weapon_data.items():
            for mode,n in [('Raise',18),('Fire',30)]:
                def demonstration(t,k=weapon,m=m,mode=mode):
                    aim=smooth((t-.20)/(.1333333/(18/FPS))) if mode=='Raise' else 1
                    elapsed=t
                    duration={'Pistol':7/30,'M4A1':5/30,'Shotgun':13/30}[k]
                    age=elapsed-.2
                    if k=='M4A1' and mode=='Fire' and .2<=elapsed<.65: age=(elapsed-.2)%.14
                    u=age/duration
                    pulse=(smooth(u/.16) if u<.16 else 1-smooth((u-.16)/.84)) if 0<=u<=1 and mode=='Fire' else 0
                    return weapon_world(rest,'Walk',t,k,m,aim,pulse)
                a=make_action(rig,rest,'REVIEW_'+weapon+'_'+mode,n,demonstration,[x for x in rest if x!='Root'],False,'review composite only')
                actions.append(a)
        # Validate all full poses; additive deltas are validated by composition
        # in validate_layers.py instead of treating them as absolute poses.
        validation.update(validate(rig,mesh,rest,[a for a in actions if a['layer']!='additive local delta'],static_signature(mesh)))
        phase=0; transition_worlds=[]
        for f in range(91):
            seconds=f/FPS
            walk=smooth((seconds-.25)/.13)*(1-smooth((seconds-2.70)/.13))
            run=smooth((seconds-1.05)/.13)*(1-smooth((seconds-2.05)/.13))
            phase+=(walk*(1-run)/1.2+run/.8)/FPS if f else 0
            idleworld=gait_world(rest,'Player','Idle',seconds/3)
            walkworld=gait_world(rest,'Player','Walk',phase)
            runworld=gait_world(rest,'Player','Run',phase)
            def blend(a,b,weight):
                return {n:Matrix.Translation(a[n].translation.lerp(b[n].translation,weight)) @ a[n].to_quaternion().slerp(b[n].to_quaternion(),weight).to_matrix().to_4x4() for n in a}
            combined=blend(idleworld,blend(walkworld,runworld,run),walk)
            floor=min((combined[p['bone']] @ rest[p['bone']].inverted() @ mesh.data.vertices[i].co).z
                      for p in json.loads(mesh['rigid_parts']) if p['part'].startswith('Leg')
                      for i in range(p['first_vertex'],p['first_vertex']+8))
            correction=Matrix.Translation((0,0,max(0,.004-floor)))
            for n in combined:
                if n!='Root':combined[n]=correction @ combined[n]
            transition_worlds.append(combined)
        a=make_action(rig,rest,'REVIEW_Locomotion_Transitions',90,lambda t:transition_worlds[round(t*90)],[n for n in rest if n!='Root'],False,'review composite only')
        actions.append(a)
        # Save neutral base with weapons hidden; reviewers can activate a
        # matching REVIEW action and collection, or use the provided renderer.
        rig['review_instructions']='REVIEW_* actions are composites only. Enable the matching weapon Review collection. Layer states replace Arm.L/R and WeaponSocket; recoil clips are local deltas.'
    reset(rig);rig.animation_data.action=bpy.data.actions[kind+'_Walk']
    bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=int(rig.animation_data.action['playback_frames'])
    bpy.context.scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    if kind=='Player':
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'player_review_v2.blend'))
        catalog=[{'name':a.name,'layer':a['layer'],'frames':int(a['playback_frames']),'fps':FPS,'loop':bool(a['loop'])} for a in actions]
        for a in list(bpy.data.actions):
            if a.name.startswith('REVIEW_'):bpy.data.actions.remove(a)
        actions=[a for a in bpy.data.actions]
    else:
        catalog=[{'name':a.name,'layer':a['layer'],'frames':int(a['playback_frames']),'fps':FPS,'loop':bool(a['loop'])} for a in actions]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(kind.lower()+'_animation_v2.blend')))
    render(kind+'_Walk',7)
    (OUT/(kind.lower()+'_validation.json')).write_text(json.dumps(validation,indent=2))
    (OUT/(kind.lower()+'_actions.json')).write_text(json.dumps(catalog,indent=2))

if __name__=='__main__':
    OUT.mkdir(exist_ok=True)
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for kind in (args or ['Player','Zombie']):build(kind)
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in HASHES.items())
    (OUT/'source_preservation.json').write_text(json.dumps({'unchanged':True,'sha256':HASHES},indent=2))
    print('ANIMATION_V2_BUILD_SUCCESS')
