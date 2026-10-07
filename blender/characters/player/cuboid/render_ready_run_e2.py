"""Render A/B/C at normal 24 FPS with 1.60 Run cadence already sampled."""
import bpy,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent
out=BASE/'ready_run_e2_review';out.mkdir(exist_ok=True)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
mode=args[0] if args else 'Detail'
s=bpy.data.scenes['E2_Run_ABC_'+mode];bpy.context.window.scene=s
s.render.engine='BLENDER_EEVEE';s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGB'
s.render.filepath=str(out/(mode+'_'))
bpy.ops.render.render(animation=True)
