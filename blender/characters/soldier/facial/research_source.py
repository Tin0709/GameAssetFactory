"""Verify reachable player definitions directly from the local resource pack."""
from pathlib import Path
from zipfile import ZipFile
import hashlib,json,re
PACK=Path('/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack')
OUT=Path(__file__).resolve().parent
z=ZipFile(PACK);definitions={};locations={};geometries={}
for path in z.namelist():
 if path.endswith('.json') and path.startswith(('animations/','animation_controllers/','models/')):
  d=json.loads(z.read(path))
  for group in ['animations','animation_controllers']:
   for name,value in d.get(group,{}).items():definitions[name]=value;locations[name]=path
  for g in d.get('minecraft:geometry',[]):geometries[g['description']['identifier']]={'file':path,'bones':[b['name'] for b in g.get('bones',[])]}
p=json.loads(z.read('entity/dtr.json'))['minecraft:client_entity']['description'];aliases=p['animations']
def refs(items):
 for item in items:
  if isinstance(item,str):yield item
  elif isinstance(item,dict):yield from item
queue=[(a,['scripts.animate',a]) for a in refs(p['scripts']['animate'])];seen={};external={}
while queue:
 alias,trace=queue.pop(0);name=aliases.get(alias,alias)
 if name in seen or name in external:continue
 if name not in definitions:external[name]=trace;continue
 seen[name]={'file':locations[name],'trace':trace}
 value=definitions[name]
 for state,spec in value.get('states',{}).items():
  for a in refs(spec.get('animations',[])):queue.append((a,trace+[name+':'+state,a]))
render=json.loads(z.read('render_controllers/464e7f72.json'))['render_controllers']
face_render={n:d for n,d in render.items() if 'persona_animated_face' in n}
blink_controller_in_pack='controller.animation.persona.blink' in definitions
blink_refs=[]
for n,info in seen.items():
 d=definitions[n]
 if 'blink' in json.dumps(d).lower():blink_refs.append({'id':n,**info,'definition':d})
all_blink_vars=[]
for path in z.namelist():
 if not path.endswith('.json'):continue
 text=z.read(path).decode('utf-8-sig',errors='replace')
 for token in ['v.is_blinking','v.last_blink_time','variable.is_blinking','variable.last_blink_time','controller.animation.persona.blink']:
  if token in text:all_blink_vars.append({'file':path,'token':token,'occurrences':text.count(token)})
# Inspect the player-bound look-at/hurt/idle clips without claiming facial use.
clips={}
for alias in ['look_at_target','hurt','bob','walk','jump','fall','holding','mhyyzj']:
 n=aliases.get(alias)
 if n in definitions:clips[alias]={'id':n,'file':locations[n],'bones':list(definitions[n].get('bones',{})),'animation_length':definitions[n].get('animation_length'),'definition':definitions[n]}
report={'pack_sha256':hashlib.sha256(PACK.read_bytes()).hexdigest(),'player_entity':'entity/dtr.json','blink_alias':aliases['blink'],'blink_controller_defined_in_pack':blink_controller_in_pack,'blink_alias_reachable':aliases['blink'] in seen or aliases['blink'] in external,'reachable_count':len(seen),'external_dependencies':external,'blink_variables':all_blink_vars,'reachable_blink_definitions':blink_refs,'persona_face_render_controllers':face_render,'player_geometry':{k:{'id':v,**geometries.get(v,{'file':None,'bones':None})} for k,v in p['geometry'].items()},'player_clip_evidence':clips,'interpretation':{'verified':'Player initializes is_blinking and last_blink_time. Persona render controllers select a two-half UV blink path or a 7Hz animated face atlas path.','missing':'The referenced vanilla/persona blink controller and engine persona face geometry/texture are not defined in this archive; custom player animate graph does not automatically prove the blink alias executes. Exact player blink intervals/close-open curve cannot be reconstructed from this pack alone.','original':'Soldier eye gaze, brows, combat/effort/hurt/victory/death expressions and situation arbitration are original; no documented player facial bank matching those names was found.'}}
(OUT/'source_evidence.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['pack_sha256','blink_controller_defined_in_pack','blink_alias_reachable','reachable_count','blink_variables']},indent=2));print('REACHABLE_BLINK',[(d['id'],d['trace']) for d in blink_refs]);print('PLAYER CLIP BONES',{k:v['bones'] for k,v in clips.items()});print('PLAYER GEOMETRY MAIN',{k:v for k,v in report['player_geometry'].items() if k in ['default','rfrkhc']})
