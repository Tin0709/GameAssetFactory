"""Render original saved source Actions using the same review-stage functions.

Extract function definitions only; never execute the central installer here.
No .blend or registry is modified. Frames are regenerable outside Git.
"""
import bpy,json,sys,ast,math
from pathlib import Path
from mathutils import Matrix,Vector
H=Path(__file__).resolve().parent;R=H.parents[4];sys.path.insert(0,str(H));import motion as m
meta=json.loads((H/'source_metadata.json').read_text(encoding='utf8'))
native=bpy.data.objects[meta['rig']];native_mesh=bpy.data.objects[meta['mesh']]
tree=ast.parse((H/'install.py').read_text(encoding='utf8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'review_stage_functions','exec'))
floor_mat=material('ASPrimary_Preview_Stage',(.085,.115,.15));ink=material('ASPrimary_Preview_Ink',(.78,.9,1),True);gridmat=material('ASPrimary_Preview_Grid',(.20,.31,.38))
s,cameras,hud,lights=stage('Original_Source_Preview','ORIGINAL WALK / RUN  |  A&S-INSPIRED','PENDING  |  ORIGINAL KEYS  |  IN-PLACE COMPARISON  |  NO GODOT CHANGE',150)
for i,spec in enumerate(meta['specs'][:2]):
 actor(s,spec,i,((i-.5)*2.7*12/math.sqrt(208),(i-.5)*2.7*8/math.sqrt(208),0))
for i,label in enumerate(['WALK  1.20 Hz / 1.50 m stride','RUN  1.60 Hz / 2.69 m stride']):text(s,'ASPrimary_Source_Column_'+str(i),label,hud,((i-.5)*2.7,1.65,-4),.13)
bpy.context.window.scene=s
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=960;s.render.resolution_y=600
sh=s.display.shading;sh.light='STUDIO';sh.color_type='TEXTURE';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.show_specular_highlight=False;sh.background_type='WORLD'
s.display.render_aa='8';s.render.image_settings.file_format='PNG'
out=R/'.validation/animation_showcase/as_primary_locomotion_original_v001/preview_frames';out.mkdir(exist_ok=True)
for i in range(75):
 s.frame_set(1+2*i);s.render.filepath=str(out/('%03d.png'%i));bpy.ops.render.render(write_still=True,scene=s.name)
print('SOURCE_PREVIEW_RENDERED_75_FRAMES_30HZ',flush=True)
