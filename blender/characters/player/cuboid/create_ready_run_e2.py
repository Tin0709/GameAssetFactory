"""E2 blocking: upper-body correction authored against Run V7, phase 1..17."""
import bpy,json,math,hashlib,shutil,datetime
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(__file__).resolve().parent
src=(BASE/'create_ready_e1.py').read_text()
exec(src[:src.index("assert 'LongGunReady_Loop_V1' not in")])
if globals().get('rebuild_e2',False):
    protected=json.loads((BASE/'ready_run_e2_protection.json').read_text())
    assert 'LongGunReady_Run_V1' not in protected['actions']
    assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
    old=bpy.data.actions['LongGunReady_Run_V1']
    assert old.get('phase_source','').startswith('Player_Run_Blocky_V7_Final;')
    bpy.data.actions.remove(old)
    backup=Path(protected['backup'])
else:
    assert 'LongGunReady_Run_V1' not in bpy.data.actions
    backup=DEV.with_name('player_cuboid_weapon_animation_dev_before_e2_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend')
    shutil.copy2(DEV,backup)
    protected={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'bones':bones(),'backup':str(backup)}
    (BASE/'ready_run_e2_protection.json').write_text(json.dumps(protected,indent=2))
run=bpy.data.actions['Player_Run_Blocky_V7_Final'];hold=bpy.data.actions['LongGunHold_V2']
hold_pose=sample(hold,1)

def baseline(f):
    base=sample(run,1+((f-1)%16))
    pose={n:m.copy() for n,m in base.items()}
    for n in ['Spine','Chest','Neck','Head']:pose[n]=base[n]@hold_pose[n]
    for n in ['Arm.R','Arm.L','WeaponCarrier']:pose[n]=hold_pose[n]
    apply(pose)
    return base,pose,{p.name:p.matrix.copy() for p in rig.pose.bones}

rows=[baseline(1+i/8)[2] for i in range(128)]
def average_q(name):
    qs=[r[name].to_quaternion() for r in rows];q0=qs[0]
    return Quaternion(tuple(sum((q[j] if q.dot(q0)>=0 else -q[j]) for q in qs)/len(qs) for j in range(4))).normalized()
mean_p={n:sum((r[n].translation for r in rows),Vector())/len(rows) for n in UPPER}
mean_q={n:average_q(n) for n in UPPER}

def target(q,p):
    m=q.to_matrix().to_4x4();m.translation=p;return m

def author_pose(f):
    _,_,lag=baseline(f-.22)
    base,pose,world=baseline(f)
    # Spine is the first absorber. Only its correction is stored, never Run keys.
    n='Spine';d=world[n].translation-mean_p[n]
    p=mean_p[n]+Vector((d.x*.90,d.y*.90,d.z*.68))
    rig.pose.bones[n].matrix=target(mean_q[n].slerp(world[n].to_quaternion(),.60),p)
    bpy.context.view_layer.update()
    # Chest keeps 58% of stride angular energy and the spine-transmitted translation.
    p=rig.pose.bones['Chest'].matrix.translation.copy()
    rig.pose.bones['Chest'].matrix=target(mean_q['Chest'].slerp(world['Chest'].to_quaternion(),.58),p)
    bpy.context.view_layer.update()
    # A small 0.22 source-frame lag retains mass response. Nonzero remaining motion
    # follows measured asymmetric Run rather than an independent oscillator.
    n='WeaponCarrier';d=lag[n].translation-mean_p[n]
    p=mean_p[n]+Vector((d.x*.65,d.y*.65,d.z*.28))
    gun=target(mean_q[n].slerp(lag[n].to_quaternion(),.35),p)
    correction=gun@world[n].inverted()
    # Shared rigid correction preserves both distinct authored grip relationships.
    for n in ['Arm.R','Arm.L','WeaponCarrier']:rig.pose.bones[n].matrix=correction@world[n]
    bpy.context.view_layer.update()
    n='Head';d=world[n].translation-mean_p[n]
    hp=mean_p[n]+Vector((d.x*.80,d.y*.80,d.z*.22))
    neck=rig.pose.bones['Neck'];offset=hp-rig.pose.bones['Head'].matrix.translation
    neck.matrix=target(mean_q['Neck'].slerp(world['Neck'].to_quaternion(),.50),neck.matrix.translation+offset)
    bpy.context.view_layer.update()
    head=rig.pose.bones['Head'];head.matrix=target(mean_q['Head'].slerp(world['Head'].to_quaternion(),.30),head.matrix.translation)
    bpy.context.view_layer.update()
    composed={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
    authored={n:Matrix.Identity(4) for n in rig.pose.bones.keys()}
    for n in ['Spine','Chest','Neck','Head']:authored[n]=base[n].inverted()@composed[n]
    for n in ['Arm.R','Arm.L','WeaponCarrier']:authored[n]=composed[n]
    return authored

poses=[author_pose(1+i*.5) for i in range(32)]
poses.append({n:m.copy() for n,m in poses[0].items()})
action=bpy.data.actions.new('LongGunReady_Run_V1');action.use_fake_user=True
rig.animation_data.action=action
for i,pose in enumerate(poses):
    for n in UPPER:
        p=rig.pose.bones[n]
        # Set and key directly. A depsgraph update here would evaluate the
        # already-keyed Action at the current scene frame and erase this pose.
        p.matrix_basis=pose[n]
        p.keyframe_insert('location',frame=1+i*.5,group=n)
        p.keyframe_insert('rotation_quaternion' if p.rotation_mode=='QUATERNION' else 'rotation_euler',frame=1+i*.5,group=n)
for c in curves(action):
    ks=c.keyframe_points
    for i,k in enumerate(ks):
        j=i%32; slope=(ks[(j+1)%32].co.y-ks[(j-1)%32].co.y)/1.0
        k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
        k.handle_left=(k.co.x-1/6,k.co.y-slope/6)
        k.handle_right=(k.co.x+1/6,k.co.y+slope/6)
    m=c.modifiers.new('CYCLES');m.mode_before=m.mode_after='REPEAT';c.update()
action['authoring_fps']=24;action['cycle_frames']=16;action['duplicate_endpoint_frame']=17
action['preview_cadence']=1.60
action['phase_source']='Player_Run_Blocky_V7_Final; exact shared phase, not an independent clock'
action['composition']='Body basis = Run basis @ Ready correction for Spine/Chest/Neck/Head; replace Arm.R/Arm.L/WeaponCarrier. Lower body exclusively Run.'
action['design']='Stride-derived asymmetric spine absorption, coordinated grip control, 0.22f rifle response lag, stabilized gaze. Pass 1 only.'
action['production_export']=False
for name,f in [('Contact L',1),('Down L',3),('Passing L',5),('Up L',7),('Contact R',9),('Down R',11),('Passing R',13),('Up R',15)]:action.pose_markers.new(name).frame=f
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert geometry()==protected['geometry']
assert json.dumps(bones(),sort_keys=True)==json.dumps(protected['bones'],sort_keys=True)
sample(action,1);scene.frame_start=1;scene.frame_end=16;scene.use_preview_range=False
scene.render.fps=24;scene.render.fps_base=1
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'action':action.name,'keys':[1,17],'playback':[1,16],'upper':UPPER,'backup':str(backup)}
