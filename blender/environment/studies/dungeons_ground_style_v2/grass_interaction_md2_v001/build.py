"""Guarded additive candidate in the SAME environment scene; stage before publishing."""
import bpy
import hashlib
import json
import math
import random
import sys
import uuid
from pathlib import Path
from mathutils import Vector

D=Path(__file__).resolve().parent;P=D.parent;R=D.parents[4]
E=R/'.validation/md2_grass_interaction_v001';LIB=P/'dungeons_ground_style_v2.blend'
sys.path[:0]=[str(D),str(P/'grass_wind_md2_v001')]
from field import CONTROLS, NAME, SIZE
import wind_nodes
import interaction_nodes

assert hashlib.sha256(LIB.read_bytes()).hexdigest()==(E/'before.sha256').read_text().strip()
bpy.ops.wm.open_mainfile(filepath=str(LIB));scene=bpy.context.scene
assert 'md2_interaction_review' not in scene,'Never rebuild over a completed interaction candidate.'
wind=json.loads(scene['md2_wind_review']);old_layers=list(scene.view_layers)
original={k:getattr(scene,k) for k in wind['original_timeline']}
def collection(name,parent):
    c=bpy.data.collections.new(name);parent.children.link(c);return c
root=collection(NAME+'_PENDING',scene.collection);root['review_status']='Pending';root['research_only']=True
field=collection('01_MD2_Interaction_Field',root);studio=collection('02_MD2_Interaction_Studio',root)
proxy_collection=collection('03_MD2_Interaction_Proxy',root)
controller=bpy.data.objects.new(NAME+'_Controls',None);studio.objects.link(controller);controller.hide_render=True
for key,(value,lo,hi,description) in CONTROLS.items():
    controller[key]=value;kw={'description':description,'default':value}
    if lo is not None:kw.update(min=lo,max=hi,soft_min=lo,soft_max=hi)
    controller.id_properties_ui(key).update(**kw)
controller['review_status']='Pending';controller['Preview Phase']='WALK / SHORT GRASS'
image=bpy.data.images.new(NAME+'_Shared_Field',*SIZE,alpha=True,float_buffer=True)
image.colorspace_settings.name='Non-Color'
import numpy as np
pixels=np.full((SIZE[1],SIZE[0],4),.5,dtype=np.float32);pixels[...,3]=1.
image.pixels.foreach_set(pixels.ravel());image.update()
group,sockets=interaction_nodes.make_group(image)
windgroup=bpy.data.node_groups[wind_nodes.NAME];windcontroller=bpy.data.objects[wind['controller']]
windsockets={s.name:s.identifier for s in windgroup.interface.items_tree if s.item_type=='SOCKET' and s.in_out=='INPUT'}
masters=[bpy.data.objects[n] for n in wind['masters']]
catalog=str(uuid.uuid5(uuid.NAMESPACE_URL,'GameAssetFactory/Environment/MD2GrassInteractionPending'))
rng=random.Random(8352);grasses=[]
def grass(source,name,x,y,angle):
    o=bpy.data.objects.new(name,source.data);field.objects.link(o);o.location=(x,y,1.);o.rotation_euler.z=angle
    o.visible_shadow=False;o['review_status']='Pending';o['wind_source']=source['wind_source'];o['interaction_family']='Tall' if source in masters[5:] else 'Short'
    o['research_only']=True
    tall=source in masters[5:]
    wind_nodes.add_modifier(o,windcontroller,windgroup,windsockets,tall,rng.random()*math.tau)
    interaction_nodes.add_modifier(o,controller,group,sockets,1. if tall else .38)
    grasses.append(o);return o
base=bpy.data.objects['ENV_GrassBlock_DI_V3']
for x in range(-3,4):
    for y in range(-2,3):
        o=bpy.data.objects.new('MD2_Interaction_Ground_%d_%d'%(x,y),base.data);field.objects.link(o);o.location=(x,y,0.)
        source=masters[(x-y)%4] if y<0 else masters[5+(x+y)%4]
        if y==0:source=masters[4] if x%2 else masters[9]
        grass(source,'MD2_Interaction_Grass_%d_%d'%(x,y),x+rng.uniform(-.035,.035),y, rng.uniform(-math.pi,math.pi))
for i in range(8):
    x=-2.5+i%6;y=-1.5 if i<6 else .5
    grass(masters[i%4] if i<6 else masters[5+i%4],'MD2_Interaction_Infill_%d'%i,x,y,rng.uniform(-math.pi,math.pi))
root.asset_mark();root.asset_data.catalog_id=catalog
root.asset_data.description='Pending MD2_Grass_Interaction_v001 / original shared spring-field study; Wind v001 preserved.'

def material(name,color):
    mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1.);mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(*color,1.);bsdf.inputs['Roughness'].default_value=.9
    return mat
gray=material('MD2_Interaction_Proxy_Gray',(.19,.23,.25))
light=material('MD2_Interaction_Proxy_Light',(.48,.53,.53))
orange=material('MD2_Interaction_Proxy_Front',(.62,.22,.055))
def empty(name,parent=None,loc=(0.,0.,0.)):
    o=bpy.data.objects.new(name,None);proxy_collection.objects.link(o);o.parent=parent;o.location=loc;return o
def cube(name,size,loc,mat,parent=None):
    sx,sy,sz=[n/2 for n in size]
    verts=[(x,y,z) for x,y,z in [(-sx,-sy,-sz),(-sx,-sy,sz),(-sx,sy,-sz),(-sx,sy,sz),(sx,-sy,-sz),(sx,-sy,sz),(sx,sy,-sz),(sx,sy,sz)]]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)])
    mesh.materials.append(mat);o=bpy.data.objects.new(name,mesh);proxy_collection.objects.link(o);o.parent=parent;o.location=loc;return o
proxy_root=empty('MD2_Interaction_Proxy_Root',loc=(-7,-4,1.));proxy={'root':proxy_root.name}
cube('MD2_Interaction_Proxy_Torso',(.45,.225,.675),(0,0,1.0125),gray,proxy_root)
cube('MD2_Interaction_Proxy_Head',(.45,.45,.45),(0,0,1.575),light,proxy_root)
cube('MD2_Interaction_Proxy_FrontMarker',(.18,.004,.18),(0,-.115,1.15),orange,proxy_root)
for key,x in [('leg_l',.115),('leg_r',-.115),('arm_l',.31),('arm_r',-.31)]:
    arm=key.startswith('arm');pivot=empty('MD2_Interaction_Proxy_'+key,proxy_root,(x,0,1.33 if arm else .675));proxy[key]=pivot.name
    cube('MD2_Interaction_Proxy_'+key+'_Mesh',(.15 if arm else .205,.225,.675),(0,0,-.3375),gray,pivot)

floor=bpy.data.meshes.new('MD2_Interaction_Studio_Floor')
floor.from_pydata([(-80,-80,-.026),(80,-80,-.026),(80,80,-.026),(-80,80,-.026)],[],[(0,1,2,3)])
floor.materials.append(bpy.data.materials['REVIEW_Studio_Charcoal_Soft_V2'])
o=bpy.data.objects.new(floor.name,floor);studio.objects.link(o)
for old in bpy.data.collections[wind['studio_collection']].objects:
    if old.type=='LIGHT':
        o=bpy.data.objects.new(old.name.replace('Wind','Interaction'),old.data.copy());studio.objects.link(o);o.matrix_world=old.matrix_world.copy()
cameras={}
for key,pos,target,scale in [('Gameplay',(9,-12,14),(0,0,1.),11.1),('Close',(6,-9,9),(0,0,1.2),8.4)]:
    d=bpy.data.cameras.new('MD2_Interaction_Camera_'+key);d.type='ORTHO';d.ortho_scale=scale
    o=bpy.data.objects.new(d.name,d);studio.objects.link(o);o.location=pos
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();cameras[key]=o.name
layer=scene.view_layers.new('Grass MD2 Interaction')
for child in layer.layer_collection.children:child.exclude=child.collection!=root
for old in old_layers:old.layer_collection.children[root.name].exclude=True
scene['md2_interaction_review']=json.dumps({'revision':NAME,'status':'Pending','layer':layer.name,'root':root.name,
    'controller':controller.name,'group':group.name,'image':image.name,'proxy':proxy,'cameras':cameras,
    'grass_objects':[o.name for o in grasses],'original_timeline':original,'field_collection':field.name,'studio_collection':studio.name})
sys.path.insert(0,str(P/'tall_grass_md2_v001'))
import grass_library_ui
import interaction_review_ui as ui
ui.register();ui.select(bpy.context);scene.frame_set(1)
report={'status':'Pending','field_clumps':len(grasses),'grass_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in grasses),
    'new_grass_meshes':0,'new_node_groups':1,'new_scenes':0,'new_actions':0,'shared_grid':list(SIZE),
    'default_controls':{k:v[0] for k,v in CONTROLS.items()},'proxy_height_m':1.8,'duration_s':20.,
    'catalog_line':catalog+':Environment/Grass Interaction Pending:Grass Interaction Pending\n'}
(D/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(E/LIB.name),relative_remap=False,compress=True)
print('MD2_INTERACTION_BUILT',json.dumps(report),flush=True)
