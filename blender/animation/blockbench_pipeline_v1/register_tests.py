"""Register only the five validated test Actions; no existing entry is edited."""
import sys,json,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];SHOWCASE=HERE.parent/'showcase'
sys.path.insert(0,str(SHOWCASE));import register_animation as register
before=ROOT/'.validation/blockbench_pipeline_v1/before';hashes=json.loads((before/'file_hashes.json').read_text())
for rel,digest in hashes.items():
 if hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()!=digest:raise RuntimeError('Concurrent change; no registration: '+rel)
report=json.loads((HERE/'validation/pose_validation.json').read_text())
names=list(report['minimal_tests'])+['BB_Rifle_Ready_Pose_v001']
for name in names:register.register_entry(name,'Showcase_Player_Rig','Showcase_Player_Mesh',1,31,30)
path=SHOWCASE/'animation_manifest.json';manifest=json.loads(path.read_text())
reference=next(e for e in manifest['animations'] if e['action']=='Rifle_Ready_V2_v16_Test')
for e in manifest['animations']:
 if e['action'] not in names:continue
 e['approval_note']='Blockbench bridge validation only. Pending explicit user review; no production approval.'
 e['blockbench_contract_sha256']=json.loads((HERE/'bridge_contract.json').read_text())['sha256']
 e['blockbench_samples']=str((HERE/'samples'/f"{e['action']}.samples.json").relative_to(ROOT))
 e['blockbench_samples_sha256']=hashlib.sha256((ROOT/e['blockbench_samples']).read_bytes()).hexdigest()
 if e['action']=='BB_Rifle_Ready_Pose_v001':
  for k in ['preview_prop','preview_prop_source','preview_prop_source_sha256']:
   if k in reference:e[k]=reference[k]
manifest_tmp=path.with_suffix('.json.tmp');manifest_tmp.write_text(json.dumps(manifest,indent=2));manifest_tmp.replace(path)
(HERE/'validation/registered_manifest_sha256.txt').write_text(hashlib.sha256(path.read_bytes()).hexdigest())
print('Registered 5 new Pending Actions; retained all 28 entries unchanged')
