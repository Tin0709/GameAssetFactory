"""Validate E1 and build a separate, baked COMPARISON file; never bake Run into Ready."""
import bpy, json, math, hashlib
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion
BASE = Path(__file__).resolve().parent
src = (BASE / 'create_ready_e1.py').read_text()
exec(src[:src.index("assert 'LongGunReady_Loop_V1' not in")])
new = bpy.data.actions['LongGunReady_Loop_V1']
hold = bpy.data.actions['LongGunHold_V2']
protected = json.loads((BASE / 'ready_e1_protection.json').read_text())
assert all(digest(bpy.data.actions[n]) == h for n,h in protected['actions'].items())
assert geometry() == protected['geometry']
assert json.dumps(bones(),sort_keys=True) == json.dumps(protected['bones'],sort_keys=True)
hold_path = BASE.parents[3] / 'game_mobile_3d/assets/characters/LongGunHold_V2.tres'
assert hashlib.sha256(hold_path.read_bytes()).hexdigest() == protected['hold_resource_sha256']

def error(a,b): return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))

first = sample(new,1); last = sample(new,33)
seam = max(error(first[n],last[n]) for n in UPPER)
assert seam < 2e-6
endpoint = sample(bpy.data.actions['Draw_LongGun_V3_Final'],14)
draw_error = max(error(first[n],endpoint[n]) for n in UPPER)
endpoint = sample(bpy.data.actions['Holster_LongGun_V3_Final'],1)
holster_error = max(error(first[n],endpoint[n]) for n in UPPER)
assert max(draw_error,holster_error) < 2e-6
lower_keys = {n:sum(len(c.keyframe_points) for c in curves(new) if c.data_path.startswith('pose.bones["'+n+'"]')) for n in LOWER}
assert not any(lower_keys.values())
assert not any(c.data_path.endswith('scale') for c in curves(new))
assert all(abs(c.keyframe_points[0].handle_right.y-c.keyframe_points[0].co.y)<1e-9 and
           abs(c.keyframe_points[-1].handle_left.y-c.keyframe_points[-1].co.y)<1e-9 for c in curves(new))

reference = sample(hold,1)
reference_world = {n:rig.pose.bones[n].matrix.copy() for n in UPPER}
ranges = {}; relations = {n:reference_world['WeaponCarrier'].inverted()@reference_world[n] for n in ['Arm.R','Arm.L']}
grip_error = 0.; motion = {n:[] for n in UPPER}; holster_phase_error = {n:0. for n in UPPER}
for i in range(257):
    pose = sample(new,1+i/8)
    for n in UPPER:
        m = rig.pose.bones[n].matrix.copy(); d = reference_world[n].inverted()@m
        motion[n].append({'degrees':math.degrees(d.to_quaternion().angle), 'position':list(m.translation-reference_world[n].translation)})
        holster_phase_error[n] = max(holster_phase_error[n],error(pose[n],reference[n]))
    for n in relations:
        grip_error = max(grip_error,error(rig.pose.bones['WeaponCarrier'].matrix.inverted()@rig.pose.bones[n].matrix,relations[n]))
for n in ['Chest','Spine','Neck','Head','Arm.R','Arm.L']:
    ranges[n] = {str(c.array_index):[math.degrees(min(c.evaluate(1+i/8) for i in range(257))),
        math.degrees(max(c.evaluate(1+i/8) for i in range(257)))] for c in curves(new)
        if c.data_path == 'pose.bones["'+n+'"].rotation_euler'}
assert grip_error < .00015, grip_error

# Conservative geometric probe: triangle intersections with inset head/chest boxes.
# This is evidence of major penetration, not an artistic quality score.
mesh = bpy.data.objects['Player_Cuboid_Base']
refs = [o for o in bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].all_objects if o.type=='MESH']
boxes={}
for n in ['Head','Chest']:
    idx=mesh.vertex_groups[n].index
    inv=rig.data.bones[n].matrix_local.inverted()@rig.matrix_world.inverted()@mesh.matrix_world
    points=[inv@v.co for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
    margin=.01 if n=='Head' else .035
    boxes[n]=(np.min(points,axis=0)+margin,np.max(points,axis=0)-margin)
triangles=[]
for o in refs:
    o.data.calc_loop_triangles()
    triangles.append((o,np.array([tuple(v.co) for v in o.data.vertices])[np.array([tuple(t.vertices) for t in o.data.loop_triangles])]))

def collision():
    deps=bpy.context.evaluated_depsgraph_get(); counts={}
    for n,(lo,hi) in boxes.items():
        center=(lo+hi)/2;extent=(hi-lo)/2;inv=np.array((rig.matrix_world@rig.pose.bones[n].matrix).inverted());count=0
        for o,ts in triangles:
            t=inv@np.array(o.evaluated_get(deps).matrix_world)
            v=ts@t[:3,:3].T+t[:3,3]-center;e=np.roll(v,-1,axis=1)-v
            axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],
                np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1)
            p=np.einsum('ntd,nad->nta',v,axes);r=np.abs(axes)@extent
            count+=int((~((p.min(1)>r+1e-8)|(p.max(1)<-r-1e-8)).any(1)).sum())
        counts[n]=count
    return counts

def composed(action,source,t,phase):
    duration=float(source.frame_range[1]-source.frame_range[0])
    sf=1+((phase+t*(1.6 if 'Run' in source.name else 1))%duration)
    base=sample(source,sf)
    overlay=sample(action,1+(t%32))
    pose={n:m.copy() for n,m in base.items()}
    # Preserve 100% source torso rhythm. No phase-dependent damping or hidden correction.
    for n in ['Spine','Chest','Neck','Head']: pose[n]=base[n]@overlay[n]
    for n in ['Arm.R','Arm.L','WeaponCarrier']: pose[n]=overlay[n]
    apply(pose)
    return {n:p.matrix_basis.copy() for n,p in rig.pose.bones.items()},base

cache={}; overlay_results=[]; lower_error=0.
for layer,phase in [('Idle',0),('Run',0),('Run',4),('Run',8),('Run',12)]:
    source=bpy.data.actions['Player_Idle' if layer=='Idle' else 'Player_Run_Blocky_V7_Final']
    # 480 frames = 20 seconds: full 3-way Run/Idle/Ready relative-phase repeat.
    # Store 160-frame Run previews / 96-frame Idle previews for normal-speed looping.
    count=160 if layer=='Run' else 96
    for label,action in [('Hold',hold),('Ready',new)]:
        poses=[];hits=[];centers={n:[] for n in ['Chest','Head','WeaponCarrier']}
        for i in range(481):
            pose,base=composed(action,source,i,phase)
            lower_error=max(lower_error,max(error(pose[n],base[n]) for n in LOWER))
            if i<=count: poses.append(pose)
            if i%2==0:
                c=collision()
                if any(c.values()):hits.append({'frame':i+1,'counts':c})
            for n in centers:centers[n].append(list(rig.pose.bones[n].matrix.translation))
        cache[(layer,phase,label)]=poses
        overlay_results.append({'layer':layer,'phase_frames':phase,'variant':label,'sampled_seconds':20,
            'inset_head_chest_hits':hits,'vertical_peak_to_peak_m':{n:float(np.ptp(np.array(v)[:,2])) for n,v in centers.items()}})
assert lower_error < 2e-6
report={'action':new.name,'fps':24,'cycle_frames':32,'seconds':32/24,'key_range':[1,33],'playback_range':[1,32],
    'animated_bones':UPPER,'lower_keys':lower_keys,'scale_keys':0,'protected_actions_unchanged':list(protected['actions']),
    'geometry_weights_rest_lengths_hierarchy_unchanged':True,'runtime_hold_resource_unchanged':True,
    'seam_matrix_error':seam,'seam_velocity':'Matched zero end/start Bezier tangents',
    'draw_endpoint_error':draw_error,'holster_start_error_at_ready_neutral':holster_error,
    'holster_note':'Neutral is exact. Other Ready phases are bounded offsets, so arbitrary-phase exit still requires the existing transition blend; this pass does not modify it.',
    'grip_relative_transform_max_error':grip_error,'ranges_degrees_local_xyz':ranges,
    'standalone_peak_rotation_degrees':{n:max(v['degrees'] for v in rows) for n,rows in motion.items()},
    'standalone_position_peak_to_peak_m':{n:np.ptp(np.array([v['position'] for v in rows]),axis=0).tolist() for n,rows in motion.items()},
    'lower_overlay_error':lower_error,'overlays':overlay_results,
    'composition_scope':'Blender preview: full locomotion body delta + Ready body delta; arms/carrier replaced. No runtime integration and no added phase damping.',
    'runtime_files_modified':False}
(BASE/'ready_e1_validation.json').write_text(json.dumps(report,indent=2))
assert not any(o['inset_head_chest_hits'] for o in overlay_results), 'Inspect collision evidence before approval'

# Separate comparison file. Preview actions contain baked lower body only here;
# LongGunReady_Loop_V1 remains strictly upper-body, with zero lower-body keys.
original_scene=scene
model_objects=[rig,mesh]+list(bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].objects)
camera_q=Vector((12,-16,15)).to_track_quat('Z','Y')
right=camera_q@Vector((1,0,0))
def copy_character(dst,label,offset,poses,layer,phase):
    objects={}
    for old in model_objects:
        obj=old.copy();obj.name='E1_'+label+'_'+old.name
        if old==rig:obj.data=old.data.copy()
        obj.animation_data_clear();dst.collection.objects.link(obj);objects[old]=obj
    rr=objects[rig]
    for old,obj in objects.items():
        if old.parent in objects:obj.parent=objects[old.parent]
        for mod in obj.modifiers:
            if mod.type=='ARMATURE' and mod.object==rig:mod.object=rr
        for con in obj.constraints:
            if hasattr(con,'target') and con.target==rig:con.target=rr
        if not old.parent:obj.location+=offset
    rr.animation_data_create();a=bpy.data.actions.new('PREVIEW_ONLY_'+layer+'_Phase'+str(phase)+'_'+label)
    a.use_fake_user=True;a['not_for_export']=True;a['source_layer']='Run 1.60' if layer=='Run' else 'Idle 1.00'
    rr.animation_data.action=a
    for i,pose in enumerate(poses):
        for n,m in pose.items():
            p=rr.pose.bones[n];p.matrix_basis=m
            p.keyframe_insert('location',frame=i+1,group=n)
            p.keyframe_insert('rotation_quaternion' if p.rotation_mode=='QUATERNION' else 'rotation_euler',frame=i+1,group=n)
    for c in curves(a):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    return rr

for layer,phase in [('Idle',0),('Run',0),('Run',4),('Run',8),('Run',12)]:
    s=bpy.data.scenes.new('E1_'+layer+'_Phase'+str(phase)+'_AB')
    s.world=original_scene.world;s.render.engine='BLENDER_EEVEE'
    s.render.resolution_x=1200;s.render.resolution_y=720;s.render.resolution_percentage=100
    s.render.fps=24;s.frame_start=1;s.frame_end=160 if layer=='Run' else 96
    s.sync_mode='FRAME_DROP';s['comparison']='LEFT LongGunHold_V2 / RIGHT LongGunReady_Loop_V1'
    s['preview_only']='Baked comparison, never export preview actions. Authored Ready in original scene has no Run keys.'
    for o in original_scene.objects:
        if o.type=='LIGHT':s.collection.objects.link(o)
    for label,side in [('Hold',-1),('Ready',1)]:
        rr=copy_character(s,label,right*(1.25*side),cache[(layer,phase,label)],layer,phase)
        font=bpy.data.curves.new('E1_Label','FONT');font.body='Hold V2' if label=='Hold' else 'Ready V1'
        font.align_x='CENTER';font.size=.16
        text=bpy.data.objects.new('E1_'+label+'_Label',font);s.collection.objects.link(text)
        text.location=right*(1.25*side)+Vector((0,0,2.08));text.rotation_euler=camera_q.to_euler()
    for name,scale in [('GameplayScale',14.5*1200/720),('Detail',5.4)]:
        cam=bpy.data.cameras.new('E1_'+layer+'_'+str(phase)+'_'+name);cam.type='ORTHO';cam.ortho_scale=scale
        obj=bpy.data.objects.new(cam.name,cam);s.collection.objects.link(obj)
        obj.rotation_euler=camera_q.to_euler();obj.location=Vector((0,0,1))+camera_q@Vector((0,0,15))
        if name=='Detail':s.camera=obj
    s.frame_set(1)
readme=bpy.data.texts.new('E1_README')
readme.write('PASS 1 ONLY. No game integration.\nScenes E1_Idle_Phase0_AB and E1_Run_Phase0/4/8/12_AB.\nLEFT Hold V2, RIGHT Ready V1. Space plays at 24 FPS; Run already sampled at 1.60.\nDetail camera is diagnostic. Select the GameplayScale camera and set active to judge actual pixel scale.\nReady action keys 1..33, play 1..32. PREVIEW_ONLY actions are baked comparison, never production exports.\nFull original assets plus upper-body Ready remain in the original scene.\n')
sample(new,1)
scene=original_scene
scene.frame_start=1;scene.frame_end=32
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'ready_e1_comparison.blend'),check_existing=False)
print('E1_VALIDATED '+json.dumps({k:report[k] for k in ['seam_matrix_error','lower_keys','lower_overlay_error','grip_relative_transform_max_error','standalone_peak_rotation_degrees']}))
