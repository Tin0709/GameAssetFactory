import bpy,json,sys,importlib.util,math
from pathlib import Path
from mathutils import Matrix,Euler,Quaternion
HERE=Path(__file__).resolve().parent
state=json.loads((HERE/'preservation_before.json').read_text());ROOT=Path(state['project'])
path=HERE/'gaf_animation_library.research.py'if'--patched'in sys.argv else ROOT/'blender/animation/showcase/gaf_animation_library.py'
spec=importlib.util.spec_from_file_location('research_scale_test_module',path);ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui)
entry=next(e for e in state['entries_before']if e['action']=='Run_Snappy_Test_v001');rig=bpy.data.objects[ui.RIG];base=bpy.data.actions[entry['action']]
policy={'research_only':True,'production_eligible':False,'source_animation':'animation.oreville_ans.fngydr','source_pack_sha256':state['pack_sha256'],
 'research_scale_channels':{s:{'axis':1,'min':1.0,'max':1.070002}for s in ['Leg.L','Leg.R']}}
checks=[]
def check(label,bone,value,metadata,expected,offset_cycles=False):
 a=base.copy();a.name='Ephemeral_scale_guard_test';e=dict(entry,action=a.name,status='pending',**metadata)
 found=False
 for c in ui.curves(a):
  if c.data_path==f'pose.bones["{bone}"].scale'and c.array_index==1:
   found=True
   for k in c.keyframe_points:k.co.y=value;k.interpolation='LINEAR'
 if not found:
  c=a.layers[0].strips[0].channelbags[0].fcurves.new(f'pose.bones["{bone}"].scale',index=1)
  for f in [1,18]:c.keyframe_points.insert(f,value).interpolation='LINEAR'
 if offset_cycles:
  modifier=c.modifiers.new('CYCLES');modifier.mode_before='REPEAT_OFFSET';modifier.mode_after='REPEAT_OFFSET'
 e['action_sha256']=ui.action_signature(a)
 try:ui.validate_action(a,e,rig);passed=True
 except ValueError:passed=False
 bpy.data.actions.remove(a)
 checks.append([label,passed]);assert passed==expected,(label,passed,expected)
ui.validate_action(base,entry,rig)
check('legacy scale rejected','Leg.L',1.07,{},False)
check('verified source leg scale allowed','Leg.L',1.07,policy,True)
check('head remains restricted','Head',1.07,policy,False)
check('source upper bound enforced','Leg.R',1.071,policy,False)
check('source lower bound enforced','Leg.L',.99,policy,False)
check('production eligibility blocks exception','Leg.L',1.07,dict(policy,production_eligible=True),False)
check('scale offset cycles rejected','Leg.L',1.07,policy,False,True)
# Verify the actual matrix product against Three.js ZYX quaternion formula.
x,y,z=map(math.radians,[-20,-30,40]);c1,c2,c3=[math.cos(a/2)for a in [x,y,z]];s1,s2,s3=[math.sin(a/2)for a in [x,y,z]]
q=Quaternion((c1*c2*c3+s1*s2*s3,s1*c2*c3-c1*s2*s3,c1*s2*c3+s1*c2*s3,c1*c2*s3-s1*s2*c3))
explicit=Matrix.Rotation(z,3,'Z')@Matrix.Rotation(y,3,'Y')@Matrix.Rotation(x,3,'X')
error=max(abs(q.to_matrix()[i][j]-explicit[i][j])for i in range(3)for j in range(3));assert error<3e-7
old=Euler((x,y,z),'ZYX').to_matrix();old_difference=max(abs(old[i][j]-explicit[i][j])for i in range(3)for j in range(3))
assert old_difference>.1
(HERE/'viewer_tests/scale_policy_validation.json').write_text(json.dumps({'passed':True,'checks':checks,'threejs_quaternion_matrix_error':error,'previous_mathutils_ZYX_difference':old_difference},indent=2))
print('SOURCE_SCALE_AND_ROTATION_GUARDS_PASS',flush=True)
