"""Export single-surface V3 native assets with the runtime shared atlas and rooted bend data."""
import bpy,json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent;WORK=ROOT.parents[3];OUT=WORK/'game_mobile_3d/assets/environment/litematic_m2_v2'
regions=json.loads((OUT/'atlas_regions.json').read_text())['blender_bottom_up_regions']
im=bpy.data.images.load(str(OUT/'meadow_m2_atlas.png'),check_existing=False);im.pack()
def mat(name,cutout):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1
    node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest';m.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    if cutout:m.node_tree.links.new(node.outputs['Alpha'],bs.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=False
    return m
opaque=mat('DI_V3_Runtime_Atlas',False);cutout=mat('DI_V3_Runtime_Cutout',True)
spec=[('ENV_GrassBlock_DI_V3','grass_block_di_v3','block'),('ENV_DirtBlock_DI_V3','dirt_block_di_v3','dirt'),('ENV_StoneBlock_DI_V3','stone_block_di_v3','stone'),('ENV_Grass_DI_V3','grass_di_v3','grass'),('ENV_TallGrass_2Block_DI_V3','tall_grass_2block_di_v3','tall_grass')]
exported=[]
for source,name,kind in spec:
    me=bpy.data.objects[source].data.copy()
    for p in me.polygons:
        region=('grass_top_0' if p.normal.z>.5 else 'dirt' if p.normal.z<-.5 else 'grass_side') if kind=='block' else kind
        x,y,w,h=regions[region]
        for li in p.loop_indices:
            uv=me.uv_layers.active.data[li].uv.copy();me.uv_layers.active.data[li].uv=((x+uv.x*w)/256,(y+uv.y*h)/128)
        p.material_index=0
    me.materials.clear();me.materials.append(cutout if kind in ['grass','tall_grass'] else opaque)
    if kind in ['grass','tall_grass']:
        rootuv=me.uv_layers.new(name='UV2_Root')
        for uv in rootuv.data:uv.uv=(.5,.5)
    o=bpy.data.objects.new('EXPORT_'+source,me);bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    path=OUT/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    raw=path.read_bytes();length,_=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length]);rest=raw[20+length:]
    # Blender 5 inserts a white material COLOR_0 and puts the authored bend
    # attribute in COLOR_1. Godot's wind shader consumes COLOR_0: preserve
    # the actual authored root/tip weights in that semantic on export.
    if kind in ['grass','tall_grass']:
        for mesh in doc['meshes']:
            for primitive in mesh['primitives']:
                attrs=primitive['attributes']
                if 'COLOR_1' in attrs: attrs['COLOR_0']=attrs.pop('COLOR_1')
    for m in doc.get('materials',[]):
        if 'Cutout' in m.get('name',''):m.update(alphaMode='MASK',alphaCutoff=.5,doubleSided=True)
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(js)+len(rest))+struct.pack('<II',len(js),0x4e4f534a)+js+rest)
    exported.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for p in me.polygons)})
    bpy.data.objects.remove(o,do_unlink=True)
r=json.loads((OUT/'runtime_map.json').read_text())
for e in r['registry']:e['sha256']=hashlib.sha256((WORK/'game_mobile_3d'/e['asset'].removeprefix('res://')).read_bytes()).hexdigest()
(OUT/'runtime_map.json').write_text(json.dumps(r,separators=(',',':')))
(OUT/'asset_registry.json').write_text(json.dumps({'entries':r['registry'],'unsupported':[],'style':'User-approved Dungeons V3'},indent=2))
(OUT/'export_report.json').write_text(json.dumps(exported,indent=2));print('V3_NATIVE_EXPORTS_READY',exported)
