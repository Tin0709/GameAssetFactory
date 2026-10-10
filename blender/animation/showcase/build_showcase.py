"""Build the isolated showcase in a fresh Blender process; never save sources."""
import bpy,json,hashlib,sys,importlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2];TMP=ROOT/'.validation/animation_showcase'
sys.path.insert(0,str(OUT));ui=importlib.import_module('gaf_animation_library')
SOURCE=ROOT/'blender/animation/reviews/player_animation_library_v1'
ITEMS=[
    ('Expressive_Arm_Motion_Test','expressive_arm_motion_test/expressive_arm_motion_review.blend','EAM_Player_Rig','EAM_Player_Mesh',24,False),
    ('Run_Expressive_Test','run_expressive_test/run_expressive_review.blend','RUN_Test_Rig','RUN_Test_Mesh',18,True),
    ('LowerBody_Recovery_Test','lowerbody_recovery_test/lowerbody_recovery_review.blend','LB_Test_Rig','LB_Test_Mesh',48,False),
]
NEUTRAL=json.loads((SOURCE/'jump_default_v001/idle_baseline.json').read_text())
def append(path,objects=(),actions=(),worlds=()):
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):
        for name in objects:assert name in src.objects,name
        for name in actions:assert name in src.actions,name
        dst.objects=list(objects);dst.actions=list(actions);dst.worlds=list(worlds)
    return dst

def reset(r):
    r.animation_data.action=None
    for b in r.pose.bones:
        for k,v in NEUTRAL[b.name].items():setattr(b,k,v)

def audit():
    s=bpy.context.scene;result={};entries=[];expected=None
    for action,file,rig,mesh,end,loop in ITEMS:
        path=SOURCE/file;data=append(path,[rig,mesh],[action]);r,m=data.objects
        for o in [r,m]:s.collection.objects.link(o)
        r.hide_viewport=m.hide_viewport=False
        signature=ui.rest_signature(r.data)
        if expected is None:expected=signature
        assert signature==expected,('Incompatible rig',rig)
        assert not r.animation_data.nla_tracks and not r.animation_data.drivers
        assert len(r.pose.bones)==13 and len(m.data.vertices)==64
        assert not any(b.constraints for b in r.pose.bones)
        assert all(abs(r.matrix_world[i][j]-(1 if i==j else 0))<1e-6 for i in range(4) for j in range(4))
        armature=r.data.name;a=data.actions[0]
        entry={'action':action,'source':path.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_rig':rig,'source_mesh':mesh,'source_armature':armature,'slot_identifier':a.slots[0].identifier,'action_sha256':ui.action_signature(a),'action_frame_range':list(a.frame_range),'start':1,'end':end,'fps':30,'fps_base':1.0,'status':'approved','approval_note':'Explicit user approval in the 2026-10-10 viewer/takeoff request; exploratory test only.','seamless_loop':loop}
        entry['rotation_modes']={b.name:b.rotation_mode for b in r.pose.bones}
        ui.validate_action(a,entry,r);reset(r);r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
        samples=[]
        for j in range((end-1)*2+1):
            f=1+j/2;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
            e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());samples.append({'frame':f,'vertices':[list(e.matrix_world@v.co) for v in e.data.vertices]})
        result[action]={'rest_sha256':signature,'entry':entry,'samples':samples};entries.append(entry)
        # Remove the temporary audit actor; only Actions remain until factory reset.
        bpy.data.objects.remove(m,do_unlink=True);bpy.data.objects.remove(r,do_unlink=True)
    (TMP/'source_audit.json').write_text(json.dumps(result,indent=2))
    return expected,entries

def build():
    target=OUT/'Animation_Showcase.blend';assert not target.exists(),'Use a versioned backup before rebuilding an existing viewer'
    assert (TMP/'live_before_viewer.blend').exists()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    expected,entries=audit()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not hasattr(bpy.types,'GAF_PT_animation_library'):ui.register()
    s=bpy.context.scene;s.name='ANIMATION_SHOWCASE';s[ui.SCENE_TAG]=True
    names=['LB_Test_Rig','LB_Test_Mesh','LB_FixedFloor','LB_Key','LB_Fill','LB_Rim','LB_FRONT','LB_THREE_QUARTER','LB_SIDE']
    data=append(SOURCE/ITEMS[-1][1],names,[ITEMS[-1][0]],['JD1_NeutralWorld'])
    for o in data.objects:
        s.collection.objects.link(o);o.hide_render=o.hide_viewport=False
        o.name=o.name.replace('LB_Test_Rig',ui.RIG).replace('LB_Test_Mesh','Showcase_Player_Mesh').replace('LB_','Showcase_')
    r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh']
    assert m.parent==r and any(mod.object==r for mod in m.modifiers if mod.type=='ARMATURE')
    assert ui.rest_signature(r.data)==expected
    s.world=data.worlds[0]
    for e in entries[:2]:append(ROOT/e['source'],actions=[e['action']])
    for a in bpy.data.actions:a.use_fake_user=True
    assert len(bpy.data.actions)==3
    text=bpy.data.texts.new(ui.BASELINE);text.write(json.dumps(NEUTRAL))
    manifest={'schema':1,'title':'GameAssetFactory Animation Library','rig_sha256':expected,'actor_rig':r.name,'actor_mesh':m.name,'animations':entries,'approval_policy':'New registrations default to pending; only explicit human review establishes approval.'}
    manifest['rotation_modes']={b.name:b.rotation_mode for b in r.pose.bones}
    (OUT/'animation_manifest.json').write_text(json.dumps(manifest,indent=2))
    s['gaf_manifest_snapshot']=json.dumps(manifest);s['gaf_manifest_file']='//animation_manifest.json'
    # Give relative-manifest helpers their final directory without saving early.
    old_location=ui.location;ui.location=lambda:OUT
    try:ui.refresh(s,import_missing=False)
    finally:ui.location=old_location
    s.gaf_loop=True
    s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.samples=16;s.cycles.use_denoising=True
    s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG';s.render.use_motion_blur=False
    # These match the approved study's saved stage and color management.
    s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=0;s.view_settings.gamma=1
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s.frame_set(1)
    bpy.context.view_layer.objects.active=r
    for o in bpy.context.selected_objects:o.select_set(False)
    r.select_set(True)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                sp=area.spaces.active;sp.show_region_ui=True;sp.show_region_toolbar=False;sp.overlay.show_overlays=False
                sp.region_3d.view_perspective='CAMERA';sp.region_3d.view_camera_zoom=0
                sp.shading.type='MATERIAL';sp.shading.use_scene_world=True;sp.shading.use_scene_lights=True
            elif area.type=='DOPESHEET_EDITOR':
                area.ui_type='DOPESHEET';area.spaces.active.mode='ACTION';area.spaces.active.dopesheet.show_only_selected=True
    for image in bpy.data.images:
        if image.source=='FILE' and not image.packed_file:image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(target))
    print('BUILT SHOWCASE',json.dumps({'file':str(target),'actions':list(bpy.data.actions.keys()),'objects':len(bpy.data.objects),'rigs':len(bpy.data.armatures),'meshes':len(bpy.data.meshes),'images':len(bpy.data.images)}),flush=True)

if __name__=='__main__':build()
