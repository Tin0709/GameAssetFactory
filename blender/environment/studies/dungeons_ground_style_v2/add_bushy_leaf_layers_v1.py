"""Live additive BetterLeaves-inspired small cutout planes; older large branches stay archived."""
import bpy,json,sys,random,math
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Current foreground Blender source writes only'
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE));from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve();base=json.loads((EVIDENCE/'before_bushy_leaf_layers_fingerprints.json').read_text());assert not compare(base['data']);assert not bpy.data.objects.get('ENV_LeafBlock_1m_V1_A_BushyFoliage')
mat=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];collection=bpy.data.collections['LEAF_MODULES_1Block_V1'];reports=[]
for variant in ('A','B','C'):
 rng=random.Random(892917+ord(variant)*911);verts=[];faces=[];sides=[];uvs=[]
 def card(center,right,up,w,h,side,uvcenter):
  points=[center+right*x*w*.5+up*y*h*.5 for x,y in((-1,-1),(1,-1),(1,1),(-1,1))]
  if not all(-.700001<=v.x<=.700001 and -.700001<=v.y<=.700001 and 0<=v.z<=1.200001 for v in points):return False
  start=len(verts);verts.extend(tuple(v)for v in points);faces.append(tuple(range(start,start+4)));sides.append(side);uvs.append([(uvcenter[0]+x*w*.5,uvcenter[1]+y*h*.5)for x,y in((-1,-1),(1,-1),(1,1),(-1,1))]);return True
 for side in range(4):
  normal=Vector(((1,0,0),(-1,0,0),(0,1,0),(0,-1,0))[side]);tangent=Vector((-normal.y,normal.x,0))
  for iz,z in enumerate((.23,.72)):
   for it,t in enumerate((-.44,-.22,0,.22,.44)):
    for attempt in range(40):
     angle=rng.uniform(-.23,.23);roll=rng.uniform(-.14,.14);up=Vector((0,0,1))*math.cos(angle)+normal*math.sin(angle);right=tangent*math.cos(roll)+up*math.sin(roll);up=up*math.cos(roll)-tangent*math.sin(roll);center=normal*rng.uniform(.545,.60)+tangent*(t+rng.uniform(-.02,.02))+Vector((0,0,z+rng.uniform(-.035,.035)));w=rng.uniform(.32,.43);h=rng.uniform(.31,.43)
     if card(center,right,up,w,h,side,(t+.5,z)):break
    else:raise AssertionError('Could not fit planar bush patch')
 for y in(-.43,0,.43):
  for x in(-.44,-.15,.15,.44):
   for attempt in range(40):
    azimuth=rng.uniform(-.15,.15);tilt=rng.uniform(.09,.28);right=Vector((math.cos(azimuth),math.sin(azimuth),0));flat=Vector((-right.y,right.x,0));up=flat*math.cos(tilt)+Vector((0,0,1))*math.sin(tilt);center=Vector((x+rng.uniform(-.01,.01),y+rng.uniform(-.02,.02),rng.uniform(1.07,1.14)));w=rng.uniform(.30,.4);h=rng.uniform(.29,.38)
    if card(center,right,up,w,h,4,(x+.5,y+.5)):break
   else:raise AssertionError('Could not fit top bush patch')
 mesh=bpy.data.meshes.new('ENV_LeafBlock_1m_V1_'+variant+'_BushyLayerPlanes');mesh.from_pydata(verts,[],faces);mesh.materials.append(mat);mesh.update();uv=mesh.uv_layers.new(name='UV_UserLeafTile_1RepeatPerMetre');sideattr=mesh.attributes.new(name='bushy_side',type='INT',domain='FACE')
 for p,side,coords in zip(mesh.polygons,sides,uvs):
  sideattr.data[p.index].value=side
  for li,coord in zip(p.loop_indices,coords):uv.data[li].uv=coord
 child=bpy.data.objects.new('ENV_LeafBlock_1m_V1_'+variant+'_BushyFoliage',mesh);collection.objects.link(child);child.parent=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant]
 reports.append({'variant':variant,'object':child.name,'quads':len(mesh.polygons),'triangles':len(mesh.polygons)*2,'bounds':[[min(v.co[k]for v in mesh.vertices)for k in range(3)],[max(v.co[k]for v in mesh.vertices)for k in range(3)]]})
# Assembly-only exposed sides: shared library layer where all sides exposed, otherwise isolated filtered copies.
import bmesh
assembly=json.loads((HERE/'leaf_plus_6blocks_v1_manifest.json').read_text());assemblycollection=bpy.data.collections['LEAF_CLUSTER_Plus_6Blocks_V1'];placements=[]
for spec in assembly['cells']:
 source=bpy.data.objects['ENV_LeafBlock_1m_V1_'+spec['variant']+'_BushyFoliage'];blocked=spec['blocked_sides'];mesh=source.data
 if any(side<5 for side in blocked):
  mesh=mesh.copy();mesh.name=spec['object']+'_ExposedBushyPlanes';bm=bmesh.new();bm.from_mesh(mesh);layer=bm.faces.layers.int['bushy_side'];bmesh.ops.delete(bm,geom=[f for f in bm.faces if f[layer]in blocked],context='FACES');orphans=[v for v in bm.verts if not v.link_faces]
  if orphans:bmesh.ops.delete(bm,geom=orphans,context='VERTS')
  bm.to_mesh(mesh);bm.free();mesh.update()
 child=bpy.data.objects.new(spec['object']+'_BushyFoliage',mesh);assemblycollection.objects.link(child);child.parent=bpy.data.objects[spec['object']];placements.append({'cell':spec['cell'],'object':child.name,'quads':len(mesh.polygons)})
assert not compare(base['data']),'Additive bush layers must preserve all prior authored data'
manifest={'status':'Latest bushy cutout plane study; awaiting artistic review','source':'Current user pixel layout, grass-green remap, unchanged gold and black transparency','geometry':'52small zero-thickness cutout quads per module:10per side+12top, evenly staggered;52independent small patches, no largecrossedstems','envelope_limit_m':[1.4,1.4,1.2],'core_grid_m':[1,1,1],'old_sprigs':'Core part1 remains masked and old2xCrossBranches hidden for reversible restoration','assembly':'Same six metre-grid cells, bush layers omitted on occupied-neighbour sides','modules':reports,'assembly_layers':placements,'preservation_digest':base['digest'],'scope':'Live Blender only, no game/bulk changes'}
(HERE/'bushy_leaf_layers_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for variant in ('A','B','C'):
 core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];child=bpy.data.objects[core.name+'_BushyFoliage']
 for o in list(bpy.context.selected_objects):o.select_set(False)
 core.select_set(True);child.select_set(True);bpy.context.view_layer.objects.active=core;display=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update()
 try:bpy.ops.export_scene.gltf(filepath=str(HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=True)
 finally:core.location=display;bpy.context.view_layer.update()
for o in list(bpy.context.selected_objects):o.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
for window in bpy.context.window_manager.windows:
 for area in window.screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False;space.region_3d.view_location=(25.5,3.2,.58);space.region_3d.view_distance=2.7;space.region_3d.view_rotation=(Vector((25.5,3.2,.55))-Vector((27,1,2))).to_track_quat('-Z','Y');space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False)
result={'status':'Small bushy cutout layers now LIVE and saved','modules':reports,'assembly_layers':placements}
