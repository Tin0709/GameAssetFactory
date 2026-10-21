"""Guarded additive tall-grass study; only also edits user-requested short-grass Z."""
import bpy,sys,json,math,random,hashlib,uuid
from pathlib import Path
from mathutils import Vector,Matrix
D=Path(__file__).resolve().parent;STUDY=D.parent;R=D.parents[4];E=R/'.validation/tall_grass_md2_v001';LIB=STUDY/'dungeons_ground_style_v2.blend'
sys.path[:0]=[str(STUDY),str(D)];from flower_preservation import snapshot,compare,mesh_content;from geometry import visible_bounds,asset_record
assert hashlib.sha256(LIB.read_bytes()).hexdigest()==(E/'before.sha256').read_text(),'Source changed since baseline; do not overwrite concurrent work'
bpy.ops.wm.open_mainfile(filepath=str(LIB));scene=bpy.context.scene
assert not bpy.data.collections.get('MD2_Tall_Grass_v001_PENDING'),'Never rebuild over completed candidates'
for name in ['Short Grass MD2','ViewLayer']:
 bpy.context.window.view_layer=scene.view_layers[name];bpy.context.view_layer.update()
baseline=json.loads((E/'before_fingerprints.json').read_text());assert not compare(baseline),compare(baseline)
# Latest explicit steering: the just-created SHORT grass should be half a block.
short_info=json.loads(scene['md2_review']);short_objects=[bpy.data.objects[n] for n in short_info['masters']];short_before={}
for o in short_objects:
 short_before[o.name]=mesh_content(o.data);im=next(n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE');top=visible_bounds(o.data,im)[2][1]
 for v in o.data.vertices:
  if v.co.z>0:v.co.z*=.5/top
 o.data.update()
(E/'before_short_meshes.json').write_text(json.dumps(short_before))
def col(name,parent):
 c=bpy.data.collections.new(name);parent.children.link(c);c['md2_tall_grass']=True;return c
root=col('MD2_Tall_Grass_v001_PENDING',bpy.data.collections['Vegetation_Grass_Pending']);root['review_status']='Pending';root['scope']='Tall grass / existing viewer / Blender review only'
masters=col('01_Tall_MD2_Candidates',root);review=col('02_Tall_MD2_Comparisons',root);patch=col('03_Tall_MD2_Grouped',root);studio=col('04_Tall_MD2_Review_Studio',root)
image=bpy.data.images.load(str(D/'Tall_Grass_MD2_v001_Atlas.png'));image.name='Tall MD2 — actual resource-pack tall grass derivatives';image.pack();image.filepath='//tall_grass_md2_v001/Tall_Grass_MD2_v001_Atlas.png'
texinfo=json.loads((D/'texture_manifest.json').read_text());mat=short_objects[0].data.materials[0].copy();mat.name='Tall MD2 — terrain-root two-sided cutout'
for n in mat.node_tree.nodes:
 if n.type=='TEX_IMAGE':n.image=image
mat['review_status']='Pending';mat['reference']='Actual tall_grass_top + tall_grass_bottom, Dungeons II Style0.7 JE; same short-grass green palette'
specs=[('A','Soft Meadow',.78,9,.54,.085,.22,(1.10,1.08)),('B','Open Fan',.94,10,.56,.105,.27,(1.22,1.12)),('C','Low Sweep',.72,8,.60,.10,.25,(1.12,1.14)),('D','Uneven Crown',.87,9,.50,.08,.23,(1.10,1.08))]
objects=[]
for idx,(suffix,label,height,count,width,radius,lean,footprint) in enumerate(specs):
 rng=random.Random(926+idx);verts=[];faces=[];uv=[];wind=[];ids=[]
 for ci in range(count):
  core=ci<3;az=ci*2.39996+idx*.52+rng.uniform(-.13,.13);tangent=Vector((math.cos(az),math.sin(az),0));out=Vector((-math.sin(az),math.cos(az),0))
  h=height*(1. if ci==0 else rng.uniform(.82,.97)) if core else height*rng.uniform(.52,.77)
  w=width*rng.uniform(.87,1.06);rad=radius*(.16 if core else 1.);bend=lean*(.32 if core else 1.)*rng.uniform(.88,1.1);start=len(verts)
  x,y,tw,th=texinfo['regions_top_left'][(idx+(ci%2 if not core else 0))%4]
  for t in (0.,.34,.70,1.):
   center=out*(rad+bend*t*t)+Vector((0,0,-.008+h*t))
   for side in [-1,1]:
    verts.append(tuple(center+tangent*side*w*(1.-.20*t)/2));wind.append(t*t);ids.append(ci)
    uv.append(((x+.5+(tw-1)*(side+1)/2)/128,1-(y+th-.5-(th-1)*t)/128))
  for ring in range(3):
   k=start+ring*2;faces.append((k,k+1,k+3,k+2))
 mesh=bpy.data.meshes.new('Tall_MD2_'+suffix+'_Layered_Strips');mesh.from_pydata(verts,[],faces);mesh.materials.append(mat);mesh.update();u=mesh.uv_layers.new(name='UV_Atlas');wm=mesh.uv_layers.new(name='Wind_Metadata')
 for p in mesh.polygons:
  for li in p.loop_indices:
   vi=mesh.loops[li].vertex_index;u.data[li].uv=uv[vi];wm.data[li].uv=(wind[vi],ids[vi]/(count-1))
 # Fit VISIBLE crown dimensions and height, while keeping compact root clusters.
 b=visible_bounds(mesh,image);sx=footprint[0]/(b[0][1]-b[0][0]);sy=footprint[1]/(b[1][1]-b[1][0]);sz=height/b[2][1]
 for v in mesh.vertices:
  v.co.x*=sx;v.co.y*=sy
  if v.co.z>0:v.co.z*=sz
 mesh.update();o=bpy.data.objects.new('Tall_Grass_MD2_v001_'+suffix,mesh);masters.objects.link(o);o.location=(idx*1.6,0,1);o['review_status']='Pending';o['variant']=label;o['cards']=count;o['reference_pack']='Dungeons II Style0.7 JE';o['review_only_no_godot']=True;o.visible_shadow=False
 anchors=o.vertex_groups.new(name='Wind_Anchors');anchors.add([i for i,t in enumerate(wind) if t==0],1.,'REPLACE');sway=o.vertex_groups.new(name='Wind_Sway')
 for i,t in enumerate(wind):sway.add([i],t,'REPLACE')
 o.asset_mark();o.asset_data.description='Pending / '+label+' / layered tall grass / source-texture study, authored geometry / no runtime export';objects.append(o)
# Different grouped architectures: three broad offset tufts, four tighter upright tufts.
for ci,parts in enumerate([[(0,-.26,-.12,.3,.65),(2,.27,-.10,2.0,.65),(3,0,.25,4.2,.60)],[(1,-.22,-.20,.2,.60),(3,.23,-.16,1.3,.60),(0,-.20,.22,2.7,.60),(2,.22,.20,4.0,.60)]]):
 verts=[];faces=[];coords=[]
 for index,ox,oy,angle,scale in parts:
  src=objects[index].data;rot=Matrix.Rotation(angle,3,'Z');offset=len(verts)
  for v in src.vertices:
   p=v.co.copy();p.x*=scale;p.y*=scale;verts.append(tuple(rot@p+Vector((ox,oy,0))))
  for p in src.polygons:faces.append(tuple(offset+i for i in p.vertices));coords.append([tuple(src.uv_layers['UV_Atlas'].data[i].uv) for i in p.loop_indices])
 mesh=bpy.data.meshes.new('Tall_MD2_Cluster_%03d_Editable'%(ci+1));mesh.from_pydata(verts,[],faces);mesh.materials.append(mat);u=mesh.uv_layers.new(name='UV_Atlas')
 for p,co in zip(mesh.polygons,coords):
  for li,xy in zip(p.loop_indices,co):u.data[li].uv=xy
 o=bpy.data.objects.new('Tall_Grass_MD2_Cluster_v%03d'%(ci+1),mesh);masters.objects.link(o);o.location=(7+ci*2.5,0,1);o['review_status']='Pending';o['variant']='Meadow Cluster' if ci==0 else 'Upright Cluster';o['cards']=sum(objects[i]['cards'] for i,*_ in parts);o.visible_shadow=False;o.asset_mark();o.asset_data.description='Pending / '+o['variant']+' / one mesh and shared material / no gameplay';objects.append(o)
# Original ground and comparison mesh data are linked unchanged.
base=bpy.data.objects['ENV_GrassBlock_DI_V3']
def linked(src,name,loc,collection):
 o=bpy.data.objects.new(name,src.data);collection.objects.link(o);o.location=loc;o.visible_shadow=src.visible_shadow;return o
for o in objects[:4]:linked(base,'Tall_MD2_Platform_'+o.name,(o.location.x,0,0),review)
for o in objects[4:]:
 for x in [-.5,.5]:
  for y in [-.5,.5]:linked(base,'Tall_MD2_ClusterBase_'+o.name+str(x)+str(y),(o.location.x+x,y,0),review)
comparison=[(short_objects[0],'SHORT MD2 / 0.5 BLOCK'),(objects[0],'TALL MD2 / A'),(bpy.data.objects['ENV_TallGrass_DI_V3'],'CURRENT TALL V3'),(bpy.data.objects['ENV_TallGoldenGrass_1m_V1'],'EXISTING GOLDEN')]
for i,(src,title) in enumerate(comparison):
 linked(base,'Tall_MD2_CompareBase_'+str(i),(i*1.6,3.4,0),review);linked(src,'Tall_MD2_Compare_'+title,(i*1.6,3.4,1),review)
for x in range(3):
 for y in range(2):linked(base,'Tall_MD2_FieldGround_%d_%d'%(x,y),(6.7+x,3.9+y,0),patch)
for i,(index,x,y,angle) in enumerate([(0,6.7,3.85,.1),(2,7.85,3.9,1.6),(3,8.6,4.7,2.5),(1,6.9,4.8,3.1)]):
 o=linked(objects[index],'Tall_MD2_Field_Tall_'+str(i),(x,y,1),patch);o.rotation_euler.z=angle;o.visible_shadow=False
 # Compact roots stay on the six ordinary terrain blocks.
 bpy.context.view_layer.update();roots=[o.matrix_world@v.co for v in o.data.vertices if v.co.z<0]
 for axis,(lo,hi) in enumerate([(6.21,9.19),(3.41,5.39)]):
  a=min(p[axis] for p in roots);b=max(p[axis] for p in roots)
  if a<lo:o.location[axis]+=lo-a
  elif b>hi:o.location[axis]-=b-hi
for i,(x,y) in enumerate([(6.4,4.3),(7.7,4.8),(8.7,3.7)]):
 o=linked(short_objects[i%4],'Tall_MD2_Field_Short_'+str(i),(x,y,1),patch);o.rotation_euler.z=.4*i;o.visible_shadow=False
# Labels, floor and soft studio lights are new data, scoped to the new layer.
labelmat=bpy.data.materials.new('Tall_MD2_Review_Label');labelmat.diffuse_color=(.68,.76,.64,1.)
def label(text,loc,size=.13):
 c=bpy.data.curves.new('Tall_MD2_Label','FONT');c.body=text;c.align_x='CENTER';c.size=size;c.materials.append(labelmat);o=bpy.data.objects.new('Tall_MD2_Label_'+text,c);studio.objects.link(o);o.location=loc
for i,o in enumerate(objects):label(chr(65+i) if i<4 else 'CLUSTER '+str(i-3),(o.location.x,-.72 if i<4 else -1.18,.012),.16)
for i,(_,title) in enumerate(comparison):label(title,(i*1.6,2.65,.012),.115)
label('TALL GRASS MD2  /  PENDING',(4.8,-1.85,.012),.24);label('MIXED SHORT + TALL',(7.7,5.7,.012),.16)
f=bpy.data.meshes.new('Tall_MD2_Studio_Floor');f.from_pydata([(-80,-80,-.026),(80,-80,-.026),(80,80,-.026),(-80,80,-.026)],[],[(0,1,2,3)]);f.materials.append(bpy.data.materials['REVIEW_Studio_Charcoal_Soft_V2']);o=bpy.data.objects.new('Tall_MD2_Studio_Floor',f);studio.objects.link(o)
for name,pos,power,size,color in [('Key',(0,-4,10),850,7,(1,.96,.87)),('Fill',(9,5,8),450,6,(.82,.91,1))]:
 d=bpy.data.lights.new('Tall_MD2_'+name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new('Tall_MD2_'+name,d);studio.objects.link(o);o.location=pos;o.rotation_euler=(Vector((4,1,1))-o.location).to_track_quat('-Z','Y').to_euler()
def camera(key,pos,target,scale):
 d=bpy.data.cameras.new('Tall_MD2_Camera_'+key);d.type='ORTHO';d.ortho_scale=scale;o=bpy.data.objects.new(d.name,d);studio.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o.name
cameras={'Overview':camera('Overview',(16,-20,18),(4.8,1.5,1.1),14.8),'Compare':camera('Compare',(9,-4,6),(2.4,3.4,1.25),7.8),'Grouped':camera('Grouped',(10.8,.0,4.8),(7.7,4.35,1.3),4.6),'Gameplay':camera('Gameplay',(12,-2,7.5),(7.7,4.35,1.2),6.7),'Opposite':camera('Opposite',(6.3,7,3.0),(7.7,4.35,1.35),4.4),'Side':camera('Side',(2.7,-.25,1.95),(0,0,1.38),2.05)}
for i,o in enumerate(objects):cameras[o['variant']]=camera(o['variant'],(o.location.x+1.2,-2.3,2.6),(o.location.x,0,1.35),2.15 if i<4 else 2.8)
layer=scene.view_layers.new('Tall Grass MD2')
def contains(c):return c==root or any(contains(child) for child in c.children)
def configure(lc,inside=False):
 keep=inside or contains(lc.collection);lc.exclude=not keep
 if keep:
  for child in lc.children:configure(child,inside or lc.collection==root)
for child in layer.layer_collection.children:configure(child)
def find(lc,c):
 if lc.collection==c:return lc
 for child in lc.children:
  result=find(child,c)
  if result:return result
for old in ['ViewLayer','Short Grass MD2']:find(scene.view_layers[old].layer_collection,root).exclude=True
scene['md2_tall_review']=json.dumps({'layer':layer.name,'original_layer':'ViewLayer','short_layer':short_info['layer'],'cameras':cameras,'masters':[o.name for o in objects],'original_camera':scene.camera.name})
# New catalog line is published only after fresh-open validation passes.
catalog=str(uuid.uuid5(uuid.NAMESPACE_URL,'GameAssetFactory/Environment/TallGrassMD2Pending'))
for o in objects:o.asset_data.catalog_id=catalog
manifest={'status':'Pending','central_library':str(LIB),'layer':layer.name,'source_reference':texinfo,'assets':[asset_record(o,image) for o in objects],'new_materials_for_assets':1,'atlas_size':[128,128],'mixed_field_tall_count':4,'mixed_field_short_count':3,'catalog_line':catalog+':Environment/Tall Grass MD2 Pending:Tall Grass MD2 Pending\n','cameras':cameras,'new_scenes':0,'new_actions':0,'no_godot_integration':True,'short_height_user_change':{'target_visible_height_m':.5,'assets':[asset_record(o,next(n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')) for o in short_objects]}}
(D/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Normalize old evaluated caches and check every old datum except authorized short Z.
for name in ['Short Grass MD2','ViewLayer']:
 bpy.context.window.view_layer=scene.view_layers[name];bpy.context.view_layer.update()
allowed_mesh={o.data.name for o in short_objects};errors=[p for p in compare(baseline) if not(p[0]=='meshes' and p[1] in allowed_mesh)];assert not errors,errors
bpy.context.window.view_layer=layer
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   s=area.spaces.active;s.use_local_camera=True;s.camera=bpy.data.objects[cameras['Overview']];s.region_3d.view_perspective='CAMERA';s.region_3d.view_camera_zoom=0;s.show_region_ui=True;s.overlay.show_overlays=False
bpy.context.preferences.filepaths.save_version=0;destination=E/LIB.name;bpy.ops.wm.save_as_mainfile(filepath=str(destination),relative_remap=False,compress=True)
print('TALL_GRASS_BUILT',json.dumps(manifest['assets']),flush=True)
