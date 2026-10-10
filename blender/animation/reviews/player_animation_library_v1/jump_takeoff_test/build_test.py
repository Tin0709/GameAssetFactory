"""Original takeoff-only study on a backed-up, minimal showcase duplicate."""
import bpy,json,math,runpy,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix,Euler,Quaternion
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
TMP=ROOT/'.validation/jump_takeoff_test';END=24;FPS=30;RELEASE=19
LB=runpy.run_path(str(OUT.parent/'lowerbody_recovery_test/build_test.py'))
sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import gaf_animation_library as ui
channel=LB['channel'];smooth=LB['smooth'];idle=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())

def design(f):
    air=max(0,f-RELEASE)/FPS
    rise=2.0*air-4.905*air*air
    z=channel(f,[(1,.674),(4,.674),(7,.658),(9,.670),(13,.571),(14,.566),(15,.574),(16,.590),(17,.612),(18,.638),(19,.674)])+rise
    return {'hip':Vector((channel(f,[(1,0),(7,.025),(10,.016),(14,-.016),(19,0),(24,.006)]),channel(f,[(1,0),(9,.010),(14,-.028),(19,-.008),(24,-.022)]),z)),
      'pelvis':(channel(f,[(1,2),(8,3),(14,7),(16,7.5),(19,-2),(21,-4),(24,-2)]),channel(f,[(1,0),(9,-1),(14,1),(19,0),(24,-1)]),channel(f,[(1,0),(8,-1.2),(14,1),(19,0),(24,-1)])),
      'spine':channel(f,[(1,2),(8,3),(14,8),(16,8.5),(19,-3),(21,-5),(24,-3)]),
      'chest':channel(f,[(1,2),(9,2),(14,5),(17,5),(20,-3),(22,-4),(24,-2)]),
      'arm_r':channel(f,[(1,-9),(7,-18),(12,-32),(14,-36),(16,-16),(18,29),(19,62),(21,108),(24,104)]),
      'arm_l':channel(f,[(1,10),(7,-8),(13,-27),(15,-31),(17,-4),(19,43),(22,96),(24,93)]),
      'spread':channel(f,[(1,20),(9,23),(14,28),(18,37),(21,43),(24,39)]),
      'leg_l':channel(f,[(19,0),(22,-18),(24,-23)]),'leg_r':channel(f,[(19,0),(22,10),(24,14)]),
      'head':channel(f,[(1,2),(10,2),(15,3),(18,3),(21,-1),(24,1)])}

def pose(r,f):
    d=design(f)
    for b in r.pose.bones:
        for k,v in idle[b.name].items():setattr(b,k,v)
    hip=r.pose.bones['Hips'];hip.rotation_euler=Euler(tuple(math.radians(a) for a in d['pelvis']),'XYZ')
    hip.location=hip.bone.matrix_local.to_3x3().inverted()@(d['hip']-hip.bone.head_local)
    bpy.context.view_layer.update()
    for side in ['L','R']:
        b=r.pose.bones['Leg.'+side];socket=hip.matrix@(hip.bone.matrix_local.inverted()@b.bone.head_local)
        socket.x+=.002*(1 if side=='L' else -1)
        base=Vector((.1145 if side=='L' else -.1145,.045 if side=='L' else -.045,0))
        if f<=RELEASE:b.matrix=LB['leg_matrix'](b,socket,base,0)
        else:
            # Continuous release from the actual supported orientation, followed
            # by a small asymmetric airborne split. No rig/shape deformation.
            ready=design(RELEASE);h=hip.bone.matrix_local.to_3x3()@Euler(tuple(math.radians(a) for a in ready['pelvis']),'XYZ').to_matrix()
            release_socket=ready['hip']+h@(hip.bone.matrix_local.inverted()@b.bone.head_local)
            release_socket.x+=.002*(1 if side=='L' else -1)
            mat=LB['leg_matrix'](b,release_socket,base,0)
            rot=Euler((math.radians(d['leg_l'] if side=='L' else d['leg_r']),0,math.radians(1 if side=='L' else -1))).to_quaternion()
            start=(mat.to_3x3()@b.bone.matrix_local.to_3x3().inverted()).to_quaternion()
            q=start.slerp(rot,smooth((f-RELEASE)/3))
            result_matrix=(q.to_matrix()@b.bone.matrix_local.to_3x3()).to_4x4()
            # At release, retain the accepted shallow hip overlap, then clear it.
            result_matrix.translation=socket+(mat.translation-release_socket)*(1-smooth((f-RELEASE)/2))
            b.matrix=result_matrix
    tracks=[('Spine',(d['spine'],-d['pelvis'][1]*.4,-d['pelvis'][2]*.55)),('Chest',(d['chest'],-d['pelvis'][1]*.5,0)),('UpperArm.R',(d['arm_r'],0,-d['spread'])),('UpperArm.L',(d['arm_l'],0,d['spread']-2))]
    for name,angles in tracks:
        b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in angles),'ZXY' if 'UpperArm' in name else 'XYZ')
        if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
        else:b.rotation_euler=e
    bpy.context.view_layer.update()
    b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler((math.radians(d['head']),0,0)).to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()

def build():
    assert not (OUT/'jump_takeoff_review.blend').exists(),'Preserve a versioned backup and choose a new study destination before rebuilding'
    assert 'Jump_Takeoff_Test' not in bpy.data.actions
    assert (TMP/'live_before_test.blend').exists()
    s=bpy.context.scene
    if ui.SCENE_TAG in s:del s[ui.SCENE_TAG]
    s.name='JUMP_TAKEOFF_REVIEW'
    r=bpy.data.objects['Showcase_Player_Rig'];m=bpy.data.objects['Showcase_Player_Mesh']
    originals={a.name:ui.action_signature(a) for a in bpy.data.actions}
    r.name='JT_Test_Rig';m.name='JT_Test_Mesh'
    r.animation_data.action=None
    a=bpy.data.actions.new('Jump_Takeoff_Test');a.use_fake_user=True;r.animation_data.action=a
    previous={}
    for j in range((END-1)*8+1):
        f=1+j/8;pose(r,f)
        for b in r.pose.bones:
            prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
            if prop=='rotation_quaternion':
                q=b.rotation_quaternion
                if b.name in previous and q.dot(previous[b.name])<0:q.negate()
                previous[b.name]=q.copy()
            b.keyframe_insert(prop,frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name)
    for c in ui.curves(a):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in originals.items())
    s.frame_start=1;s.frame_end=END;s.render.fps=FPS;s.render.fps_base=1
    s.render.filepath='//frames/';s.camera=bpy.data.objects['Showcase_THREE_QUARTER']
    s['purpose']='Takeoff only / nhung nhung soft compression / early flight / pending review'
    s.timeline_markers.clear()
    for f,label in [(1,'READY'),(7,'LIGHT LOAD'),(9,'SOFT COUNTER-BOUNCE'),(14,'SOFT COMPRESSION'),(17,'UPWARD PUSH'),(19,'LAST SUPPORT'),(20,'LIFTOFF'),(24,'EARLY FLIGHT - TEST ENDS')]:s.timeline_markers.new(label,frame=f)
    s.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'jump_takeoff_review.blend'))
    (OUT/'manifest.json').write_text(json.dumps({'action':a.name,'frames':[1,END],'fps':FPS,'last_support_frame':RELEASE,'status':'pending','rig_changes':[],'original_actions':originals,'scope':'Ready through early flight; no apex, descent or landing.','source_showcase_sha256':json.loads((TMP/'backup_manifest.json').read_text())['files'][str(ROOT/'blender/animation/showcase/Animation_Showcase.blend')]},indent=2))
    print('BUILT TAKEOFF',a.name,flush=True)

if __name__=='__main__':build()
