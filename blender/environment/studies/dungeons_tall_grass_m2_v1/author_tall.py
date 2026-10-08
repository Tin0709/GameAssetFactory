"""Native bottom-root segmented crossed cards with float motion attributes."""
import bpy, math, json, struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.name='REVIEW_TallGrass_M2_V1'
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
atlas=bpy.data.images.load(str(ROOT/'meadow_m2_atlas.png'));atlas.pack();atlas.use_fake_user=True
mat=bpy.data.materials.new('MAT_Meadow_M2_Cutout');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest';tex.extension='EXTEND'
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
mat.surface_render_method='DITHERED';mat.use_backface_culling=False;mat['gltf_alpha_mode']='MASK'
vertices=[];faces=[];coords=[]
H=1.95;W=.90
# Two connected cards, eight vertical sections each: 32 triangles total.
for axis in range(2):
    start=len(vertices)
    for row in range(9):
        t=row/8
        for s in [-1,1]:
            p=(s*W/2,0,H*t) if axis==0 else (0,s*W/2,H*t)
            vertices.append(p);coords.append(((38+(s+1)*16)/128,(38+64*t)/128))
    for row in range(8):
        a=start+row*2;faces.append((a,a+1,a+3,a+2))
mesh=bpy.data.meshes.new('TallGrass_M2_SegmentedCross');mesh.from_pydata(vertices,[],faces);mesh.update()
uv=mesh.uv_layers.new(name='UVMap');uv2=mesh.uv_layers.new(name='UV2')
color=mesh.color_attributes.new(name='Bend',type='FLOAT_COLOR',domain='CORNER');mesh.color_attributes.active_color=color
for poly in mesh.polygons:
    for li in poly.loop_indices:
        vi=mesh.loops[li].vertex_index;t=vertices[vi][2]/H
        uv.data[li].uv=coords[vi];uv2.data[li].uv=(.5,.5);color.data[li].color=(t*t,t,0,1)
ob=bpy.data.objects.new('ENV_TallGrass_M2_V1',mesh);scene.collection.objects.link(ob);mesh.materials.append(mat)
ob.asset_mark();ob.asset_data.description='1.95 m original tall meadow plant; one root, 32 tris, COLOR bend and UV2 root contract.'
ob['height_m']=H;ob['bend_mask']='COLOR.r=t^2; COLOR.g=t; UV2=(0.5,0.5)';ob['pivot']='bottom center'
ob.select_set(True);bpy.context.view_layer.objects.active=ob
path=ROOT/'tall_grass_m2_v1.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_all_vertex_colors=True)
raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);rest=raw[20+size:]
# Blender's material-free bend layer is exported as a secondary quantized color.
# Establish the shader contract explicitly as native float COLOR_0 in the GLB.
binary=bytearray(rest[8:]);primitive=doc['meshes'][0]['primitives'][0]
position=doc['accessors'][primitive['attributes']['POSITION']];view=doc['bufferViews'][position['bufferView']]
base=view.get('byteOffset',0)+position.get('byteOffset',0)
values=[]
for i in range(position['count']):
    y=struct.unpack_from('<fff',binary,base+i*12)[1];t=y/H
    t=max(0,min(1,t));values.extend((t*t,t,0,1))
binary.extend(b'\0'*((-len(binary))%4));offset=len(binary);payload=struct.pack('<'+'f'*len(values),*values);binary.extend(payload)
doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload),'target':34962})
doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':5126,'count':position['count'],'type':'VEC4'})
primitive['attributes']['COLOR_0']=len(doc['accessors'])-1;primitive['attributes'].pop('COLOR_1',None)
doc['buffers'][0]['byteLength']=len(binary);rest=struct.pack('<II',len(binary),0x004e4942)+binary
for m in doc['materials']:m.update(alphaMode='MASK',alphaCutoff=.5,doubleSided=True)
for s in doc.get('samplers',[]):s.update(magFilter=9728,minFilter=9728,wrapS=33071,wrapT=33071)
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(js)+len(rest))+struct.pack('<II',len(js),0x4e4f534a)+js+rest)
# Render context is kept out of the export. Real V2 short plant provides scale reference.
v2=ROOT.parent/'dungeons_ground_style_v2/dungeons_ground_style_v2.blend'
with bpy.data.libraries.load(str(v2),link=False) as (src,dst):dst.objects=['ENV_Grass_DI_Study_V1']
short=dst.objects[0];scene.collection.objects.link(short);short.location=(-1.25,0,0)
for m in short.data.materials:
    for n in m.node_tree.nodes:
        if n.type=='TEX_IMAGE':n.image=atlas
def plain(name,c):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1;return m
floor_mat=plain('Review_Backdrop',(.06,.08,.075))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));floor=bpy.context.object;floor.name='REVIEW_Ground';floor.data.materials.append(floor_mat)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for name,pos,power,size in [('Key',(-3,-4,6),700,5),('Fill',(4,1,5),450,5)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;aim(o,(0,0,1))
camdata=bpy.data.cameras.new('Review_Camera');cam=bpy.data.objects.new('Review_Camera',camdata);scene.collection.objects.link(cam)
cam.location=(4,-7,3.5);aim(cam,(-.4,0,.9));camdata.type='ORTHO';camdata.ortho_scale=3.65;scene.camera=cam
scene.world=bpy.data.worlds.new('Review_World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.29,.27,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tall_grass_m2_v1.blend'))
scene.render.filepath=str(ROOT/'review_render.png');bpy.ops.render.render(write_still=True)
manifest={'asset':'ENV_TallGrass_M2_V1','artistic_status':'awaiting human review','blender_source':'tall_grass_m2_v1.blend','native_gltf':'tall_grass_m2_v1.glb','height_m':H,'dimensions_blender_xyz_m':[W,W,H],'dimensions_gltf_xyz_m':[W,H,W],'triangles':32,'geometry':'two crossed cards with 8 vertical segments each','pivot':'bottom center (0,0,0)','axis':'native glTF +Y up','motion_attributes':{'COLOR_0':'FLOAT_COLOR (t²,t,0,1)','TEXCOORD_1':[.5,.5]},'atlas':{'path':'meadow_m2_atlas.png','size':[128,128],'changed_region_blender_bottom_up':[38,38,32,64],'all_other_pixels':'exact V2 preservation','old_four_assets_uvs':'unchanged'},'material':{'alphaMode':'MASK','alphaCutoff':.5,'doubleSided':True,'filter':'nearest','packed_texture':True},'review_render':'review_render.png','reference':{'study':'dungeons_ground_style_v2','short_height_m':.46,'prototype_tall_height_m':.95,'originals':'preserved'},'originality':'Independently authored 7 angular blades with connected crown, varied long tips and lower fans, exact original short-grass palette; no duplicated tuft or copied source alpha.'}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('M2_TALL_AUTHOR_COMPLETE')
