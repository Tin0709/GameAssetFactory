"""Readable turning evidence: camera-only tracking, original paths untouched."""
from hold_r10wh1_common import *
design=json.loads((OUT/'design.json').read_text())
for cat in ['Rifle','Shotgun','Pistol']:
    row=design['reviews'][cat+'_Turn'];s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s
    original=s.camera;name='R10WH1_'+cat+'_Turn_CloseCamera';assert name not in bpy.data.objects
    cam=original.copy();cam.data=original.data.copy();cam.name=name;s.collection.objects.link(cam)
    cam.data.ortho_scale=9.2
    rigs=[bpy.data.objects[row['actors'][label]['rig']] for label in ['A','B']]
    # Same world view direction; only the shared path translation is tracked.
    for f in range(1,457):
        s.frame_set(f);bpy.context.view_layer.update()
        midpoint=(rigs[0].matrix_world.translation+rigs[1].matrix_world.translation)*.5
        cam.location=(midpoint.x,midpoint.y+10,5.5)
        cam.keyframe_insert('location',frame=f)
    for c in curves(cam.animation_data.action):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    for ob in s.objects:
        if ob.type=='FONT' and ob.parent==original:
            ob.parent=cam;ob.location.y=9.2/(1920/900)/2-.17
    s.camera=cam;s.frame_set(1)
    row['context_movie']=cat+'_Turn_context_AB_24fps.mp4'
    row['camera_fit']='fixed direction / shared path translation tracking / ortho 9.2 m'
    row['camera_scale']=9.2
design['reviews_camera_note']='Closer turn review cameras only; original locomotion/path/facing preserved. Wide context movies retained.'
(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'close_turn_scenes':3,'camera_only':True}
