"""Original block rifle; run in a NEW background Blender instance through Blender MCP.
The supplied existing blend is read-only; factory reset affects only that process.
"""
import bpy, bmesh, math, json, hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons/m4a1_blocky')
OUT.mkdir(parents=True,exist_ok=True)
SOURCE_FILES=[Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/player_cuboid_v6.blend'),Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/enemies/zombie/zombie_cuboid_v2.blend')]
hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE_FILES}
TARGET=OUT/'m4a1_blocky_v1.blend'
# This builder writes only its own named weapon outputs.
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.name='M4A1_Blocky_Asset'
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
asset=bpy.data.collections.new('WEAPON_EXPORT');scene.collection.children.link(asset)
studio=bpy.data.collections.new('PREVIEW_STUDIO');scene.collection.children.link(studio)
root=bpy.data.objects.new('M4A1_Blocky_Root',None);asset.objects.link(root)
root['asset_role']='rigid weapon attach root';root['forward']='Blender +Y; glTF/Godot -Z';root['original_design']=True
# Modeling coordinates are converted to a grip-centered local origin.
GRIP_ORIGIN=Vector((0,-.135,-.025))
palette=[(39,50,59),(83,105,116),(33,46,54),(43,60,70),(29,40,48),(98,119,128),(61,81,92),(25,34,42),(146,173,182),(64,82,93),(54,71,81),(38,52,62),(29,166,179),(17,24,30),(85,107,117),(111,137,145)]
pixels=[0.0]*(64*64*4)
def paint(x,y,c):
 i=(y*64+x)*4;pixels[i:i+4]=[((v/255)/12.92 if v/255 <= .04045 else ((v/255+.055)/1.055)**2.4) for v in c]+[1.0]
for tile,c in enumerate(palette):
 tx=(tile%4)*16;ty=(tile//4)*16
 for y in range(16):
  for x in range(16): paint(tx+x,ty+y,c)
 # Restrained pixel edge paint, with solid one-pixel gutters around each tile.
 if tile not in (7,8,12,13):
  light=tuple(min(255,int(v*1.12+5)) for v in c);dark=tuple(int(v*.83) for v in c)
  for x in range(2,14):paint(tx+x,ty+13,light);paint(tx+x,ty+2,dark)
  for y in range(3,13):paint(tx+2,ty+y,light)
# Big readable surface motifs; no letters, numbers, logos or copied symbols.
for x0 in (4,8,12):
 for x in range(x0,min(x0+2,14)):
  for y in range(5,11):paint(32+x,y,palette[13]) # handguard tile 2
for y in range(4,11):
 for x in range(4,6): paint(48+x,y,palette[6]) # magazine wide diagonal bands
 for x in range(9,11): paint(48+x,y,palette[6])
for x in range(5,12):
 for y in range(6,8):paint(16+x,y,palette[6]) # receiver inset block
for x in range(10,13):
 for y in range(10,12):paint(16+x,y,palette[12]) # original small cyan badge
for x in range(5,12):
 for y in range(6,9):paint(x,y,palette[7]) # solid stock inset
img=bpy.data.images.new('M4A1_Original_Atlas_64',64,64,alpha=True)
img.colorspace_settings.name='sRGB';img.pixels.foreach_set(pixels)
img.filepath_raw=str(OUT/'m4a1_blocky_atlas_64.png');img.file_format='PNG';img.save();img.pack()
mat=bpy.data.materials.new('M4A1_Atlas_Main');mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Metallic'].default_value=0
bsdf.inputs['Roughness'].default_value=.48;bsdf.inputs['Specular IOR Level'].default_value=.25
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;tex.interpolation='Closest';tex.extension='EXTEND'
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
parts=[]
def part(name,verts,faces,side=6,top=5,bevel=0,omit=()):
 mesh=bpy.data.meshes.new(name+'_Geometry');mesh.from_pydata([Vector(v)-GRIP_ORIGIN for v in verts],[],[f for i,f in enumerate(faces) if i not in omit]);mesh.update()
 obj=bpy.data.objects.new(name,mesh);asset.objects.link(obj)
 obj.data.materials.append(mat);obj.data.materials.append(mat)
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 if bevel:
  bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
  mod=obj.modifiers.new('Tiny structural chamfer','BEVEL');mod.width=bevel;mod.segments=1;mod.affect='EDGES';mod.material=1
  bpy.ops.object.modifier_apply(modifier=mod.name)
 mesh=obj.data;uv=mesh.uv_layers.new(name='AtlasUV')
 for poly in mesh.polygons:
  tile=8 if poly.material_index==1 else (side if abs(poly.normal.x)>.8 else top if poly.normal.z>.8 else 7 if poly.normal.z<-.8 else 11)
  # Long axis projection makes intentional tile reuse, not accidental overlap.
  axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis]
  points=[mesh.vertices[mesh.loops[li].vertex_index].co for li in poly.loop_indices]
  lo=[min(v[a] for v in points) for a in axes];hi=[max(v[a] for v in points) for a in axes]
  for li,v in zip(poly.loop_indices,points):
   u=(v[axes[0]]-lo[0])/max(hi[0]-lo[0],1e-8);w=(v[axes[1]]-lo[1])/max(hi[1]-lo[1],1e-8)
   uv.data[li].uv=((tile%4*16+2.5+u*11)/64,(tile//4*16+2.5+w*11)/64)
  poly.material_index=0;poly.use_smooth=False
 obj.data.materials.pop(index=1)
 group=obj.vertex_groups.new(name=name)
 group.add(list(range(len(mesh.vertices))),1.0,'REPLACE')
 mesh.calc_loop_triangles();parts.append({'name':name,'triangles':len(mesh.loop_triangles),'bevel_m':bevel})
 return obj
box_faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
def box(name,center,size,side=6,top=5,bevel=0,omit=()):
 x,y,z=center;w,l,h=(v/2 for v in size)
 v=[(x-w,y-l,z-h),(x+w,y-l,z-h),(x+w,y+l,z-h),(x-w,y+l,z-h),(x-w,y-l,z+h),(x+w,y-l,z+h),(x+w,y+l,z+h),(x-w,y+l,z+h)]
 return part(name,v,box_faces,side,top,bevel,omit)
def profile(name,yz,width,side,top=5,bevel=0):
 n=len(yz);v=[(x,y,z) for x in (-width/2,width/2) for y,z in yz]
 f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return part(name,v,f,side,top,bevel)
# Distinct solid heel stock and compact rail; avoid the reference's open stock/carry handle.
profile('Stock', [(-.43,.185),(-.22,.185),(-.185,.145),(-.205,.10),(-.28,.10),(-.36,.025),(-.43,.025)],.108,0,9,.0025)
box('Stock_Heel',(0,-.438,.105),(.116,.018,.177),7,9)
box('Stock_Link',(0,-.193,.155),(.072,.039,.068),6,14,omit=(2,4))
profile('Receiver',[(-.174,.208),(.127,.208),(.148,.181),(.148,.095),(.08,.065),(-.065,.065),(-.115,.09),(-.174,.09)],.112,1,5,.002)
box('Top_Rail',(0,-.015,.224),(.069,.284,.023),0,9)
box('Rear_Sight_Base',(0,-.126,.25),(.083,.045,.023),6,14)
box('Rear_Sight_Left',(-.031,-.126,.269),(.021,.033,.022),7,9)
box('Rear_Sight_Right',(.031,-.126,.269),(.021,.033,.022),7,9)
box('Handguard',(0,.247,.155),(.115,.20,.116),2,0,.002)
box('Front_Collar',(0,.355,.155),(.085,.016,.084),6,14)
box('Barrel',(0,.435,.155),(.044,.144,.044),11,14,.001)
# Square muzzle tube: true front opening, not an extra hidden solid box.
w=.034;inner=.012;y0=.505;y1=.55;z=.155
verts=[(x,y,z+zz) for y in (y0,y1) for size in (w,inner) for x,zz in [(-size,-size),(size,-size),(size,size),(-size,size)]]
faces=[]
for i in range(4):
 j=(i+1)%4
 faces.extend([(i,j,j+8,i+8),(i+4,i+12,j+12,j+4),(i+8,j+8,j+12,i+12)])
part('Muzzle_Shroud',verts,faces,11,14)
box('Front_Sight_Base',(0,.373,.196),(.077,.032,.029),7,9)
box('Front_Sight_Left',(-.024,.373,.241),(.015,.026,.065),0,14)
box('Front_Sight_Right',(.024,.373,.241),(.015,.026,.065),0,14)
box('Front_Sight_Bridge',(0,.373,.281),(.063,.026,.015),6,15)
profile('Magazine',[(.018,.067),(.105,.067),(.125,-.048),(.15,-.143),(.062,-.15),(.039,-.065)],.081,3,10,.0015)
box('Magazine_Floorplate',(0,.108,-.151),(.093,.097,.022),7,10)
profile('Pistol_Grip',[(-.113,.085),(-.058,.067),(-.116,-.10),(-.19,-.09)],.074,4,6,.0015)
box('Trigger_Guard_Bottom',(0,-.011,.015),(.035,.10,.012),6,14)
box('Trigger_Guard_Front',(0,.035,.04),(.035,.012,.063),6,14)
box('Trigger',(0,-.017,.055),(.013,.013,.047),7,11)
# Cyan is painted on the receiver atlas; no decorative floating panels or lights.
bpy.ops.object.select_all(action='DESELECT')
for o in list(asset.objects):
 if o.type=='MESH':o.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Receiver']
bpy.ops.object.join();mesh=bpy.context.object;mesh.name='M4A1_Blocky_Base';mesh.data.name='M4A1_Blocky_RuntimeMesh'
# Consolidate duplicate slots created by joining; preserve the single atlas draw surface.
mesh.data.materials.clear();mesh.data.materials.append(mat)
for poly in mesh.data.polygons:poly.material_index=0
mesh.parent=root;mesh.location=(0,0,0);mesh.rotation_euler=(0,0,0);mesh.scale=(1,1,1)
for name,position in [('Grip_Point',Vector((0,-.135,-.025))),('Muzzle_Point',Vector((0,.551,.155))),('Support_Hand_Point',Vector((0,.24,.10)))]:
 obj=bpy.data.objects.new(name,None);asset.objects.link(obj);obj.parent=root;obj.location=position-GRIP_ORIGIN;obj.empty_display_type='ARROWS';obj.empty_display_size=.045
 obj['role']={'Grip_Point':'primary hand attachment center','Muzzle_Point':'projectile/VFX spawn, local +Y forward','Support_Hand_Point':'optional support hand reference'}[name]
# Studio objects remain outside the export selection.
world=bpy.data.worlds.new('Weapon_Studio_World');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.20,.24,1);world.node_tree.nodes['Background'].inputs[1].default_value=.32
for name,loc,power,size,color in [('Key',(1,-1,1.5),110,1.5,(.88,.95,1)),('Fill',(-1,-.2,.7),75,1.3,(.63,.80,1)),('Rim',(.3,1,1.2),150,1.2,(1,.95,.88))]:
 data=bpy.data.lights.new('Weapon_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
 obj=bpy.data.objects.new(data.name,data);studio.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,.1,.15))-obj.location).to_track_quat('-Z','Y').to_euler()
center=Vector((0,.045,.09))-GRIP_ORIGIN
cameras={}
for name,relative,scale in [('Side',(2,0,0),1.15),('Front',(0,2,0),.57),('Isometric',(1.4,-1.2,1.1),1.06)]:
 data=bpy.data.cameras.new('Weapon_'+name);data.type='ORTHO';data.ortho_scale=scale;data.lens=50
 obj=bpy.data.objects.new(data.name,data);studio.objects.link(obj);obj.location=center+Vector(relative);obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler();cameras[name]=obj
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
scene.view_settings.view_transform='AgX'
scene.camera=cameras['Isometric'];scene.render.filepath=str(OUT/'m4a1_blocky_isometric.png')
scene['design_notes']='Original compact rail, solid tapered heel, forward angular magazine, cyan badge. No copied text or marks.'
mesh.data.calc_loop_triangles();tris=len(mesh.data.loop_triangles)
coords=[v.co for v in mesh.data.vertices];bounds={axis:[min(v[i] for v in coords),max(v[i] for v in coords)] for i,axis in enumerate('XYZ')}
report={'triangles':tris,'vertices':len(mesh.data.vertices),'polygons':len(mesh.data.polygons),'material_count':len(mesh.data.materials),'texture_resolution':[64,64],'texture_packed':bool(img.packed_file),'forward_blender':'+Y','forward_godot':'-Z','origin':'primary grip center','bounds_m':bounds,'dimensions_m':[bounds[a][1]-bounds[a][0] for a in 'XYZ'],'markers':{n:list(bpy.data.objects[n].location) for n in ['Grip_Point','Muzzle_Point','Support_Hand_Point']},'parts':parts,'original':True,'character_sources_unchanged':all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in hashes.items())}
assert 300<=tris<=900,report
assert mesh.scale==Vector((1,1,1)) and len(mesh.data.materials)==1
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene['triangle_count']=tris
# Selected GLB exports the mesh and markers; cameras/lights stay in the blend studio.
bpy.ops.object.select_all(action='DESELECT')
for obj in asset.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=mesh
bpy.ops.export_scene.gltf(filepath=str(OUT/'m4a1_blocky_v1.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
for name,cam in cameras.items():
 scene.camera=cam;scene.render.filepath=str(OUT/('m4a1_blocky_'+name.lower()+'.png'));bpy.ops.render.render(write_still=True)
scene.camera=cameras['Isometric'];scene.render.filepath=str(OUT/'m4a1_blocky_isometric.png')
# Save default camera and embedded image; no unrelated source is ever saved.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
result=report


