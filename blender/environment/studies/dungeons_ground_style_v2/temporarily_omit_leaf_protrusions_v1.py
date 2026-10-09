"""Foreground-only reversible omission phase, retained for reproducibility from its pre-phase baseline."""
import bpy,json,sys
from pathlib import Path
assert not bpy.app.background
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE));from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve();base=json.loads((EVIDENCE/'before_leaf_core_only_fingerprints.json').read_text());assert not compare(base['data'])
cores=[o for o in bpy.data.objects if o.type=='MESH'and o.data.materials and o.data.materials[0]and o.data.materials[0].name=='MAT_LeafModules_V1_DirectLeafPattern'];assert len(cores)==9
for obj in cores:
 assert not obj.modifiers.get('REVIEW_Temporarily_Omit_Protruding_Leaves');group=obj.vertex_groups.new(name='REVIEW_CoreOnly_NoSprigs');ids=sorted({vi for p in obj.data.polygons if obj.data.attributes['leaf_part'].data[p.index].value in(0,2)for vi in p.vertices});group.add(ids,1,'REPLACE');mod=obj.modifiers.new('REVIEW_Temporarily_Omit_Protruding_Leaves','MASK');mod.vertex_group=group.name;mod.threshold=.5
for obj in bpy.data.objects:
 if obj.name.startswith(('ENV_LeafBlock_1m_V1_','ENV_LeafCluster_Plus_Cell_'))and obj.name.endswith('_CrossBranches'):obj.hide_render=True;obj.hide_set(True)
bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False);result={'status':'Core part1 masked and oldCrossBrancheshidden, all raw geometry preserved'}
