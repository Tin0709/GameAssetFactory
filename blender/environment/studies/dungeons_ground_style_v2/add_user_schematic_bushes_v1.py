"""Live exact user schematic assemblies and physically mapped half-height leaf templates."""
import bpy,json,sys,copy,hashlib
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Create/save only in current foreground source window'
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE));from flower_preservation import compare
from leaf_planar_geometry_v1 import records,clip,make_mesh,contacts,trimmed
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve();base=json.loads((EVIDENCE/'before_user_schematic_bushes_fingerprints.json').read_text(encoding='utf-8'));assert not compare(base['data']);assert not bpy.data.collections.get('USER_BushDesign_Litematic_V1')
layouts=json.loads((HERE/'user_litematic_layouts_v1.json').read_text(encoding='utf-8'));outer=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];inner=bpy.data.materials['MAT_LeafModules_V1_Interior_088Linear'];halfcollection=bpy.data.collections.new('LEAF_MODULES_HalfBlock_V1');bpy.context.scene.collection.children.link(halfcollection);templates={};half_reports=[]
# Half-height derived source; no global/full-library scale. Side UVs are cropped, not squashed.
for variant,x in zip(('A','B','C'),(25.5,27.6,29.7)):
 full=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];source=full.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh();items=[]
 for record in records(source):
  r=copy.deepcopy(record)
  if r['part']==0 and r['side']==4:
   for c in r['corners']:c['p'].z=.5
   items.append(r)
  else:
   r=clip(r,.5,False)
   if r:items.append(r)
 full.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear();mesh=make_mesh('ENV_LeafSlab_1x1x05m_V1_'+variant+'_Core',items,outer);obj=bpy.data.objects.new('ENV_LeafSlab_1x1x05m_V1_'+variant,mesh);halfcollection.objects.link(obj);obj.location=(x,7.8,0);obj['core_m']=[1,1,.5]
 bush=[]
 for record in records(bpy.data.objects[full.name+'_BushyFoliage'].data):
  r=copy.deepcopy(record)
  if r['side']==4:
   for c in r['corners']:c['p'].z=.5+(c['p'].z-1)*.5
   ps=[c['p']for c in r['corners']];width=(ps[1]-ps[0]).length;height=(ps[3]-ps[0]).length;uc=sum((c['u']for c in r['corners']),Vector((0,0)))/4
   for c,(a,b)in zip(r['corners'],((-1,-1),(1,-1),(1,1),(-1,1))):c['u']=uc+Vector((a*width*.5,b*height*.5))
   bush.append(r)
  elif sum(c['p'].z for c in r['corners'])/len(r['corners'])<.5:bush.append(r)
 bm=make_mesh(obj.name+'_BushyLayerPlanes',bush,outer);bo=bpy.data.objects.new(obj.name+'_BushyFoliage',bm);halfcollection.objects.link(bo);bo.parent=obj
 interior=[r for r in records(bpy.data.objects[full.name+'_DenseInterior'].data)if sum(c['p'].z for c in r['corners'])/len(r['corners'])<.5];im=make_mesh(obj.name+'_DenseInteriorPlanes',interior,inner);io=bpy.data.objects.new(obj.name+'_DenseInterior',im);halfcollection.objects.link(io);io.parent=obj;templates[(variant,.5)]=(obj,bo,io);half_reports.append({'variant':variant,'object':obj.name,'core_m':[1,1,.5],'bushy_planes':len(bm.polygons),'interior_planes':len(im.polygons)})
for variant in('A','B','C'):
 o=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];templates[(variant,1)]=(o,bpy.data.objects[o.name+'_BushyFoliage'],bpy.data.objects[o.name+'_DenseInterior'])
# Shared neutral floor for both separately placed designs and actual1.8m scale actor.
review=bpy.data.collections.new('REVIEW_User_Schematic_Bushes_V1');bpy.context.scene.collection.children.link(review);floor_mat=bpy.data.materials['MAT_LeafModule_StudioFloor']
def floor(name,bounds,collection):
 x0,y0,x1,y1=bounds;m=bpy.data.meshes.new(name);m.from_pydata([(x0,y0,-.012),(x1,y0,-.012),(x1,y1,-.012),(x0,y1,-.012)],[],[(0,1,2,3)]);m.materials.append(floor_mat);o=bpy.data.objects.new(name,m);collection.objects.link(o)
floor('REVIEW_UserSchematic_StudioFloor',(33.8,5.5,46.5,12),review);floor('REVIEW_HalfLeafModules_StudioFloor',(24.3,6.5,31,9.1),halfcollection)
results=[]
for design_index,(design,cname,origin)in enumerate(zip(layouts['designs'],('USER_BushDesign_Litematic_V1','USER_111_Litematic_V1'),((36,9,0),(42,9,0)))):
 collection=bpy.data.collections.new(cname);bpy.context.scene.collection.children.link(collection);root=bpy.data.objects.new(cname+'_Root',None);collection.objects.link(root);root.location=origin;cells=design['cells'];lo=[min(c['blender_bottom_center'][k]-(.5 if k<2 else 0)for c in cells)for k in range(3)];hi=[max(c['blender_bottom_center'][k]+(.5 if k<2 else c['height_m'])for c in cells)for k in range(3)];offset=Vector(((lo[0]+hi[0])*.5,(lo[1]+hi[1])*.5,lo[2]));spec=[]
 for i,cell in enumerate(cells):
  height=cell['height_m'];full,bushy,inside=templates[('A',height)];contact=contacts(cells,i);source=full.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh();coreitems=trimmed(records(source),contact,'core');full.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear();name=cname+'_Cell_'+str(i);mesh=make_mesh(name+'_Core',coreitems,outer);obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);obj.parent=root;obj.location=Vector(cell['blender_bottom_center'])-offset;obj['minecraft_xyz']=cell['minecraft_xyz'];obj['source_block_state']=json.dumps(cell['block_state']);obj['nominal_height_m']=height
  bmesh=make_mesh(name+'_ExposedBushyPlanes',trimmed(records(bushy.data),contact,'bushy'),outer);bo=bpy.data.objects.new(name+'_BushyFoliage',bmesh);collection.objects.link(bo);bo.parent=obj;io=bpy.data.objects.new(name+'_DenseInterior',inside.data);collection.objects.link(io);io.parent=obj
  spec.append({'object':name,'blender_local_bottom_center':list(obj.location),'source_minecraft_xyz':cell['minecraft_xyz'],'source_bottom_center':cell['blender_bottom_center'],'height_m':height,'slab_type':cell['slab_type'],'contact_intervals':contact})
 label=bpy.data.objects['REVIEW_LeafModule_A_Label'].copy();label.data=label.data.copy();label.name=cname+'_Label';collection.objects.link(label);label.location=(origin[0]-1.4,6.05,.015);label.data.size=.13;label.data.body=('BUSH DESIGN /6 FULL LEAF BLOCKS'if design_index==0 else'111 /5 FULL +4 HALF LEAF BLOCKS')+'\n1 BLOCK =1 m / R15 REST 1.8 m'
 results.append({'name':cname,'source_file':design['source_file'],'stored_source':'schematics/'+Path(design['source_file']).name,'source_sha256':design['source_sha256'],'axis_transform':design['axis_transform'],'display_root':origin,'source_recenter_offset':list(offset),'structural_bounds_local':[[lo[k]-offset[k]for k in range(3)],[hi[k]-offset[k]for k in range(3)]],'cells':spec})
for x in range(34,47):
 m=bpy.data.meshes.new('REVIEW_UserSchematic_Metre_'+str(x));m.from_pydata([(x,5.5,-.009),(x+.012,5.5,-.009),(x+.012,12,-.009),(x,12,-.009)],[],[(0,1,2,3)]);o=bpy.data.objects.new(m.name,m);review.objects.link(o)
rig=bpy.data.objects['REVIEW_LeafModules_R15_Rest_Rig'].copy();rig.data=rig.data.copy();rig.name='REVIEW_UserSchematic_R15_Rest_Rig';review.objects.link(rig);rig.location=(45.3,9,0);actor=bpy.data.objects['REVIEW_LeafModules_R15_Rest_1p8m'].copy();actor.name='REVIEW_UserSchematic_R15_Rest_1p8m';review.objects.link(actor);actor.parent=rig
for mod in actor.modifiers:
 if mod.type=='ARMATURE':mod.object=rig
old=bpy.data.collections['LEAF_CLUSTER_Plus_6Blocks_V1'];old.hide_viewport=True;old.hide_render=True
assert not compare(base['data']),'All existing authored source objects/mesh/material/UV/color data preserved'
manifest={'status':'Exact two user schematics, current leaf style; artistic review pending','designs':results,'half_sources':half_reports,'half_method':'Core sides clipped to.5, top surface moved to.5; lower exterior/interior layer kept, top exterior tilted rise halved. PhysicalUVdensity512/m retained without verticaltile squash','partial_contacts':'Full-to-bottomslab sides clip only occludedlower.5m; exposedupperhalf retained. Top/bottom side contacts only when actualheightintervals touch.','old_plus':'Frozen comparison collection hidden; oldbulk remainspaused','baseline_digest':base['digest'],'scope':'Live sameBlenderfile/window, no game integration'};(HERE/'user_schematic_bushes_v1_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
# Selected half templates rest exports; fullmodule source exports remain byte-identical.
for variant in('A','B','C'):
 core,bo,io=templates[(variant,.5)]
 for o in list(bpy.context.selected_objects):o.select_set(False)
 for o in(core,bo,io):o.select_set(True)
 bpy.context.view_layer.objects.active=core;display=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update()
 try:bpy.ops.export_scene.gltf(filepath=str(HERE/'exports'/('leaf_slab_1x1x05m_v1_'+variant.lower()+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=True)
 finally:core.location=display;bpy.context.view_layer.update()
for o in list(bpy.context.selected_objects):o.select_set(False)
bpy.data.objects['USER_BushDesign_Litematic_V1_Root'].select_set(True);bpy.context.view_layer.objects.active=bpy.data.objects['USER_BushDesign_Litematic_V1_Root']
for window in bpy.context.window_manager.windows:
 for area in window.screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False;space.region_3d.view_location=(40.1,9,1);space.region_3d.view_distance=12;space.region_3d.view_rotation=(Vector((40.1,9,1))-Vector((47,2,6))).to_track_quat('-Z','Y');space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False);result={'status':'Two exact schematic assemblies +half sources LIVE and saved','designs':results,'half_sources':half_reports}
