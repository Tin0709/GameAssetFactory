"""Reproduce the original three-asset study with Blender 5.2, background factory startup."""
import bpy, math, json, hashlib, struct
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
WORK=ROOT.parents[3]
VALID=WORK/'.validation/dungeons_grass_style_v1'
REF=WORK/'references/resource_packs/dungeons_ii_style/extracted/assets/minecraft/textures/block'
for p in (ROOT/'textures',ROOT/'exports',VALID): p.mkdir(parents=True,exist_ok=True)
REF_NAMES=['dirt','grass_block_top','grass_block_side','grass_block_side_overlay','short_grass','tall_grass_bottom','tall_grass_top']
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
refs={n:sha(REF/(n+'.png')) for n in REF_NAMES}

# Independent 32px fields: quantized overlapping low frequency waves, periodic on 31px.
def field(x,y,phase=0):
    x=x%31; y=y%31
    v=math.sin(2*math.pi*(x+phase)/31)+.7*math.cos(2*math.pi*(y-phase)/31)+.45*math.sin(2*math.pi*(x+y+phase)/31)
    return max(0,min(4,int((v+2.15)/.88)))
greens=[(91,120,60),(100,131,66),(111,142,72),(119,149,78),(128,156,85)]
earth=[(119,85,59),(130,94,64),(141,103,70),(151,112,77),(160,121,84)]
top=[[(*greens[field(x,y,5)],255) for x in range(32)] for y in range(32)]
dirt=[[(*earth[field(x,y,13)],255) for x in range(32)] for y in range(32)]
side=[]
for y in range(32):
    row=[]
    for x in range(32):
        cap=23+int(2.1*math.sin(2*math.pi*(x%31)/31)+1.1*math.sin(6*math.pi*(x%31)/31))
        color=greens[field(x,y,5)] if y>=cap else earth[field(x,y,13)]
        if y==cap-1: color=tuple(round(c*.92) for c in greens[1])
        row.append((*color,255))
    side.append(row)

def contains(x,y,poly):
    inside=False; j=len(poly)-1
    for i in range(len(poly)):
        xi,yi=poly[i]; xj,yj=poly[j]
        if (yi>y)!=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi: inside=not inside
        j=i
    return inside

def plants(h):
    # New authored angular broad blades, leaning alternately; no source alpha sampling.
    if h==32:
        blades=[[(13,0),(8,7),(4,12),(2,20),(6,18),(10,12),(17,0)],[(12,0),(10,12),(10,24),(13,29),(15,23),(15,11),(18,0)],[(15,0),(17,13),(22,23),(27,27),(26,20),(22,13),(20,0)],[(15,0),(6,5),(3,10),(6,12),(12,8),(20,0)],[(17,0),(23,6),(29,12),(31,18),(26,16),(20,9),(14,0)],[(14,0),(14,17),(18,22),(20,19),(18,8),(19,0)]]
    else:
        blades=[[(12,0),(9,16),(6,29),(3,43),(5,49),(9,39),(12,23),(17,0)],[(12,0),(11,27),(12,53),(15,64),(17,57),(17,29),(18,0)],[(15,0),(18,24),(23,40),(28,53),(29,47),(26,32),(23,19),(20,0)],[(15,0),(7,14),(2,23),(1,32),(5,30),(11,20),(20,0)],[(17,0),(23,15),(29,25),(31,37),(27,35),(22,27),(14,0)],[(15,0),(15,32),(18,46),(21,49),(22,43),(20,29),(19,0)],[(13,0),(9,29),(9,44),(7,55),(5,53),(6,35),(10,0)]]
    palette=[(119,148,76),(138,160,91),(101,130,63),(111,140,69),(131,153,82),(146,165,98),(123,145,77)]
    out=[]
    for y in range(h):
        row=[]
        for x in range(32):
            c=(0,0,0,0)
            for i,poly in enumerate(blades):
                if contains(x+.5,y+.5,poly):
                    base=palette[i]; lift=3 if y>h*.65 else (-6 if y<h*.2 else 0)
                    c=(*(max(0,min(255,k+lift)) for k in base),255)
            row.append(c)
        out.append(row)
    return out
short=plants(32); tall=plants(64)
regions={'grass_top':(2,2,32,32),'dirt':(38,2,32,32),'grass_side':(74,2,32,32),'short_grass':(2,38,32,32),'tall_grass':(38,38,32,64)}
arrays=dict(zip(regions,[top,dirt,side,short,tall]))
atlas=[[(0,0,0,0) for x in range(128)] for y in range(128)]
def save_image(name,data):
    h=len(data); w=len(data[0]); im=bpy.data.images.new(name,width=w,height=h,alpha=True)
    im.pixels.foreach_set([c/255 for row in data for pixel in row for c in pixel]); im.filepath_raw=str(ROOT/'textures'/(name+'.png')); im.file_format='PNG'; im.save(); im.pack(); im.use_fake_user=True; return im
for n,a in arrays.items():
    save_image(n,a); ox,oy,w,h=regions[n]
    for y in range(-2,h+2):
        for x in range(-2,w+2): atlas[oy+y][ox+x]=a[min(h-1,max(0,y))][min(w-1,max(0,x))]
atlas_image=save_image('meadow_atlas',atlas); atlas_image.pack()

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene; scene.name='REVIEW_DungeonsGrass_Style_V1'
assets=bpy.data.collections.new('ASSETS_Export'); scene.collection.children.link(assets)
instances=bpy.data.collections.new('REVIEW_Instances'); scene.collection.children.link(instances)
presentation=bpy.data.collections.new('REVIEW_Presentation'); scene.collection.children.link(presentation)
def material(name,masked=False):
    m=bpy.data.materials.new(name); m.use_nodes=True
    n=m.node_tree.nodes; bs=n.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.92
    tex=n.new('ShaderNodeTexImage'); tex.image=atlas_image; tex.interpolation='Closest'; tex.extension='EXTEND'
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    if masked:
        m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']); m.surface_render_method='DITHERED'; m.use_backface_culling=False
        m['gltf_alpha_mode']='MASK'; m['alpha_binary']=True
    return m
opaque=material('MAT_Meadow_Atlas_Opaque'); cutout=material('MAT_Meadow_Atlas_Cutout',True)
def rect(n):
    x,y,w,h=regions[n]; return [(x/128,y/128),((x+w)/128,y/128),((x+w)/128,(y+h)/128),(x/128,(y+h)/128)]
def meshobj(name,vertices,faces,uvnames,mat):
    me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(vertices,[],faces); me.update(); uv=me.uv_layers.new(name='UVMap')
    for poly,n in zip(me.polygons,uvnames):
        for li,co in zip(poly.loop_indices,rect(n)): uv.data[li].uv=co
    ob=bpy.data.objects.new(name,me); assets.objects.link(ob); me.materials.append(mat); ob.asset_mark(); ob.asset_data.description='Original muted meadow study; bottom-center pivot; metres; nearest-filtered shared atlas.'; return ob
v=[(-.5,-.5,0),(.5,-.5,0),(.5,.5,0),(-.5,.5,0),(-.5,-.5,1),(.5,-.5,1),(.5,.5,1),(-.5,.5,1)]
block=meshobj('ENV_GrassBlock_DI_Study_V1',v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],['dirt','grass_top']+['grass_side']*4,opaque)
def card(name,w,h,region):
    s=w/2; return meshobj(name,[(-s,0,0),(s,0,0),(s,0,h),(-s,0,h),(0,-s,0),(0,s,0),(0,s,h),(0,-s,h)],[(0,1,2,3),(4,5,6,7)],[region]*2,cutout)
grass=card('ENV_Grass_DI_Study_V1',.58,.46,'short_grass'); tallgrass=card('ENV_TallGrass_DI_Study_V1',.72,.95,'tall_grass')
block.location=(-2,0,0); grass.location=(0,0,1); tallgrass.location=(2,0,1)
def linked(source,name,loc):
    o=bpy.data.objects.new(name,source.data); instances.objects.link(o); o.location=loc; return o
linked(block,'Sample_Small_Base',(0,0,0)); linked(block,'Sample_Tall_Base',(2,0,0))
for x in range(3):
    for y in range(3): linked(block,f'Tile_{x}_{y}',(x-1,y+3.6,0))
for i,(x,y,z,kind,ang) in enumerate([(-.8,3.1,1,grass,.2),(.5,3.8,1,grass,1.0),(1,4.5,1,tallgrass,.35),(-.9,4.6,1,tallgrass,1.1),(.1,5.1,1,grass,.7)]):
    o=linked(kind,'Meadow_Clump_'+str(i),(x,y,z)); o.rotation_euler.z=ang
def plain(name,color):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True; m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1); return m
floor_mat=plain('Studio_Charcoal',(0.105,.135,.13)); textmat=plain('Type_Cream',(.78,.81,.69))
def move_collection(o,col):
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o)
bpy.ops.mesh.primitive_plane_add(size=200); floor=bpy.context.object; floor.name='Studio_Floor'; floor.location.z=-.035; floor.data.materials.append(floor_mat); move_collection(floor,presentation)
def text(body,loc,size):
    curve=bpy.data.curves.new(body,'FONT'); curve.body=body; curve.size=size; curve.align_x='CENTER'; curve.extrude=0
    ob=bpy.data.objects.new('Label_'+body,curve); presentation.objects.link(ob); ob.location=loc; curve.materials.append(textmat); return ob
# Floor typography is readable in the raised front camera and never part of exports.
for x,title,note in [(-2,'GRASS BLOCK','1 m  /  12 triangles'),(0,'SHORT GRASS','0.46 m  /  4 triangles'),(2,'TALL GRASS','0.95 m  /  4 triangles')]:
    text(title,(x,-1,.005),.17); text(note,(x,-1.28,.005),.10)
text('MEADOW  /  ORIGINAL PIXEL STUDY',(0,-2,.005),.21)
def aim(ob,point): ob.rotation_euler=(Vector(point)-ob.location).to_track_quat('-Z','Y').to_euler()
def camera(name,pos,target,scale):
    d=bpy.data.cameras.new(name); o=bpy.data.objects.new(name,d); presentation.objects.link(o); o.location=pos; aim(o,target); d.type='ORTHO'; d.ortho_scale=scale; return o
cameras=[camera('CAM_Showcase',(6,-10,8),(0,.25,.65),7.6),camera('CAM_Tiling',(6,-3,8),(0,4.5,.75),5.5),camera('CAM_Closeup',(4,-6,4.2),(1,.05,1.02),3.7)]
def light(name,kind,pos,energy,color,size=5):
    d=bpy.data.lights.new(name,kind); o=bpy.data.objects.new(name,d); presentation.objects.link(o); o.location=pos; d.energy=energy; d.color=color
    if kind=='AREA': d.shape='DISK'; d.size=size
    aim(o,(0,1,0)); return o
light('Warm_Key','AREA',(-3,-4,8),1100,(1,.89,.73),7); light('Soft_Fill','AREA',(5,1,6),800,(.78,.88,1),8)
scene.world.color=(.22,.22,.22); scene.render.engine='CYCLES'; scene.cycles.samples=48
scene.render.resolution_x=1600; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'; scene.camera=cameras[0]

# Isolated export copies at origin. Blender transparent glTF exporter defaults to BLEND;
# binary alpha is explicitly normalized to MASK in the exported JSON chunk below.
def force_mask(path):
    raw=path.read_bytes(); length,kind=struct.unpack_from('<II',raw,12); doc=json.loads(raw[20:20+length]); rest=raw[20+length:]
    for m in doc.get('materials',[]):
        if 'Cutout' in m.get('name',''): m['alphaMode']='MASK'; m['alphaCutoff']=.5; m['doubleSided']=True
    js=json.dumps(doc,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(js)+len(rest))+struct.pack('<II',len(js),0x4e4f534a)+js+rest)
exports=[]
for ob,filename in [(block,'grass_block'),(grass,'grass'),(tallgrass,'tall_grass')]:
    bpy.ops.object.select_all(action='DESELECT'); copy=bpy.data.objects.new('Export_'+filename,ob.data); scene.collection.objects.link(copy); copy.select_set(True); bpy.context.view_layer.objects.active=copy
    path=ROOT/'exports'/(filename+'_di_study_v1.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    force_mask(path); exports.append(path); bpy.data.objects.remove(copy,do_unlink=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.shading.type='MATERIAL'; area.spaces.active.shading.use_scene_lights=True; area.spaces.active.shading.use_scene_world=True
bpy.ops.object.select_all(action='DESELECT'); block.select_set(True); bpy.context.view_layer.objects.active=block
blend=ROOT/'dungeons_grass_style_v1.blend'; bpy.ops.wm.save_as_mainfile(filepath=str(blend))
for cam,n in zip(cameras,['showcase','tiling','closeup']):
    scene.camera=cam; scene.render.filepath=str(ROOT/(n+'.png')); bpy.ops.render.render(write_still=True)
scene.camera=cameras[0]
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
manifest={'study':'Dungeons grass style V1','artistic_status':'awaiting human review','assets':[{'name':o.name,'dimensions_m':list(o.dimensions),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'pivot':'bottom center','materials':[m.name for m in o.data.materials]} for o in [block,grass,tallgrass]],'atlas':{'path':'textures/meadow_atlas.png','size':[128,128],'gutters_px':2,'regions':regions,'filter':'Closest','packed':True},'reference_paths_hashes':{str(REF/(n+'.png')):h for n,h in refs.items()},'texture_hashes':{p.name:sha(p) for p in (ROOT/'textures').glob('*.png')},'export_hashes':{p.name:sha(p) for p in exports},'originality_notes':['No source pixel data was sampled during generation. References were inspected in a seven-image board only.','New quantized periodic analytic fields generate broad independent color patches; authored polygon blade coordinates define new cutout silhouettes.','Hash differences demonstrate distinct files, not by themselves artistic originality.','Only original atlas is used by asset materials and embedded into GLBs.'],'units':'metres; Blender Z up / glTF Y up','source_reference_hashes_unchanged':refs=={n:sha(REF/(n+'.png')) for n in REF_NAMES}}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('AUTHORING_COMPLETE',json.dumps(manifest['assets']))
