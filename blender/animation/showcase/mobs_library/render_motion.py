"""Render native-FPS cycles, then repeat closing-key-free cycles through VSE."""
import bpy,sys,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT));import gaf_mobs_animation_library as lib
lib.register();bpy.ops.wm.open_mainfile(filepath=str((OUT.parent if OUT.parent.name=='showcase' else OUT)/'Mobs_Animation_Library.blend'))
s=bpy.context.scene;r=bpy.data.objects['Zombie_Cuboid_Rig'];s.cycles.samples=8
s.render.resolution_x=448;s.render.resolution_y=448;s.render.resolution_percentage=100
reviews=OUT/'review';frames=OUT/'motion_frames';frames.mkdir(exist_ok=True)
records=[]
for i,kind in enumerate(['Idle','Walk']):
    s.mobs_active_index=i;lib.activate(s)
    for view in ['THREE_QUARTER','FRONT','SIDE']:
        s.camera=bpy.data.objects['Mobs Camera '+view]
        folder=frames/f'{kind}_{view}';folder.mkdir(exist_ok=True)
        for f in range(1,s.frame_end+1):
            path=folder/f'{f:04}.png'
            if path.exists():continue
            s.frame_set(f);s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        records.append({'kind':kind,'view':view,'frames':s.frame_end,'fps':30,'folder':str(folder),'cycles':3,'output':str(reviews/f'Zombie_{kind}_Original_V1_{view}_1x.mp4')})
(OUT/'motion_manifest.json').write_text(json.dumps(records,indent=2))
print('NATIVE_CYCLE_RENDER_COMPLETE',flush=True)
for record in records:
    edit_scene=bpy.data.scenes.new('Encoding '+record['kind']+' '+record['view'])
    edit_scene.render.resolution_x=448;edit_scene.render.resolution_y=448;edit_scene.render.resolution_percentage=100
    edit_scene.render.fps=30;edit_scene.frame_start=1;edit_scene.frame_end=record['frames']*record['cycles']
    edit_scene.render.use_sequencer=True;edit_scene.render.use_compositing=False
    edit_scene.view_settings.view_transform='Standard';edit_scene.view_settings.look='None'
    ed=edit_scene.sequence_editor_create()
    strip=ed.strips.new_image('Native motion',str(Path(record['folder'])/'0001.png'),channel=1,frame_start=1)
    for j in range(1,edit_scene.frame_end):strip.elements.append(f"{j%record['frames']+1:04}.png")
    strip.frame_final_duration=edit_scene.frame_end
    edit_scene.render.image_settings.media_type='VIDEO';edit_scene.render.image_settings.file_format='FFMPEG'
    edit_scene.render.ffmpeg.format='MPEG4';edit_scene.render.ffmpeg.codec='H264';edit_scene.render.ffmpeg.constant_rate_factor='MEDIUM'
    edit_scene.render.filepath=record['output']
    bpy.ops.render.render(animation=True,scene=edit_scene.name)
    bpy.data.scenes.remove(edit_scene)
print('SIX_NATIVE_SPEED_VIDEOS_COMPLETE',flush=True)
