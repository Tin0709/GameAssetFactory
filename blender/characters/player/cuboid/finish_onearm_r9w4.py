"""Leave the live isolated file in a comparison state and save a live copy."""
from onearm_r9w4_common import *
assert Path(bpy.data.filepath).name=='player_weapon_onearm_r9w4_study.blend'
for name in ['validation.json','review_validation.json','motion_validation.json','camera_validation.json','media_validation.json','file_preservation.json']:
    evidence=json.loads((OUT/name).read_text());assert evidence['passed'],name
design=json.loads((OUT/'design.json').read_text());row=design['reviews']['Rifle_AimAround'];s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s;s.frame_set(73);s.render.fps=24;s.sync_mode='FRAME_DROP';bpy.context.view_layer.update()
r=bpy.data.objects[row['actors']['B']['rig']]
for ob in bpy.context.selected_objects:ob.select_set(False)
r.select_set(True);bpy.context.view_layer.objects.active=r
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.overlay.show_overlays=False;space.shading.type='MATERIAL';space.region_3d.view_perspective='CAMERA'
report=(OUT/'R9W4_REPORT.txt').read_text(encoding='utf-8-sig');text=bpy.data.texts.get('R9W4_REVIEW_REPORT') or bpy.data.texts.new('R9W4_REVIEW_REPORT');text.clear();text.write(report)
checkpoint=save_checkpoint();result={'checkpoint':str(checkpoint),'target':bpy.data.filepath,'scene':s.name,'frame':s.frame_current,'A':row['actors']['A']['upper'],'B':row['actors']['B']['upper'],'artistic_status':'AWAITING HUMAN REVIEW'}
(OUT/'review_state.json').write_text(json.dumps(result,indent=2))
