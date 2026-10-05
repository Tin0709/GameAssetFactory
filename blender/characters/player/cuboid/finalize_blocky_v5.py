from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid\create_blocky_run_v5_pass5.py');s=p.read_text(encoding='utf-8-sig')
s=s.replace("assert root_travel<1e-7", """for pose in details:
    d=pose['arm_leg_forward_component']
    if pose['frame'] in [1,17]:assert d['Arm.L']>0 and d['Leg.R']>0 and d['Arm.R']<0 and d['Leg.L']<0
    if pose['frame']==9:assert d['Arm.R']>0 and d['Leg.L']>0 and d['Arm.L']<0 and d['Leg.R']<0
assert root_travel<1e-7""")
s+='''
    # Bounded live review only: 24 FPS, then 12 FPS, restore 24 and stop at frame 1.
    # No action/key data changes during playback inspection.
    review_window=bpy.context.window;review_stage_state={'stage':0}
    def run_preview_review():
        try:
            assert Path(bpy.data.filepath)==TEST
            with bpy.context.temp_override(window=review_window):
                if review_window.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
                stage=review_stage_state['stage'];scene.frame_set(1)
                if stage<2:
                    scene.render.fps=24 if stage==0 else 12
                    bpy.ops.screen.animation_play();review_stage_state['stage']+=1
                    print('PASS5_REVIEW_FPS='+str(scene.render.fps),flush=True)
                    return 6.0
                scene.render.fps=24
                bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
                print('PASS5_REVIEW_DONE_24FPS_READY',flush=True)
            return None
        except Exception:
            scene.render.fps=24
            with bpy.context.temp_override(window=review_window):
                if review_window.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
            raise
    bpy.app.timers.register(run_preview_review,first_interval=.5)
'''
p.write_text(s,encoding='utf-8')
