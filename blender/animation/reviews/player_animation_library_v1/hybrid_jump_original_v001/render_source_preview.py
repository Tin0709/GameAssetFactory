import bpy,json,sys
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parents[4];sys.path.insert(0,str(H));import stage,motion as m
meta=json.loads((H/'source_metadata.json').read_text(encoding='utf8'))
s,carrier,rig,mesh,a,cameras,hud=stage.build(bpy.data.objects[meta['rig']],bpy.data.objects[meta['mesh']],bpy.data.actions[meta['actions'][-1]],m)
bpy.context.window.scene=s;s.render.engine='BLENDER_WORKBENCH';sh=s.display.shading;sh.color_type='TEXTURE';sh.show_shadows=False;sh.show_cavity=True;sh.background_type='WORLD';s.display.render_aa='8'
out=R/'.validation/animation_showcase/hybrid_jump_original_v001/preview_frames';out.mkdir(exist_ok=True)
for i in range(60):
 s.frame_set(1+2*i);s.render.filepath=str(out/('%03d.png'%i));bpy.ops.render.render(write_still=True,scene=s.name)
for d in ['FRONT','SIDE']:
 s.camera=bpy.data.objects[cameras[d]];hud.parent=s.camera
 for f in [40,59]:
  s.frame_set(f);s.render.filepath=str(H/('review_'+d.lower()+'_'+str(f)+'.png'));bpy.ops.render.render(write_still=True,scene=s.name)
print('JUMP_SOURCE_PREVIEW_RENDERED',flush=True)
