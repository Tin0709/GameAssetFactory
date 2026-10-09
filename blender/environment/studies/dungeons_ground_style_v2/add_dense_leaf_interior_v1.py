"""Live additive denser interior cutout layers with isolated0.88linear albedo multiplier."""
import bpy,json,sys,random,math
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE));from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve();base=json.loads((EVIDENCE/'before_dense_leaf_interior_fingerprints.json').read_text());assert not compare(base['data']);assert not bpy.data.objects.get('ENV_LeafBlock_1m_V1_A_DenseInterior')
outer=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];mat=outer.copy();mat.name='MAT_LeafModules_V1_Interior_088Linear';nodes=mat.node_tree.nodes;bsdf=nodes['Principled BSDF'];tex=bsdf.inputs['Base Color'].links[0].from_node;mix=nodes.new('ShaderNodeMix');mix.name='Interior Linear Albedo 0.88';mix.data_type='RGBA';mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
colorinputs=[s for s in mix.inputs if s.type=='RGBA'];colorinputs[1].default_value=(.88,.88,.88,1);mat.node_tree.links.new(tex.outputs['Color'],colorinputs[0]);mat.node_tree.links.new(next(s for s in mix.outputs if s.type=='RGBA'),bsdf.inputs['Base Color']);collection=bpy.data.collections['LEAF_MODULES_1Block_V1'];reports=[]
for variant in('A','B','C'):
 rng=random.Random(821717+ord(variant)*991);verts=[];faces=[];uvs=[]
 for z in(.28,.68):
  for y in(-.27,0,.27):
   for x in(-.27,0,.27):
    center=Vector((x+rng.uniform(-.012,.012),y+rng.uniform(-.012,.012),z+rng.uniform(-.018,.018)));az=rng.uniform(-.25,.25);w=rng.uniform(.30,.37);h=rng.uniform(.30,.39)
    for angle in(az,az+math.pi*.5):
     right=Vector((math.cos(angle),math.sin(angle),0));up=Vector((0,0,1));points=[center+right*a*w*.5+up*b*h*.5 for a,b in((-1,-1),(1,-1),(1,1),(-1,1))];assert all(-.5<v.x<.5 and -.5<v.y<.5 and 0<v.z<1 for v in points);start=len(verts);verts.extend(tuple(v)for v in points);faces.append(tuple(range(start,start+4)));uvs.append([(x+.5+a*w*.5,z+b*h*.5)for a,b in((-1,-1),(1,-1),(1,1),(-1,1))])
 mesh=bpy.data.meshes.new('ENV_LeafBlock_1m_V1_'+variant+'_DenseInteriorPlanes');mesh.from_pydata(verts,[],faces);mesh.materials.append(mat);mesh.update();uv=mesh.uv_layers.new(name='UV_UserLeafTile_1RepeatPerMetre')
 for p,coords in zip(mesh.polygons,uvs):
  for li,coord in zip(p.loop_indices,coords):uv.data[li].uv=coord
 child=bpy.data.objects.new('ENV_LeafBlock_1m_V1_'+variant+'_DenseInterior',mesh);collection.objects.link(child);child.parent=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];reports.append({'variant':variant,'object':child.name,'quads':36,'triangles':72,'interior_linear_albedo_multiplier':.88})
assembly=json.loads((HERE/'leaf_plus_6blocks_v1_manifest.json').read_text());acollection=bpy.data.collections['LEAF_CLUSTER_Plus_6Blocks_V1']
for spec in assembly['cells']:
 source=bpy.data.objects['ENV_LeafBlock_1m_V1_'+spec['variant']+'_DenseInterior'];child=bpy.data.objects.new(spec['object']+'_DenseInterior',source.data);acollection.objects.link(child);child.parent=bpy.data.objects[spec['object']]
assert not compare(base['data'])
manifest={'status':'Latest denser and slightly darker interior, pending visual review','geometry':'36small internal cutout quads,18perpendicular pair clusters at two staggered levels; all vertices strictly inside1mcore','interior_linear_albedo_multiplier':.88,'material':'Isolated copiedMASKmaterial with MixRGBA MULTIPLY; unchanged shared currentPNG; native glTF constantfactor expected. No globallighting/AO/world changes.','outer':'Outer palette/pattern/gold/fluffy52plane layer unchanged','modules':reports,'scope':'Live Blender study, six-cell assembly retained, no game/bulk edits','baseline_digest':base['digest']};(HERE/'dense_leaf_interior_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for variant in('A','B','C'):
 core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant]
 for o in list(bpy.context.selected_objects):o.select_set(False)
 for obj in(core,bpy.data.objects[core.name+'_BushyFoliage'],bpy.data.objects[core.name+'_DenseInterior']):obj.select_set(True)
 bpy.context.view_layer.objects.active=core;display=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update()
 try:bpy.ops.export_scene.gltf(filepath=str(HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=True)
 finally:core.location=display;bpy.context.view_layer.update()
for o in list(bpy.context.selected_objects):o.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False)
result={'status':'Darker denser interior layers LIVE and saved','modules':reports}
