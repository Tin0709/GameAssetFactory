"""Refine only the three existing Pending block meshes/materials; no new variants."""
import bpy,json,hashlib,sys
from pathlib import Path
D=Path(__file__).resolve().parent;P=D.parent;R=P.parents[3];E=R/'.validation/soft_textured_blocks_v001';LIB=P/'dungeons_ground_style_v2.blend'
assert bpy.app.background
assert hashlib.sha256(LIB.read_bytes()).hexdigest()==(E/'before.sha256').read_text().strip()
bpy.ops.wm.open_mainfile(filepath=str(LIB))
scene=bpy.context.scene;info=json.loads(scene['md2_flat_blocks_review']);palette=json.loads((D/'palette.json').read_text())
assert 'MD2_Soft_Blocks_Atlas_r2' not in bpy.data.images,'Never rerun over completed refinement'
image=bpy.data.images.load(str(D/'Soft_Blocks_MD2_Atlas.png'));image.name='MD2_Soft_Blocks_Atlas_r2';image.pack();image.filepath='//flat_blocks_md2_v001/Soft_Blocks_MD2_Atlas.png'
objects={k:bpy.data.objects[n] for k,n in info['objects'].items()}
allow={'objects':list(info['objects'].values()),'meshes':[o.data.name for o in objects.values()],'materials':[o.active_material.name for o in objects.values()]}
(E/'authorized_ids.json').write_text(json.dumps(allow))
for key,obj in objects.items():
 mesh=obj.data;old_positions=[tuple(v.co) for v in mesh.vertices];old_faces=[tuple(p.vertices) for p in mesh.polygons]
 uv=mesh.uv_layers.new(name='UV_MD2_Soft')
 face_tiles={}
 for polygon in mesh.polygons:
  if key=='Grass':tile='GrassTop' if polygon.normal.z>.5 else ('Dirt' if polygon.normal.z<-.5 else 'GrassSide')
  else:tile=key
  face_tiles[str(polygon.index)]=tile
  lo_u,lo_v,hi_u,hi_v=palette['atlas_rects'][tile]
  for loop_index in polygon.loop_indices:
   point=mesh.vertices[mesh.loops[loop_index].vertex_index].co
   if abs(polygon.normal.z)>.5:u=point.x+.5;v=point.y+.5
   elif abs(polygon.normal.x)>.5:u=point.y*polygon.normal.x+.5;v=point.z
   else:u=-point.x*polygon.normal.y+.5;v=point.z
   uv.data[loop_index].uv=(lo_u+u*(hi_u-lo_u),lo_v+v*(hi_v-lo_v))
 mat=obj.active_material;nodes=mat.node_tree.nodes;shader=nodes.get('Principled BSDF')
 tex=nodes.new('ShaderNodeTexImage');tex.name='Soft_MD2_Source_Patches';tex.image=image;tex.interpolation='Closest';tex.extension='EXTEND'
 uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map=uv.name
 mat.node_tree.links.new(uvnode.outputs['UV'],tex.inputs['Vector']);mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
 shader.inputs['Base Color'].default_value=(1,1,1,1)
 def linear(c):
  s=c/255.;return s/12.92 if s<=.04045 else ((s+.055)/1.055)**2.4
 mat.diffuse_color=(*[linear(c) for c in palette['blocks'][key]['srgb']],1)
 mat['srgb_hex']=palette['blocks'][key]['hex'];mat['texture_contrast']=palette['contrast_strength']
 obj['flat_color_hex']=palette['blocks'][key]['hex'];obj['color_method']=palette['blocks'][key]['method'];obj['texture_revision']='soft_texture_r2';obj['texture_face_tiles']=json.dumps(face_tiles)
 obj['source_texture']='assets/minecraft/textures/block/'+('grass_block_side' if key=='Grass' else key.lower())+'.png'
 obj['source_texture_sha256']=palette['source_sha256']['grass_block_side' if key=='Grass' else key.lower()]
 obj.asset_data.description='Pending / subtle16px pack-derived patches at25%contrast / '+('green grass cap over dirt sides and bottom' if key=='Grass' else key.lower()+' on all faces')+' / 1m block'
 assert old_positions==[tuple(v.co) for v in mesh.vertices] and old_faces==[tuple(p.vertices) for p in mesh.polygons]
info['revision']='soft_texture_r2';info['texture_contrast']=.25
scene['md2_flat_blocks_review']=json.dumps(info)
bpy.context.window.view_layer=scene.view_layers[info['layer']]
for obj in objects.values():obj.hide_set(False)
scene['md2_flat_blocks_selected']='All'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(E/'soft_blocks_stage.blend'),relative_remap=False,compress=True)
print('MD2_SOFT_BLOCKS_STAGE_READY',flush=True)
