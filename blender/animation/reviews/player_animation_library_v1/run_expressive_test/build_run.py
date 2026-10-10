"""Original rigid-block run study, separate from approved arm/source libraries."""
import bpy,json,math,runpy,hashlib
from pathlib import Path
from mathutils import Euler,Matrix,Vector
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
TMP=ROOT/'.validation/run_expressive_test'
H=runpy.run_path(str(OUT.parent/'jump_dungeons_gif_v004/build_jump.py'))
P=18; FPS=30; DUTY=.34; L=.675; D=.1125; ANGLE=25

def hermite(x,a,b,va=0,vb=0):
    return (2*x**3-3*x*x+1)*a+(x**3-2*x*x+x)*va+(-2*x**3+3*x*x)*b+(x**3-x*x)*vb

def spline(x,keys):
    for (ta,a,va),(tb,b,vb) in zip(keys,keys[1:]):
        if ta<=x<=tb:return hermite((x-ta)/(tb-ta),a,b,va*(tb-ta),vb*(tb-ta))
    return keys[-1][1]

def corner_y(theta):
    a=math.radians(theta)
    return -L*math.sin(a)+(D if theta>=0 else -D)*math.cos(a)

DIST=2*(D-corner_y(ANGLE)); SPEED=DIST/(DUTY*P/FPS)

def leg_angle(u):
    u%=1
    if u<=DUTY:
        t=u/DUTY
        target=corner_y(ANGLE)+DIST*t-(2*D if t>.5 else 0)
        low,high=(-ANGLE,0) if t>.5 else (0,ANGLE)
        for _ in range(35):
            mid=(low+high)/2
            if corner_y(mid)>target:low=mid
            else:high=mid
        return (low+high)/2
    # A quick backward release, then recovery through a lifted passing pose.
    v=-math.degrees(DIST/DUTY/(L*math.cos(math.radians(ANGLE))+D*math.sin(math.radians(ANGLE))))
    return spline(u,[(DUTY,-ANGLE,v),(.43,-58,0),(.72,4,310),(.91,46,0),(1,ANGLE,v)])

def radius(theta):
    a=math.radians(theta);return L*math.cos(a)+D*abs(math.sin(a))

def compression(u):
    return spline(u/DUTY,[(0,.015,.12),(.24,.055,0),(.62,.039,-.05),(1,0,-.22)])

def stance_height(u):return radius(leg_angle(u))-compression(u)

def height(u):
    h=u%.5
    if h<=DUTY:return stance_height(h)
    a,b=stance_height(DUTY),stance_height(0)
    eps=1e-5;va=(stance_height(DUTY)-stance_height(DUTY-eps))/eps;vb=(stance_height(eps)-stance_height(0))/eps
    t=(h-DUTY)/(.5-DUTY)
    return hermite(t,a,b,va*(.5-DUTY),vb*(.5-DUTY))+.070*math.sin(math.pi*t)**2

def sample(u):
    u%=1;z=height(u);w=2*math.pi*u
    angles={};lifts={}
    for side,offset in [('R',0),('L',.5)]:
        q=(u+offset)%1;theta=leg_angle(q);angles['Leg.'+side]=(theta,0,0)
        if q<=DUTY:lift=compression(q)
        else:
            # Small whole-leg retraction hidden inside the torso; no stretch/IK.
            gap=z-radius(theta)
            ease=lambda x:(lambda t:t*t*(3-2*t))(max(0,min(1,x)))
            clearance=.035*ease((q-DUTY)/.08)*ease((1-q)/.06)
            lift=max(0,clearance-gap)
        lifts[side]=lift
        phase=w+(0 if side=='R' else math.pi)-.13
        pitch=7-(62 if side=='R' else 59)*math.cos(phase)
        spread=(14+17*abs(math.cos(phase))) * (-1 if side=='R' else 1)
        angles['UpperArm.'+side]=(pitch,0,spread)
    angles['Spine']=(4+1.1*math.sin(2*w-.4),1.5*math.cos(w),0)
    angles['Chest']=(5+1.5*math.sin(2*w-.65),4.5*math.cos(w-.12),.7*math.sin(w))
    angles['Head']=(-7-1.4*math.sin(2*w-.95),-4.3*math.cos(w-.3),-.4*math.sin(w-.2))
    return angles,z,lifts

def make_actor(scene,source,body,name,clear=True):
    r=source.copy();r.data=source.data.copy();r.name=name+'_Rig';r.data.name=name+'_RestRig'
    if clear:r.animation_data_clear()
    r.parent=None;r.matrix_world=Matrix.Identity(4);scene.collection.objects.link(r)
    m=body.copy();m.name=name+'_Mesh';m.parent=r;scene.collection.objects.link(m)
    for mod in m.modifiers:
        if mod.type=='ARMATURE':mod.object=r
    for o in [r,m]:o.hide_render=o.hide_viewport=False
    return r,m

def build():
    assert bpy.context.mode=='OBJECT' and 'Run_Expressive_Test' not in bpy.data.actions
    assert (TMP/'live_before_run.blend').exists()
    template=bpy.data.scenes['EXPRESSIVE_ARM_MOTION_REVIEW']
    scene=bpy.data.scenes.new('RUN_EXPRESSIVE_REVIEW')
    scene.world=template.world;scene.render.engine='CYCLES';scene.cycles.device='GPU';scene.cycles.samples=16
    scene.cycles.use_denoising=True;scene.render.resolution_x=scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.fps=FPS;scene.frame_start=1;scene.frame_end=P
    scene.render.image_settings.file_format='PNG';scene.render.use_motion_blur=False
    for k in ['view_transform','look','exposure','gamma']:setattr(scene.view_settings,k,getattr(template.view_settings,k))
    r,m=make_actor(scene,bpy.data.objects['EAM_Player_Rig'],bpy.data.objects['EAM_Player_Mesh'],'RUN_Test')
    idle=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
    for b in r.pose.bones:
        for k,v in idle[b.name].items():setattr(b,k,v)
    for suffix in ['FixedFloor','Key','Fill','Rim']:
        o=bpy.data.objects['EAM_'+suffix].copy();o.name='RUN_'+suffix;scene.collection.objects.link(o)
    for name,loc in [('FRONT',(0,-7,2.2)),('THREE_QUARTER',(3,-6,3)),('SIDE',(7,0,1.9))]:
        d=bpy.data.cameras.new('RUN_'+name);d.type='ORTHO';d.ortho_scale=2.8
        o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=loc
        o.rotation_euler=(Vector((0,0,.95))-o.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=bpy.data.objects['RUN_THREE_QUARTER'];bpy.context.window.scene=scene
    # Unmodified prior NLA/Action compositions, on isolated duplicates for A/B.
    for tag in ['Walk','Sprint']:
        old=bpy.data.objects['LIB_'+tag+'_Unarmed_R12_'+tag+'_Unarmed_Rig']
        body=next(o for o in old.children if o.type=='MESH' and len(o.data.vertices)==64)
        br,bm=make_actor(scene,old,body,'RUN_Baseline_'+tag,False)
        br.hide_render=bm.hide_render=True
    a=bpy.data.actions.new('Run_Expressive_Test');a.use_fake_user=True;r.animation_data_create();r.animation_data.action=a
    animate(r,a,idle)
    for f,label in [(1,'RIGHT CONTACT'),(4,'PASSING / SUPPORT'),(8,'FLIGHT / SPLIT'),(10,'LEFT CONTACT'),(13,'PASSING / SUPPORT'),(17,'FLIGHT / SPLIT'),(19,'CLOSING KEY / NOT PLAYED')]:scene.timeline_markers.new(label,frame=f)
    scene['purpose']='Original in-place run test / Blender only / pending review'
    scene['cycle_frames']=P;scene['diagnostic_travel_speed_m_s']=SPEED
    scene.frame_set(1);bpy.context.view_layer.objects.active=r;r.select_set(True)
    manifest={'action':a.name,'scene':scene.name,'period_frames':P,'closing_frame':P+1,'fps':FPS,'duty_each_leg':DUTY,'diagnostic_speed_m_s':SPEED,'source':json.loads((TMP/'backup_manifest.json').read_text()),'rig_changes':[],'status':'Run test pending user review; arm proof explicitly approved','lower_body':'Rigid whole-leg support rotation plus bounded translation into torso; no knee/ankle or scale changes'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    return manifest

def animate(r,a,idle):
    # Dense periodic samples bake authoring calculations into plain bone tracks.
    for layer in list(a.layers):a.layers.remove(layer)
    for j in range(P*8+1):
        f=1+j/8;angles,z,lifts=sample((f-1)/P)
        for b in r.pose.bones:
            for k,v in idle[b.name].items():setattr(b,k,v)
            deg=angles.get(b.name,(0,0,0));e=Euler(tuple(math.radians(x) for x in deg),'ZXY' if 'UpperArm' in b.name else 'XYZ')
            prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
            setattr(b,prop,e.to_quaternion() if prop=='rotation_quaternion' else e)
            b.keyframe_insert(prop,frame=f,group=b.name)
            if b.name=='Hips':b.location += b.bone.matrix_local.to_3x3().inverted()@Vector((0,0,z-L+.0004))
            if b.name.startswith('Leg.'):
                b.location += b.bone.matrix_local.to_3x3().inverted()@Vector((0,0,lifts[b.name[-1]]))
            b.keyframe_insert('location',frame=f,group=b.name)
    for c in H['curves'](a):
        keys=c.keyframe_points;count=len(keys)-1;step=.125
        for i,k in enumerate(keys):
            slope=(keys[(i+1)%count].co.y-keys[(i-1)%count].co.y)/(2*step)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-step/3,k.co.y-slope*step/3)
            k.handle_right=(k.co.x+step/3,k.co.y+slope*step/3)
        mod=c.modifiers.new('CYCLES');mod.mode_before=mod.mode_after='REPEAT'

def render(view,start,end,variant='test',native=False):
    s=bpy.data.scenes['RUN_EXPRESSIVE_REVIEW'];bpy.context.window.scene=s
    s.camera=bpy.data.objects['RUN_'+view]
    for tag in ['Test','Baseline_Walk','Baseline_Sprint']:
        show=tag==({'test':'Test','walk':'Baseline_Walk','sprint':'Baseline_Sprint'}[variant])
        for suffix in ['Rig','Mesh']:bpy.data.objects['RUN_'+tag+'_'+suffix].hide_render=not show
    p=OUT/'frames'/variant/view.lower();p.mkdir(parents=True,exist_ok=True)
    for f in range(start,end+1):
        sf=f if variant=='test' or native else 1+((f-1)/FPS*24)%(16 if variant=='walk' else 13)
        s.frame_set(int(sf),subframe=sf%1);s.render.filepath=str(p/f'{f:03d}.png')
        bpy.ops.render.render(write_still=True,scene=s.name)
    return {'variant':variant,'view':view,'frames':[start,end]}
