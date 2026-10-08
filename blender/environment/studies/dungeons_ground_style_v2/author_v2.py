"""Add original matching stone/dirt cubes to a preserved V1 grass study."""
import bpy,math,json,hashlib,struct,shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent; V1=ROOT.parent/'dungeons_grass_style_v1'; WORK=ROOT.parents[3]; VALID=WORK/'.validation/dungeons_grass_style_v1'
REF=WORK/'references/resource_packs/dungeons_ii_style/extracted/assets/minecraft/textures/block'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p.relative_to(V1)):sha(p) for p in V1.rglob('*') if p.is_file()}
for folder in ['textures','exports']:(ROOT/folder).mkdir(parents=True,exist_ok=True)
for p in (V1/'textures').glob('*.png'):shutil.copy2(p,ROOT/'textures'/p.name)
bpy.ops.wm.open_mainfile(filepath=str(V1/'dungeons_grass_style_v1.blend'))
scene=bpy.context.scene;scene.name='REVIEW_DungeonsGround_Style_V2'
assets=bpy.data.collections['ASSETS_Export'];instances=bpy.data.collections['REVIEW_Instances'];presentation=bpy.data.collections['REVIEW_Presentation']
originals=[bpy.data.objects[n] for n in ['ENV_GrassBlock_DI_Study_V1','ENV_Grass_DI_Study_V1','ENV_TallGrass_DI_Study_V1']]
original_geometry={o.name:{'vertices':[list(v.co) for v in o.data.vertices],'faces':[list(p.vertices) for p in o.data.polygons],'uv':[list(u.uv) for u in o.data.uv_layers.active.data]} for o in originals}
for o in list(instances.objects):bpy.data.objects.remove(o,do_unlink=True)
for o in list(presentation.objects):
    if o.type in ['FONT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)

# New soft neutral stone pattern uses its own smooth periodic field and five restrained colors.
palette=[(116,114,108),(124,122,115),(132,130,122),(140,138,129),(148,146,136)]
stone=[]
for y in range(32):
    row=[]
    for x in range(32):
        xx=x%31;yy=y%31
        f=.72*math.cos(2*math.pi*(xx+7)/31)+.8*math.sin(2*math.pi*(yy+4)/31)+.5*math.cos(2*math.pi*(xx-yy+3)/31)
        idx=max(0,min(4,int((f+2.0)/.78))); row.append((*palette[idx],255))
    stone.append(row)
im=bpy.data.images.new('stone',width=32,height=32,alpha=True);im.pixels.foreach_set([c/255 for row in stone for px in row for c in px]);im.filepath_raw=str(ROOT/'textures/stone.png');im.file_format='PNG';im.save();im.pack();im.use_fake_user=True
atlas=bpy.data.images['meadow_atlas'];oldpixels=list(atlas.pixels);pixels=oldpixels.copy();atlas.unpack(method='REMOVE')
# Blank region x74,y38; two pixel gutter extends to [72..107,36..71], clear of all V1 regions.
stonepixels=list(im.pixels)
for y in range(-2,34):
    for x in range(-2,34):
        src=(min(31,max(0,y))*32+min(31,max(0,x)))*4;dst=((38+y)*128+74+x)*4
        pixels[dst:dst+4]=stonepixels[src:src+4]
atlas.pixels.foreach_set(pixels);atlas.filepath_raw=str(ROOT/'textures/meadow_atlas.png');atlas.file_format='PNG';atlas.save();atlas.pack();atlas.use_fake_user=True
for n in ['grass_top','dirt','grass_side','short_grass','tall_grass']:
    image=bpy.data.images[n];image.filepath_raw=str(ROOT/'textures'/(n+'.png'));image.pack();image.use_fake_user=True
opaque=originals[0].data.materials[0]
def region_uv(x,y):return [(x/128,y/128),((x+32)/128,y/128),((x+32)/128,(y+32)/128),(x/128,(y+32)/128)]
def cube(name,xy):
    mesh=originals[0].data.copy();mesh.name=name+'_Mesh'
    for face in mesh.polygons:
        for li,uv in zip(face.loop_indices,region_uv(*xy)):mesh.uv_layers.active.data[li].uv=uv
    ob=bpy.data.objects.new(name,mesh);assets.objects.link(ob);ob.asset_mark();ob.asset_data.description='Original soft pixel block, 1 m cube, 12 triangles, bottom-center origin; shared original packed atlas.';return ob
dirt=cube('ENV_DirtBlock_DI_Study_V2',(38,2));stoneob=cube('ENV_StoneBlock_DI_Study_V2',(74,38))
originals[0].location=(-2,0,0);dirt.location=(0,0,0);stoneob.location=(2,0,0)
originals[1].location=(-1,3.2,1);originals[2].location=(1,3.2,1)
def linked(source,name,loc):
    ob=bpy.data.objects.new(name,source.data);instances.objects.link(ob);ob.location=loc;return ob
bases=[linked(originals[0],'Short_Grass_Base',(-1,3.2,0)),linked(originals[0],'Tall_Grass_Base',(1,3.2,0))]
textmat=bpy.data.materials['Type_Cream']
def text(body,pos,size):
    c=bpy.data.curves.new(body,'FONT');c.body=body;c.size=size;c.align_x='CENTER';o=bpy.data.objects.new('Label_'+body,c);presentation.objects.link(o);o.location=pos;c.materials.append(textmat);return o
for x,title in [(-2,'GRASS BLOCK'),(0,'DIRT BLOCK'),(2,'STONE BLOCK')]:
    text(title,(x,-.95,.005),.16);text('1 x 1 x 1 m  /  12 triangles',(x,-1.22,.005),.09)
plantlabels=[]
for x,title,note in [(-1,'SHORT GRASS','0.46 m / 4 triangles'),(1,'TALL GRASS','0.95 m / 4 triangles')]:
    plantlabels.extend([text(title,(x,2.35,.006),.14),text(note,(x,2.12,.006),.085)])
text('MEADOW GROUND  /  ORIGINAL PIXEL STUDY',(0,-1.95,.005),.20)
def camera(name,pos,target,scale):
    d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);presentation.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=scale;return o
showcam=camera('CAM_Five_Assets',(7,-12,11),(0,1,.45),8.6);blockcam=camera('CAM_Block_Comparison',(6,-11,8),(0,-.25,.43),7.5)
scene.camera=showcam;scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.cycles.samples=48
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.region_3d.view_perspective='CAMERA';sp.shading.type='MATERIAL';sp.shading.use_scene_lights=True;sp.shading.use_scene_world=True;sp.overlay.show_overlays=False
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
def force_mask(path):
    raw=path.read_bytes();size,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+size]);rest=raw[20+size:]
    for m in doc.get('materials',[]):
        if 'Cutout' in m.get('name',''):m['alphaMode']='MASK';m['alphaCutoff']=.5;m['doubleSided']=True
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(js)+len(rest))+struct.pack('<II',len(js),0x4e4f534a)+js+rest)
exportmap=[(originals[0],'grass_block_di_study_v1'),(originals[1],'grass_di_study_v1'),(originals[2],'tall_grass_di_study_v1'),(dirt,'dirt_block_di_study_v2'),(stoneob,'stone_block_di_study_v2')]
for source,filename in exportmap:
    bpy.ops.object.select_all(action='DESELECT');copy=bpy.data.objects.new('Export_'+filename,source.data);scene.collection.objects.link(copy);copy.select_set(True);bpy.context.view_layer.objects.active=copy
    path=ROOT/'exports'/(filename+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False);force_mask(path);bpy.data.objects.remove(copy,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT');dirt.select_set(True);bpy.context.view_layer.objects.active=dirt
blend=ROOT/'dungeons_ground_style_v2.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
scene.render.filepath=str(ROOT/'showcase.png');bpy.ops.render.render(write_still=True)
for o in originals[1:]+bases+plantlabels:o.hide_render=True
scene.camera=blockcam;scene.render.filepath=str(ROOT/'blocks_comparison.png');bpy.ops.render.render(write_still=True)
for o in originals[1:]+bases+plantlabels:o.hide_render=False
scene.camera=showcam;bpy.ops.wm.save_as_mainfile(filepath=str(blend))
manifest={'study':'Dungeons Ground Style V2','scene':scene.name,'artistic_status':'awaiting human review','assets':[{'name':o.name,'dimensions_m':list(o.dimensions),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'pivot':'bottom center'} for o in assets.objects],'atlas':{'path':'textures/meadow_atlas.png','size':[128,128],'stone_region':[74,38,32,32],'gutter':2,'previous_regions':json.loads((V1/'manifest.json').read_text())['atlas']['regions']},'stone_palette_srgb_author_values':palette,'reference_hashes':{n+'.png':sha(REF/(n+'.png')) for n in ['stone','dirt']},'originality_notes':['Original V1 meshes/UVs retained exactly; all existing atlas region pixels preserved.','Six dirt faces reuse the original V1 independently authored dirt region.','New independently computed stone color clusters; source stone/dirt references read-only.','V2 omits a repeated tiling platform to keep one five-asset primary presentation clear; full V1 tiling study remains untouched.'],'V1_file_hashes_before':before,'V1_original_geometry':original_geometry,'texture_hashes':{p.name:sha(p) for p in (ROOT/'textures').glob('*.png')},'export_hashes':{p.name:sha(p) for p in (ROOT/'exports').glob('*.glb')},'preview_paths':['showcase.png','blocks_comparison.png']}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2));print('V2_AUTHOR_COMPLETE')
