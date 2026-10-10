"""Original in-place airborne articulation, continuing the approved takeoff."""
import bpy,json,math,runpy,sys
from pathlib import Path
from mathutils import Vector,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/jump_airpose_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
T=runpy.run_path(str(OUT.parent/'jump_takeoff_test/build_test.py'))
original_design=T['design'];channel=T['channel'];END=22;FPS=30

def design(g):
    if g<24:return original_design(g)
    f=g-23;d=original_design(24)
    d['hip']=Vector((.006,-.022,.674))
    d['pelvis']=(channel(f,[(1,-2),(8,1),(15,3.5),(22,2.5)]),channel(f,[(1,-1),(10,5),(22,3)]),channel(f,[(1,-1),(11,-3),(22,-1.8)]))
    d['spine']=channel(f,[(1,-3),(9,-1),(16,2),(22,2.5)])
    d['chest']=channel(f,[(1,-2),(7,-2.5),(14,0),(22,1)])
    d['arm_r']=channel(f,[(1,104),(7,112),(15,96),(22,100)])
    d['arm_l']=channel(f,[(1,93),(5,86),(13,67),(22,73)])
    d['spread']=channel(f,[(1,39),(8,44),(14,48),(22,44)])
    d['spread_l']=channel(f,[(1,37),(6,40),(16,49),(22,45)])
    d['leg_l']=channel(f,[(1,-23),(9,-44),(22,-34)])
    d['leg_r']=channel(f,[(1,14),(6,19),(13,31),(22,26)])
    d['head']=channel(f,[(1,1),(11,-1),(22,0)])
    return d

def pose_values(r):
    return {b.name:{'location':list(b.location),('rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'):list(b.rotation_quaternion if b.rotation_mode=='QUATERNION' else b.rotation_euler)} for b in r.pose.bones}

def raw_pose(r,f):
    T['pose'].__globals__['design']=design
    T['pose'](r,f+23)
    d=design(f+23);b=r.pose.bones['UpperArm.L']
    b.rotation_quaternion=Euler((math.radians(d['arm_l']),0,math.radians(d['spread_l'])),'ZXY').to_quaternion()
    for side in ['L','R']:
        b=r.pose.bones['Leg.'+side];mat=b.matrix.copy()
        spread=channel(f,[(1,0),(10,-9),(22,-6)]) if side=='L' else channel(f,[(1,0),(14,7),(22,5)])
        matrix=(Euler((0,math.radians(spread),0)).to_matrix()@mat.to_3x3()).to_4x4()
        clearance=channel(f,[(1,0),(6,.002),(16,.002),(22,.001)])
        matrix.translation=mat.translation+Vector((clearance*(1 if side=='L' else -1),0,0))
        b.matrix=matrix
    bpy.context.view_layer.update()

def build():
    assert not (OUT/'jump_airpose_review.blend').exists(),'Back up and version existing studies before rebuilding'
    assert (TMP/'live_before_test.blend').exists() and 'Jump_AirPose_Test' not in bpy.data.actions
    s=bpy.context.scene;r=bpy.data.objects['JT_Test_Rig'];m=bpy.data.objects['JT_Test_Mesh']
    old={a.name:ui.action_signature(a) for a in bpy.data.actions}
    s.frame_set(23,subframe=.875);bpy.context.view_layer.update();previous=pose_values(r);hip_previous=r.pose.bones['Hips'].head.copy()
    s.frame_set(24);bpy.context.view_layer.update();start=pose_values(r);hip_end=r.pose.bones['Hips'].head.copy()
    hip_velocity=(hip_end-hip_previous)/.125
    physical_offset=hip_end.z-.674
    b=r.pose.bones['Hips'];world_delta=Vector((0,0,physical_offset));local_delta=b.bone.matrix_local.to_3x3().inverted()@world_delta
    start['Hips']['location']=list(Vector(start['Hips']['location'])-local_delta)
    r.animation_data.action=None
    raw_pose(r,1);desired0=pose_values(r);raw_pose(r,1.125);desired1=pose_values(r)
    velocities={}
    for name,props in start.items():
        velocities[name]={}
        for prop,values in props.items():
            old_end=values if name=='Hips' and prop=='location' else start[name][prop]
            # The only removed velocity is common body translation, owned by physics.
            source_velocity=[0]*len(values) if prop=='location' and name in ['Root','Hips'] else [(x-y)/.125 for x,y in zip(old_end,previous[name][prop])]
            target_velocity=[(x-y)/.125 for x,y in zip(desired1[name][prop],desired0[name][prop])]
            velocities[name][prop]=[x-y for x,y in zip(source_velocity,target_velocity)]
    r.name='AP_Test_Rig';m.name='AP_Test_Mesh';s.name='JUMP_AIRPOSE_REVIEW'
    if ui.SCENE_TAG in s:del s[ui.SCENE_TAG]
    a=bpy.data.actions.new('Jump_AirPose_Test');a.use_fake_user=True;r.animation_data.action=a
    previous_quat={}
    for j in range((END-1)*8+1):
        f=1+j/8;r.animation_data.action=None;raw_pose(r,f);wanted=pose_values(r)
        t=f-1;carry=t*(1-t/4)**2 if t<4 else 0
        for b in r.pose.bones:
            for prop,values in wanted[b.name].items():
                if prop=='location' and b.name in ['Root','Hips']:values=start[b.name][prop]
                elif f<=1.125:values=[v+(v-p)/.125*t for v,p in zip(start[b.name][prop],previous[b.name][prop])]
                else:values=[x+(v-z)+dv*carry for x,v,z,dv in zip(values,start[b.name][prop],desired0[b.name][prop],velocities[b.name][prop])]
                setattr(b,prop,values)
                if prop=='rotation_quaternion':
                    q=b.rotation_quaternion;q.normalize()
                    if b.name in previous_quat and q.dot(previous_quat[b.name])<0:q.negate()
                    previous_quat[b.name]=q.copy()
            r.animation_data.action=a
            for prop in wanted[b.name]:b.keyframe_insert(prop,frame=f,group=b.name)
        r.animation_data.action=None
    r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
    for c in ui.curves(a):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in old.items())
    s.frame_start=1;s.frame_end=END;s.render.fps=FPS;s.render.fps_base=1
    s.timeline_markers.clear()
    for f,label in [(1,'APPROVED TAKEOFF CONTINUATION'),(7,'ARM FOLLOW-THROUGH'),(9,'LEAD LEG OPENS'),(13,'TRAIL / COUNTER-ROTATION'),(16,'WIDE FLIGHT SILHOUETTE'),(22,'CONTROLLED CONTINUATION - NO LANDING')]:s.timeline_markers.new(label,frame=f)
    # This fixed stage offset is presentation, not part of the registered pose Action.
    floor=bpy.data.objects['Showcase_FixedFloor'];floor.location.z=-physical_offset
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s.frame_set(1)
    manifest={'action':a.name,'frames':[1,END],'fps':FPS,'status':'pending','rig_changes':[],'original_actions':old,'in_place':True,'canonical_hip_height_m':.674,'takeoff_frame':24,'pose_start':start,'preview_offset_m':[0,0,physical_offset],'preview_entry_velocity_m_per_frame':list(hip_velocity),'preview_settle_frames':6,'scope':'Airborne articulation only; no physical trajectory, landing or combined production Action.'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    s['purpose']='Airborne silhouette study / in-place / pending user review'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'jump_airpose_review.blend'))
    print('BUILT AIRPOSE',a.name,flush=True)

if __name__=='__main__':build()
