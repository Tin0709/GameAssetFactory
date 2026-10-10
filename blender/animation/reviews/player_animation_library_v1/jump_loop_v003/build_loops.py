"""Continuous walk/run footwork; additive Blender studies, no runtime writes."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
TAU=2*math.pi
CONFIGS={
 'walk':dict(period=28,take=6,land=22,height=.50,speed=1.45,source='PREVIEW_ONLY_R9W4_Walk_LOWER',source_period=16,leg_gain=.70,leg_bias=10,lean=5,arm_gain=.65),
 'run':dict(period=26,take=4,land=20,height=.58,speed=2.50,source='PREVIEW_ONLY_R9W4_Sprint_LOWER',source_period=13,leg_gain=.65,leg_bias=13,lean=10,arm_gain=.78)}
def curves(a):return [c for l in a.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]
def sig(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
def periodic_fit(curve,period):
    # Periodic band-limited copy of existing gait. Never edit source keys.
    count=256;ys=[curve.evaluate(1+period*i/count) for i in range(count)]
    mean=sum(ys)/count
    harmonics=[(2*sum(y*math.cos(TAU*k*i/count) for i,y in enumerate(ys))/count,
                2*sum(y*math.sin(TAU*k*i/count) for i,y in enumerate(ys))/count) for k in range(1,7)]
    return lambda p:mean+sum(a*math.cos(TAU*k*p)+b*math.sin(TAU*k*p) for k,(a,b) in enumerate(harmonics,1))
def make_channel(action,rig,path,index,samples,values,derivatives):
    rig.path_resolve(path)[index]=values[0];rig.keyframe_insert(path,index=index,frame=samples[0])
    c=next(c for c in curves(action) if c.data_path==path and c.array_index==index)
    c.keyframe_points.clear();c.keyframe_points.add(len(samples))
    for k,f,v,d in zip(c.keyframe_points,samples,values,derivatives):
        k.co=(f,v);k.interpolation='BEZIER';k.handle_left_type='FREE';k.handle_right_type='FREE'
        h=(samples[1]-samples[0])/3;k.handle_left=(f-h,v-d*h);k.handle_right=(f+h,v+d*h)
    c.update();c.modifiers.new('CYCLES');return c
def pose_values(t,cfg,fits):
    p=(t/cfg['period'])%1;get=lambda n,prop,i:fits.get((n,prop,i),lambda p:0)(p)
    # Full stride continues during ascent and descent. No held-leg interval.
    r=cfg['leg_gain']*get('Leg.R','rotation_euler',0)+math.radians(cfg['leg_bias'])
    l=cfg['leg_gain']*get('Leg.L','rotation_euler',0)+math.radians(cfg['leg_bias'])
    impact=math.exp(-((math.sin(math.pi*(t-cfg['land']-1.0)/cfg['period']))/.21)**2)
    lean=math.radians(cfg['lean']+3.0*impact)
    sway=.015*math.sin(TAU*p)
    vals={('Spine','rotation_euler',0):lean*.35,('Chest','rotation_euler',0):lean*.65,
          ('Chest','rotation_euler',1):math.radians(1.6)*math.sin(TAU*p),
          ('Head','rotation_euler',0):-lean*.45,('Head','rotation_euler',1):-math.radians(.5)*math.sin(TAU*p),
          ('Hips','location',0):sway,
          ('Leg.R','rotation_euler',0):r,('Leg.L','rotation_euler',0):l,
          ('Leg.R','rotation_euler',2):0,('Leg.L','rotation_euler',2):0}
    for side,angle in [('R',r),('L',l)]:
        arm=-cfg['arm_gain']*angle
        vals[('UpperArm.'+side,'rotation_euler',0)]=arm
        vals[('UpperArm.'+side,'rotation_euler',2)]=math.radians(-3 if side=='R' else 3)
        vals[('UpperArm.'+side,'location',0)]=(-.024 if side=='R' else .024)
        vals[('ForeArm.'+side,'rotation_euler',0)]=math.radians(9 if cfg['lean']<8 else 15)+.18*math.sqrt(arm*arm+.001)
        # Keep the original gait's subtle rigid-leg lift/return, at half amplitude.
        vals[('Leg.'+side,'location',1)]=.5*get('Leg.'+side,'location',1)
        vals[('Leg.'+side,'location',2)]=.5*get('Leg.'+side,'location',2)
    return vals
def make_scene(kind,cfg):
    prefix='JL3_'+kind.upper();sc=bpy.data.scenes.new(prefix+'_REVIEW');template=bpy.data.scenes['JUMP_DEFAULT_V001_REVIEW']
    sc.render.engine='CYCLES';sc.cycles.samples=16;sc.cycles.use_denoising=True
    sc.render.resolution_x=720;sc.render.resolution_y=540;sc.render.resolution_percentage=100
    sc.render.fps=30;sc.frame_start=1;sc.frame_end=cfg['period']*3;sc.world=template.world
    sc.view_settings.view_transform=template.view_settings.view_transform;sc.view_settings.look=template.view_settings.look
    sc.view_settings.exposure=template.view_settings.exposure;sc.render.image_settings.file_format='PNG'
    sc['jump_status']='Continuous Blender loop study; awaiting review; no runtime export'
    carrier=bpy.data.objects.new(prefix+'_PREVIEW_ONLY_Carrier',None);sc.collection.objects.link(carrier)
    source=bpy.data.objects['JD1_Player_Rig'];rig=source.copy();rig.data=source.data.copy();rig.name=prefix+'_Rig'
    sc.collection.objects.link(rig);rig.animation_data_clear();rig.parent=carrier;rig.matrix_parent_inverse=Matrix.Identity(4)
    idle=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
    for pb in rig.pose.bones:
        b=idle[pb.name];pb.location=b['location'];pb.rotation_mode='XYZ';pb.rotation_euler=b['rotation_euler'];pb.scale=(1,1,1)
    body=bpy.data.objects['JD1_Player_Mesh'].copy();body.name=prefix+'_Mesh';body.parent=rig;sc.collection.objects.link(body)
    for md in body.modifiers:
        if md.type=='ARMATURE':md.object=rig
    for ob in [rig,body]:ob.hide_viewport=False;ob.hide_render=False
    for suffix in ['FixedFloor','Key','Fill','Rim']:
        ob=bpy.data.objects['JD1_'+suffix].copy();ob.name=prefix+'_'+suffix;sc.collection.objects.link(ob)
        if suffix!='FixedFloor':
            follow=ob.constraints.new('COPY_LOCATION');follow.name='Preview_Follow_Y';follow.target=carrier
            follow.use_x=False;follow.use_z=False;follow.use_offset=True
    cameras={}
    for label,xyz in [('THREE_QUARTER',(3,-6,4.6)),('SIDE',(6,0,2.6)),('FRONT',(0,-7,2.8)),('BACK',(0,7,2.8))]:
        dat=bpy.data.cameras.new(prefix+'_'+label);cam=bpy.data.objects.new(dat.name,dat);sc.collection.objects.link(cam)
        cam.location=xyz;cam.rotation_euler=(Vector((0,0,1.15))-cam.location).to_track_quat('-Z','Y').to_euler()
        dat.type='ORTHO';dat.ortho_scale=4.2
        constraint=cam.constraints.new('COPY_LOCATION');constraint.target=carrier;constraint.use_x=False;constraint.use_z=False;constraint.use_offset=True
        cameras[label]=cam.name
    sc.camera=bpy.data.objects[cameras['THREE_QUARTER']];sc['review_cameras']=json.dumps(cameras)
    bpy.context.window.scene=sc;bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    action=bpy.data.actions.new('Jump_'+('Walk' if kind=='walk' else 'Run')+'_Loop_v003');action.use_fake_user=True
    rig.animation_data_create();rig.animation_data.action=action
    fits={}
    import re
    for curve in curves(bpy.data.actions[cfg['source']]):
        match=re.fullmatch(r'pose\.bones\["([^"]+)"\]\.(\w+)',curve.data_path)
        if match:fits[(match[1],match[2],curve.array_index)]=periodic_fit(curve,cfg['source_period'])
    samples=[1+i*.25 for i in range(cfg['period']*4+1)];keys=pose_values(0,cfg,fits)
    for bone,prop,index in keys:
        key=(bone,prop,index);fn=lambda t:pose_values(t,cfg,fits)[key]
        vals=[fn(f-1) for f in samples];ds=[(fn(f-1+.0001)-fn(f-1-.0001))/.0002 for f in samples]
        make_channel(action,rig,f'pose.bones["{bone}"].{prop}',index,samples,vals,ds)
    source_sole=[v.index for v in body.data.vertices if abs(v.co.z)<1e-6]
    ground=[];density=32
    for i in range(cfg['period']*density+1):
        t=i/density;sc.frame_set(1+int(t),subframe=t%1);bpy.context.view_layer.update()
        ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());zs=[(ev.matrix_world@ev.data.vertices[v].co).z for v in source_sole]
        lowest=min(zs);beta=700
        support=-lowest+(math.log(sum(math.exp(-beta*(z-lowest)) for z in zs))-math.log(2))/beta+.0003
        u=(t-cfg['take'])/(cfg['land']-cfg['take'])
        arc=4*cfg['height']*u*(1-u) if 0<u<1 else 0
        ground.append((t,support,arc))
    travel=bpy.data.actions.new('PREVIEW_ONLY_'+action.name+'_Travel');travel.use_fake_user=True
    carrier.animation_data_create();carrier.animation_data.action=travel
    for t,support,arc in ground:
        carrier.location=(0,-cfg['speed']*t/30,support+arc)
        carrier.keyframe_insert('location',index=1,frame=1+t);carrier.keyframe_insert('location',index=2,frame=1+t)
    for curve in curves(travel):
        for key in curve.keyframe_points:key.interpolation='LINEAR'
        modifier=curve.modifiers.new('CYCLES')
        if curve.array_index==1:modifier.mode_before='REPEAT_OFFSET';modifier.mode_after='REPEAT_OFFSET'
    for cycle in range(3):
        for t,label in [(0,'LOOP JOIN'),(cfg['take'],'PUSH'),((cfg['take']+cfg['land'])//2,'STEP THROUGH AIR'),(cfg['land'],'CONTACT')]:
            sc.timeline_markers.new(f'{cycle+1}: {label}',frame=1+cycle*cfg['period']+t)
    sc.frame_set(1)
    c={**cfg,'kind':kind,'scene':sc.name,'rig':rig.name,'mesh':body.name,'carrier':carrier.name,'action':action.name,
       'slot':rig.animation_data.action_slot.identifier,'travel_action':travel.name,'cameras':cameras,
       'closing_key':cfg['period']+1,'preview_end':cfg['period']*3,'support_sample_step':1/density}
    return c
def build():
    assert not any(bpy.data.scenes.get('JL3_'+k.upper()+'_REVIEW') for k in CONFIGS),'Never replace prior studies'
    old={a.name:sig(a) for a in bpy.data.actions};timing={s.name:[s.render.fps,s.render.fps_base,s.frame_start,s.frame_end] for s in bpy.data.scenes}
    cases={kind:make_scene(kind,cfg) for kind,cfg in CONFIGS.items()}
    assert all(sig(bpy.data.actions[n])==h for n,h in old.items())
    manifest={'cases':cases,'fps':30,'previous_action_hashes':old,'previous_scene_timing':timing,
       'status':'Blender-only continuous loops; not artistically approved or integrated into runtime',
       'export_contract':'Pose closes at P+1, loop duration P/30. Do not duplicate closing sample on replay. Preserve phase. Carrier Z support/arc and Y travel are preview-only.'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));return cases
if __name__=='__main__':
    result=build()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'.validation/jump_loop_v003/draft.blend'))
