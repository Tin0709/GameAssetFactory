"""Read the actual SHA-pinned pack; cache full raw JSON externally, not in Git."""
import json,zipfile,hashlib,argparse
from pathlib import Path
def extract(pack,cache):
 pack=Path(pack);cache=Path(cache);assert hashlib.sha256(pack.read_bytes()).hexdigest()=='9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d','Different pack version; inspect before rebuilding'
 z=zipfile.ZipFile(pack);p=json.loads(z.read('entity/dtr.json'))['minecraft:client_entity']['description'];clips={};controllers={};files={}
 for n in z.namelist():
  if n.endswith('.json') and n.startswith(('animations/','animation_controllers/')):
   d=json.loads(z.read(n))
   for k,v in d.get('animations',{}).items():clips[k]=v;files[k]=n
   for k,v in d.get('animation_controllers',{}).items():controllers[k]=v;files[k]=n
 assert p['animations']['tcucxa']=='animation.oreville_ans.dubgwy' and p['animations']['mshwsb']=='animation.oreville_ans.rrvlnm'
 assert controllers[p['animations']['kcexxa']]['states']['ltqtzr']['animations']==['mshwsb',{'tcucxa':'1-v.jkpkmj'}]
 cache.mkdir(parents=True,exist_ok=True);out=cache/'source_payload.json';out.write_text(json.dumps({'player':p,'clips':clips,'controllers':controllers,'files':files},separators=(',',':')));return out
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--pack',required=True);p.add_argument('--cache',required=True);a=p.parse_args();print(extract(a.pack,a.cache))
