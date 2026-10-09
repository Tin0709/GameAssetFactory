"""Idempotent current rest export only: evaluated core +bushy exterior +darker dense interior."""
import bpy,json,sys,hashlib,importlib
from pathlib import Path
assert not bpy.app.background,'Export/save through the current foreground Blender window'
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE));from flower_preservation import snapshot,compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve();baseline=snapshot()
for variant in('A','B','C'):
 core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant]
 for obj in list(bpy.context.selected_objects):obj.select_set(False)
 for obj in(core,bpy.data.objects[core.name+'_BushyFoliage'],bpy.data.objects[core.name+'_DenseInterior']):obj.select_set(True)
 bpy.context.view_layer.objects.active=core;display=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update()
 try:bpy.ops.export_scene.gltf(filepath=str(HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=True)
 finally:core.location=display;bpy.context.view_layer.update()
assert not compare(baseline),'Rest re-export must preserve every existing authored datablock'
import validate_bushy_leaf_modules_v1 as validation;importlib.reload(validation);report=validation.audit_bushy_modules();path=HERE/'leaf_modules_v1_manifest.json';manifest=json.loads(path.read_text());manifest['audit']=report
for module,current in zip(manifest['modules'],report['modules']):module.update(current)
path.write_text(json.dumps(manifest,indent=2))
for obj in list(bpy.context.selected_objects):obj.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False);result={'status':'Current local study GLBs refreshed; source preserved','audit':report}
