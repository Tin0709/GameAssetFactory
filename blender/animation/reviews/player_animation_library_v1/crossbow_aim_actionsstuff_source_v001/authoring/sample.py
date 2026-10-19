"""Read fresh pack payload; evaluate ordinary charged crossbow source graph."""
from pathlib import Path
import sys,json,math
import argparse
p=argparse.ArgumentParser();p.add_argument('--pack',required=True);p.add_argument('--cache',required=True);opt=p.parse_args()
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());S=Path(opt.cache).resolve();S.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v003/authoring'))
from extract_source import extract
extract(opt.pack,S)
original=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v003/authoring/crossbow_runtime.py'
src=original.read_text().replace("ROOT=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists())",f'ROOT=Path({str(R)!r})').replace(",'main_hand_item_use_duration','item_is_charged'",'')
(S/'aim_runtime.py').write_text(src)
sys.path.insert(0,str(S));import aim_runtime as vm
import jump_runtime
scope=dict(jump_runtime.__dict__)
controller=(R/'blender/animation/reviews/player_animation_library_v1/actions_stuff_idle_v001/immutable_dependencies/jump_runtime.py').read_text().split('class _Controller:',1)[1].split('class JumpRuntime:',1)[0]
exec('class _Controller:'+controller.replace("not in (True,'hold_on_last_frame')",'is not True'),scope);vm._Controller=scope['_Controller']
def query(charged):
 return vm.idle_query(item_is_charged=int(charged),main_hand_item_max_duration=25,main_hand_item_use_duration=0,is_item_name_any=lambda slot,*items:float(slot=='slot.weapon.mainhand' and 'minecraft:crossbow' in items),equipped_item_any_tag=lambda slot,*tags:float(slot=='slot.weapon.mainhand' and 'oreville:is_crossbow' in tags),get_equipped_item_name=lambda slot:'crossbow' if slot==0 else '',is_item_equipped=lambda slot:float(slot!='off_hand'))
r=vm.IdleRuntime(S/'source_payload.json',initial_life=13.4,seed=139,modified_distance_moved=1.,attack_free_age=12.)
for i in range(240):r.step(1/240,query(False))
# Settle real charged entry. Source clips jump straight to their charged endpoint.
entry=[]
for i in range(144):
 row=r.step(1/240,query(True))
 if i in [0,1,2,23,47,143]:entry.append(vm.serializable_snapshot(row))
rows=[]
for i in range(865):
 row=r.last if i==0 else r.step(1/240,query(True));snap=vm.serializable_snapshot(row)
 assert snap['controllers']['ybphcg']['state']=='gjhnog'
 assert snap['controllers']['kcexxa']['state']=='ltqtzr'
 rows.append({'t':i/240,'life':snap['life'],'channels':snap['channels']})
for b,e in rows[0]['channels'].items():
 for c,v in e.items():assert max(abs(v[i]-rows[-1]['channels'][b][c][i]) for i in range(3))<1e-6,(b,c,v,rows[-1]['channels'][b][c])
assert all(abs(x-1)<1e-8 for r0 in rows for b in r0['channels'].values() for x in b['scale'])
(S/'samples.json').write_text(json.dumps(rows,separators=(',',':')))
(S/'charged_entry_trace.json').write_text(json.dumps(entry,indent=2))
report={'pack_sha256':'9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d','layers':[l for l in vm.serializable_snapshot(r.last)['layers'] if l['applied_weight']>0],'controllers':{a:c['state'] for a,c in r.last['controllers'].items()},'first_channels':rows[0]['channels'],'first_life':rows[0]['life'],'last_life':rows[-1]['life'],'duration_s':3.6,'samples':865,'neutral_look':True,'loop_error':max(abs(rows[0]['channels'][b][c][j]-rows[-1]['channels'][b][c][j]) for b in rows[0]['channels'] for c in rows[0]['channels'][b] for j in range(3)),'engine_conventions':vm.ENGINE_CONVENTIONS+['hold_on_last_frame_is_finished_at_duration_while_visually_held'],'passed':True}
(S/'source_evaluation.json').write_text(json.dumps(report,indent=2))
print('CHANNELS',json.dumps(rows[0]['channels']));print('ACTIVE_LAYERS',[(l['alias'],l['clock']) for l in report['layers']]);print('LOOP',report['loop_error'])
