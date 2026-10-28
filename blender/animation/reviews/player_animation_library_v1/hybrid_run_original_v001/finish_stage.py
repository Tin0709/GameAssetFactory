import bpy,sys,json,runpy,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
runpy.run_path(str(ROOT/'scripts/load_showcase_ui.py'),run_name='__main__')
s=bpy.data.scenes['Hybrid_Run_Comparison_v001_PENDING'];entry=json.loads(s['gaf_review_entry_json'])
for i in [0,2]:
 c=bpy.data.objects['Hybrid_Run_Comparison_Carrier_'+str(i+1)];c.location=((i-1)*2.4*12/math.sqrt(208),(i-1)*2.4*8/math.sqrt(208),0)
for mat in bpy.data.materials:
 if not mat.name.startswith('Hybrid_Run_'):continue
 color=mat.diffuse_color[:];mat.use_nodes=True
 if 'Ink' in mat.name:
  mat.node_tree.nodes.clear();out=mat.node_tree.nodes.new('ShaderNodeOutputMaterial');em=mat.node_tree.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=color;em.inputs[1].default_value=.85;mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
 else:
  node=mat.node_tree.nodes.get('Principled BSDF');node.inputs['Base Color'].default_value=color;node.inputs['Roughness'].default_value=.9
hud=bpy.data.objects['Hybrid_Run_HUD'];rows=[o for o in list(hud.children)if o.type=='FONT' and o.data.body.startswith('V1 SUBTLE')]
for o in rows:bpy.data.objects.remove(o,do_unlink=True)
ink=bpy.data.materials['Hybrid_Run_HUD_Ink']
for i,label in enumerate(['V1 SUBTLE','V2 BALANCED','V3 EXPRESSIVE']):
 curve=bpy.data.curves.new('Hybrid_Run_Variant_Header','FONT');curve.body=label;curve.size=.18;curve.align_x='CENTER';curve.materials.append(ink);o=bpy.data.objects.new('Hybrid_Run_Variant_Header',curve);s.collection.objects.link(o);o.parent=hud;o.location=((i-1)*2.4,2.2,-4)
s.render.engine='CYCLES';s.cycles.samples=16;s.frame_set(1)
bpy.context.window.scene=s
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/animation/showcase/Animation_Showcase.blend'))
for frame in [9,17]:
 s.frame_set(frame);s.render.filepath=str(HERE/('comparison_%03d.png'%frame));bpy.ops.render.render(write_still=True,scene=s.name)
print('COMPARISON_STAGE_RENDERED',flush=True)
