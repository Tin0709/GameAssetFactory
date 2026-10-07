"""Six isolated FK combat studies, calibrated to translated 2.6 m/s previews.

Never alters an existing Action, mesh, rig, or production file. Run on R14 V1.
"""
import ast, bpy, math, sys, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector
BASE=Path(__file__).resolve().parent;sys.path.insert(0,str(BASE))
from turning_r2_common import curves,assign,camera,digest,geometry,bone_signature,periodic
OUT=BASE/'combat_strafe_r14_pass2_review';OUT.mkdir(exist_ok=True)
FPS=48;PERIOD=16;SPEED=2.6;DIST=SPEED*PERIOD/FPS;FLIGHT=.58
before={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'},'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()}
(OUT/'preservation_before.json').write_text(json.dumps(before))
# Reuse inspected approved ready-rig cloning and review-camera conventions.
p=BASE/'create_combat_strafe_r14.py';txt=p.read_text();ns={'__file__':str(p)}
exec(compile(txt.split('FLOOR=')[0],str(p),'exec'),ns)
for k,n in [('FLOOR','R14_Floor'),('GRID','R14_Grid'),('TARGETMAT','R14_Target')]:ns[k]=bpy.data.materials[n]
exec(compile(ast.Module(body=[n for n in ast.parse(txt).body if isinstance(n,ast.FunctionDef) and n.name in ['box','new_scene']],type_ignores=[]),str(p),'exec'),ns)
REST=ns['REST'];POINTS=ns['LEGPTS'];NAMES=['Hips','Leg.L','Leg.R','Spine']
DIRECTIONS={'Right':(-1,0),'Left':(1,0),'ForwardRight':(-2**-.5,-2**-.5),'ForwardLeft':(2**-.5,-2**-.5),'BackwardRight':(-2**-.5,2**-.5),'BackwardLeft':(2**-.5,2**-.5)}

def footstroke(u):
    """Hermite recovery, constant-speed plant; endpoint velocity is continuous."""
    u%=1;reach=DIST*(1-FLIGHT)/2
    if u<FLIGHT:return -reach-DIST*u+DIST*ns['ease'](u/FLIGHT)
    return reach-DIST*(u-FLIGHT)

def pose(t,direction,vector=None):
    phase=(t/PERIOD)%1;v=Vector((*DIRECTIONS[direction],0)) if vector is None else vector.copy()
    lead='R' if direction.endswith('Right') else 'L';theta=2*math.pi*phase
    waves={side:footstroke(phase-(0 if side==lead else .5)) for side in ['R','L']}
    # Weight shift follows feet, keeping modest angular reach at actual game speed.
    shift=v*(.65*(waves['R']+waves['L'])/2)
    hop=.007*(1-math.cos(4*math.pi*(phase-.035)))
    yaw=math.radians(1.5)*math.sin(theta)*(1 if lead=='L' else -1)
    # A shallow 35mm weight-bearing crouch reduces visible rigid-leg hip seams.
    hm=Matrix.Translation(REST['Hips'].translation+shift+Vector((0,0,-.031+hop)))@Matrix.Rotation(yaw,4,'Z')@REST['Hips'].to_quaternion().to_matrix().to_4x4()
    values={'Hips':REST['Hips'].inverted()@hm,'Spine':Matrix.Rotation(-yaw,4,'Y')@Matrix.Rotation(math.radians(.7)*math.sin(theta-.25),4,'Z')}
    for side in ['R','L']:
        n='Leg.'+side;u=(phase-(0 if side==lead else .5))%1
        # Rear diagonals use lower, earlier-peaking recovery, not reversed forward keys.
        backward=direction.startswith('Backward');flightheight=.045 if backward else .053
        s=u/FLIGHT
        lift=flightheight*math.sin(math.pi*s)**2*(1+.18*math.sin(2*math.pi*s) if backward else 1) if u<FLIGHT else 0
        bias=DIST*.25*(1 if side==lead else -1)
        target=Vector((REST[n].translation.x,0,0))+v*(bias+waves[side])
        parent=hm@REST['Hips'].inverted()@REST[n];head=parent.translation
        dx,dy=target.x-head.x,target.y-head.y
        radius=math.hypot(dx,dy);assert radius<.675*.84,(direction,t,radius)
        down=Vector((dx,dy,-math.sqrt(.675**2-radius**2)))/.675
        rot=Vector((0,0,-1)).rotation_difference(down).to_matrix().to_4x4()@REST[n].to_quaternion().to_matrix().to_4x4()
        lm=Matrix.Translation(head)@rot;deform=lm@REST[n].inverted()
        lm.translation.z+=.002+lift-min((deform@p).z for p in POINTS[n])
        values[n]=parent.inverted()@lm
    return values

def key(r,a,f,values):
    ns['key_values'](r,a,f,values)

def safe_floor(values):
    """Preview-only floor repair after matrix blending, without new rig mechanics."""
    values={n:m.copy() for n,m in values.items()};hm=REST['Hips']@values['Hips']
    for n in ['Leg.R','Leg.L']:
        parent=hm@REST['Hips'].inverted()@REST[n];lm=parent@values[n];deform=lm@REST[n].inverted()
        low=min((deform@p).z for p in POINTS[n])
        if low<.002:lm.translation.z+=.002-low;values[n]=parent.inverted()@lm
    return values

def continuous_curves(a):
    for c in curves(a):
        ks=c.keyframe_points
        for i,k in enumerate(ks):
            slope=0 if i in [0,len(ks)-1] else (ks[i+1].co.y-ks[i-1].co.y)/(ks[i+1].co.x-ks[i-1].co.x)
            step=.25;k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-step/3,k.co.y-slope*step/3);k.handle_right=(k.co.x+step/3,k.co.y+slope*step/3)
        c.update()

def planted_preview(values,position,canonical_phase,memory,enabled):
    """Bake coherent-family contact positions into PREVIEW Actions only.

    This authors existing FK transforms, without constraints/IK or a runtime
    movement system. Keep the same45deg leg limit; unreachable plants can slip.
    """
    if not enabled:
        memory.clear();return values
    values={n:m.copy() for n,m in values.items()};hm=REST['Hips']@values['Hips']
    for n in ['Leg.R','Leg.L']:
        u=(canonical_phase-(0 if n=='Leg.R' else .5))%1
        parent=hm@REST['Hips'].inverted()@REST[n];lm=parent@values[n];deform=lm@REST[n].inverted()
        sole=[p for p in POINTS[n] if p.z<.0001];center=sum((deform@p for p in sole),Vector())/4
        world=center+position;contact=u>=FLIGHT
        state=memory.setdefault(n,{'contact':False,'carry':Vector((0,0,0)),'corrected':world.copy()})
        if contact:
            if not state['contact']:state['anchor']=world.copy()
            desired=state['anchor'].copy()
        else:
            if state['contact']:state['carry']=state['corrected']-world
            desired=world+state['carry']*(1-ns['ease'](u/FLIGHT))
        target=desired-position;head=parent.translation;dx,dy=target.x-head.x,target.y-head.y;radius=math.hypot(dx,dy)
        limit=.675*math.sin(math.radians(45))
        if radius>limit:dx*=limit/radius;dy*=limit/radius;radius=limit
        down=Vector((dx,dy,-math.sqrt(.675**2-radius**2)))/.675
        rot=Vector((0,0,-1)).rotation_difference(down).to_matrix().to_4x4()@REST[n].to_quaternion().to_matrix().to_4x4()
        newlm=Matrix.Translation(head)@rot;newdef=newlm@REST[n].inverted()
        clearance=max(.002,min((deform@p).z for p in POINTS[n]))
        newlm.translation.z+=clearance-min((newdef@p).z for p in POINTS[n])
        values[n]=parent.inverted()@newlm
        actual=sum((newlm@REST[n].inverted()@p for p in sole),Vector())/4+position
        state['corrected']=actual;state['contact']=contact
    return values

def text(s,name,body,pos,size=.16):
    d=bpy.data.curves.new(name,'FONT');d.body=body;d.size=size;d.align_x='CENTER'
    o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(math.pi/2,0,0);return o

def scene(name):
    s,cs=ns['new_scene'](name);s.render.fps=FPS;s.frame_end=32;s.render.resolution_x=1200;s.render.resolution_y=800;s.eevee.taa_render_samples=8
    s.unit_settings.system='METRIC'
    for o in s.objects:
        if 'Enemy' in o.name:o.hide_render=True;o.hide_set(True)
    return s,cs

def travel(stage,direction,base=(0,0,0),periods=2,speed=SPEED):
    v=Vector((*DIRECTIONS[direction],0));duration=PERIOD*periods/FPS
    for f in [1,1+PERIOD*periods]:
        stage.location=Vector(base)+v*speed*((f-1)/FPS-duration/2);stage.keyframe_insert('location',frame=f)
    stage.animation_data.action.name='PREVIEW_ONLY_R14P2_'+stage.name+'_Travel'
    for c in curves(stage.animation_data.action):
        for k in c.keyframe_points:k.interpolation='LINEAR'

def clone(s,label,a):
    r,m,st=ns['clone'](s,'P2_'+label,a)
    for tr in r.animation_data.nla_tracks:
        for strip in tr.strips:strip.scale=2;strip.repeat=100
    return r,m,st

assert not any(bpy.data.actions.get('Combat_Strafe'+d+('_V2' if d in ['Right','Left'] else '_V1')) for d in DIRECTIONS)
author,cams=scene('R14P2_Right');r,m,st=clone(author,'Right',None)
actions={};reviews={}
for d in DIRECTIONS:
    a=bpy.data.actions.new('Combat_Strafe'+d+('_V2' if d in ['Left','Right'] else '_V1'));a.use_fake_user=True
    a['scope']='R14 Pass 2 Blender study only; no root motion, IK, bones, or upper-ready changes'
    a['fps']=FPS;a['cycle_frames']=PERIOD;a['duration_seconds']=PERIOD/FPS;a['distance_per_cycle_m']=DIST;a['preview_speed_mps']=SPEED;a['flight_fraction']=FLIGHT
    a['leading_leg']='Leg.R' if d.endswith('Right') else 'Leg.L';a['trailing_delay_seconds']=PERIOD/FPS/2
    a['direction_blender_xy']=list(DIRECTIONS[d]);a['recovery']='lower earlier-peaking rear recovery' if d.startswith('Backward') else 'forward/lateral smooth recovery'
    for i in range(PERIOD*4+1):key(r,a,1+i/4,pose(i/4,d))
    periodic(a,PERIOD);actions[d]=a
assign(r,actions['Right'])
for d,a in actions.items():
    if d=='Right':s,cs,rr,mm,ss=author,cams,r,m,st
    else:s,cs=scene('R14P2_'+d);rr,mm,ss=clone(s,d,a)
    travel(ss,d)
    # Follow at the unchanged lab camera angle, with the grid moving visibly below.
    for cname in cs.values():
        cam=bpy.data.objects[cname];pos=cam.location.copy()
        for f in [1,33]:cam.location=pos+Vector((*DIRECTIONS[d],0))*SPEED*((f-1)/FPS-1/3);cam.keyframe_insert('location',frame=f)
        for c in curves(cam.animation_data.action):
            for k in c.keyframe_points:k.interpolation='LINEAR'
    s.camera=bpy.data.objects[cs['ThreeQuarter']]
    text(s,'R14P2_'+d+'_Label',d+' | 2.60 m/s',(0,0,2.13))
    reviews[d]={'scene':s.name,'rig':rr.name,'mesh':mm.name,'stage':ss.name,'cameras':cs,'action':a.name}

# Six-direction layout: short translated paths retain a readable character scale.
s,cs=scene('R14P2_00_SIX_DIRECTION_SHOWCASE');s.render.resolution_x=1600;s.render.resolution_y=1050
for i,d in enumerate(['ForwardLeft','Left','BackwardLeft','ForwardRight','Right','BackwardRight']):
    x=(i%3-1)*3.45;y=(i//3)*3.45
    rr,mm,ss=clone(s,'Show_'+d,actions[d]);travel(ss,d,(x,y,0))
    text(s,'R14P2_Show_'+d,d.upper(),(x,y,2.05),.17)
    # Arrow points along actual travel; enemy-facing direction always remains -Y.
    v=Vector((*DIRECTIONS[d],0));start=Vector((x,y,0.004));end=start+v*.7
    ns['box'](s,'R14P2_Arrow_'+d,tuple((start+end)/2),(.01,.01,.002),ns['TARGETMAT'])
    shaft=s.objects['R14P2_Arrow_'+d];shaft.scale=(.025,.35,.003);shaft.rotation_euler.z=math.atan2(-v.x,v.y)
    text(s,'R14P2_Speed_'+d,'2.60 m/s  |  0.333 s', (x,y,-.01),.11)
cam=bpy.data.objects[cs['ThreeQuarter']];cam.location=(2,-11,8);cam.rotation_euler=(Vector((0,1.6,.9))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=11.5;s.camera=cam
text(s,'R14P2_Title','R14 PASS 2 - SIX DIRECTIONS / HUMAN REVIEW',(0,1.8,3.1),.22)
showcase=s.name

# A/B at IDENTICAL real combat speed: V1's .192 m/s stroke exposes the mismatch.
s,cs=scene('R14P2_01_AB_SAME_GAME_SPEED');s.render.resolution_x=1400;s.render.resolution_y=700
for i,(label,a) in enumerate([('A  V1 / ORIGINAL',bpy.data.actions['Combat_StrafeRight_V1']),('B  V2 / SPEED MATCHED',actions['Right'])]):
    rr,mm,ss=clone(s,'AB_'+str(i),a);travel(ss,'Right',((i-.5)*3.4,0,0))
    if i==0:
        # V1 retained at its authored 24 fps, represented in the 48 fps scene.
        assign(rr,None);tr=rr.animation_data.nla_tracks.new();strip=tr.strips.new(a.name,1,a);strip.action_slot=a.slots[0];strip.scale=2;strip.repeat=100
    text(s,'R14P2_AB_'+str(i),label,((i-.5)*3.4,0,2.15),.17)
cam=bpy.data.objects[cs['ThreeQuarter']];cam.location=(1,-9,4);cam.rotation_euler=(Vector((0,0,.9))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=7.5;s.camera=cam
ab=s.name

# Continuous shared-phase transitions; preview-only baking never creates extra
# Combat_Strafe Actions. Existing forward/back Walk is sampled without mutation.
walk=bpy.data.actions['PREVIEW_ONLY_R9W4_Walk_LOWER']
sample_scene,sc=scene('R14P2_WALK_SAMPLER');sam,_,_=clone(sample_scene,'WalkSampler',walk)
for n in ['Root','Hips','Leg.L','Leg.R']:sam.pose.bones[n].rotation_mode='XYZ'
walk_samples=[]
for i in range(65):
    f=float(walk.frame_range[0])+((float(walk.frame_range[1])-float(walk.frame_range[0]))*i/64)
    sample_scene.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
    walk_samples.append({n:sam.pose.bones[n].matrix_basis.copy() for n in NAMES})

def blend(a,b,w):
    return {n:Matrix.LocRotScale(a[n].to_translation().lerp(b[n].to_translation(),w),a[n].to_quaternion().slerp(b[n].to_quaternion(),w),Vector((1,1,1))) for n in NAMES}

def existing_walk(canonical_phase,backward=False):
    # Study-only backward comparison uses the EXISTING Walk backwards, labelled.
    # Source Walk is16@24fps, represented as32@48fps. Its phase0 is
    # right-forward contact, whereas the strafe right plant begins atphase.58.
    # Map contact once at the handoff, then continue at native Walk cadence.
    p=(canonical_phase-.58)%1
    if backward:p=(.58-canonical_phase)%1
    x=p*64;i=min(63,int(x));return blend(walk_samples[i],walk_samples[i+1],x-i)

sequences=[['Right','ForwardRight','Forward'],['Left','ForwardLeft','Forward'],['Right','BackwardRight','Backward'],['Left','BackwardLeft','Backward'],['ForwardRight','BackwardRight'],['ForwardLeft','BackwardLeft'],['ForwardRight','BackwardRight','BackwardLeft','ForwardLeft','ForwardRight'],['Forward','ForwardRight','Right'],['Backward','BackwardLeft','Left']]
transition_reviews=[]
for idx,seq in enumerate(sequences):
    segment=32+[0,4,8,12][idx%4]
    s,cs=scene('R14P2_T'+str(idx+1)+'_'+'_'.join(seq));s.frame_end=len(seq)*segment
    rr,mm,ss=clone(s,'Transition'+str(idx),None);a=bpy.data.actions.new('PREVIEW_ONLY_R14P2_Transition_'+str(idx+1));a.use_fake_user=True
    pos=Vector((0,0,0));prevvel=None;contact_memory={}
    clocks=[0]
    def rate(d):return 1/(32 if d in ['Forward','Backward'] else PERIOD)
    for j,previous in enumerate(seq[:-1]):
        correction=4*(rate(seq[j-1])-rate(previous)) if j else 0
        clocks.append(clocks[-1]+segment*rate(previous)+correction)
    def state(d,phase):
        if d in ['Forward','Backward']:return existing_walk(phase,d=='Backward'),Vector((0,-1 if d=='Forward' else 1,0))
        # Keep each physical foot's phase through handed-direction changes.
        phase=phase*PERIOD+(PERIOD/2 if d.endswith('Left') else 0)
        return pose(phase,d),Vector((*DIRECTIONS[d],0))
    for i in range(s.frame_end*4+1):
        t=i/4;k=min(len(seq)-1,int(t//segment));local=t-k*segment;d=seq[k]
        # One physical-foot clock for BOTH poses during every crossfade.
        phase=clocks[k]+local*rate(d)
        if k:
            oldrate=rate(seq[k-1]);newrate=rate(d)
            if local<8:
                u=local/8;integral=2.5*u**4-3*u**5+u**6
                phase=clocks[k]+local*oldrate+8*(newrate-oldrate)*integral
            else:phase+=4*(oldrate-newrate)
        vals,vel=state(d,phase)
        if k>0 and local<8:
            old,oldv=state(seq[k-1],phase);w=ns['ease'](local/8);vals=blend(old,vals,w);vel=oldv.lerp(vel,w)
        if prevvel is not None:pos+=(prevvel+vel)*(.25/FPS*SPEED/2)
        prevvel=vel.copy()
        family=d not in ['Forward','Backward'] and not(k>0 and local<8 and seq[k-1] in ['Forward','Backward'])
        vals=planted_preview(safe_floor(vals),pos,phase,contact_memory,family)
        key(rr,a,1+t,vals);ss.location=pos;ss.keyframe_insert('location',frame=1+t)
    continuous_curves(a);ss.animation_data.action.name='PREVIEW_ONLY_R14P2_TransitionTravel_'+str(idx+1)
    for c in curves(ss.animation_data.action):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    # Tracking camera preserves the gameplay/lab viewing angle without hiding travel.
    cam=bpy.data.objects[cs['ThreeQuarter']];cam.parent=ss;s.camera=cam
    for i,d in enumerate(seq):s.timeline_markers.new(d+(' / EXISTING WALK' if d in ['Forward','Backward'] else ''),frame=1+i*segment)
    transition_reviews.append({'scene':s.name,'rig':rr.name,'mesh':mm.name,'stage':ss.name,'action':a.name,'sequence':seq,'camera':cam.name,'segment_frames':segment,'handoff_phases':[phase%1 for phase in clocks[1:]]})

# Optional lab walk-speed reference, NLA retiming of SAME six Actions only.
s,cs=scene('R14P2_02_LAB_SPEED_4_25');s.frame_end=20
for i,d in enumerate(['Left','Right','ForwardLeft','ForwardRight','BackwardLeft','BackwardRight']):
    rr,mm,ss=clone(s,'Lab_'+d,None);tr=rr.animation_data.nla_tracks.new();st2=tr.strips.new(actions[d].name,1,actions[d]);st2.action_slot=actions[d].slots[0];st2.scale=2.6/4.25;st2.repeat=100
    travel(ss,d,((i%3-1)*3.45,(i//3)*3.45,0),periods=1.25,speed=4.25)
    text(s,'R14P2_Lab_'+d,d+' / 4.25 m/s',((i%3-1)*3.45,(i//3)*3.45,2.05),.15)
cam=bpy.data.objects[cs['ThreeQuarter']];cam.location=(2,-11,8);cam.rotation_euler=(Vector((0,1.6,.9))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=11.5;s.camera=cam
design={'fps':FPS,'period':PERIOD,'duration_seconds':PERIOD/FPS,'speed_mps':SPEED,'distance_per_cycle_m':DIST,'flight_fraction':FLIGHT,'reviews':reviews,'showcase_scene':showcase,'ab_scene':ab,'transitions':transition_reviews,'lab_speed_scene':s.name,'status':'ARTISTIC STATUS: AWAITING HUMAN REVIEW'}
(OUT/'design.json').write_text(json.dumps(design,indent=2))
readme=bpy.data.texts.new('R14_PASS2_READ_ME');readme.write(json.dumps(design,indent=2)+'\n\nOnly six new Combat_Strafe Actions. FPS48; frames1-16 playback, closure17. V1 at24fps is retained.\nPrimary speed2.6m/s (real combat). Optional LAB_SPEED_4_25 scene retimes the SAME Actions to4.25m/s.\nNo Godot/export/production edits. Forward and backward transition endpoints compare existing Walk (backwards for Backward), not new Actions.\nNative .blend is the authoritative animation preview; parent travel visibly resets at the end of showcase path.\n')
assert all(digest(bpy.data.actions[n])==h for n,h in before['actions'].items())
geo=geometry();assert all(geo[n]==h for n,h in before['geometry'].items())
assert all(json.dumps(bone_signature(bpy.data.objects[n]),sort_keys=True)==json.dumps(sig,sort_keys=True) for n,sig in before['rigs'].items())
bpy.context.window.scene=bpy.data.scenes[showcase];bpy.context.scene.frame_set(1)
for ob in bpy.context.view_layer.objects:ob.select_set(False)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.region_3d.view_camera_zoom=0;area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL';area.spaces.active.show_region_ui=False
    if area.type=='DOPESHEET_EDITOR':area.spaces.active.mode='TIMELINE'
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'player_combat_strafe_r14_pass2_study.blend'))
print('R14 PASS2 SAVED',bpy.data.filepath,flush=True)
