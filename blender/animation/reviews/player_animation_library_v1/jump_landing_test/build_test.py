"""Isolated rigid-block landing; approved airborne source is read-only."""
import bpy,json,math,runpy,sys
from pathlib import Path
from mathutils import Vector,Matrix,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/jump_landing_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
T=runpy.run_path(str(OUT.parent/'jump_takeoff_test/build_test.py'))
LB=T['LB'];channel=LB['channel'];smooth=LB['smooth'];idle=T['idle'];END=44;FPS=30
CONTACT={'L':9,'R':11};BASES={'L':Vector((.128,-.105,0)),'R':Vector((-.128,.070,0))}
START_MATRICES={}

def hermite(f,keys):
    for (fa,a,da),(fb,b,db) in zip(keys,keys[1:]):
        if fa<=f<=fb:
            t=(f-fa)/(fb-fa);h=fb-fa
            return (2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*h*da+(-2*t**3+3*t*t)*b+(t**3-t*t)*h*db
    return keys[0][1] if f<keys[0][0] else keys[-1][1]

def design(f):
    return {'hip':Vector((channel(f,[(1,.006),(9,.018),(16,.030),(27,.006),(38,0),(44,0)]),channel(f,[(1,-.022),(9,-.035),(16,-.018),(29,0),(44,0)]),hermite(f,[(1,.674,0),(6,.674,0),(9,.663,-.010),(16,.584,0),(26,.681,0),(37,.674,0),(44,.674,0)]))),
      'pelvis':(channel(f,[(1,2.5),(9,3.5),(16,7),(26,1),(38,2),(44,2)]),channel(f,[(1,3),(10,1),(18,-1),(32,0),(44,0)]),channel(f,[(1,-1.8),(9,-1),(16,-1.4),(29,0),(44,0)])),
      'spine':channel(f,[(1,2.5),(9,3.5),(18,8.5),(29,0),(40,2),(44,2)]),
      'chest':channel(f,[(1,1),(10,2),(20,5.5),(31,0),(42,2),(44,2)]),
      'arm_r':channel(f,[(1,100),(5,88),(10,53),(17,18),(26,-16),(40,-9),(44,-9)]),
      'arm_l':channel(f,[(1,73),(6,68),(12,35),(19,-5),(30,15),(42,10),(44,10)]),
      'spread_r':channel(f,[(1,44),(9,42),(17,32),(29,24),(40,20),(44,20)]),
      'spread_l':channel(f,[(1,45),(10,43),(19,35),(31,26),(42,18),(44,18)]),
      'head':channel(f,[(1,0),(8,1),(19,3),(24,1),(31,-1),(42,2),(44,2)])}

def pose_values(r):
    return {b.name:{'location':list(b.location),('rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'):list(b.rotation_quaternion if b.rotation_mode=='QUATERNION' else b.rotation_euler)} for b in r.pose.bones}

def raw_pose(r,f):
    d=design(f)
    for b in r.pose.bones:
        for k,v in idle[b.name].items():setattr(b,k,v)
    hip=r.pose.bones['Hips'];hip.rotation_euler=Euler(tuple(math.radians(a) for a in d['pelvis']),'XYZ')
    hip.location=hip.bone.matrix_local.to_3x3().inverted()@(d['hip']-hip.bone.head_local)
    bpy.context.view_layer.update()
    for side in ['L','R']:
        b=r.pose.bones['Leg.'+side];socket=hip.matrix@(hip.bone.matrix_local.inverted()@b.bone.head_local)
        socket.x+=(.002+channel(f,[(1,0),(9,.003),(19,.003),(32,.002),(44,0)]))*(1 if side=='L' else -1)
        target=LB['leg_matrix'](b,socket,BASES[side],0)
        if f<CONTACT[side]:
            u=smooth((f-1)/(CONTACT[side]-1));start=START_MATRICES[side]
            q=start.to_quaternion().slerp(target.to_quaternion(),u)
            mat=q.to_matrix().to_4x4();mat.translation=(start.translation+d['hip']-Vector((.006,-.022,.674))).lerp(target.translation,u)
            # Rotation interpolation can sweep a sole corner below its endpoints.
            # Prescribe a monotone approach clearance, then lock the support corner.
            center=.1125 if side=='L' else -.1125
            corners=[Vector((center+x,y,0)) for x in [-.1125,.1125] for y in [-.1125,.1125]]
            rest_inverse=b.bone.matrix_local.inverted()
            start_z=min((start@rest_inverse@p).z for p in corners)
            wanted_z=start_z*(1-u)+.0004*u
            actual_z=min((mat@rest_inverse@p).z for p in corners)
            mat.translation.z+=wanted_z-actual_z
            b.matrix=mat
        else:b.matrix=target
    for name,angles in [('Spine',(d['spine'],-d['pelvis'][1]*.4,-d['pelvis'][2]*.55)),('Chest',(d['chest'],-d['pelvis'][1]*.5,0)),('UpperArm.R',(d['arm_r'],0,-d['spread_r'])),('UpperArm.L',(d['arm_l'],0,d['spread_l']))]:
        b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in angles),'ZXY' if 'UpperArm' in name else 'XYZ')
        if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
        else:b.rotation_euler=e
    bpy.context.view_layer.update()
    b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler((math.radians(d['head']),0,0)).to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()

def build():
    assert not (OUT/'jump_landing_review.blend').exists(),'Preserve/version saved studies before rebuilding'
    assert (TMP/'live_before_test.blend').exists() and 'Jump_Landing_Test' not in bpy.data.actions
    s=bpy.context.scene;r=bpy.data.objects['AP_Test_Rig'];m=bpy.data.objects['AP_Test_Mesh']
    old={a.name:ui.action_signature(a) for a in bpy.data.actions}
    r.animation_data.action=bpy.data.actions['Jump_AirPose_Test'];r.animation_data.action_slot=r.animation_data.action.slots[0]
    s.frame_set(21,subframe=.875);bpy.context.view_layer.update();previous=pose_values(r)
    s.frame_set(22);bpy.context.view_layer.update();start=pose_values(r)
    START_MATRICES.update({side:r.pose.bones['Leg.'+side].matrix.copy() for side in ['L','R']})
    r.animation_data.action=None;raw_pose(r,1);desired0=pose_values(r);raw_pose(r,1.125);desired1=pose_values(r)
    velocities={n:{p:[(v-prev)/.125-(x-y)/.125 for v,prev,x,y in zip(vals,previous[n][p],desired1[n][p],desired0[n][p])] for p,vals in props.items()} for n,props in start.items()}
    r.name='JL_Test_Rig';m.name='JL_Test_Mesh';s.name='JUMP_LANDING_REVIEW'
    if ui.SCENE_TAG in s:del s[ui.SCENE_TAG]
    a=bpy.data.actions.new('Jump_Landing_Test');a.use_fake_user=True;r.animation_data.action=a;previous_quat={}
    for j in range((END-1)*8+1):
        f=1+j/8;r.animation_data.action=None;raw_pose(r,f);wanted=pose_values(r);t=f-1;carry=t*(1-t/4)**2 if t<4 else 0
        for b in r.pose.bones:
            for prop,values in wanted[b.name].items():
                if f<=1.125:values=[v+(v-p)/.125*t for v,p in zip(start[b.name][prop],previous[b.name][prop])]
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
    s.frame_start=1;s.frame_end=END;s.render.fps=FPS;s.render.fps_base=1;s.timeline_markers.clear()
    for f,label in [(1,'APPROVED AIRPOSE CONTINUATION'),(9,'LEAD CONTACT'),(11,'SECOND SUPPORT'),(16,'SOFT ABSORPTION'),(20,'TORSO / ARM FOLLOW-THROUGH'),(26,'RESTRAINED REBOUND'),(40,'MOVEMENT-READY SETTLE')]:s.timeline_markers.new(label,frame=f)
    bpy.data.objects['Showcase_FixedFloor'].location.z=0;r.location=(0,0,0)
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s.frame_set(1)
    s['purpose']='Soft rigid-block landing / pending review / no runtime or full trajectory'
    data={'action':a.name,'frames':[1,END],'fps':FPS,'status':'pending','rig_changes':[],'original_actions':old,'airpose_frame':22,'contact_frames':CONTACT,'foot_bases':{k:list(v) for k,v in BASES.items()},'canonical_hip_height_m':.674,'maximum_compression_frame':16,'rebound_frame':26,'root_static':True,'scope':'Approach articulation, ground absorption and recovery only; world descent stays in preview/physics.'}
    (OUT/'manifest.json').write_text(json.dumps(data,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'jump_landing_review.blend'));print('BUILT LANDING',flush=True)

if __name__=='__main__':build()
