"""Run with Blender -b Animation_Showcase.blend --python-exit-code 1 --python test_import.py."""
import sys,json,copy,unittest
from pathlib import Path
import bpy
from mathutils import Matrix
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import import_blockbench as bridge
class ImportTests(unittest.TestCase):
 def setUp(self):
  self.rig=bpy.data.objects['Showcase_Player_Rig'];self.contract=json.loads((HERE/'bridge_contract.json').read_text());self.old=self.rig.animation_data.action
  self.clip={'schema':'gaf.blockbench.samples.v1','contract_sha256':self.contract['sha256'],'blockbench_version':'5.2.2','name':'TEST_BB_TEMP','fps':30,'sample_rate':1,'duration':1,'loop':'once','samples':[]}
  self.clip['rest']={b['name']:[list(row) for row in Matrix.Translation(b['origin'])] for b in self.contract['bones']}
  for t in [0,1]:self.clip['samples'].append({'time':t,'matrices':copy.deepcopy(self.clip['rest'])})
 def tearDown(self):
  self.rig.animation_data.action=self.old
  for a in list(bpy.data.actions):
   if a.name.startswith('TEST_BB_TEMP'):bpy.data.actions.remove(a)
 def test_neutral_overrides_viewer_offsets_without_editing_rig(self):
  a=bridge.import_clip(self.rig,self.clip,self.contract)
  self.assertEqual(self.rig.animation_data.action,self.old)
  self.rig.animation_data.action=a;self.rig.animation_data.action_slot=a.slots[0];bpy.context.scene.frame_set(1)
  self.assertLess(max(abs(p.matrix[i][j]-p.bone.matrix_local[i][j]) for p in self.rig.pose.bones for i in range(4) for j in range(4)),2e-6)
  self.assertEqual(a['review_status'],'pending')
 def test_head_y_in_blockbench_is_blender_z(self):
  h=Matrix.Translation(next(b['origin'] for b in self.contract['bones'] if b['name']=='Head'))
  p=h@Matrix.Rotation(.6,4,'Y')
  self.clip['samples'][0]['matrices']['Head']=list(map(list,p));self.clip['samples'][1]['matrices']['Head']=list(map(list,p))
  a=bridge.import_clip(self.rig,self.clip,self.contract);self.rig.animation_data.action=a;self.rig.animation_data.action_slot=a.slots[0];bpy.context.scene.frame_set(1)
  head=self.rig.pose.bones['Head'];expected=Matrix.Translation(head.bone.head_local)@Matrix.Rotation(.6,4,'Z')@head.bone.matrix_local.to_3x3().to_4x4()
  self.assertLess(max(abs(head.matrix[i][j]-expected[i][j]) for i in range(4) for j in range(4)),2e-6)
 def test_bent_forearm_rejected_before_action_creation(self):
  rest=Matrix(self.clip['rest']['ForeArm.R']);self.clip['samples'][1]['matrices']['ForeArm.R']=list(map(list,rest@Matrix.Rotation(.2,4,'X')))
  count=len(bpy.data.actions)
  with self.assertRaisesRegex(ValueError,'ForeArm'):bridge.import_clip(self.rig,self.clip,self.contract)
  self.assertEqual(len(bpy.data.actions),count)
 def test_nonunit_scale_rejected(self):
  self.clip['samples'][0]['matrices']['Head'][0][0]=1.2
  with self.assertRaisesRegex(ValueError,'scale|rigid'):bridge.import_clip(self.rig,self.clip,self.contract)
 def test_contract_mismatch_rejected(self):
  self.clip['contract_sha256']='wrong'
  with self.assertRaisesRegex(ValueError,'contract'):bridge.import_clip(self.rig,self.clip,self.contract)
 def test_existing_name_never_overwritten(self):
  self.clip['name']=self.old.name
  with self.assertRaisesRegex(ValueError,'exist'):bridge.import_clip(self.rig,self.clip,self.contract)
 def test_rest_pivot_mismatch_rejected(self):
  self.clip['rest']['Head'][0][3]+=.1
  with self.assertRaisesRegex(ValueError,'rest|pivot'):bridge.import_clip(self.rig,self.clip,self.contract)
 def test_nan_rejected(self):
  self.clip['samples'][0]['matrices']['Head'][0][0]=float('nan')
  with self.assertRaisesRegex(ValueError,'finite'):bridge.import_clip(self.rig,self.clip,self.contract)
if __name__=='__main__':
 r=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ImportTests))
 if not r.wasSuccessful():raise RuntimeError('Import tests failed')
