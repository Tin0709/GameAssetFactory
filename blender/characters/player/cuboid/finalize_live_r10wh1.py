from hold_r10wh1_common import *
design=json.loads((OUT/'design.json').read_text())
s=bpy.data.scenes[design['reviews']['Rifle_AimAround']['scene']]
bpy.context.window.scene=s;s.frame_set(73);s.render.fps=24;s.sync_mode='FRAME_DROP'
# Show the paired review through its camera when this file is opened.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.shading.type='MATERIAL'
for o in bpy.context.selected_objects:o.select_set(False)
rig=bpy.data.objects[design['reviews']['Rifle_AimAround']['actors']['B']['rig']]
rig.select_set(True);bpy.context.view_layer.objects.active=rig
name='R10WH1_REVIEW_REPORT';t=bpy.data.texts.get(name) or bpy.data.texts.new(name)
t.clear();t.write((OUT/'R10WH1_REPORT.txt').read_text(encoding='utf-8'))
state={'scene':s.name,'frame':s.frame_current,'active_object':rig.name,'fps':24,
       'study_only':True,'artistic_status':'AWAITING HUMAN REVIEW','checkpoint':checkpoint()}
(OUT/'review_state.json').write_text(json.dumps(state,indent=2));result=state
