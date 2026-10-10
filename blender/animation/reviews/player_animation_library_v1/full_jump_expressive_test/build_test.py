"""New independent in-place full jump; read-only approved study inputs."""
import bpy,json,sys,math,runpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/full_jump_expressive_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
AP=runpy.run_path(str(OUT.parent/'jump_airpose_test/review_scene.py'));bind=AP['bind']
END=93;AIR_START=24;LAND_START=38;RELEASE=19;CONTACT=46;HEIGHT=.58

def phase(f):
    if f<=AIR_START:return 'Jump_Takeoff_Test',f
    if f<=LAND_START:
        t=f-AIR_START;u=t/(LAND_START-AIR_START)
        ease=u**3*(10-15*u+6*u*u)
        # Compress only the middle of flight: unit endpoint rate/zero warp acceleration.
        return 'Jump_AirPose_Test',1+t+7*ease
    return 'Jump_Landing_Impact_Test',f-LAND_START+1

def height(f):
    if f<=RELEASE or f>=CONTACT:return 0.0
    u=(f-RELEASE)/(CONTACT-RELEASE);h=4*HEIGHT*u*(1-u)
    # Short release acceleration, then one rise/apex/descent; never a midair bounce.
    t=min(1,(f-RELEASE)/.5);return h*t*t*(3-2*t)

def values(r):
    return {b.name:{'location':list(b.location),('rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'):list(b.rotation_quaternion if b.rotation_mode=='QUATERNION' else b.rotation_euler)} for b in r.pose.bones}

def build():
    assert (TMP/'live_before_test.blend').exists()
    assert not (OUT/'full_jump_expressive_review.blend').exists()
    assert 'Full_Jump_Expressive_Test' not in bpy.data.actions
    s=bpy.context.scene;r=bpy.data.objects['JI_Test_Rig'];m=bpy.data.objects['JI_Test_Mesh']
    old={a.name:ui.action_signature(a) for a in bpy.data.actions}
    samples=[]
    for j in range((END-1)*8+1):
        f=1+j/8;name,local=phase(f);bind(s,r,name,local)
        if name=='Jump_Takeoff_Test' and f>RELEASE:
            # Remove the takeoff study's common vertical flight translation only.
            hip=r.pose.bones['Hips'];delta=Vector((0,0,hip.head.z-.674))
            hip.location-=hip.bone.matrix_local.to_3x3().inverted()@delta
            bpy.context.view_layer.update()
        samples.append((f,values(r)))
    r.animation_data.action=None;r.name='FJ_Test_Rig';m.name='FJ_Test_Mesh';s.name='FULL_JUMP_IN_PLACE'
    if ui.SCENE_TAG in s:del s[ui.SCENE_TAG]
    a=bpy.data.actions.new('Full_Jump_Expressive_Test');a.use_fake_user=True;r.animation_data.action=a;previous={}
    for f,pose in samples:
        for b in r.pose.bones:
            for prop,v in pose[b.name].items():
                setattr(b,prop,v)
                if prop=='rotation_quaternion':
                    q=b.rotation_quaternion;q.normalize()
                    if b.name in previous and q.dot(previous[b.name])<0:q.negate()
                    previous[b.name]=q.copy()
                b.keyframe_insert(prop,frame=f,group=b.name)
    r.animation_data.action_slot=a.slots[0]
    for c in ui.curves(a):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in old.items())
    s.frame_start=1;s.frame_end=END;s.render.fps=30;s.render.fps_base=1;s.timeline_markers.clear()
    for f,label in [(1,'READY'),(7,'LIGHT LOAD'),(9,'SOFT COUNTER'),(14,'PREPARATION DIP'),(17,'PUSH'),(19,'LAST SUPPORT'),(24,'EARLY AIR / CONTINUOUS BOUNDARY'),(32,'OPEN AIR SILHOUETTE / PREVIEW APEX'),(38,'DESCENT PREPARATION'),(46,'LEAD CONTACT'),(47,'SECOND SUPPORT'),(51,'HEAVY SOFT ABSORPTION'),(55,'TORSO / ARM FOLLOW THROUGH'),(67,'CONTROLLED REBOUND'),(89,'MOVEMENT READY'),(93,'SETTLED')]:s.timeline_markers.new(label,frame=f)
    r.location=(0,0,0);bpy.data.objects['Showcase_FixedFloor'].location.z=0;s.frame_set(1)
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s['purpose']='Pending full jump / in-place pose Action / controller owns flight translation / see separate preview file'
    data={'action':a.name,'frames':[1,END],'fps':30,'status':'pending','original_actions':old,'rig_changes':[],'root_static':True,'in_place':True,'phase_boundaries':{'takeoff_to_air':24,'air_to_approach':38},'last_support_frame':19,'contact_frames':{'L':46,'R':47},'foot_bases':{'L':[.128,-.105,0],'R':[-.128,.070,0]},'takeoff_foot_bases':{'L':[.1145,.045,0],'R':[-.1145,-.045,0]},'compression_frames':{'preparation':14,'impact':51},'rebound_frame':67,'air_source_time_map':'1+t+7*quintic_smooth(t/14), t=full_frame-24; endpoint rate 1','preview_only':{'file':'full_jump_preview.blend','parent':'Review_Only_Jump_Travel','action':'PREVIEW_ONLY_FullJump_Height','release':RELEASE,'contact':CONTACT,'apex_frame':32.5,'height_m':HEIGHT,'scope':'Presentation only, not registered or export-ready. Controller physics must replace this travel.'},'scope':'First complete expressive jump study, pending review; no export or Godot integration.'}
    (OUT/'manifest.json').write_text(json.dumps(data,indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'full_jump_expressive_review.blend'))
    # Dedicated presentation file: no travel curves are added to the reusable rig Action.
    travel=bpy.data.objects.new(data['preview_only']['parent'],None);s.collection.objects.link(travel);r.parent=travel
    for j in range((END-1)*8+1):
        f=1+j/8;travel.location=(0,0,height(f));travel.keyframe_insert('location',frame=f)
    travel.animation_data.action.name=data['preview_only']['action']
    for c in ui.curves(travel.animation_data.action):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    # Camera changes are presentation-only; retain original lights/materials/textures.
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        cam=bpy.data.objects['Showcase_'+view];cam.data.ortho_scale=2.9;cam.location.z+=.22
    s.name='FULL_JUMP_PREVIEW_ONLY';s['purpose']='Blender-only review travel: never export parent/height Action; Full_Jump_Expressive_Test stays in place'
    s.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'full_jump_preview.blend'))
    print('BUILT IN-PLACE FULL JUMP + SEPARATE PREVIEW',flush=True)

if __name__=='__main__':build()
