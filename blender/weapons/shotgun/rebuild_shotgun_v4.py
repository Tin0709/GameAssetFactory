"""Original traditional-stock shotgun V4; Blender MCP execution.
Uses the existing shotgun material/atlas and runtime object conventions.
"""
import bpy,bmesh,json,hashlib,math
from pathlib import Path
from mathutils import Vector
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons');OUT=BASE/'shotgun';TARGET=OUT/'blocky_shotgun_v4.blend'
assert not TARGET.exists(),'V4 already exists; inspect before overwriting.'
SOURCE=OUT/'blocky_shotgun_v3.blend';source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene
root=bpy.data.objects['Blocky_Shotgun_Root'];asset=bpy.data.collections['WEAPON_EXPORT'];mat=bpy.data.objects['Blocky_Shotgun_Base'].data.materials[0]
image=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');image_hash=hashlib.sha256(image.packed_file.data).hexdigest()
for o in list(asset.objects):
 if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
GRIP_ORIGIN=Vector((0,0,0));parts=[]
source=(BASE/'m4a1_blocky/build_m4a1_blocky_v1.py').read_text(encoding='utf-8-sig');exec(source[source.index('def part('):source.index('# Distinct solid heel stock')])
cleanup=(BASE/'cleanup_weapon_geometry.py').read_text(encoding='utf-8-sig')
exec(cleanup[cleanup.index('def topology('):cleanup.index('def extract(')])
exec(cleanup[cleanup.index('def union('):cleanup.index('def process(')])

def octagonal(name,y0,y1,z,r,tile=11):
 pts=[(math.cos(math.pi/8+i*math.pi/4)*r,math.sin(math.pi/8+i*math.pi/4)*r) for i in range(8)]
 vs=[(x,y,z+zz) for y in [y0,y1] for x,zz in pts]
 faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
 return part(name,vs,faces,tile,14)

def muzzle_tube(y0,y1,z,r,inner):
 vs=[(math.cos(math.pi/8+i*math.pi/4)*rad,y,z+math.sin(math.pi/8+i*math.pi/4)*rad) for y in [y0,y1] for rad in [r,inner] for i in range(8)]
 fs=[]
 for i in range(8):
  j=(i+1)%8;fs.extend([(i,j,j+16,i+16),(i+8,i+24,j+24,j+8),(i+16,j+16,j+24,i+24),(i,i+8,j+8,j)])
 o=part('Shotgun_Muzzle',vs,fs,11,14)
 uv=o.data.uv_layers.active
 for p in o.data.polygons:
  if p.index%4==1:
   for li in p.loop_indices:uv.data[li].uv=((16+8)/64,(48+8)/64) # deep bore charcoal tile13
 return o

body=profile('Shotgun_Receiver',[(-.034,.142),(.219,.142),(.237,.123),(.237,.064),(.192,.054),(-.012,.054),(-.034,.071)],.075,1,9,.001)
static=[profile('Shotgun_Traditional_Stock',[(-.418,.057),(-.222,.070),(-.125,.098),(-.058,.101),(.027,.088),(.041,.049),(.018,-.013),(-.070,-.018),(-.215,-.055),(-.418,-.080)],.090,6,9,.0013),box('Shotgun_Butt_Pad',(0,-.424,-.012),(.095,.014,.148),7,9)]
# Closed guard and trigger; no separate vertical pistol grip.
static.append(profile('Shotgun_Trigger_Guard',[(.014,.079),(.014,.015),(.151,.015),(.151,.079),(.141,.079),(.141,.025),(.024,.025),(.024,.079)],.027,6,14))
static.append(box('Shotgun_Trigger',(0,.088,.050),(.011,.011,.030),7,11))
static.append(octagonal('Shotgun_Barrel',.223,.676,.122,.018))
static.append(octagonal('Shotgun_Guide_Tube',.221,.553,.070,.0135,0))
static.append(muzzle_tube(.668,.689,.122,.022,.011))
static.append(box('Shotgun_Front_Bead',(0,.648,.143),(.011,.016,.012),7,14))
# Small sight seat intersects the barrel physically; it is part of the static body.
static.append(connector('Front_Bead_Seat',(-.004,.642,.132),(.004,.654,.141)))
static.append(box('Shotgun_Rear_Sight',(0,.024,.148),(.031,.027,.012),7,9))
static.append(connector('Rear_Sight_Seat',(-.011,.013,.137),(.011,.035,.149)))
for o in static:union(body,o)
finish_mesh(body);body.name='Blocky_Shotgun_Base';body.parent=root;body.location=(0,0,0);body.rotation_euler=(0,0,0);body.scale=(1,1,1)
# A broad slate fore-end is a distinct rigid animated part with a running bore.
pump_center=Vector((0,.356,.070))
pump=box('Shotgun_Pump',tuple(pump_center),(.086,.220,.060),6,9,.0012)
cutter=octagonal('Pump_Guide_Clearance',.235,.477,.070,.016)
union(pump,cutter,'DIFFERENCE');finish_mesh(pump)
for v in pump.data.vertices:v.co-=pump_center
pump.parent=root;pump.location=pump_center;pump.rotation_euler=(0,0,0);pump.scale=(1,1,1)
pump['future_motion']='Rigid local Y translation along the guide; verify receiver clearance when authoring pump stroke.'
markers={'Grip_Point':(0,0,0),'Support_Hand_Point':tuple(pump_center),'Muzzle_Point':(0,.690,.122)}
for n,pos in markers.items():bpy.data.objects[n].location=pos
bpy.context.view_layer.update();meshes=[body,pump];audits={o.name:topology(o) for o in meshes}
for o,t in audits.items():assert t['islands']==1 and t['nonmanifold_edges']==0 and t['boundary_edges']==0 and t['loose_vertices']==0 and t['duplicate_faces']==0 and t['inconsistent_normal_edges']==0,(o,t)
verts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
lo=Vector(tuple(min(v[i] for v in verts) for i in range(3)));hi=Vector(tuple(max(v[i] for v in verts) for i in range(3)));center=(lo+hi)/2;dims=hi-lo
tris=sum(t['triangles'] for t in audits.values());assert tris<=700,tris
assert image_hash==hashlib.sha256(image.packed_file.data).hexdigest()
report={'before_triangles':670,'after_triangles':tris,'topology':audits,'dimensions_m':{'width':dims.x,'length':dims.y,'height':dims.z},'materials':1,'texture_resolution':[64,64],'packed_atlas_sha256':image_hash,'markers_blender_m':markers,'origin':'unchanged grip root at (0,0,0)','forward':'Blender +Y / Godot -Z','separate_pump':True,'blend':str(TARGET),'glb':str(OUT/'blocky_shotgun_v4.glb'),'design':'Original tapered traditional stock, slim receiver, long faceted barrel and guide tube, slate fore-end; same family atlas.'}
bpy.ops.object.select_all(action='DESELECT')
for o in [root]+list(root.children):o.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.ops.export_scene.gltf(filepath=report['glb'],export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
for name,dir in [('Side',(2,0,0)),('ThreeQuarter',(1.5,1.7,.8)),('Isometric',(1.4,-1.2,1.1))]:
 cam=bpy.data.objects['Weapon_'+name];cam.location=center+Vector(dir)*dims.y;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=dims.y*1.17
 scene.camera=cam;scene.render.filepath=str(OUT/('blocky_shotgun_v4_'+name.lower()+'.png'));bpy.ops.render.render(write_still=True)
cam=bpy.data.objects['Geometry_Validation_Closeup'];focus=Vector((0,.043,.043));cam.location=focus+Vector((1.3,-.55,.32));cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.34
scene.camera=cam;scene.render.filepath=str(OUT/'blocky_shotgun_v4_trigger_closeup.png');bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['Weapon_Isometric'];scene['shotgun_v4_report']=json.dumps(report)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest()
(OUT/'blocky_shotgun_v4_report.json').write_text(json.dumps(report,indent=2));result=report

