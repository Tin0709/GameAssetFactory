"""Build separate import source, only after cross-editor evaluation passes."""
import bpy,json,sys,math,hashlib,itertools
from pathlib import Path
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import import_blockbench as bridge
ui=bridge.library
rig=bpy.data.objects['Showcase_Player_Rig'];mesh=bpy.data.objects['Showcase_Player_Mesh'];scene=bpy.context.scene
contract=json.loads((HERE/'bridge_contract.json').read_text());C=Matrix(contract['blender_to_blockbench']);Ci=C.inverted()
before={a.name:ui.action_signature(a) for a in bpy.data.actions};resthash=ui.rest_signature(rig.data)
original_mesh=hashlib.sha256(repr(([list(v.co) for v in mesh.data.vertices],[list(p.vertices) for p in mesh.data.polygons],[[tuple(g) if False else (g.group,g.weight) for g in v.groups] for v in mesh.data.vertices])).encode()).hexdigest()
(HERE/'validation/before_action_signatures.json').write_text(json.dumps(before,indent=2))
report={'tolerances':{'sample_vertex_m':2e-6,'between_sample_vertex_m':.0001,'rigid_distance_m':2e-6},'minimal_tests':{},'rifle_test':{},'original_actions':len(before),'original_rig_sha256':resthash}
def check(name):
 clip=json.loads((HERE/'samples'/f'{name}.samples.json').read_text());a=bridge.import_clip(rig,clip,contract)
 rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
 ref=json.loads((HERE/'validation'/f'{name}.reference240.json').read_text());rest={n:Matrix(m) for n,m in ref['rest'].items()}
 maxima={'sample_vertex_error_m':0,'between_sample_vertex_error_m':0,'bone_matrix_error':0,'actual_blockbench_corner_error_m':0,'rigid_distance_error_m':0,'forearm_basis_error':0}
 vertices=[v.co.copy() for v in mesh.data.vertices];owners=[mesh.vertex_groups[v.groups[0].group].name for v in mesh.data.vertices]
 for sample in ref['samples']:
  frame=1+sample['time']*ref['fps'];whole=int(math.floor(frame+1e-8));scene.frame_set(whole,subframe=frame-whole);bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();evaluated=mesh.evaluated_get(dep).to_mesh()
  actual=[mesh.matrix_world@v.co for v in evaluated.vertices]
  d={n:Ci@Matrix(m)@rest[n].inverted()@C for n,m in sample['matrices'].items()}
  sample_error=max((actual[i]-d[n]@v).length for i,(v,n) in enumerate(zip(vertices,owners)))
  is_sample=abs(sample['time']*120-round(sample['time']*120))<1e-6
  key='sample_vertex_error_m' if is_sample else 'between_sample_vertex_error_m';maxima[key]=max(maxima[key],sample_error)
  for n in d:maxima['bone_matrix_error']=max(maxima['bone_matrix_error'],bridge.delta(rig.pose.bones[n].matrix,d[n]@rig.data.bones[n].matrix_local))
  for side in ['L','R']:
   maxima['forearm_basis_error']=max(maxima['forearm_basis_error'],bridge.delta(rig.pose.bones['ForeArm.'+side].matrix_basis,Matrix.Identity(4)))
  for group in [['UpperArm.L','ForeArm.L'],['UpperArm.R','ForeArm.R'],['Leg.L'],['Leg.R']]:
   ids=[i for i,n in enumerate(owners) if n in group]
   for i,j in itertools.combinations(ids,2):maxima['rigid_distance_error_m']=max(maxima['rigid_distance_error_m'],abs((actual[i]-actual[j]).length-(vertices[i]-vertices[j]).length))
  for q in contract['cubes']:
   if q['name'] not in sample.get('corners',{}):continue
   ids=[i for i,n in enumerate(owners) if n in [q['bone'],q['bone'].replace('UpperArm','ForeArm')]]
   for v in sample['corners'][q['name']]:maxima['actual_blockbench_corner_error_m']=max(maxima['actual_blockbench_corner_error_m'],min((Ci@Vector(v)-actual[i]).length for i in ids))
  mesh.evaluated_get(dep).to_mesh_clear()
 assert maxima['sample_vertex_error_m']<2e-6,maxima
 assert maxima['between_sample_vertex_error_m']<.0001,maxima
 assert maxima['rigid_distance_error_m']<2e-6,maxima
 assert maxima['actual_blockbench_corner_error_m']<2e-6,maxima
 assert maxima['forearm_basis_error']<2e-6,maxima
 maxima['reference_samples']=len(ref['samples']);maxima['import_samples']=len(clip['samples']);maxima['status']='pending';maxima['action_signature']=ui.action_signature(a)
 print('VALIDATED',name,maxima,flush=True)
 return maxima
for name in ['BB_Neutral_Test_v001','BB_RightArm_Test_v001','BB_LeftArm_Test_v001','BB_HeadTurn_Test_v001']:report['minimal_tests'][name]=check(name)
# Only proceed to Rifle after all minimal checks pass.
report['rifle_test']=check('BB_Rifle_Ready_Pose_v001')
expected=json.loads((HERE/'ready_reference.json').read_text())['blender_pose']
error=max(bridge.delta(rig.pose.bones[n].matrix,Matrix(m)) for n,m in expected.items())
assert error<3e-6,('Original Ready reference mismatch',error)
report['rifle_test']['original_approved_ready_matrix_error']=error
for n,sig in before.items():assert ui.action_signature(bpy.data.actions[n])==sig,n
assert ui.rest_signature(rig.data)==resthash
report['all_original_actions_unchanged']=True;report['approved_actions_backed_up']=12
# A source study is not a second showcase. Reuse this saved armature and mesh.
scene.name='BLOCKBENCH_IMPORT_SOURCE'
if 'gaf_animation_showcase' in scene:del scene['gaf_animation_showcase']
scene.frame_start=1;scene.frame_end=31;scene.render.fps=30;scene.frame_set(16)
source=HERE/'blockbench_import_source_v001.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
report['source']=source.name
(HERE/'validation/pose_validation.json').write_text(json.dumps(report,indent=2))
