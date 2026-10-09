"""Foreground-only targeted refinement from hollow frames to dense fine leaf modules."""
import bpy,json,sys,random,hashlib,textwrap,importlib
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
baseline=json.loads((EVIDENCE/'before_dense_leaf_modules_fingerprints.json').read_text())
allowed={('meshes','ENV_LeafBlock_1m_V1_'+v+'_PlanarLeafMesh')for v in ('A','B','C')};assert set(compare(baseline['data']))<=allowed,'Only this authorized module geometry correction may be resumed'
builder=(HERE/'add_leaf_modules_v1.py').read_text();geometry=textwrap.dedent(builder[builder.index('    rng=random.Random'):builder.index('    m=bpy.data.meshes.new')]);palette=['324420','435222','59642b','687333','78853b','859344','3c4b1f'];rgba=[tuple(int(h[k:k+2],16)/255 for k in(0,2,4))+(1,)for h in palette]
for variant in ('A','B','C'):
    ns={'random':random,'variant':variant,'Vector':Vector};exec(geometry,ns)
    obj=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];m=obj.data;m.clear_geometry();m.from_pydata(ns['verts'],[],ns['faces']);m.update()
    color=m.color_attributes.get('Color')or m.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for name in ('leaf_part','core_face'):
        if not m.attributes.get(name):m.attributes.new(name=name,type='INT',domain='FACE')
    for p,c,kind,axis in zip(m.polygons,ns['colors'],ns['parts'],ns['axes']):
        m.attributes['leaf_part'].data[p.index].value=kind;m.attributes['core_face'].data[p.index].value=axis
        for li in p.loop_indices:color.data[li].color_srgb=rgba[c]
    m.color_attributes.active_color=color
    for o in list(bpy.context.selected_objects):o.select_set(False)
    obj.select_set(True);bpy.context.view_layer.objects.active=obj;display=obj.location.copy();obj.location=(0,0,0);bpy.context.view_layer.update();path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')
    branch=bpy.data.objects.get('ENV_LeafBlock_1m_V1_'+variant+'_CrossBranches')
    if branch:branch.select_set(True)
    try:bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_materials='EXPORT',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
    finally:obj.location=display;bpy.context.view_layer.update()
import validate_leaf_modules_v1;importlib.reload(validate_leaf_modules_v1);report=validate_leaf_modules_v1.audit_modules()
allowed={('meshes','ENV_LeafBlock_1m_V1_'+v+'_PlanarLeafMesh')for v in ('A','B','C')};changes=compare(baseline['data']);assert set(changes)==allowed,str(changes)
manifest_path=HERE/'leaf_modules_v1_manifest.json';manifest=json.loads(manifest_path.read_text());manifest['audit']=report;manifest['geometry']='Dense18cells/m opaque geometric leaf pixels, maxmerged2×3cells;79–81% surface coverage, small real holes, crossed internal leaf clumps, fine edge/top sprigs';manifest['current_refinement']='refine_dense_leaf_modules_v1.py'
for spec,new in zip(manifest['modules'],report['core_modules']):spec['sha256']=new['sha256'];spec['core_surface_coverage']=new['solid_surface_coverage']
manifest_path.write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result={'status':'Dense finer individual leaf modules now saved LIVE','audit':report,'preservation_changes':changes}
