import json,zipfile,pathlib,hashlib
P=pathlib.Path(__file__).resolve().parent
PACK=pathlib.Path('/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack')
REPO=pathlib.Path('/Users/tin/Desktop/Game Dev/GameAssetFactory')
z=zipfile.ZipFile(PACK)
d=json.loads(z.read('entity/dtr.json'))['minecraft:client_entity']['description']
idx=json.loads((P/'source_index.json').read_text())
aliases=['rzkmtm','hsfnbp','agyfrv','bjmscc','ppzqvo','bypidi','look_at_target','xfltzh','bob','holding','tculwn','qofebb','hyopyb','lsswib','vmmadd','sztvzu','ksxdmq','iljvrj','nqwtki','gppwit','qsuikd','ndhbnd','jwkabt','rgrypt','hbadod','cpnaoo','tesczf','vrkauw','bvlbek','drqjht','iodvus','fyennh','xoqtsu','dpoyzc']
sel={a:dict(alias=a,id=d['animations'][a],**idx[d['animations'][a]]) for a in aliases}
renderids=['controller.render.player.third_person','controller.render.oreville_ans.vmmipy']
selrender={i:idx[i] for i in renderids}
geos={a:dict(id=d['geometry'][a],**idx[d['geometry'][a]]) for a in ['pfsswq','ryhgyw']}
mat=json.loads(z.read('materials/entity.material'))['materials']
manifest=json.loads(z.read('manifest.json'))
(P/'selected_player_head_face_source.json').write_text(json.dumps(dict(pack=str(PACK),pack_sha256=hashlib.sha256(PACK.read_bytes()).hexdigest(),entity='entity/dtr.json',pre_animation={str(i):d['scripts']['pre_animation'][i] for i in [18,21,23,27,29,30,36,37,38,44]},scripts_animate=d['scripts']['animate'],aliases=sel,render_controllers=selrender,geometry=geos,materials={k:v for k,v in mat.items() if k.startswith('oreville_')},textures={k:d['textures'][k] for k in ['default','transparent','ryhgyw']},settings=[x for x in manifest['settings'] if x.get('name') in ['oreville_ans:pntihm','oreville_ans:wzqdjp']]),indent=2))
contract=json.loads((REPO/'blender/animation/blockbench_pipeline_v1/bridge_contract.json').read_text())
rig=dict(contract_path=str(REPO/'blender/animation/blockbench_pipeline_v1/bridge_contract.json'),bone_names=[b['name'] for b in contract['bones']],rig_sha256=contract['rig_sha256'],head_proxy=[c for c in contract['cubes'] if c['name']=='Head'],source_channels_bones=['root','waist','body','head','rightarm','leftarm','rightleg','leftleg'],source_channels_path=str(REPO/'blender/animation/reviews/player_animation_library_v1/actions_stuff_jump_v001/immutable_dependencies/source_channels.py'),retarget_path=str(REPO/'blender/animation/reviews/player_animation_library_v1/actions_stuff_jump_v001/jump_retarget.py'))
(P/'rig_limitation_evidence.json').write_text(json.dumps(rig,indent=2))
# Resolve only PLAYER animation aliases. Do not borrow unrelated entity aliases named blink.
seen=set();missing={};uses=[]
def walk(a,path):
 if a in seen:return
 seen.add(a)
 id=d['animations'].get(a)
 if id is None:missing[a]='not in player aliases';return
 j=idx.get(id)
 if j is None:missing[a]=id;return
 if not id.startswith('controller.animation'):return
 for state,rec in j['data'].get('states',{}).items():
  for item in rec.get('animations',[]):
   child=item if isinstance(item,str) else next(iter(item))
   uses.append(dict(parent_alias=a,parent_id=id,state=state,child_alias=child,condition=1 if isinstance(item,str) else item[child]))
   walk(child,path+[a])
for item in d['scripts']['animate']:walk(item if isinstance(item,str) else next(iter(item)),[])
blinks=[u for u in uses if u['child_alias']=='blink']
check=dict(reachable_player_alias_count=len(seen),persona_blink_alias=d['animations']['blink'],persona_blink_defined_in_pack=d['animations']['blink'] in idx,persona_blink_in_reachable_player_graph='blink' in seen,reachable_player_blink_edges=blinks,missing_referenced_aliases=missing,tculwn_normal_and_egjh9_body_curves_equal=all(sel['tculwn']['data']['bones'][b]==sel['tculwn']['data']['bones']['egjh9'+b] for b in ['head','waist','body','leftarm','rightarm','leftleg','rightleg']),idle_clip_metadata=[dict(alias=a,id=sel[a]['id'],length=sel[a]['data'].get('animation_length'),loop=sel[a]['data'].get('loop',False),timeline=sel[a]['data'].get('timeline')) for a in ['tculwn','qofebb','hyopyb','lsswib','vmmadd','sztvzu','ksxdmq','iljvrj','nqwtki','gppwit','qsuikd','ndhbnd','jwkabt','rgrypt','hbadod','cpnaoo']],player_head_face_source_paths=sorted(set([x['path'] for x in sel.values()]+[x['path'] for x in geos.values()]+[x['path'] for x in selrender.values()]+['entity/dtr.json','manifest.json','materials/entity.material','texts/en_US.lang'])))
(P/'audit_checks.json').write_text(json.dumps(check,indent=2))
(P/'player_controller_edges.json').write_text(json.dumps(uses,indent=2))
print(json.dumps(check,indent=2))
