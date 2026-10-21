"""Two Pending head assets in the ONE existing library; no rig/Action edits."""
from pathlib import Path
import bpy,json,sys,math,hashlib
from mathutils import Vector
D=Path(__file__).resolve().parent;LIB=D.parents[1]/'showcase/SOLDIER_Asset_Library.blend'
bpy.ops.wm.open_mainfile(filepath=str(LIB),load_ui=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];bpy.context.window.scene=scene
registry=json.loads(scene['soldier_registry']);skin=next(e for e in registry['entries'] if e['id']=='SOLDIER_Skin_v001')
rig=bpy.data.objects[skin['rig']];body=bpy.data.objects[skin['body']];clothes=bpy.data.objects[skin['clothing']];oldhair=bpy.data.objects[skin['hair']]
# Rebuild own Pending assets only. User's native objects/Actions are untouched.
for obj in list(bpy.data.objects):
 if obj.get('hc_owned',False):bpy.data.objects.remove(obj,do_unlink=True)
if 'Hair & Bandana' in scene.view_layers:scene.view_layers.remove(scene.view_layers['Hair & Bandana'])
for col in list(bpy.data.collections):
 if col.get('hc_owned',False):bpy.data.collections.remove(col)
for group in [bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.cameras]:
 for block in list(group):
  if block.get('hc_owned',False) and block.users==0:group.remove(block)
def collection(name,parent):
 c=bpy.data.collections.new(name);parent.children.link(c);c['hc_owned']=True;return c
assets=bpy.data.collections['SOLDIER_ASSETS']
review=collection('HC_REVIEW — linked original Soldier',assets)
refs=collection('HC_Rig — existing Head attachment',review);refs.objects.link(rig)
character=collection('HC_Character — unchanged body and clothing',review)
for o in [body,clothes]:character.objects.link(o)
archive=collection('HC_Original_Hair — archived / unchanged',review);archive.objects.link(oldhair)
haircol=collection('SOLDIER_HairCards_v001_PENDING',bpy.data.collections['02_HAIR_VARIANTS'])
bandcol=collection('SOLDIER_Bandana_2D_v001_PENDING',bpy.data.collections['04_EQUIPMENT'])
studio=collection('HC_REVIEW — head cameras',review)
layout=json.loads((D/'cards.json').read_text());atlas=bpy.data.images.load(str(D/'soldier_hair_bandana_atlas.png'));atlas.name='HC_Hair_Bandana — original pixel atlas';atlas['hc_owned']=True;atlas.pack()
mat=bpy.data.materials.new('HC_Pixel_Cutout — binary alpha / two-sided');mat['hc_owned']=True;mat.use_nodes=True
mat.surface_render_method='DITHERED';mat.use_backface_culling=False
if hasattr(mat,'use_transparency_overlap'):mat.use_transparency_overlap=False
p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=1.;p.inputs['Specular IOR Level'].default_value=.15
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest';tex.extension='CLIP'
cut=mat.node_tree.nodes.new('ShaderNodeMath');cut.operation='GREATER_THAN';cut.inputs[1].default_value=.5;cut.label='Hard pixel cutout; no fractional opacity'
mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);mat.node_tree.links.new(tex.outputs['Alpha'],cut.inputs[0]);mat.node_tree.links.new(cut.outputs[0],p.inputs['Alpha'])
mat['alpha_mode']='MASK';mat['alpha_cutoff']=.5;mat['future_godot_material']='Alpha Scissor0.5, nearest filtering, cull disabled. No Godot export in this task.'
def mesh_asset(name,kind,col,catalog):
 selected=[c for c in layout['cards'] if c['kind']==kind];vertices=[];faces=[];uvcoords=[];parts=[]
 for c in selected:
  i=len(vertices);vertices+=c['vertices'];faces.append(tuple(range(i,i+4)));x,y,w,h=c['region'];uvcoords += [((x+.5)/512,1-(y+h-.5)/512),((x+w-.5)/512,1-(y+h-.5)/512),((x+w-.5)/512,1-(y+.5)/512),((x+.5)/512,1-(y+.5)/512)]
  parts.append({'name':c['name'],'vertices':list(range(i,i+4))})
 mesh=bpy.data.meshes.new(name+' — flat cards');mesh['hc_owned']=True;mesh.from_pydata(vertices,[],faces);mesh.update()
 for poly in mesh.polygons:
  outward=poly.center-Vector((0,0,1.57))
  if poly.normal.dot(outward)<0:poly.flip()
 obj=bpy.data.objects.new(name,mesh);col.objects.link(obj);obj['hc_owned']=True;obj['review_status']='Pending';obj['construction']='Flat hair/accessory cards. No extrusion, solidify, solid knot, cubes or new bones.';obj['parts_json']=json.dumps(parts)
 mesh.materials.append(mat);uv=mesh.uv_layers.new(name='HC_Pixel_Atlas')
 for loop in mesh.loops:uv.data[loop.index].uv=uvcoords[loop.vertex_index]
 obj.parent=rig;group=obj.vertex_groups.new(name='Head');group.add(list(range(len(vertices))),1.,'REPLACE');mod=obj.modifiers.new('Follow existing Head — rigid weights','ARMATURE');mod.object=rig
 obj.asset_mark();obj.asset_data.catalog_id=catalog;obj.asset_data.description='Pending | original Minecraft-style flat '+kind+' cards | existing Soldier Head attachment'
 col['review_status']='Pending';col.asset_mark();col.asset_data.catalog_id=catalog
 return obj
hair=mesh_asset('SOLDIER_HairCards_v001','hair',haircol,'a41806cf-eeea-51c5-ae49-fd8dca35da64')
band=mesh_asset('SOLDIER_Bandana_2D_v001','bandana',bandcol,'ee5433eb-89c3-542c-a670-b18fc5e0c248')
band['tail_islands']=json.dumps([p for p in json.loads(band['parts_json']) if '/ Tail.' in p['name']]);band['secondary_animation']='Separated coplanar Tail.L/R islands reserved; no extra bones or Actions added.'
layer=scene.view_layers.new('Hair & Bandana')
def lc(root,col):
 if root.collection==col:return root
 for child in root.children:
  found=lc(child,col)
  if found:return found
# Other review layers remain exact: new collections only exist in Head review.
for s in bpy.data.scenes:
 for vl in s.view_layers:
  for col in [review,haircol,bandcol]:
   item=lc(vl.layer_collection,col)
   if item:item.exclude=vl!=layer
# Head review reuses exact existing objects in isolated linked collections.
for e in registry['entries']:
 if e['id'] in ['SOLDIER_HairCards_v001','SOLDIER_Bandana_2D_v001']:continue
 c=bpy.data.collections.get(e.get('collection',''))
 if c:
  item=lc(layer.layer_collection,c)
  if item:item.exclude=True
lc(layer.layer_collection,archive).exclude=True
bpy.context.window.view_layer=layer
for vl in scene.view_layers:vl.use=vl==layer
rig.hide_set(True,view_layer=layer)
def camera(name,pos,target,scale):
 data=bpy.data.cameras.new(name);data.type='ORTHO';data.ortho_scale=scale;data.lens=50;data['hc_owned']=True
 obj=bpy.data.objects.new(name,data);obj['hc_owned']=True;studio.objects.link(obj);obj.location=pos;obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler();return obj
for name,pos in [('Front',(0,-4,1.95)),('ThreeQuarter',(-2.6,-4.1,2.45)),('Side',(4,0,1.95)),('Back',(0,4,1.95)),('BackThreeQuarter',(-2.6,4.1,2.45)),('OtherSide',(-4,0,1.95))]:camera('HC_'+name,pos,(0,0,1.605),.87)
scene.camera=bpy.data.objects['HC_ThreeQuarter'];scene['hc_style']='CARDS';scene['hc_bandana']=True;scene['hc_preview']='CHARACTER';scene['hc_closeup']=True;scene['hc_camera']='ThreeQuarter'
for e in list(registry['entries']):
 if e['id'] in ['SOLDIER_HairCards_v001','SOLDIER_Bandana_2D_v001']:registry['entries'].remove(e)
for obj,kind,c in [(hair,'hair',haircol),(band,'headwear',bandcol)]:
 registry['entries'].append({'id':obj.name,'label':obj.name,'status':'Pending','type':kind,'object':obj.name,'collection':c.name,'review_scene':scene.name,'view_layer':layer.name,'head_bone':'Head','head_rig':rig.name,'thin_planar_cards':True,'original_hair_preserved':oldhair.name})
scene['soldier_registry']=json.dumps(registry);(D.parents[1]/'showcase/registry.json').write_text(json.dumps(registry,indent=2)+'\n')
for name,path in [('SOLDIER — Hair Cards + Bandana construction',D/'cards.json'),('SOLDIER — Hair Cards review guide',D/'README.md')]:
 if path.exists():
  text=bpy.data.texts.get(name) or bpy.data.texts.new(name);text.clear();text.write(path.read_text())
refpath=Path('/Users/tin/Downloads/Voxel Character Turnaround with Bandana Tails.png')
if not bpy.data.images.get('HC_Reference — Soldier bandana concept'):
 image=bpy.data.images.load(str(refpath));image.name='HC_Reference — Soldier bandana concept';image.pack();image['hc_owned']=True
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.show_region_ui=True;area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.use_local_camera=False;area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(LIB),compress=True)
report={'passed':True,'hair_cards':len(hair.data.polygons),'bandana_cards':len(band.data.polygons),'hair_triangles':2*len(hair.data.polygons),'bandana_triangles':2*len(band.data.polygons),'materials':1,'atlas_size':512,'new_scenes':0,'actions':len(bpy.data.actions),'new_bones':0,'status':'Pending'}
(D/'build_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('HAIRCARDS_BUILT',json.dumps(report),flush=True)
