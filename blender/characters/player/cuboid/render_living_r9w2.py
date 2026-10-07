"""Reuse W1 render settings; process one live-Blender review job per invocation."""
from living_r9w2_common import *
import ast
tree=ast.parse((BASE/'render_living_r9w1.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='settings'],type_ignores=[]),'<W1 render settings>','exec'))
job=globals().get('JOB','stills');d=json.loads((OUT/'design.json').read_text())
if job=='stills':
 s=bpy.data.scenes['R9W2_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W2_Probe_Rig'];settings(s)
 for label,mode,f in [('Ready','Ready',25),('Left','Steering',49),('Reversal','Steering',145),('Right','Steering',193),('StockWorst','Steering',191.5),('SupportGapWorst','Steering',256.5)]:
  for abc,an in d['actions'][mode]['variants'].items():
   sample(r,s,bpy.data.actions[an],f,False,False)
   for view in ['Gameplay','Close','Side','Opposite','Distance']:
    s.camera=bpy.data.objects['R9W2_'+view];s.render.filepath=str(OUT/f'{label}_{abc}_{view}.png');bpy.ops.render.render(write_still=True)
else:
 s=bpy.data.scenes['R9W2_REVIEW_'+job];bpy.context.window.scene=s;settings(s)
 s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE';s.render.filepath=str(OUT/(job.lower()+'_ABC_24fps.mp4'));s.frame_start=1
 bpy.ops.render.render(animation=True)
