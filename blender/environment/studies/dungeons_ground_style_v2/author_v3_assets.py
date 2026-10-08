"""Add a separate V3 study to the preserved V2 scene; Blender Z-up metres."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
scene=bpy.context.scene
assert 'ENV_GrassBlock_DI_Study_V1' in bpy.data.objects
assert not bpy.data.collections.get('REVIEW_DungeonsII_V3'), 'V3 already present'
before={o.name:{'location':list(o.location),'data':o.data.name if o.data else None} for o in scene.objects}
parent=bpy.data.collections.new('REVIEW_DungeonsII_V3');scene.collection.children.link(parent)
def collection(name):
    c=bpy.data.collections.new(name);parent.children.link(c);return c
assets=collection('V3_Assets_Export'); instances=collection('V3_Review_Instances'); pres=collection('V3_Presentation')
def material(n,cutout=False):
    m=bpy.data.materials.new('DI_V3_'+n);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1;bs.inputs['Specular IOR Level'].default_value=.08
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'v3_textures'/(n+'.png')),check_existing=False);tex.image.pack();tex.interpolation='Closest';tex.extension='REPEAT'
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    if cutout:
        m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=False
    return m
mats={n:material(n,n in ['grass','tall_grass']) for n in ['grass_top_0','grass_top_1','grass_top_2','grass_top_3','grass_side','dirt','stone','grass','tall_grass']}
def meshobj(name,verts,faces,col):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);col.objects.link(ob);return ob
verts=[(-.5,-.5,0),(.5,-.5,0),(.5,.5,0),(-.5,.5,0),(-.5,-.5,1),(.5,-.5,1),(.5,.5,1),(-.5,.5,1)]
faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
uvs=[(0,0),(1,0),(1,1),(0,1)]
def cube(name,kind):
    ob=meshobj(name,verts,faces,assets);me=ob.data;uv=me.uv_layers.new(name='UVMap')
    names=['dirt','grass_top_0','grass_side'] if kind=='grass' else [kind]
    for n in names:me.materials.append(mats[n])
    for i,p in enumerate(me.polygons):
        p.material_index=(0 if i==0 else 1 if i==1 else 2) if kind=='grass' else 0
        for li,xy in zip(p.loop_indices,uvs):uv.data[li].uv=xy
    ob.asset_mark();ob.asset_data.description='Original Dungeons-inspired angular pixel study; 1m cube, bottom-centre, 12 triangles; REVIEW ONLY.'
    return ob
grassblock=cube('ENV_GrassBlock_DI_V3','grass');dirt=cube('ENV_DirtBlock_DI_V3','dirt');stone=cube('ENV_StoneBlock_DI_V3','stone')
def card(name,w,h,n):
    v=[];f=[];coords=[]
    # Two crossed cards, four height segments; reusable future rooted-bend data.
    for angle in [0,math.pi/2]:
        base=len(v)
        for row in range(5):
            t=row/4
            for sign in [-1,1]:v.append((sign*w/2*math.cos(angle),sign*w/2*math.sin(angle),h*t));coords.append((0 if sign==-1 else 1,t))
        for row in range(4):i=base+row*2;f.append((i,i+1,i+3,i+2))
    ob=meshobj(name,v,f,assets);me=ob.data;me.materials.append(mats[n]);uv=me.uv_layers.new(name='UVMap')
    color=me.color_attributes.new(name='COLOR_0',type='FLOAT_COLOR',domain='POINT')
    for i,vtx in enumerate(me.vertices):
        t=vtx.co.z/h;color.data[i].color=(t*t,t,0,1)
    for p in me.polygons:
        for li in p.loop_indices:uv.data[li].uv=coords[me.loops[li].vertex_index]
    ob.asset_mark();ob.asset_data.description=f'Original square-tipped grass, {h}m high, root-centre origin, 16 triangles, packed alpha texture; REVIEW ONLY.'
    return ob
grass=card('ENV_Grass_DI_V3',.62,.46,'grass');tall=card('ENV_TallGrass_DI_V3',.78,.95,'tall_grass');tall2=card('ENV_TallGrass_2Block_DI_V3',.9,1.95,'tall_grass')
for ob,loc in [(grassblock,(7,0,0)),(dirt,(9,0,0)),(stone,(11,0,0)),(grass,(7,3.2,1)),(tall,(9,3.2,1)),(tall2,(11,3.2,1))]:ob.location=loc
def linked(source,name,loc,col=instances):
    o=bpy.data.objects.new(name,source.data);col.objects.link(o);o.location=loc;return o
for x in [7,9,11]:linked(grassblock,'V3_Plant_Base_'+str(x),(x,3.2,0))
textmat=bpy.data.materials['Type_Cream']
def text(body,pos,size):
    c=bpy.data.curves.new('V3_'+body,'FONT');c.body=body;c.size=size;c.align_x='CENTER';o=bpy.data.objects.new('V3_Label_'+body,c);pres.objects.link(o);o.location=pos;c.materials.append(textmat)
for x,title in [(7,'GRASS BLOCK'),(9,'DIRT BLOCK'),(11,'STONE BLOCK')]:text(title,(x,-.95,.005),.16);text('1 x 1 x 1 m',(x,-1.22,.006),.09)
for x,title,sub in [(7,'SHORT GRASS','0.46 m'),(9,'TALL GRASS','0.95 m'),(11,'TWO-BLOCK GRASS','1.95 m')]:text(title,(x,2.25,.006),.13);text(sub,(x,2.02,.006),.09)
text('DUNGEONS DIRECTION / V3 ORIGINAL TEXTURES',(9,-1.95,.008),.19)
text('V2 PRESERVED',(0,-2.4,.008),.13)
# A small assembled terrain patch makes repetition and scale reviewable.
for x in range(5):
    for y in range(5):
        o=linked(grassblock,f'V3_Tile_{x}_{y}',(x+7,y+6.5,0))
        o.data=o.data.copy();o.data.materials[1]=mats['grass_top_'+str((x*7+y*3)%4)]
        o.rotation_euler.z=((x+2*y)%4)*math.pi/2
for i,(x,y) in enumerate([(7.3,6.7),(8.6,7.5),(10.5,6.8),(9.4,9.4),(7.4,9.8),(10.8,10.1),(8.2,8.9),(9.9,8.2)]):
    o=linked(grass if i%4 else tall,f'V3_Patch_Grass_{i}',(x,y,1));o.rotation_euler.z=i*.61
for i in range(3):linked(dirt,'V3_Patch_Dirt_'+str(i),(6,7.5+i,0))
for i in range(3):linked(stone,'V3_Patch_Stone_'+str(i),(12,7.5+i,0))
text('TILING / FOUR TOP VARIANTS',(9,5.55,.008),.16)
def aim(o,point):o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()
def camera(name,pos,target,scale):
    data=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,data);pres.objects.link(o);o.location=pos;aim(o,target);data.type='ORTHO';data.ortho_scale=scale;return o
show=camera('CAM_V3_Showcase',(16,-12,11),(9,1,.65),9.0)
ab=camera('CAM_V3_AB',(13,-17,15),(4.5,1,.6),17)
patch=camera('CAM_V3_Tiling',(15,1,10),(9,8.5,.8),7.6)
for name,pos,energy,color,size in [('V3_Warm_Key',(6,-3,8),1000,(1,.96,.87),7),('V3_Cool_Fill',(14,4,7),750,(.84,.92,1),8)]:
    data=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,data);pres.objects.link(o);o.location=pos;data.energy=energy;data.color=color;data.shape='DISK';data.size=size;aim(o,(9,1,0))
bpy.context.view_layer.update()
assert all(list(bpy.data.objects[n].location)==v['location'] and (bpy.data.objects[n].data.name if bpy.data.objects[n].data else None)==v['data'] for n,v in before.items()),'Old objects changed'
manifest={'status':'AWAITING HUMAN REVIEW','assets':[{'name':o.name,'dimensions':list(o.dimensions),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'location':list(o.location)} for o in assets.objects],'old_object_count':len(before),'old_objects_preserved':True,'scene':scene.name,'collection':parent.name,'mobile':'12 triangles/cube,16/plant; no modifiers; packed nearest textures; no Godot changes','source_texture_manifest':'v3_texture_manifest.json'}
(ROOT/'v3_asset_manifest.json').write_text(json.dumps(manifest,indent=2))
scene.camera=show;scene.render.resolution_x=1500;scene.render.resolution_y=1050;scene.render.resolution_percentage=100;scene.cycles.samples=32
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'v3_asset_library.blend'))
for cam,path in [(show,'v3_showcase.png'),(ab,'v3_ab.png'),(patch,'v3_tiling.png')]:
    scene.camera=cam;scene.render.filepath=str(ROOT/path);bpy.ops.render.render(write_still=True)
scene.camera=show
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'v3_asset_library.blend'))
print('V3_ASSET_REVIEW_READY')
