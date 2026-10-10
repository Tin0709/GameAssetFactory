"""Three compact jump studies from the user's stationary/walk/run videos.

Additive authoring through the live Blender connection. Existing scenes, rig rest
data, materials and Actions are never rebuilt. No Godot export or modification.
"""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Euler, Matrix, Vector

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
CONFIGS={
 'stationary':dict(label='Jump / Stationary V002',action='Jump_Stationary_v002',end=27,take=5,land=21,height=.58,speed=0,scale=3.9),
 'walk':dict(label='Jump / Walking V002',action='Jump_Walk_v002',end=29,take=7,land=23,height=.58,speed=2.0,scale=4.8,
             pre=[-28,14,34,-18],post=[18,-32,-18,30]),
 'run':dict(label='Jump / Running V002',action='Jump_Run_v002',end=27,take=5,land=21,height=.64,speed=4.0,scale=5.7,
            pre=[-42,22,44,-28],post=[24,-44,-34,42]),
}

def curves(a):return [c for l in a.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]
def sig(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
def point_at(ob,target):ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()

def tables(kind):
    # lean, torso twist, head compensation, lead R / low L, arm R / L, elbows R / L
    if kind=='stationary':return {
      1:[0,0,0,0,0,0,0,0,0],2:[0,0,0,0,0,0,0,0,0],
      3:[6,-1,-2,0,0,-7,-5,5,5],5:[-1,0,0,0,0,8,-4,6,5],
      6:[1,1,-1,10,-4,-2,10,7,8],9:[3,2,-2,22,-8,-10,15,8,10],
      13:[3,2,-2,24,-9,-12,17,8,10],17:[3,1,-2,22,-8,-10,16,8,10],
      19:[2,0,-1,12,-4,-4,11,7,8],21:[3,0,-1,0,0,2,6,5,6],
      23:[10,-1,-4,0,0,-6,-5,12,10],24:[8,-1,-5,0,0,-8,-6,12,10],
      26:[0,0,0,0,0,0,0,0,0],27:[0,0,0,0,0,0,0,0,0]}
    if kind=='walk':return {
      1:[5,0,-2,-28,14,20,-14,6,6],4:[8,-1,-3,3,-2,8,6,8,8],
      7:[5,1,-2,34,-18,-15,22,8,9],8:[6,2,-3,35,-19,-17,24,9,10],
      11:[7,3,-3,36,-20,-18,26,9,10],15:[8,3,-4,38,-20,-20,28,10,11],
      19:[7,2,-3,34,-17,-18,25,9,10],21:[5,1,-2,26,-23,-15,21,8,9],
      23:[6,0,-2,18,-32,-12,17,8,8],25:[12,-1,-5,6,-11,-4,9,12,10],
      27:[8,0,-4,-6,9,8,-4,9,8],29:[5,0,-2,-18,30,20,-18,6,6]}
    return {
      1:[9,1,-4,-42,22,28,-24,12,10],3:[12,-2,-5,1,-3,6,10,14,12],
      5:[8,2,-3,44,-28,-26,32,12,14],6:[9,3,-4,46,-29,-28,34,13,15],
      9:[11,4,-5,50,-31,-30,37,14,16],13:[12,4,-5,52,-32,-32,39,15,17],
      17:[10,3,-4,47,-28,-29,36,14,16],19:[8,1,-3,35,-32,-23,29,13,14],
      21:[9,0,-3,24,-44,-20,25,12,12],23:[16,-2,-7,5,-15,-8,12,17,15],
      25:[12,-1,-6,-15,13,13,-10,14,12],27:[9,1,-4,-34,42,28,-26,12,10]}

def make_camera(sc,name,location,target,scale):
    d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);sc.collection.objects.link(o)
    o.location=location;point_at(o,target);d.type='ORTHO';d.ortho_scale=scale;return o

def make_scene(kind,cfg,idle):
    prefix='JS2_'+kind.upper();name=prefix+'_REVIEW'
    assert not bpy.data.scenes.get(name),'Never overwrite a review scene'
    template=bpy.data.scenes['JUMP_DEFAULT_V001_REVIEW']; sc=bpy.data.scenes.new(name)
    sc.render.engine='CYCLES';sc.cycles.samples=20;sc.cycles.use_denoising=True
    sc.render.resolution_x=960;sc.render.resolution_y=720;sc.render.resolution_percentage=100
    sc.render.fps=30;sc.render.fps_base=1;sc.frame_start=1;sc.frame_end=cfg['end']
    sc.world=template.world;sc.view_settings.view_transform=template.view_settings.view_transform
    sc.view_settings.look=template.view_settings.look;sc.view_settings.exposure=template.view_settings.exposure
    sc.render.use_motion_blur=False;sc.render.image_settings.file_format='PNG'
    actor=bpy.data.collections.new(prefix+'_Actor');sc.collection.children.link(actor)
    carrier=bpy.data.objects.new(prefix+'_PREVIEW_ONLY_Carrier',None);actor.objects.link(carrier)
    carrier.empty_display_type='PLAIN_AXES';carrier.empty_display_size=.15
    carrier['purpose']='Preview world travel and grounded support alignment. Exclude from future pose export.'
    source=bpy.data.objects['JD1_Player_Rig'];body=bpy.data.objects['JD1_Player_Mesh']
    rig=source.copy();rig.data=source.data.copy();rig.name=prefix+'_Rig';actor.objects.link(rig)
    rig.animation_data_clear();rig.parent=carrier;rig.matrix_parent_inverse=Matrix.Identity(4)
    mesh=body.copy();mesh.name=prefix+'_Mesh';actor.objects.link(mesh);mesh.parent=rig
    for m in mesh.modifiers:
        if m.type=='ARMATURE':m.object=rig
    for p in rig.pose.bones:
        base=idle[p.name];p.location=base['location'];p.scale=base['scale'];p.rotation_mode=base['rotation_mode']
        p.rotation_quaternion=base['rotation_quaternion'];p.rotation_euler=base['rotation_euler']
    for o in [rig,mesh]:o.hide_viewport=False;o.hide_render=False
    # Only the floor and three lights are linked/copied from the neutral review.
    stage=bpy.data.collections.new(prefix+'_Stage');sc.collection.children.link(stage)
    for name in ['JD1_FixedFloor','JD1_Key','JD1_Fill','JD1_Rim']:
        old=bpy.data.objects[name];ob=old.copy();ob.name=prefix+'_'+name[4:];stage.objects.link(ob)
    cameras={}
    target=(0,0,1.10)
    for direction,pos in [('THREE_QUARTER',(3,-6,5.2)),('SIDE',(6,0,2.6)),('FRONT',(0,-7,2.8)),('BACK',(0,7,2.8))]:
        cameras[direction]=make_camera(sc,prefix+'_'+direction,pos,target,cfg['scale']).name
    sc['review_cameras']=json.dumps(cameras);sc.camera=bpy.data.objects[cameras['THREE_QUARTER']]
    sc['jump_kind']=kind;sc['jump_rig']=rig.name;sc['jump_carrier']=carrier.name
    sc['jump_status']='New reference-based Blender study; not integrated or artistically approved'
    bpy.context.window.scene=sc;bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    action=bpy.data.actions.new(cfg['action']);action.use_fake_user=True;rig.animation_data_create();rig.animation_data.action=action
    animate_pose(sc,rig,kind,cfg,idle)
    motion=animate_carrier(sc,rig,mesh,carrier,kind,cfg)
    markers={1:'ENTRY / '+('IDLE' if kind=='stationary' else kind.upper()+' STRIDE'),cfg['take']:'LAST SUPPORT',cfg['take']+1:'AIRBORNE',(cfg['take']+cfg['land'])//2:'APEX / HELD STRIDE',cfg['land']:'FIRST CONTACT',cfg['land']+2:'ABSORB',cfg['end']:'RETURN TO '+('IDLE' if kind=='stationary' else 'STRIDE')}
    for f,label in markers.items():sc.timeline_markers.new(label,frame=f)
    sc.frame_set((cfg['take']+cfg['land'])//2)
    return {**cfg,**motion,'kind':kind,'scene':sc.name,'rig':rig.name,'mesh':mesh.name,'carrier':carrier.name,
            'slot':rig.animation_data.action_slot.identifier,'travel_action':carrier.animation_data.action.name,'cameras':cameras,'markers':markers}

def animate_pose(sc,rig,kind,cfg,idle):
    action=rig.animation_data.action
    for c in curves(action):c.keyframe_points.clear()
    for f,values in tables(kind).items():
        lean,twist,head,rleg,lleg,rarm,larm,relbow,lelbow=values
        if kind!='stationary':
            if f<=cfg['take']:
                u=(f-1)/(cfg['take']-1);a,b,c,d=cfg['pre'];rleg=a+(c-a)*u;lleg=b+(d-b)*u
            elif f>=cfg['land']:
                u=(f-cfg['land'])/(cfg['end']-cfg['land']);a,b,c,d=cfg['post'];rleg=a+(c-a)*u;lleg=b+(d-b)*u
        rotations={'Spine':(lean*.35,0,0),'Chest':(lean*.65,twist,0),'Head':(head,-twist*.35,0),
          'Leg.R':(rleg,0,0),'Leg.L':(lleg,0,0),'UpperArm.R':(rarm,0,-3 if f not in [1,cfg['end']] or kind!='stationary' else 0),
          'UpperArm.L':(larm,0,3 if f not in [1,cfg['end']] or kind!='stationary' else 0),
          'ForeArm.R':(relbow,0,0),'ForeArm.L':(lelbow,0,0)}
        # Stationary F2/F26 open/close clearance before rotating limbs.
        if kind=='stationary' and f in [2,26]:rotations={n:(0,0,0) for n in rotations}
        for n,angles in rotations.items():
            p=rig.pose.bones[n];p.location=idle[n]['location'];p.scale=idle[n]['scale']
            if n.startswith('UpperArm') and (kind!='stationary' or 2<=f<=cfg['end']-1):p.location.x += -.008 if n.endswith('.L') else .008
            e=Euler(tuple(math.radians(x) for x in angles),'ZXY' if n.startswith('UpperArm') else 'XYZ')
            if p.rotation_mode=='QUATERNION':p.rotation_quaternion=e.to_quaternion();prop='rotation_quaternion'
            else:p.rotation_euler=e;prop='rotation_euler'
            p.keyframe_insert(prop,frame=f,group=n)
            if n.startswith('UpperArm'):p.keyframe_insert('location',frame=f,group=n)
    for c in curves(action):
        c.extrapolation='CONSTANT'
        for k in c.keyframe_points:
            k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
            if 'Leg.' in c.data_path and (k.co.x<cfg['take'] or k.co.x>=cfg['land']):k.interpolation='LINEAR'

def animate_carrier(sc,rig,mesh,carrier,kind,cfg):
    carrier.animation_data_clear();carrier.location=(0,0,0)
    groups={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups) and abs(v.co.z)<1e-5] for g in mesh.vertex_groups if g.name.startswith('Leg.')}
    samples=[];take=cfg['take'];land=cfg['land'];end=cfg['end'];margin=.0001
    density=64
    for q in range((end-1)*density+1):
        f=1+q/density;sc.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get();e=mesh.evaluated_get(dg)
        points={n:[e.matrix_world@e.data.vertices[i].co for i in ids] for n,ids in groups.items()}
        samples.append({'f':f,'z':-min(p.z for pts in points.values() for p in pts)+margin,
                        'left_y':sum(p.y for p in points['Leg.L'])/4,'right_y':sum(p.y for p in points['Leg.R'])/4})
    first=samples[0];launch=samples[(take-1)*density];contact=samples[(land-1)*density];last=samples[-1]
    flight_distance=cfg['speed']*(land-take)/30
    pre_distance=launch['left_y']-first['left_y'] if kind!='stationary' else 0
    post_distance=last['right_y']-contact['right_y'] if kind!='stationary' else 0
    distance=pre_distance+flight_distance+post_distance;start_y=distance/2
    launch_y=start_y-pre_distance;contact_y=launch_y-flight_distance
    name='PREVIEW_ONLY_'+cfg['action']+'_Travel'
    action=bpy.data.actions.get(name) or bpy.data.actions.new(name);action.use_fake_user=True
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in list(bag.fcurves):bag.fcurves.remove(curve)
    carrier.animation_data_create();carrier.animation_data.action=action
    for s in samples:
        f=s['f']
        if kind=='stationary':y=0
        elif f<=take:y=start_y+first['left_y']-s['left_y']
        elif f>=land:y=contact_y+contact['right_y']-s['right_y']
        else:y=launch_y-flight_distance*(f-take)/(land-take)
        if take<f<land:
            u=(f-take)/(land-take);z=(1-u)*launch['z']+u*contact['z']+4*cfg['height']*u*(1-u)
        else:z=s['z']
        carrier.location=(0,y,z);carrier.keyframe_insert('location',index=1,frame=f,group='PREVIEW ONLY')
        carrier.keyframe_insert('location',index=2,frame=f,group='PREVIEW ONLY')
    for c in curves(action):
        c.extrapolation='CONSTANT'
        for k in c.keyframe_points:k.interpolation='LINEAR'
    return {'travel_distance_m':distance,'flight_distance_m':flight_distance,'ground_contact_margin_m':margin,
            'launch_carrier_z':launch['z'],'contact_carrier_z':contact['z'],'carrier_sample_step':1/density}

def build():
    if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    assert bpy.context.mode=='OBJECT'
    idle=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
    source_hashes={a.name:sig(a) for a in bpy.data.actions}
    scenes_before={s.name:[s.render.fps,s.render.fps_base,s.frame_start,s.frame_end] for s in bpy.data.scenes}
    cases={k:make_scene(k,c,idle) for k,c in CONFIGS.items()}
    assert all(sig(bpy.data.actions[n])==h for n,h in source_hashes.items())
    manifest={'cases':cases,'fps':30,'height_H':1.8,'source_rig':'JD1_Player_Rig','source_mesh':'JD1_Player_Mesh',
              'preserved_action_hashes':source_hashes,'old_scene_timing':scenes_before,
              'scope':'Three new Blender-only Actions plus separate preview carriers; preserve current game and every previous Action',
              'status':'Awaiting user review; not measured Minecraft physics; not exported to runtime'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    bpy.context.window.scene=bpy.data.scenes[cases['stationary']['scene']]
    bpy.context.scene.frame_set(13)
    bpy.ops.ed.undo_push(message='Add stationary, walking and running jump studies')
    return {k:{n:v for n,v in c.items() if n in ['action','scene','end','travel_distance_m']} for k,c in cases.items()}

if __name__=='__main__':result=build()
