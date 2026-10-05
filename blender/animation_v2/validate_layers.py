"""Validate evaluated rigid contacts and actual modular composition, including subframes."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT))
from build_animation_v2 import curves,reset
bpy.ops.wm.open_mainfile(filepath=str(OUT/'player_review_v2.blend'))
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
def snapshot():
    return {p.name:(p.location.copy(),p.rotation_euler.copy()) for p in rig.pose.bones}
def sample(a,f):
    reset(rig);rig.animation_data.action=a
    scene.frame_set(int(f),subframe=f%1)
    return snapshot()
def apply(values):
    reset(rig)
    for n,(loc,rot) in values.items():
        rig.pose.bones[n].location=loc;rig.pose.bones[n].rotation_euler=rot
    bpy.context.view_layer.update()
def contacts(weapon):
    err=0
    for side,name in [('R','Grip_Point'),('L','Support_Hand_Point')]:
        marker=bpy.data.objects[weapon+'_'+name].matrix_basis.translation
        target=rig.pose.bones['WeaponSocket'].matrix @ marker
        palm=rig.pose.bones['Arm.'+side].matrix @ rest['Arm.'+side].inverted() @ (rest['Arm.'+side].translation+Vector((0,0,-.605)))
        err=max(err,(target-palm).length)
    return err
report={'composites':{},'layers':{},'recoil_endpoint_errors':{},'stance_contact_slip_m_s':{}}
for a in bpy.data.actions:
    if not a.name.startswith('REVIEW_') or a.name=='REVIEW_Locomotion_Transitions':continue
    weapon=a.name.split('_')[1];error=0
    for k in range(int(a['playback_frames'])*4+1):
        sample(a,1+k/4);error=max(error,contacts(weapon))
    report['composites'][a.name]=error
    assert error<.006,(a.name,error)
for weapon,prefix,recoil in [('Pistol','Pistol','Pistol_Recoil'),('M4A1','LongGun','Rifle_Recoil'),('Shotgun','Shotgun','Shotgun_Recoil')]:
    for state in ['LowReady','Aim']:
        stance=sample(bpy.data.actions[prefix+'_'+state],1)
        for gait in ['Idle','Walk','Run']:
            a=bpy.data.actions['Player_'+gait];err=0
            for i in range(24):
                base=sample(a,1+i*int(a['playback_frames'])/24)
                for n in ['Arm.L','Arm.R','WeaponSocket']:base[n]=stance[n]
                apply(base);err=max(err,contacts(weapon))
            report['layers'][weapon+'_'+state+'_'+gait]=err
            assert err<.0001,(weapon,state,gait,err)
    reference=sample(bpy.data.actions[prefix+'_Aim'],1)
    a=bpy.data.actions[recoil];err=0
    for i in range(int(a['playback_frames'])*4+1):
        f=1+i/4
        values={n:(v[0].copy(),v[1].copy()) for n,v in reference.items()}
        for fc in curves(a):
            n=fc.data_path.split('"')[1];j=0 if fc.data_path.endswith('.location') else 1
            values[n][j][fc.array_index]+=fc.evaluate(f)
        apply(values);err=max(err,contacts(weapon))
    report['layers'][recoil+'_on_Aim']=err
    assert err<.006,(recoil,err)
    for gait in ['Walk','Run']:
        err=0
        for i in range(25):
            base_action=bpy.data.actions['Player_'+gait]
            values=sample(base_action,1+i*int(base_action['playback_frames'])/24)
            for n in ['Arm.L','Arm.R','WeaponSocket']:
                values[n]=(reference[n][0].copy(),reference[n][1].copy())
            f=1+i*int(a['playback_frames'])/24
            for fc in curves(a):
                n=fc.data_path.split('"')[1];j=0 if fc.data_path.endswith('.location') else 1
                values[n][j][fc.array_index]+=fc.evaluate(f)
            apply(values);err=max(err,contacts(weapon))
        report['layers'][recoil+'_on_'+gait+'_Aim']=err
        assert err<.006,(recoil,gait,err)
    endpoint=max(abs(fc.evaluate(f)) for fc in curves(a) for f in [1,int(a['playback_frames'])+1])
    report['recoil_endpoint_errors'][recoil]=endpoint
    assert endpoint<1e-5,(recoil,endpoint)
# The stance bottom-face center is the travel proxy. Heel/toe corner turnover
# is intentionally not counted as sliding; both are fixed points on a rigid box.
for gait,speed in [('Walk',.783333333333),('Run',2.0)]:
    a=bpy.data.actions['Player_'+gait];n=int(a['playback_frames']);positions=[]
    for i in range(2,n*2-1):
        f=1+i/4;t=(f-1)/n
        if t>=.5:break
        sample(a,f)
        point=rig.pose.bones['Leg.L'].matrix @ rest['Leg.L'].inverted() @ Vector((.1125,0,0))
        positions.append((t*n/30,point.y-speed*t*n/30))
    drift=max(p[1] for p in positions)-min(p[1] for p in positions)
    report['stance_contact_slip_m_s'][gait]=drift/(positions[-1][0]-positions[0][0])
    assert drift<.003,(gait,drift)
report['notes']=['Contact points sit within unchanged cuboid hand volume, 70 mm from its end.',
                 'Subframe interpolation contact tolerance is 6 mm; authored frame contacts are near floating-point precision.',
                 'Godot quaternion additive import/runtime has not been tested.']
from build_animation_v2 import validate,static_signature
mesh=bpy.data.objects['Player_Cuboid_Base']
report['locomotion_transition']=validate(rig,mesh,rest,[bpy.data.actions['REVIEW_Locomotion_Transitions']],static_signature(mesh))
assert report['locomotion_transition']['REVIEW_Locomotion_Transitions']['minimum_z_m']>-.002
(OUT/'layer_validation.json').write_text(json.dumps(report,indent=2))
print('LAYER_VALIDATION_SUCCESS',json.dumps(report))
