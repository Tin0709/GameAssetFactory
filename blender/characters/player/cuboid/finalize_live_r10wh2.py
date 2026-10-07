from hold_r10wh2_common import *
design=json.loads((OUT/'design.json').read_text());s=bpy.data.scenes[design['showcases']['Hold']['scene']];bpy.context.window.scene=s;s.frame_set(25);s.render.fps=24;s.sync_mode='FRAME_DROP';s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
for ob in bpy.context.selected_objects:ob.select_set(False)
rig=bpy.data.objects[design['showcases']['Hold']['actors']['Rifle']['rig']];rig.select_set(True);bpy.context.view_layer.objects.active=rig
name='R10WH2_REVIEW_REPORT';t=bpy.data.texts.get(name) or bpy.data.texts.new(name);t.clear();t.write((OUT/'R10WH2_REPORT.txt').read_text(encoding='utf-8'))
state={'scene':s.name,'frame':25,'fps':24,'active_object':rig.name,'artistic_status':'AWAITING HUMAN REVIEW','study_only':True,'checkpoint':checkpoint()};(OUT/'review_state.json').write_text(json.dumps(state,indent=2));result=state
