"""Native Blender review-only scatter study. Does not export or mutate production."""
import bpy, math, random, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
D=Path(__file__).resolve().parent
SOURCE=D.parent/'grass_block_reference_v4/grass_block_reference_v4.blend'
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.name='ENV_Scatter_Set_V1_Showcase'
def coll(name):
 c=bpy.data.collections.new(name);s.collection.children.link(c);return c
rocks=coll('01 • ROCKS | 2 small · 2 medium · 2 large')
dirts=coll('02 • GROUND | four ochre tile variants')
flowers={c:coll('03 • FLOWERS | '+c.upper()) for c in ('purple','yellow','white','red')}
refs=coll('04 • V4 REFERENCE | copied, static')
show=coll('05 • PRESENTATION | plinths · labels · lights · cameras')
vig=coll('06 • VIGNETTE | linked asset instances')
palette=[('Stone',(123,130,120)),('StoneLight',(143,150,138)),('SoilTop',(162,130,77)),('SoilSide',(133,101,58)),('SoilBottom',(117,88,52)),('Stem',(67,111,56)),('Leaf',(91,135,66)),('Purple',(158,119,186)),('Yellow',(226,187,67)),('White',(224,224,201)),('Red',(190,73,64)),('Pollen',(217,164,55)),('DarkCenter',(107,77,47))]
N=128;pix=[0.0]*(N*N*4);rng=random.Random(821)
for tile,(_,rgb) in enumerate(palette):
 tx=(tile%4)*32;ty=(tile//4)*32
 for y in range(ty,ty+32):
  for x in range(tx,tx+32):
   k=(y*N+x)*4;pix[k:k+4]=[v/255 for v in rgb]+[1]
 for i in range(16 if tile<5 else 6):
  x=rng.randrange(tx+2,tx+29);y=rng.randrange(ty+2,ty+29);delta=rng.choice((-6,-4,4,6))
  for dx,dy in ((0,0),(1,0),(1,1))[:rng.choice((1,2,3))]:
   k=((y+dy)*N+x+dx)*4;pix[k:k+4]=[max(0,min(255,v+delta))/255 for v in rgb]+[1]
img=bpy.data.images.new('SCATTER_Palette_128_Opaque',width=N,height=N,alpha=True);img.pixels.foreach_set(pix);img.update();img.pack()
mat=bpy.data.materials.new('SCATTER • muted pixel palette | packed nearest');mat.use_nodes=True
nd=mat.node_tree.nodes;p=nd.get('Principled BSDF');p.inputs['Roughness'].default_value=1;p.inputs['Specular IOR Level'].default_value=.12
t=nd.new('ShaderNodeTexImage');t.image=img;t.interpolation='Closest';mat.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
class Mesh:
 def __init__(self):self.v=[];self.f=[];self.tiles=[]
 def box(self,c,dim,tile,rot=None,side=None,bottom=None):
  x,y,z=[v/2 for v in dim];pts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
  idx=len(self.v)
  for pt in pts:self.v.append(tuple((rot@Vector(pt) if rot else Vector(pt))+Vector(c)))
  ff=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
  for n,f in enumerate(ff):self.f.append(tuple(idx+i for i in f));self.tiles.append(bottom if n==0 and bottom is not None else side if n>1 and side is not None else tile)
 def grid(self,heights,unit,tile,side=None,bottom=None):
  nx=len(heights);ny=len(heights[0]);ff=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
  # Surface-only voxels; adjoining cells share no hidden faces.
  for x in range(nx):
   for y in range(ny):
    for z in range(heights[x][y]):
     cx=(x-(nx-1)/2)*unit[0];cy=(y-(ny-1)/2)*unit[1];cz=(z+.5)*unit[2]
     vx,vy,vz=[u/2 for u in unit];points=[(cx-vx,cy-vy,cz-vz),(cx+vx,cy-vy,cz-vz),(cx+vx,cy+vy,cz-vz),(cx-vx,cy+vy,cz-vz),(cx-vx,cy-vy,cz+vz),(cx+vx,cy-vy,cz+vz),(cx+vx,cy+vy,cz+vz),(cx-vx,cy+vy,cz+vz)]
     for f,(dx,dy,dz) in zip(ff,[(0,0,-1),(0,0,1),(0,-1,0),(1,0,0),(0,1,0),(-1,0,0)]):
      ax,ay,az=x+dx,y+dy,z+dz
      occupied=0<=ax<nx and 0<=ay<ny and 0<=az<heights[ax][ay]
      if occupied:continue
      start=len(self.v);self.v.extend(points[i] for i in f);self.f.append(tuple(range(start,start+4)));self.tiles.append(bottom if dz<0 and bottom is not None else side if dz==0 and side is not None else tile)
 def object(self,name,collection,pos=(0,0,0),asset=False,category='',variant=''):
  if asset:
   lo=[min(p[i] for p in self.v) for i in range(3)];hi=[max(p[i] for p in self.v) for i in range(3)];offset=((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]);self.v=[tuple(p[i]-offset[i] for i in range(3)) for p in self.v]
  me=bpy.data.meshes.new(name+' • native mesh');me.from_pydata(self.v,[],self.f);me.materials.append(mat);me.update();uv=me.uv_layers.new(name='UV_Atlas')
  for poly,tile in zip(me.polygons,self.tiles):
   tx=(tile%4)*32;ty=(tile//4)*32;uvs=[((tx+2)/128,(ty+2)/128),((tx+30)/128,(ty+2)/128),((tx+30)/128,(ty+30)/128),((tx+2)/128,(ty+30)/128)]
   for li,v in zip(poly.loop_indices,uvs):uv.data[li].uv=v
  o=bpy.data.objects.new(name,me);collection.objects.link(o);o.location=pos
  if asset:
   o['scatter_asset']=True;o['category']=category;o['variant']=variant;o['pivot']='bottom centre; authored mesh-local metres';o.asset_mark();o.asset_data.description='Voxel meadow '+category+' / '+variant+'; bottom-centred, 1m V4 scale.'
   for tag in ('environment','voxel','scatter',category,variant):o.asset_data.tags.new(tag)
  return o
assets=[];xrock=[-4.1,-2.95,-1.65,-.2,1.3,2.8]
shapes=[[[1,1,0],[1,2,1],[0,1,1]],[[0,1,1],[1,2,1],[1,1,0]],[[1,2,1],[2,3,2],[1,2,0]],[[0,1,2],[1,3,2],[1,2,1]],[[1,2,1],[2,3,2],[1,2,2]],[[1,2,0],[2,3,2],[1,2,1]]]
for i,w in enumerate((.3,.4,.58,.68,.86,.95)):
 m=Mesh();m.grid(shapes[i],(w/3,w*.82/3,w*.50/max(max(row) for row in shapes[i])),i%2)
 cat=('Small','Small','Medium','Medium','Large','Large')[i];assets.append(m.object(f'ENV_Rock_{cat}_{i%2+1:02}',rocks,(xrock[i],2.35,.045),True,'rock',cat.lower()))
for i,(w,dep,h) in enumerate(((.65,.65,.12),(.85,.65,.17),(.9,.8,.2),(1,.75,.23))):
 m=Mesh();hs=([[1,1,1],[1,1,1],[1,1,1]],[[0,1,1],[1,1,1],[1,1,0]],[[1,1,1],[1,2,1],[1,1,1]],[[0,1,1,0],[1,1,2,1],[1,1,1,1],[0,1,1,0]])[i];m.grid(hs,(w/len(hs),dep/len(hs[0]),h/max(max(r) for r in hs)),2,3,4)
 assets.append(m.object(f'ENV_Ground_{("Flat_Tile","Broken_Edge","Raised_Core","Stepped_Chunk")[i]}',dirts,(-3.7+i*2.02,.35,.045),True,'dirt',str(i+1)))
for ci,color in enumerate(flowers):
 for variant in range(2):
  m=Mesh();r=random.Random(900+ci*11+variant);n=5 if variant==0 else 7
  for k in range(n):
   a=k*2.399;radius=(.10 if variant==0 else .15)*(1 if k else 0);x=math.cos(a)*radius;y=math.sin(a)*radius;h=r.uniform(.22,.32) if variant==0 else r.uniform(.25,.38)
   m.box((x,y,h/2),(.018,.018,h),5)
   # broad blunt leaves on alternating stem sides
   for sign,z in ((-1,h*.37),(1,h*.6)):
    rot=Matrix.Rotation(sign*.42,3,'Y');m.box((x+sign*.037,y,z),(.085,.031,.011),6,rot)
   petal=.044 if variant==0 else .038;head=.074 if variant==0 else .067
   # Cross-shaped daisies: four substantial cuboid petals and yellow/brown square centre.
   for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
    m.box((x+dx*petal,y+dy*petal,h), (head if dx else petal,petal if dx else head,.021),7+ci)
   m.box((x,y,h+.012),(.041,.041,.026),12 if color=='yellow' else 11)
  # A few blunt grass leaves bind the stems into a compact rooted clump.
  for k in range(9):
   a=k*2.399;rr=.11 if variant==0 else .17;x=math.cos(a)*rr;y=math.sin(a)*rr;h=r.uniform(.07,.14);rot=Matrix.Rotation(a,3,'Z')@Matrix.Rotation(.28,3,'Y');m.box((x,y,h/2),(.022,.014,h),6,rot)
  assets.append(m.object(f'ENV_Flowers_{color.title()}_{variant+1:02}',flowers[color],(-4.15+ci*1.93+variant*.74,-1.75,.045),True,'flower',color))
# Read-only append static compatibility objects, keeping their packed V4 material.
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.objects=[n for n in ('ENV_GrassDirt_Block_1m','ENV_Grass_Square_Leaves_V4','ENV_Dirt_Block_1m_V4') if n in src.objects]
for o in dst.objects:
 if not o:continue
 refs.objects.link(o);o.animation_data_clear();o['reference_only']=True
 if o.type=='MESH' and o.data.shape_keys:
  basis=[v.co.copy() for v in o.data.shape_keys.key_blocks['Basis'].data];o.shape_key_clear()
  for v,co in zip(o.data.vertices,basis):v.co=co
 o.location=(5.15,1.15,.045+(1 if 'Leaves' in o.name else 0))
 if 'Dirt_Block_1m_V4' in o.name:o.location=(5.15,-.18,.045)
 for ma in o.data.materials:
  if ma and ma.use_nodes:
   for node in ma.node_tree.nodes:
    if node.type=='TEX_IMAGE' and node.image:node.image.pack();node.image.filepath=''
# linked mini composition on grass cube top
for idx,(x,y) in enumerate(((4.9,1.00),(5.4,1.40))):
 orig=assets[10+idx*3];o=orig.copy();o.data=orig.data;o.asset_clear();o['scatter_asset']=False;o['vignette_instance']=True;vig.objects.link(o);o.name='VIGNETTE_Linked_'+orig.name;o.location=(x,y,1.045)
# Showcase materials and native plinths
def solid(name,rgb):
 ma=bpy.data.materials.new(name);ma.diffuse_color=(*rgb,1);ma.use_nodes=True;ma.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rgb,1);ma.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return ma
slab=solid('SHOWCASE • ivory',(0.68,.66,.59));ink=solid('SHOWCASE • charcoal',(.11,.15,.14));bg=solid('SHOWCASE • studio warm gray',(.42,.44,.42))
def boxshow(name,c,dim,ma):
 m=Mesh();m.box(c,dim,0);o=m.object(name,show);o.data.materials.clear();o.data.materials.append(ma);return o
boxshow('Studio Ground',(0,0,-.14),(200,200,.2),bg)
for y in (2.35,.35,-1.75):boxshow('Catalog Plinth',( -.55,y,0),(8.6,1.50,.09),slab)
boxshow('V4 Reference Plinth',(5.15,.6,0),(1.55,3.1,.09),slab)
def text(name,body,pos,size=.18,ma=ink):
 d=bpy.data.curves.new(name,'FONT');d.body=body;d.size=size;d.extrude=0;d.align_x='LEFT';o=bpy.data.objects.new(name,d);show.objects.link(o);o.location=pos;d.materials.append(ma);return o
text('Title','MEADOW / SCATTER 01',(-4.8,4.3,.05),.44)
text('Subtitle','18 native assets    /    voxel field study    /    V4 palette',(-4.78,3.86,.05),.17)
text('Rock category','01  ROCKS  /  SMALL > MEDIUM > LARGE',(-4.75,3.20,.05),.21)
for i,o in enumerate(assets[:6]):text('Rock ID '+str(i),f'{i+1:02}  {o["variant"].upper()}',(xrock[i]-.30,1.78,.10),.115)
text('Ground category','02  GROUND  /  OCHRE SOIL',(-4.75,1.23,.05),.21)
for i,b in enumerate(('FLAT TILE','BROKEN EDGE','RAISED CORE','STEPPED CHUNK')):text('Ground ID '+str(i),b,(-4.04+i*2.02,-.29,.10),.12)
text('Flower category','03  FLOWERS  /  COMPACT CLUMPS',(-4.75,-.82,.05),.21)
for ci,color in enumerate(flowers):
 ma=solid('LABEL • '+color,tuple(v/255*.65 for v in palette[7+ci][1]));text('Flower color '+color,color.upper()+'   01 / 02',(-4.47+ci*1.93,-2.34,.1),.15,ma)
text('Reference header','V4 / SCALE',(4.42,2.52,.05),.24)
text('Reference note','1 m GRASS + DIRT',(4.42,-1.12,.10),.12)
text('Footer','BOTTOM-CENTRED PIVOTS  /  IDENTITY SCALE  /  PACKED 128px NEAREST ATLAS',(-4.75,-3.02,.04),.14)
def camera(name,loc,target,scale):
 d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale;o=bpy.data.objects.new(name,d);show.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
hero=camera('REVIEW • overview',(1,-12,17),(1,.5,0),12.6)
cams={'overview':hero,'rocks':camera('REVIEW • rocks',(-.5,-5,8),(-.5,2.4,.15),8.7),'ground':camera('REVIEW • ground',(-.5,-6,8),(-.5,.4,.07),8.7),'flowers':camera('REVIEW • flowers',(-.6,-7,7),(-.6,-1.65,.16),8.7),'v4_compatibility':camera('REVIEW • V4 compatibility',(8,-4,5),(5.15,.65,.65),3.6)}
for name,loc,power,size,col in [('Key',(-4,-5,12),1700,9,(1,.96,.86)),('Fill',(7,-1,9),1100,7,(.86,.93,1))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=col;o=bpy.data.objects.new(name,d);show.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
w=bpy.data.worlds.new('Soft neutral studio');w.use_nodes=True;w.node_tree.nodes['Background'].inputs['Color'].default_value=(.65,.70,.74,1);w.node_tree.nodes['Background'].inputs['Strength'].default_value=.4;s.world=w
s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True;s.render.resolution_x=1600;s.render.resolution_y=1150;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='Standard';s.view_settings.look='None';s.camera=hero
s['artistic_status']='AWAITING HUMAN REVIEW';s['new_asset_count']=18;s['notes']='18 native reusable asset meshes; copied static V4 reference, linked mini vignette, one showcase scene. No exports.'
for o in bpy.context.selected_objects:o.select_set(False)
assets[10].select_set(True);bpy.context.view_layer.objects.active=assets[10]
for sc in bpy.data.screens:
 for a in sc.areas:
  if a.type=='VIEW_3D':a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.shading.type='MATERIAL'
bpy.context.preferences.filepaths.save_version=0
# Strip unused appended orphan datablocks and external path hints.
for im in bpy.data.images:
 if im.packed_file:im.filepath=''
bpy.ops.wm.save_as_mainfile(filepath=str(D/'environment_scatter_set_v1.blend'))
manifest={'study':'environment_scatter_set_v1.blend','source_reference':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'new_assets':[],'counts':{'rock':6,'dirt':4,'flower':8},'renders':list(cams),'artistic_status':'AWAITING HUMAN REVIEW'}
for o in assets:
 o.data.calc_loop_triangles();manifest['new_assets'].append({'name':o.name,'category':o['category'],'variant':o['variant'],'dimensions_m':list(o.dimensions),'vertices':len(o.data.vertices),'triangles':len(o.data.loop_triangles),'mesh':o.data.name})
(D/'manifest.json').write_text(json.dumps(manifest,indent=2))
for name,cam in cams.items():
 s.camera=cam;s.render.filepath=str(D/('preview_'+name+'.png'));s.render.resolution_x=1600 if name=='overview' else 1400;s.render.resolution_y=1150 if name=='overview' else 800;bpy.ops.render.render(write_still=True)
s.camera=hero;s.render.resolution_x=1600;s.render.resolution_y=1150;s.render.filepath=str(D/'preview_overview.png');bpy.ops.wm.save_as_mainfile(filepath=str(D/'environment_scatter_set_v1.blend'))
print('SCATTER_AUTHORING_COMPLETE')
