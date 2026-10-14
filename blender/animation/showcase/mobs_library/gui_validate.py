"""Native window playback test in a separate Blender process; never touches player windows."""
import bpy,time,json,traceback
from pathlib import Path
OUT=Path(__file__).resolve().parent
TARGET=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/Mobs_Animation_Library.blend')
assert Path(bpy.data.filepath)==TARGET
state={'stage':'start','wraps':0,'last':1,'start':time.monotonic(),'results':[]}
STAGES=['idle','walk','source_idle','source_walk']

def op(name,**kwargs):
    window=bpy.context.window_manager.windows[0]
    area=next(a for a in window.screen.areas if a.type=='VIEW_3D')
    with bpy.context.temp_override(window=window,screen=window.screen,area=area):
        return getattr(bpy.ops.mobs,name)(**kwargs)

def playing():return bpy.context.window_manager.windows[0].screen.is_animation_playing
def begin(index,stage):
    s=bpy.context.scene;s.mobs_active_index=index;s.mobs_loop=True
    s.sync_mode='NONE'
    op('restart');op('play_pause')
    assert playing()
    state.update(stage=stage,wraps=0,last=1,start=time.monotonic())

def tick():
    try:
        s=bpy.context.scene
        # macOS can defer drawing of another Blender instance. Force a native
        # draw/swap without manually advancing frames; playback still owns time.
        window=bpy.context.window_manager.windows[0]
        with bpy.context.temp_override(window=window,screen=window.screen):bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP',iterations=1)
        if state['stage']=='start':begin(0,'idle');return .12
        if s.frame_current<state['last']:state['wraps']+=1
        state['last']=s.frame_current
        if state['stage'] in STAGES:
            if state['wraps']<2:
                assert time.monotonic()-state['start']<(s.frame_end/30)*2+12,'Playback failed to complete two native loops'
                return .12
            op('play_pause');assert not playing()
            state['results'].append({'clip':state['stage'],'two_wraps':True,'pause':True})
            op('restart');assert s.frame_current==1
            index=STAGES.index(state['stage'])
            if index<3:begin(index+1,STAGES[index+1]);return .12
            s.mobs_loop=False;s.frame_set(s.frame_end-4);op('play_pause')
            state.update(stage='one_shot',start=time.monotonic());return .12
        if state['stage']=='one_shot':
            if playing():
                assert time.monotonic()-state['start']<3,'Loop-off did not pause at the final frame'
                return .12
            assert s.frame_current==s.frame_end
            state['results'].append({'loop_off_stops_at_end':True})
            s.mobs_loop=True;s.mobs_active_index=3;op('restart')
            for area in bpy.context.window.screen.areas:
                if area.type=='VIEW_3D':
                    area.spaces.active.show_region_ui=True
                    area.spaces.active.overlay.show_overlays=False
                    area.spaces.active.region_3d.view_perspective='CAMERA'
            bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
            bpy.ops.wm.open_mainfile(filepath=str(TARGET))
            state.update(stage='reopened',start=time.monotonic());return .5
        if state['stage']=='reopened':
            assert s.mobs_mob=='Zombie' and len(s.mobs_clips)==4
            assert all(c.status=='Pending' for c in s.mobs_clips)
            assert not s.mobs_error and s.mobs_active_index==3
            state['results'].append({'saved_reopened_sidebar':True,'all_four_pending':True})
            (OUT/'validation_gui.json').write_text(json.dumps({'passed':True,'checks':state['results'],'target':str(TARGET)},indent=2))
            print('NATIVE_GUI_PASS',flush=True)
            return None
    except Exception:
        error=traceback.format_exc()
        (OUT/'validation_gui.json').write_text(json.dumps({'passed':False,'error':error,'state':state},indent=2))
        print(error,flush=True)
        return None

bpy.app.timers.register(tick,first_interval=2,persistent=True)
