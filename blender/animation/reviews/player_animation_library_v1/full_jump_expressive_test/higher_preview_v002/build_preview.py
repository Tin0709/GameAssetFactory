"""Presentation-only height revision; every skeletal Action stays unchanged."""
import bpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;BASE=OUT.parent;ROOT=BASE.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
OLD_HEIGHT=.58;HEIGHT=.72;RATIO=HEIGHT/OLD_HEIGHT

def build():
    destination=OUT/'full_jump_higher_preview_v002.blend'
    assert not destination.exists(),'Use a new version; never overwrite a reviewed preview'
    assert (ROOT/'.validation/full_jump_higher_preview_v002/backup_manifest.json').exists()
    s=bpy.context.scene;r=bpy.data.objects['FJ_Test_Rig'];travel=bpy.data.objects['Review_Only_Jump_Travel']
    assert r.parent==travel and s.frame_end==93 and s.render.fps==30
    originals={a.name:ui.action_signature(a) for a in bpy.data.actions}
    original=travel.animation_data.action
    assert original.name=='PREVIEW_ONLY_FullJump_Height'
    a=original.copy();a.name='PREVIEW_ONLY_FullJump_Height_V002';original.use_fake_user=True
    travel.animation_data.action=a;travel.animation_data.action_slot=a.slots[0]
    for c in ui.curves(a):
        assert c.data_path=='location'
        if c.array_index==2:
            for k in c.keyframe_points:
                k.co.y*=RATIO;k.handle_left.y*=RATIO;k.handle_right.y*=RATIO
            c.update()
    assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in originals.items())
    s.name='FULL_JUMP_HIGHER_PREVIEW_V002'
    s['purpose']='Pending presentation-only review: 0.72 m vs original 0.58 m; same in-place pose, timing and cameras; no export travel'
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s.frame_set(1)
    data={'status':'pending_presentation_review','pose_action':'Full_Jump_Expressive_Test','pose_action_unchanged':True,'skeletal_motion_variant_created':False,'original_preview':'../full_jump_preview.blend','original_height_m':OLD_HEIGHT,'height_m':HEIGHT,'increase_m':HEIGHT-OLD_HEIGHT,'increase_percent':(RATIO-1)*100,'height_ratio':RATIO,'frames':[1,93],'fps':30,'last_support_frame':19,'contact_frames':{'L':46,'R':47},'apex_frame':32.5,'landing_compression_frame':51,'rebound_frame':67,'preview_parent':travel.name,'preview_action':a.name,'original_action_signatures':originals,'cameras_lighting_materials_unchanged':True,'scope':'Only external preview Z elevation increases. No retiming, limb/hip changes, new skeletal Action, library import or Godot modification. Original preview and source remain unchanged.'}
    (OUT/'manifest.json').write_text(json.dumps(data,indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=str(destination));print('BUILT HIGHER PREVIEW ONLY',json.dumps(data),flush=True)

if __name__=='__main__':build()
