"""Add five Pending short-grass assets to the EXISTING environment study only."""
import bpy,sys,json,math,random,hashlib,uuid
from pathlib import Path
from mathutils import Vector,Matrix
D=Path(__file__).resolve().parent;STUDY=D.parent;R=STUDY.parents[3];EV=R/'.validation/short_grass_md2_v001';LIB=STUDY/'dungeons_ground_style_v2.blend'
sys.path.insert(0,str(STUDY));from flower_preservation import snapshot,compare
bpy.ops.wm.open_mainfile(filepath=str(LIB),load_ui=True)
assert not bpy.data.collections.get('MD2_Short_Grass_v001_PENDING'),'One additive build only; use the recorded baseline for a revision.'
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;original_layer=bpy.context.view_layer;original_camera=scene.camera
baseline=snapshot();(EV/'before_fingerprints.json').write_text(json.dumps(baseline))
assert hashlib.sha256(LIB.read_bytes()).hexdigest()==(EV/'before.sha256').read_text()
def col(name,parent):
 c=bpy.data.collections.new(name);parent.children.link(c);c['md2_short_grass']=True;return c
root=col('MD2_Short_Grass_v001_PENDING',bpy.data.collections['Vegetation_Grass_Pending']);root['review_status']='Pending';root['scope']='Short grass only / Blender review / no runtime integration'
masters=col('01_MD2_Candidates_A_B_C_D_Cluster',root);review=col('02_MD2_Review_Ground_And_Comparisons',root);patch=col('03_MD2_Grouped_Ground_Cover',root);studio=col('04_MD2_Review_Cameras_Labels_Studio',root)
image=bpy.data.images.load(str(D/'Short_Grass_MD2_v001_Atlas.png'));image.name='MD2_ShortGrass — pack-derived crisp pixel atlas';image.pack();image.filepath='//short_grass_md2_v001/Short_Grass_MD2_v001_Atlas.png'
texinfo=json.loads((D/'texture_manifest.json').read_text())
mat=bpy.data.materials.new('MD2_ShortGrass — terrain-matched cutout');mat.use_nodes=True;mat.use_backface_culling=False;mat.surface_render_method='DITHERED';mat.alpha_threshold=.5
mat['alpha_mode']='MASK';mat['alpha_cutoff']=.5;mat['review_status']='Pending';mat['reference']='Dungeons II Style0.7 JE short_grass.png; tinted to existing terrain roots'
nt=mat.node_tree;p=nt.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=1.;p.inputs['Specular IOR Level'].default_value=0.
tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest';tex.extension='EXTEND';uvnode=nt.nodes.new('ShaderNodeUVMap');uvnode.uv_map='UV_Atlas';nt.links.new(uvnode.outputs['UV'],tex.inputs['Vector'])
clip=nt.nodes.new('ShaderNodeMath');clip.operation='GREATER_THAN';clip.inputs[1].default_value=.5;nt.links.new(tex.outputs['Color'],p.inputs['Base Color']);nt.links.new(tex.outputs['Alpha'],clip.inputs[0]);nt.links.new(clip.outputs[0],p.inputs['Alpha'])
# Terrain-aligned soft leaf normals retain a modest side response, no emission.
g=nt.nodes.new('ShaderNodeNewGeometry')
n=nt.nodes.new('ShaderNodeCombineXYZ');n.inputs['Z'].default_value=.86;mult=nt.nodes.new('ShaderNodeVectorMath');mult.operation='SCALE';mult.inputs[3].default_value=.14;nt.links.new(g.outputs['Normal'],mult.inputs[0]);add=nt.nodes.new('ShaderNodeVectorMath');add.operation='ADD';nt.links.new(n.outputs[0],add.inputs[0]);nt.links.new(mult.outputs[0],add.inputs[1]);nt.links.new(add.outputs[0],p.inputs['Normal'])
# Reuse the current Fluffy study's proven thin-foliage transmission. Both
# lobes are clipped, so reverse-light cards stay readable without emission.
trans=nt.nodes.new('ShaderNodeBsdfTranslucent');trans.name='MD2_ThinLeaf_Transmission';nt.links.new(tex.outputs['Color'],trans.inputs['Color']);nt.links.new(add.outputs[0],trans.inputs['Normal'])
shader_add=nt.nodes.new('ShaderNodeAddShader');nt.links.new(p.outputs[0],shader_add.inputs[0]);nt.links.new(trans.outputs[0],shader_add.inputs[1])
transparent=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader');nt.links.new(clip.outputs[0],mix.inputs[0]);nt.links.new(transparent.outputs[0],mix.inputs[1]);nt.links.new(shader_add.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],nt.nodes.get('Material Output').inputs['Surface'])
mat['thin_leaf_lighting']='Terrain-up weighted normal on both card sides, diffuse + thin transmission, both binary cutout; no emission.'
# Core shape families: differentiated architecture, not just colour variants.
specs=[('A','Low Cushion',.202,8,.27,.075,.074),('B','Broad Fan',.242,7,.31,.080,.108),('C','Soft Rosette',.172,9,.29,.105,.115),('D','Uneven Tuft',.282,7,.235,.055,.065)]
objects=[];card_specs={}
for idx,(suffix,label,height,count,width,radius,lean) in enumerate(specs):
 rng=random.Random(741+idx);v=[];f=[];uv=[];weights=[];ids=[];records=[]
 for ci in range(count):
  core=ci<3;az=(ci*2.39996+idx*.43)+(rng.random()-.5)*.25
  tangent=Vector((math.cos(az),math.sin(az),0));out=Vector((-math.sin(az),math.cos(az),0))
  h=height*(1. if ci==0 else rng.uniform(.80,.96)) if core else height*rng.uniform(.50,.73)
  w=width*(rng.uniform(.90,1.07) if core else rng.uniform(.64,.85));rad=radius*(.15 if core else 1.)
  bend=lean*(.30 if core else 1.)*(.85+rng.random()*.3)
  start=len(v);tile=(idx+(ci%2 if not core else 0))%4;x,y,tw,th=texinfo['regions_top_left'][tile]
  for t in (0.,.48,1.):
   centre=out*(rad+bend*t*t)+Vector((0,0,-.008+h*t))
   # Broad, blunt leaf groups taper gently; roots are all on the terrain surface.
   for side in [-1,1]:
    v.append(tuple(centre+tangent*side*w*(1.-.22*t)/2));weights.append(t*t);ids.append(ci)
    u=(x+.5+(tw-1)*(side+1)/2)/128;vv=1-(y+th-.5-(th-1)*t)/64;uv.append((u,vv))
  f.extend([(start,start+1,start+3,start+2),(start+2,start+3,start+5,start+4)])
  records.append({'height':h,'width':w,'azimuth':az,'root_radius':rad,'outward_bend':bend,'core':core})
 mesh=bpy.data.meshes.new('MD2_'+suffix+'_Editable_Card_Strips');mesh.from_pydata(v,[],f);mesh.update();mesh.materials.append(mat)
 mapping=mesh.uv_layers.new(name='UV_Atlas');wind=mesh.uv_layers.new(name='Wind_Metadata')
 for poly in mesh.polygons:
  for li in poly.loop_indices:
   vi=mesh.loops[li].vertex_index;mapping.data[li].uv=uv[vi];wind.data[li].uv=(weights[vi],ids[vi]/max(1,count-1))
 obj=bpy.data.objects.new('Short_Grass_MD2_v001_'+suffix,mesh);masters.objects.link(obj);obj.location=(idx*1.35,0,1);obj['review_status']='Pending';obj['variant']=label;obj['cards']=count;obj['root_penetration_m']=.008;obj['only_review_no_godot']=True;obj['reference_pack']='Dungeons II Style0.7 JE';obj.visible_shadow=False
 group=obj.vertex_groups.new(name='Wind_Anchors');group.add([i for i,t in enumerate(weights) if t==0],1.,'REPLACE')
 group=obj.vertex_groups.new(name='Wind_Sway')
 for i,t in enumerate(weights):group.add([i],t,'REPLACE')
 obj.asset_mark();obj.asset_data.description='Pending / '+label+' / short ground-grown layered grass / source-style research / no runtime integration'
 objects.append(obj);card_specs[obj.name]=records
# A genuinely denser one-mesh cluster, with bottom-centred local origin.
verts=[];faces=[];coords=[]
for k,(ox,oy,angle,scale) in enumerate([(-.19,-.17,.3,.86),(.18,-.15,1.1,.82),(-.18,.17,2.3,.90),(.17,.17,3.1,.76),(0,0,.7,1.02)]):
 src=objects[k%4];m=src.data;offset=len(verts);rot=Matrix.Rotation(angle,3,'Z')
 verts.extend([tuple(rot@vert.co*scale+Vector((ox,oy,0))) for vert in m.vertices])
 for poly in m.polygons:
  faces.append(tuple(offset+i for i in poly.vertices));coords.append([tuple(m.uv_layers['UV_Atlas'].data[li].uv) for li in poly.loop_indices])
mesh=bpy.data.meshes.new('MD2_Cluster_Editable');mesh.from_pydata(verts,[],faces);mesh.materials.append(mat);u=mesh.uv_layers.new(name='UV_Atlas')
for poly,co in zip(mesh.polygons,coords):
 for li,p in zip(poly.loop_indices,co):u.data[li].uv=p
cluster=bpy.data.objects.new('Short_Grass_MD2_Cluster_v001',mesh);masters.objects.link(cluster);cluster.location=(5.6,0,1);cluster.visible_shadow=False;cluster['review_status']='Pending';cluster['cards']=sum(objects[k%4]['cards'] for k in range(5));cluster.asset_mark();cluster.asset_data.description='Pending / five offset short tufts in one editable mesh, one shared material.';objects.append(cluster)
# Latest user requirement: every individual bush spans at least one block in
# both horizontal axes. Bake the wider footprint; retain authored short heights.
for obj,(width,length) in zip(objects,[(1.03,1.01),(1.15,1.02),(1.10,1.12),(1.02,1.04),(1.35,1.30)]):
 bounds=[max(v.co[i] for v in obj.data.vertices)-min(v.co[i] for v in obj.data.vertices) for i in [0,1]]
 for v in obj.data.vertices:v.co.x*=width/bounds[0];v.co.y*=length/bounds[1]
 obj.data.update();obj['minimum_footprint_m']='1 x 1';obj['width_m']=width;obj['length_m']=length
 obj.asset_data.description+=' / at least 1 x 1 block footprint'
# Linked existing ground/grass comparisons. Never edit their shared mesh/materials.
base=bpy.data.objects['ENV_GrassBlock_DI_V3']
def linked(src,name,loc,collection):
 obj=bpy.data.objects.new(name,src.data);collection.objects.link(obj);obj.location=loc;return obj
for obj in objects[:4]:linked(base,'MD2_Platform_'+obj.name,(obj.location.x,0,0),review)
for x in [-.5,.5]:
 for y in [-.5,.5]:linked(base,'MD2_Cluster_Base_'+str(x)+'_'+str(y),(5.6+x,y,0),review)
for x,name in [(7.1,'ENV_Grass_DI_V3'),(8.45,'ShortGrass_Fluffy_v1_SageGreen')]:
 linked(base,'MD2_Existing_Platform_'+str(x),(x,0,0),review);source=bpy.data.objects[name];copy=linked(source,'MD2_Comparison_'+name,(x,0,1),review);copy.visible_shadow=False
# A3x2m mixed patch seen at gameplay distance and from the opposite light side.
for x in range(3):
 for y in range(2):linked(base,'MD2_Field_Ground_%d_%d'%(x,y),(1.0+x,2.65+y,0),patch)
for x in range(3):
 for y in range(2):
  source=objects[(x+y*2)%4];o=bpy.data.objects.new('MD2_Field_Tuft_%02d'%(x*2+y),source.data);patch.objects.link(o);o.location=(1+x,2.65+y,1);o.rotation_euler.z=math.radians([0,11,-9,5,-12,8][x*2+y]);o.visible_shadow=False
  # Every geometric root is physically over the actual block footprint.
  bpy.context.view_layer.update();roots=[o.matrix_world@v.co for v in o.data.vertices if v.co.z<0.]
  bounds=[(min(p[i] for p in roots),max(p[i] for p in roots)) for i in [0,1]]
  for axis,(lo,hi) in enumerate([(.51,3.49),(2.16,4.14)]):
   a,b=bounds[axis]
   if a<lo:o.location[axis]+=lo-a
   elif b>hi:o.location[axis]-=b-hi
# All presentation additions stay in this one new review collection/view layer.
labelmat=bpy.data.materials.new('MD2_Review_Type');labelmat.diffuse_color=(.68,.76,.64,1.)
def label(body,loc,size=.14):
 d=bpy.data.curves.new('MD2_Label','FONT');d.body=body;d.size=size;d.align_x='CENTER';obj=bpy.data.objects.new('MD2_Label_'+body,d);studio.objects.link(obj);obj.location=loc;d.materials.append(labelmat)
for obj in objects:label(obj.name.replace('Short_Grass_MD2_v001_','').replace('Short_Grass_MD2_Cluster_v001','CLUSTER'),(obj.location.x,-1.18 if obj==cluster else -.70,.012),.15)
for x,title in [(7.1,'CURRENT V3'),(8.45,'CURRENT FLUFFY')]:label(title,(x,-.70,.012),.11)
label('SHORT GRASS MD2  /  PENDING',(4.1,-1.80,.012),.21)
label('MIXED GROUND COVER  /  3 x 2 m',(2.,4.45,.012),.17)
# A new floor uses the unchanged studio material without altering the old floor.
floor_mat=bpy.data.materials.get('REVIEW_Studio_Charcoal_Soft_V2') or bpy.data.materials.get('Studio_Charcoal')
fmesh=bpy.data.meshes.new('MD2_Review_Floor');fmesh.from_pydata([(-80,-80,-.025),(80,-80,-.025),(80,80,-.025),(-80,80,-.025)],[],[(0,1,2,3)])
floor=bpy.data.objects.new('MD2_Review_Floor',fmesh);studio.objects.link(floor)
if floor_mat:fmesh.materials.append(floor_mat)
def light(name,pos,power,size,color):
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);studio.objects.link(o);o.location=pos;o.rotation_euler=(Vector((3,1,.9))-o.location).to_track_quat('-Z','Y').to_euler()
light('MD2_Soft_Key',(0,-4,9),850,7,(1,.96,.87));light('MD2_Soft_Fill',(7,4,7),450,6,(.82,.91,1.))
def camera(name,pos,target,scale):
 d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale;o=bpy.data.objects.new(name,d);studio.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
cams={}
cams['Overview']=camera('MD2_Camera_Overview',(12,-16,15),(4.1,1.25,.70),12.0)
cams['Compare']=camera('MD2_Camera_Compare',(11,-13,9),(4.1,0,.85),11.1)
for obj in objects:
 x=obj.location.x;key=obj['variant'] if 'variant' in obj else 'Cluster';cams[key]=camera('MD2_Camera_'+key,(x+1.2,-2.1,2.3),(x,0,1.12),1.65 if obj!=cluster else 1.90)
cams['Grouped']=camera('MD2_Camera_Grouped',(4,-1.5,4.6),(2,3.1,1.07),3.8)
cams['Gameplay']=camera('MD2_Camera_Gameplay',(6,-3,6),(2,3.1,1.06),6.4)
cams['Opposite']=camera('MD2_Camera_Opposite',(0,6,3),(2,3.1,1.05),3.6)
layer=scene.view_layers.new('Short Grass MD2')
def enable_tree(lc):
 keep=lc.collection==root or lc.collection.name=='Vegetation_Grass_Pending' or lc.collection in [masters,review,patch,studio]
 lc.exclude=not keep
 if keep:
  for child in lc.children:enable_tree(child)
for child in layer.layer_collection.children:enable_tree(child)
# Existing layer stays exactly as it was, with just the new additions excluded.
def find(lc,c):
 if lc.collection==c:return lc
 for child in lc.children:
  result=find(child,c)
  if result:return result
find(original_layer.layer_collection,root).exclude=True
bpy.context.window.view_layer=layer
scene['md2_review'] = json.dumps({'layer':layer.name,'old_layer':original_layer.name,'original_camera':original_camera.name if original_camera else '', 'cameras':{k:o.name for k,o in cams.items()},'masters':[o.name for o in objects]})
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.use_local_camera=True;space.camera=cams['Overview'];space.region_3d.view_perspective='CAMERA';space.region_3d.view_camera_zoom=0;space.overlay.show_overlays=False;space.show_region_ui=True
   space.shading.type='MATERIAL';space.shading.studio_light='forest.exr';space.shading.studiolight_intensity=1.;space.shading.use_scene_lights=False;space.shading.use_scene_world=False
for o in bpy.context.selected_objects:o.select_set(False)
objects[0].select_set(True);layer.objects.active=objects[0]
scene.camera=original_camera
assert not compare(baseline),compare(baseline)
# Namespaced native catalog, keeping all previous catalogs.
cat=STUDY/'blender_assets.cats.txt';catalog=str(uuid.uuid5(uuid.NAMESPACE_URL,'GameAssetFactory/Environment/ShortGrassMD2Pending'))
text=cat.read_text() if cat.exists() else '# This is an Asset Catalog Definition file for Blender.\nVERSION 1\n\n'
line=catalog+':Environment/Short Grass MD2 Pending:Short Grass MD2 Pending\n'
if line not in text:cat.write_text(text.rstrip()+'\n'+line)
for obj in objects:obj.asset_data.catalog_id=catalog
manifest={'status':'Pending','source_reference':texinfo,'central_library':str(LIB),'new_scene_count':0,'no_godot_integration':True,'layer':layer.name,'cameras':{k:o.name for k,o in cams.items()},'original_layer':original_layer.name,'original_camera':original_camera.name if original_camera else '', 'assets':[],'mixed_patch_tufts':6,'material':mat.name,'new_materials_for_assets':1,'atlas_size':[128,64],'root_gap_m':0,'cards':card_specs,'user_footprint_requirement':'Every bush is at least 1 block wide AND 1 block long; 1 block = 1 m. Height remains short.'}
for obj in objects:
 mesh=obj.data;manifest['assets'].append({'name':obj.name,'triangles':sum(len(p.vertices)-2 for p in mesh.polygons),'vertices':len(mesh.vertices),'cards':int(obj['cards']),'z_min':min(v.co.z for v in mesh.vertices),'height_above_surface':max(v.co.z for v in mesh.vertices),'xy_size':[max(v.co[i] for v in mesh.vertices)-min(v.co[i] for v in mesh.vertices) for i in [0,1]],'materials':len(mesh.materials),'minimum_one_block_footprint':True})
(D/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(EV/'after_fingerprints.json').write_text(json.dumps(snapshot()))
bpy.ops.wm.save_as_mainfile(filepath=str(LIB),compress=True)
print('MD2_GRASS_CREATED',json.dumps(manifest['assets']),flush=True)
