"""Native Blender renders at normal clock speed; reduced review sample rate."""
import bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'combat_strafe_r14_pass2_review'
d=json.loads((OUT/'design.json').read_text())
jobs=[('six_directions',d['showcase_scene']),('AB',d['ab_scene'])]+[('T'+str(i+1),x['scene']) for i,x in enumerate(d['transitions'])]
for title,name in jobs:
    s=bpy.data.scenes[name];bpy.context.window.scene=s;s.render.resolution_percentage=65;s.eevee.taa_render_samples=4
    # Keep the48fps evaluation clock; encode every2frames as24fps real time.
    s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
    dest=OUT/title;dest.mkdir(exist_ok=True)
    for i,f in enumerate(range(1,s.frame_end+1,2)):
        s.frame_set(f);s.render.filepath=str(dest/f'{i:04}.png');bpy.ops.render.render(write_still=True)
    print('RENDERED',title,flush=True)
