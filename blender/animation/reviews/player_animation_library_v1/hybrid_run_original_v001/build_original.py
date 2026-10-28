import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Euler
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(HERE));sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import motion as m
import gaf_animation_library as ui
m.verify()
CENTRAL=ROOT/'blender/animation/showcase/Animation_Showcase.blend'
SOURCE=HERE/'hybrid_run_authoring.blend'
assert not SOURCE.exists() or '--refine-draft' in sys.argv,'Do not overwrite an authored revision'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(str(CENTRAL),link=False) as (src,dst):dst.objects=['Showcase_Player_Rig','Showcase_Player_Mesh']
rig,mesh=dst.objects
bpy.context.scene.collection.objects.link(rig);bpy.context.scene.collection.objects.link(mesh)
rig.name='HybridRun_Authoring_Rig';mesh.name='HybridRun_Authoring_Mesh'
rig.animation_data_clear();rig.matrix_world=Matrix.Identity(4)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
assert ui.rest_signature(rig.data)==json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())['rig_sha256']
rests={b.name:b.bone.matrix_local.copy()for b in rig.pose.bones}
points={}
for name in ['Leg.L','Leg.R']:
    idx=mesh.vertex_groups[name].index
    points[name]=[v.co-rests[name].translation for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
    assert len(points[name])==8

def rotate(x=0,y=0,z=0):return Euler((x,y,z),'XYZ').to_matrix().to_4x4()
def pose(p,variant):
    _,amplitude,torso,arms,head=variant
    wave=2*math.pi*p;global_poses={}
    for bone in rig.pose.bones:
        name=bone.name;parent=bone.parent.name if bone.parent else None
        rest=rests[name];relative=rests[parent].inverted()@rest if parent else rest
        default=global_poses[parent]@relative if parent else rest.copy()
        pivot=default.translation.copy();R=None
        if name=='Hips':
            pivot.x=.004*(amplitude/.045)*math.sin(wave+.3)
            pivot.z=.635+amplitude*.5*m.bounce(p)
        elif name in ['Spine','Chest']:
            R=rotate(math.radians(8 if name=='Spine' else 6),math.radians(torso*.18)*math.sin(wave+.2),math.radians(torso)*math.sin(wave-.22))
        elif name=='Head':
            R=rotate(math.radians(head)*math.sin(2*wave-.28),math.radians(head*.45)*math.sin(wave+.4),math.radians(head*.4)*math.sin(wave-.2))
        elif name.startswith('UpperArm.'):
            side=1 if name.endswith('L') else -1
            pitch=side*math.radians(arms)*(math.sin(wave+.15)+.12*math.sin(2*wave-.25))/1.12
            R=rotate(pitch,-side*math.radians(4),side*math.radians(2)*math.sin(wave+.1))
        elif name in points:
            phase=p if name.endswith('L') else (p+.5)%1
            theta,clearance,plant,corner=m.leg(phase)
            R=rotate(theta)
            pivot.x=rest.translation.x;pivot.y=0.
            minimum=min((R.to_3x3()@v).z for v in points[name])
            support_height=clearance-minimum+.00025
            pivot.z=support_height if plant else max(global_poses['Hips'].translation.z,support_height)
        target=Matrix.Translation(pivot)@(R@rest.to_3x3().to_4x4() if R is not None else default.to_3x3().to_4x4())
        if name=='Root':target=rest.copy()
        global_poses[name]=target
        basis=relative.inverted()@(global_poses[parent].inverted()@target if parent else target)
        bone.matrix_basis=basis;bone.scale=(1,1,1)
    return global_poses

actions=[]
for variant in m.VARIANTS:
    name='Run_Hybrid_'+variant[0]+'_Original_v001'
    action=bpy.data.actions.new(name);action.use_fake_user=True
    slot=action.slots.new(id_type='OBJECT',name=rig.name)
    layer=action.layers.new('Original authored pose');strip=layer.strips.new(type='KEYFRAME');bag=strip.channelbags.new(slot)
    values={}
    for j in range(2049):
        frame=1+j/16;p=((frame-1)/m.FRAMES+m.ORIGIN)%1
        pose(p,variant)
        for bone in rig.pose.bones:
            rotation='rotation_euler' if bone.rotation_mode!='QUATERNION' else 'rotation_quaternion'
            for prop in ['location',rotation,'scale']:
                for axis,value in enumerate(getattr(bone,prop)):
                    values.setdefault((bone.path_from_id(prop),axis),[]).extend((frame,value))
    for (path,axis),coords in values.items():
        c=bag.fcurves.new(path,index=axis);c.keyframe_points.add(len(coords)//2);c.keyframe_points.foreach_set('co',coords)
        for key in c.keyframe_points:key.interpolation='LINEAR'
        c.update()
    action['original_authored']=True;action['gait_hz']=m.HZ;action['status']='pending';action['source_keyframes_copied']=False
    actions.append(action)
    print('AUTHORED',name,flush=True)
rig.animation_data_create();rig.animation_data.action=actions[1];rig.animation_data.action_slot=actions[1].slots[0]
scene=bpy.context.scene;scene.name='HYBRID_RUN_AUTHORING';scene.frame_start=1;scene.frame_end=128;scene.render.fps=m.FPS;scene.render.fps_base=m.FPS_BASE;scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))

# Measure the actually keyed rig, not just the generating equations.
metrics=[]
for action,variant in zip(actions,m.VARIANTS):
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    hips=[];angles=[];heads=[];penetrations=[];contacts=[];scales=[];extensions=[]
    for j in range(1025):
        frame=1+32*j/1024;scene.frame_set(int(frame),subframe=frame%1)
        p=((frame-1)/32+m.ORIGIN)%1;time=(frame-1)/32/m.HZ
        hips.append(rig.pose.bones['Hips'].matrix.translation.z)
        body=rig.pose.bones['Chest'].matrix.to_3x3()@rests['Chest'].to_3x3().inverted();angles.append(math.degrees(body.to_euler('XYZ').z))
        head=rig.pose.bones['Head'].matrix.to_3x3()@rests['Head'].to_3x3().inverted();heads.append([math.degrees(v) for v in head.to_euler('XYZ')])
        for bone in rig.pose.bones:scales.append(max(abs(v-1) for v in bone.scale))
        for name in points:
            theta,height,plant,corner=m.leg(p if name.endswith('L') else (p+.5)%1)
            world=rig.pose.bones[name].matrix@rests[name].inverted()
            actual=[world@(v+rests[name].translation)for v in points[name]]
            penetrations.append(max(0,-min(v.z for v in actual)))
            extensions.append(rig.pose.bones[name].matrix.translation.z-rig.pose.bones['Hips'].matrix.translation.z)
            if plant:
                edge=[v for v in points[name] if abs(v.z+.675)<1e-5 and abs(v.y-corner)<1e-5]
                assert len(edge)==2
                pt=sum((world@(v+rests[name].translation)for v in edge),Vector())/2
                contacts.append({'bone':name,'corner':corner,'time':time,'point':[pt.x,pt.y-7*time,pt.z]})
    speeds=[]
    for name in points:
        rows=[v for v in contacts if v['bone']==name]
        for a,b in zip(rows,rows[1:]):
            if b['time']-a['time']<.001 and a['corner']==b['corner']:
                speeds.append((Vector(b['point'])-Vector(a['point'])).length/(b['time']-a['time']))
    result={'action':action.name,'hip_bounce_mm':(max(hips)-min(hips))*1000,'torso_yaw_peak_to_peak_deg':max(angles)-min(angles),'head_world_relative_rest_peak_abs_deg':[max(abs(h[i])for h in heads)for i in range(3)],'rolling_contact_samples':len(speeds),'rolling_contact_speed_rms_m_s':math.sqrt(sum(v*v for v in speeds)/len(speeds)),'rolling_contact_speed_max_m_s':max(speeds),'max_floor_penetration_mm':max(penetrations)*1000,'max_scale_error':max(scales),'leg_pivot_offset_z_m':[min(extensions),max(extensions)],'gait_hz':m.HZ,'stance_fraction_original':m.DUTY,'phase_origin':m.ORIGIN,'root_world_travel_m':0}
    assert max(penetrations)<.001 and max(speeds)<.05 and max(scales)<1e-6,result
    assert abs(result['hip_bounce_mm']-variant[1]*1000)<.1,result
    metrics.append(result);print('MEASURED',json.dumps(result),flush=True)
(HERE/'measurements.json').write_text(json.dumps({'scope':'Actually evaluated source study; rolling-edge stance schedule is original, not recovered native MD2 contacts. Virtual travel7m/s, in-place rig root. No terrain IK.','metrics':metrics},indent=2))
(HERE/'source_metadata.json').write_text(json.dumps({'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'actions':[a.name for a in actions],'rig':rig.name,'mesh':mesh.name,'armature':rig.data.name,'fps':m.FPS,'fps_base':m.FPS_BASE},indent=2))
