"""Refine the existing Pending tall assets; add one combined review row only."""
import bpy,sys,json,random,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
D=Path(__file__).resolve().parent;T=D.parent;P=T.parent;R=T.parents[4];E=R/'.validation/grass_md2_single_window_v001';LIB=P/'dungeons_ground_style_v2.blend';sys.path[:0]=[str(P),str(T)]
from flower_preservation import mesh_content
from geometry import visible_bounds,asset_record
assert hashlib.sha256(LIB.read_bytes()).hexdigest()==(E/'before.sha256').read_text()
bpy.ops.wm.open_mainfile(filepath=str(LIB));s=bpy.context.scene;info=json.loads(s['md2_tall_review']);objects=[bpy.data.objects[n] for n in info['masters']]
assert not bpy.data.collections.get('05_MD2_TallGrass_In_Same_Review')
oldmat=objects[0].data.materials[0];oldmat.use_fake_user=True
for n in oldmat.node_tree.nodes:
 if n.type=='TEX_IMAGE':n.image.use_fake_user=True
image=bpy.data.images.load(str(D/'Tall_Grass_MD2_Meadow_Atlas.png'));image.name='MD2 Meadow — green base and pale seed tips';image.pack();image.filepath='//tall_grass_md2_v001/refinement_md2/Tall_Grass_MD2_Meadow_Atlas.png'
mat=oldmat.copy();mat.name='Tall MD2 — green meadow pale seed tips';mat.use_fake_user=False
for n in mat.node_tree.nodes:
 if n.type=='TEX_IMAGE':n.image=image
mat['reference']='Supplied MD2 meadow screenshot: green undergrowth, upright stalks, small pale heads. Actual resource-pack masks with authored seed tint.'
tex=json.loads((D/'texture_manifest.json').read_text())
def setmesh(m,vertices,faces,uvs,wind=None):
 for uv in list(m.uv_layers):m.uv_layers.remove(uv)
 m.clear_geometry();m.from_pydata(vertices,[],faces);m.materials.clear();m.materials.append(mat);m.update();u=m.uv_layers.new(name='UV_Atlas')
 for p,co in zip(m.polygons,uvs):
  for li,xy in zip(p.loop_indices,co):u.data[li].uv=xy
 if wind is not None:
  w=m.uv_layers.new(name='Wind_Metadata')
  for p in m.polygons:
   for li in p.loop_indices:w.data[li].uv=wind[m.loops[li].vertex_index]
specs=[(.78,9,.52,.075,.30,(1.10,1.08)),(.94,10,.54,.095,.34,(1.22,1.12)),(.72,8,.46,.085,.34,(1.12,1.14)),(.87,9,.48,.070,.30,(1.10,1.08))]
for idx,(o,sp) in enumerate(zip(objects[:4],specs)):
 height,count,width,radius,lean,foot=sp;rng=random.Random(926+idx);verts=[];faces=[];uv=[];wind=[]
 for ci in range(count):
  core=ci<3;az=ci*2.39996+idx*.52+rng.uniform(-.13,.13);tan=Vector((math.cos(az),math.sin(az),0));out=Vector((-math.sin(az),math.cos(az),0))
  h=height*(1. if ci==0 else rng.uniform(.83,.97)) if core else height*rng.uniform(.48,.66)
  w=width*(.58 if core else rng.uniform(.88,1.04));rad=radius*(.16 if core else 1.);bend=lean*(.22 if core else 1.)*rng.uniform(.88,1.1);start=len(verts)
  region=idx if core else 4+ci%2;x,y,tw,th=tex['regions_top_left'][region]
  for t in (0.,.34,.70,1.):
   center=out*(rad+bend*t*t)+Vector((0,0,-.008+h*t))
   for side in [-1,1]:
    verts.append(tuple(center+tan*side*w*(1-.20*t)/2));uv.append(((x+.5+(tw-1)*(side+1)/2)/128,1-(y+th-.5-(th-1)*t)/128));wind.append((t*t,ci/(count-1)))
  for ring in range(3):
   k=start+ring*2;faces.append((k,k+1,k+3,k+2))
 coords=[[uv[i] for i in f] for f in faces];setmesh(o.data,verts,faces,coords,wind);b=visible_bounds(o.data,image);factors=[foot[i]/(b[i][1]-b[i][0]) for i in range(2)]+[height/b[2][1]]
 for v in o.data.vertices:
  v.co.x*=factors[0];v.co.y*=factors[1]
  if v.co.z>0:v.co.z*=factors[2]
 o.data.update()
for ci,parts in enumerate([[(0,-.26,-.12,.3,.65),(2,.27,-.10,2.0,.65),(3,0,.25,4.2,.60)],[(1,-.22,-.20,.2,.60),(3,.23,-.16,1.3,.60),(0,-.20,.22,2.7,.60),(2,.22,.20,4.0,.60)]]):
 verts=[];faces=[];coords=[]
 for index,ox,oy,angle,scale in parts:
  m=objects[index].data;rot=Matrix.Rotation(angle,3,'Z');offset=len(verts)
  for v in m.vertices:
   p=v.co.copy();p.x*=scale;p.y*=scale;verts.append(tuple(rot@p+Vector((ox,oy,0))))
  for p in m.polygons:faces.append(tuple(offset+i for i in p.vertices));coords.append([tuple(m.uv_layers['UV_Atlas'].data[i].uv) for i in p.loop_indices])
 setmesh(objects[4+ci].data,verts,faces,coords)
# Existing short display and its source data remain unchanged; add a tall row behind it.
short=json.loads(s['md2_review']);parent=bpy.data.collections['MD2_Short_Grass_v001_PENDING'];combo=bpy.data.collections.new('05_MD2_TallGrass_In_Same_Review');parent.children.link(combo);combo['presentation_only']=True;base=bpy.data.objects['ENV_GrassBlock_DI_V3']
for i,src in enumerate(objects):
 x=src.location.x;o=bpy.data.objects.new('MD2_Combined_Tall_'+src.name,src.data);combo.objects.link(o);o.location=(x,6.4,1);o.visible_shadow=False
 points=[(0,0)] if i<4 else [(a,b) for a in [-.5,.5] for b in [-.5,.5]]
 for j,(ox,oy) in enumerate(points):
  g=bpy.data.objects.new('MD2_Combined_Base_%d_%d'%(i,j),base.data);combo.objects.link(g);g.location=(x+ox,6.4+oy,0)
 label=bpy.data.curves.new('MD2_Combined_Label','FONT');label.body='TALL '+chr(65+i) if i<4 else 'TALL CLUSTER '+str(i-3);label.size=.16;label.align_x='CENTER';label.materials.append(bpy.data.materials['MD2_Review_Type']);o=bpy.data.objects.new('MD2_Combined_Label_'+str(i),label);combo.objects.link(o);o.location=(x,5.65 if i<4 else 5.2,.012)
def find(lc,c):
 if lc.collection==c:return lc
 for child in lc.children:
  result=find(child,c)
  if result:return result
layer=s.view_layers[short['layer']];find(layer.layer_collection,combo).exclude=False
cam=bpy.data.cameras.new('MD2_Combined_Camera');cam.type='ORTHO';cam.ortho_scale=16.8;o=bpy.data.objects.new(cam.name,cam);combo.objects.link(o);o.location=(16,-18,22);o.rotation_euler=(Vector((4.6,3.1,1.0))-o.location).to_track_quat('-Z','Y').to_euler()
s['md2_grass_library']=json.dumps({'layer':layer.name,'all_camera':o.name,'combined_collection':combo.name,'revision':'MD2_GRASS_LIBRARY_V001','short_height_m':.5,'tall_height_range_m':[.72,.94]})
bpy.context.window.view_layer=layer
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   v=area.spaces.active;v.use_local_camera=True;v.camera=o;v.region_3d.view_perspective='CAMERA';v.region_3d.view_camera_zoom=0;v.show_region_ui=True
M=json.loads((T/'manifest.json').read_text());M['assets']=[asset_record(o,image) for o in objects];M['material']=mat.name;M['style_refinement']=tex;M['same_window_library']=json.loads(s['md2_grass_library']);(D/'manifest.json').write_text(json.dumps(M,indent=2)+'\n')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(E/LIB.name),relative_remap=False,compress=True);print('MD2_MEADOW_REFINED',json.dumps(M['assets']),flush=True)
