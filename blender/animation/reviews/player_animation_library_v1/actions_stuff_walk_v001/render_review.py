import bpy
from pathlib import Path
HERE=Path(__file__).resolve().parent
s=bpy.data.scenes['ASW_Walking_Review_v001'];bpy.context.window.scene=s;s.camera=bpy.data.objects['Showcase_THREE_QUARTER']
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=8;s.cycles.use_denoising=True
s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
out=Path('/tmp/codex-player-walk-01a1399a/frames');out.mkdir(exist_ok=True)
for frame in range(1,25):
 s.frame_set(frame);s.render.filepath=str(out/f'walking_{frame:04}.png');bpy.ops.render.render(write_still=True,scene=s.name)
print('WALK_FRAMES_READY',flush=True)
