"""Create original weapon family through the live Blender MCP bridge.
Opens the style anchor read-only and writes only newly named family outputs.
"""
import bpy,bmesh,json,hashlib,math
from pathlib import Path
from mathutils import Vector
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
ANCHOR=BASE/'m4a1_blocky/m4a1_blocky_v1.blend'
anchor_hash=hashlib.sha256(ANCHOR.read_bytes()).hexdigest()
for f in [BASE/'m4a1_blocky/m4a1_blocky_v2.blend',BASE/'pistol/blocky_pistol_v1.blend',BASE/'shotgun/blocky_shotgun_v1.blend']:
 if f.exists(): raise RuntimeError('New output already exists: '+str(f))
# Use the proven mesh/atlas helpers, without executing the V1 builder itself.
source=(BASE/'m4a1_blocky/build_m4a1_blocky_v1.py').read_text(encoding='utf-8-sig')
exec(source[source.index('def part('):source.index('# Distinct solid heel stock')])
reports={}
def open_anchor():
 bpy.ops.wm.open_mainfile(filepath=str(ANCHOR))
 return bpy.context.scene

def configure_studio(scene,meshes):
 bpy.context.view_layer.update()
 coords=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
 lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)));hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
 center=(lo+hi)/2;d=hi-lo;length=d.y
 for name,direction in [('Side',(2,0,0)),('ThreeQuarter',(1.5,1.7,.8)),('Isometric',(1.4,-1.2,1.1))]:
  obj=bpy.data.objects.get('Weapon_'+name)
  if obj is None:
   data=bpy.data.cameras.new('Weapon_'+name);obj=bpy.data.objects.new(data.name,data);bpy.data.collections['PREVIEW_STUDIO'].objects.link(obj)
  obj.data.type='ORTHO';obj.data.ortho_scale=max(length*1.2,d.z*1.7)
  obj.location=center+Vector(direction)*max(.5,length)
  obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
 scene.render.resolution_x=1280;scene.render.resolution_y=960
 scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
 return lo,hi

def finalize(key,folder,stem,root,meshes,minimum,maximum):
 scene=bpy.context.scene
 lo,hi=configure_studio(scene,meshes)
 tris=0
 for o in meshes:
  o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
  assert all(abs(v-1)<1e-6 for v in o.scale) and not o.modifiers
 assert minimum<=tris<=maximum,(key,tris)
 image=next(n.image for n in meshes[0].data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
 assert image.packed_file and list(image.size)==[64,64]
 mat=meshes[0].data.materials[0]
 report={'dimensions_m':{'width':hi.x-lo.x,'length':hi.y-lo.y,'height':hi.z-lo.z},'triangles':tris,'mesh_count':len(meshes),'material_count':len(set(m.name for o in meshes for m in o.data.materials)),'texture_resolution':[64,64],'texture_packed':True,'forward_blender':'+Y','forward_godot':'-Z','origin':'primary hand grip center','markers_blender_m':{o.name:list(o.location) for o in root.children if o.name.endswith('_Point')},'identity_transforms':True,'original_design':True,'material':{'roughness':.48,'metallic':0,'specular_ior_level':.25,'filter':'Closest'},'blend':str(folder/(stem+'.blend')),'glb':str(folder/(stem+'.glb'))}
 bpy.ops.object.select_all(action='DESELECT')
 for o in [root]+list(root.children):o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 bpy.ops.export_scene.gltf(filepath=report['glb'],export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
 for name in ['Side','ThreeQuarter','Isometric']:
  scene.camera=bpy.data.objects['Weapon_'+name];scene.render.filepath=str(folder/(stem+'_'+name.lower()+'.png'));bpy.ops.render.render(write_still=True)
 scene['asset_report']=json.dumps(report);scene['original_design']='Original game asset, shared style palette and atlas; no logos or copied branding.'
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=report['blend'])
 (folder/(stem+'_report.json')).write_text(json.dumps(report,indent=2))
 reports[key]=report

# Width-only M4A1 edit in mesh space; UVs, height, length and markers unchanged.
scene=open_anchor();mesh=bpy.data.objects['M4A1_Blocky_Base'];root=bpy.data.objects['M4A1_Blocky_Root']
old_yz=[(v.co.y,v.co.z) for v in mesh.data.vertices]
old_uv=[tuple(x.uv) for x in mesh.data.uv_layers.active.data]
old_markers={o.name:tuple(o.location) for o in root.children if o.type=='EMPTY'}
factor=.103/mesh.dimensions.x
for v in mesh.data.vertices:v.co.x*=factor
mesh.data.update();bpy.context.view_layer.update()
assert old_yz==[(v.co.y,v.co.z) for v in mesh.data.vertices]
assert old_uv==[tuple(x.uv) for x in mesh.data.uv_layers.active.data]
assert old_markers=={o.name:tuple(o.location) for o in root.children if o.type=='EMPTY'}
finalize('M4A1',BASE/'m4a1_blocky','m4a1_blocky_v2',root,[mesh],300,900)
reports['M4A1']['width_reduction_percent']=(1-factor)*100

def new_asset(prefix,grip):
 global scene,asset,mat,parts,GRIP_ORIGIN,root
 scene=open_anchor();scene.name=prefix+'_Asset'
 asset=bpy.data.collections['WEAPON_EXPORT']
 mat=bpy.data.objects['M4A1_Blocky_Base'].data.materials[0]
 for o in list(asset.objects):bpy.data.objects.remove(o,do_unlink=True)
 root=bpy.data.objects.new(prefix+'_Root',None);asset.objects.link(root)
 root['forward']='Blender +Y / Godot -Z';root['origin']='primary hand grip center';root['original_design']=True
 parts=[];GRIP_ORIGIN=Vector(grip)

def join_parts(name,exclude=()):
 bpy.ops.object.select_all(action='DESELECT')
 objs=[o for o in asset.objects if o.type=='MESH' and o.name not in exclude]
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join()
 main=bpy.context.object;main.name=name;main.data.materials.clear();main.data.materials.append(mat)
 for p in main.data.polygons:p.material_index=0
 for o in [main]+[bpy.data.objects[n] for n in exclude]:
  o.parent=root;o.location=(0,0,0);o.rotation_euler=(0,0,0);o.scale=(1,1,1)
 return [main]+[bpy.data.objects[n] for n in exclude]

def marker(name,coord):
 o=bpy.data.objects.new(name,None);asset.objects.link(o);o.parent=root;o.location=Vector(coord)-GRIP_ORIGIN;o.empty_display_type='ARROWS';o.empty_display_size=.025
 o['forward']='local +Y in Blender / -Z in Godot'

def tube(name,y0,y1,z,outer,inner):
 verts=[(x,y,z+zz) for y in (y0,y1) for size in (outer,inner) for x,zz in [(-size,-size),(size,-size),(size,size),(-size,size)]]
 faces=[]
 for i in range(4):
  j=(i+1)%4;faces.extend([(i,j,j+8,i+8),(i+4,i+12,j+12,j+4),(i+8,j+8,j+12,i+12)])
 return part(name,verts,faces,11,14)

# Original chunky service pistol. Short slab slide, stepped frame, swept grip.
new_asset('Blocky_Pistol',(0,-.064,-.044))
box('Pistol_Slide',(0,.032,.073),(.052,.242,.052),0,9,.0008)
profile('Pistol_Frame',[(-.085,.047),(.121,.047),(.121,.023),(.025,.023),(-.011,.011),(-.063,.011),(-.085,.02)],.045,1,6,.0007)
profile('Pistol_Grip',[(-.073,.019),(-.022,.012),(-.05,-.107),(-.097,-.104)],.041,4,6,.0007)
box('Pistol_Grip_Heel',(0,-.073,-.11),(.045,.058,.012),7,9)
box('Pistol_Guard_Bottom',(0,.013,-.034),(.019,.084,.008),6,14)
box('Pistol_Guard_Front',(0,.055,-.009),(.019,.010,.056),6,14)
box('Pistol_Trigger',(0,.01,.002),(.01,.009,.034),7,11)
box('Pistol_Rear_Sight_Left',(-.018,-.067,.105),(.01,.017,.012),7,14)
box('Pistol_Rear_Sight_Right',(.018,-.067,.105),(.01,.017,.012),7,14)
box('Pistol_Front_Sight',(0,.119,.104),(.012,.019,.01),7,14)
tube('Pistol_Muzzle',.149,.171,.073,.016,.008)
meshes=join_parts('Blocky_Pistol_Base')
marker('Grip_Point',tuple(GRIP_ORIGIN));marker('Muzzle_Point',(0,.172,.073));marker('Support_Hand_Point',(0,-.03,-.044))
finalize('Pistol',BASE/'pistol','blocky_pistol_v1',root,meshes,150,350)

# Original pump shotgun: straight dual tube, broad fore-end, heavy stepped stock.
new_asset('Blocky_Shotgun',(0,-.15,-.025))
profile('Shotgun_Stock',[(-.46,.19),(-.237,.19),(-.187,.153),(-.205,.116),(-.292,.116),(-.375,.015),(-.46,.015)],.116,0,9,.002)
box('Shotgun_Heel',(0,-.468,.10),(.124,.016,.178),7,9)
box('Shotgun_Stock_Link',(0,-.207,.154),(.08,.035,.07),6,14,omit=(2,4))
profile('Shotgun_Receiver',[(-.187,.217),(.076,.217),(.094,.195),(.094,.115),(.058,.093),(-.083,.093),(-.135,.113),(-.187,.113)],.118,1,5,.0015)
box('Shotgun_Top_Rib',(0,.009,.228),(.037,.188,.017),0,9)
profile('Shotgun_Grip',[(-.126,.11),(-.072,.091),(-.127,-.061),(-.193,-.054)],.081,4,6,.001)
box('Shotgun_Guard_Bottom',(0,-.018,.048),(.031,.091,.011),6,14)
box('Shotgun_Guard_Front',(0,.027,.071),(.031,.01,.055),6,14)
box('Shotgun_Trigger',(0,-.018,.085),(.012,.012,.039),7,11)
box('Shotgun_Barrel',(0,.283,.177),(.039,.397,.039),11,14,.0007)
box('Shotgun_Magazine_Tube',(0,.261,.106),(.042,.356,.042),0,9)
# Independent fore-end, same atlas and material. Mesh origin at the support hand.
pump=box('Shotgun_Pump',(0,.206,.106),(.129,.206,.096),2,0,.0015)
pump['future_motion']='Translate local Y by approximately 0.045 m rearward; whole rigid part.'
box('Shotgun_Pump_Front_Collar',(0,.321,.106),(.068,.020,.064),6,14)
tube('Shotgun_Muzzle',.475,.499,.177,.028,.013)
box('Shotgun_Front_Sight',(0,.45,.204),(.014,.024,.016),7,14)
meshes=join_parts('Blocky_Shotgun_Base',('Shotgun_Pump',))
pump=bpy.data.objects['Shotgun_Pump'];pump_center=Vector((0,.206,.106))-GRIP_ORIGIN
for v in pump.data.vertices:v.co-=pump_center
pump.location=pump_center # geometry placement unchanged; useful rigid pump pivot
marker('Grip_Point',tuple(GRIP_ORIGIN));marker('Muzzle_Point',(0,.5,.177));marker('Support_Hand_Point',(0,.206,.106))
finalize('Shotgun',BASE/'shotgun','blocky_shotgun_v1',root,meshes,300,700)
reports['Shotgun']['pump_translation_blender_m']=list(pump_center)
assert hashlib.sha256(ANCHOR.read_bytes()).hexdigest()==anchor_hash
# Comparison scene: orthographic camera, no object scaling, true relative dimensions.
scene=open_anchor()
compare=bpy.data.scenes.new('Weapon_Family_Comparison');compare.world=scene.world
bpy.context.window.scene=compare
for key,center_x in [('Pistol',-1.09),('M4A1',-.425),('Shotgun',.615)]:
 path=reports[key]['blend']
 with bpy.data.libraries.load(path,link=False) as (src,dst):
  dst.objects=[n for n in src.objects if n.endswith('_Root') or n.endswith('_Base') or n.endswith('_Point') or n=='Shotgun_Pump']
 objects=[o for o in dst.objects if o]
 for o in objects:compare.collection.objects.link(o)
 rt=next(o for o in objects if o.name.split('.')[0].endswith('_Root'))
 verts=[o.matrix_world@v.co for o in objects if o.type=='MESH' for v in o.data.vertices]
 mid_y=(min(v.y for v in verts)+max(v.y for v in verts))/2
 rt.rotation_euler.z=-math.pi/2;rt.location=(center_x-mid_y,0,0)
 rt['comparison_scale']=1.0
# Shared studio lights copied without altering their original files.
for n in ['Weapon_Key','Weapon_Fill','Weapon_Rim']:
 original=bpy.data.objects[n];o=original.copy();o.data=original.data.copy();compare.collection.objects.link(o)
 o.location=Vector(o.location)*2; o.data.energy*=4
 o.rotation_euler=(Vector((0,0,.07))-o.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Comparison_Camera');data.type='ORTHO';data.ortho_scale=2.62
cam=bpy.data.objects.new(data.name,data);compare.collection.objects.link(cam);cam.location=(0,-3,1.3)
cam.rotation_euler=(Vector((0,0,.06))-cam.location).to_track_quat('-Z','Y').to_euler();compare.camera=cam
for label,x in [('Pistol',-1.09),('M4A1',-.425),('Shotgun',.615)]:
 font=bpy.data.curves.new(label+'_Label','FONT');font.body=label;font.size=.057;font.align_x='CENTER'
 ob=bpy.data.objects.new(font.name,font);compare.collection.objects.link(ob);ob.location=(x,0,-.21);ob.rotation_euler=cam.rotation_euler
 labelmat=bpy.data.materials.get('Comparison_Label')
 if labelmat is None:
  labelmat=bpy.data.materials.new('Comparison_Label');labelmat.diffuse_color=(.35,.65,.75,1)
 ob.data.materials.append(labelmat)
compare.render.engine='CYCLES';compare.cycles.samples=32;compare.cycles.use_denoising=True
compare.render.resolution_x=2048;compare.render.resolution_y=768;compare.render.resolution_percentage=100
compare.render.image_settings.file_format='PNG';compare.render.image_settings.color_mode='RGBA';compare.render.film_transparent=True
compare.view_settings.view_transform='AgX';compare.render.filepath=str(BASE/'weapon_family_comparison.png')
bpy.ops.render.render(write_still=True)
compare['relative_scale']='All weapon roots at scale 1.0; meters; same orthographic camera.'
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'weapon_family_comparison.blend'))
(BASE/'weapon_family_report.json').write_text(json.dumps(reports,indent=2))
result=reports


