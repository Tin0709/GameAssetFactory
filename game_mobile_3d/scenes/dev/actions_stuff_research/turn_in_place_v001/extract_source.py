"""Rebuild compact research-only source subset directly from the local pack.
No full source index, Blender Action or production export is generated.
"""
import argparse, hashlib, importlib.util, json, pathlib, re, zipfile
ROOT = pathlib.Path(__file__).resolve().parents[5]
PARSER = ROOT / 'blender/animation/reviews/player_animation_library_v1/actions_stuff_directional_v001/molang.py'
spec = importlib.util.spec_from_file_location('turn_molang', PARSER)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
EXPECTED_SHA256 = '9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d'
BONES = ['root','waist','body','head','rightarm','leftarm','rightleg','leftleg']
def expression(value):
    return m._compile(value) if isinstance(value,str) else ['literal',value]
def vector(value):
    return [expression(v) for v in (value if isinstance(value,list) else [value]*3)]
def channel(value):
    if not isinstance(value,dict): return [[0,vector(value),vector(value),False]]
    out=[]
    for time,key in sorted(value.items(),key=lambda item:float(item[0])):
        if isinstance(key,dict):
            pre=key.get('pre',key.get('post'));post=key.get('post',pre)
            out.append([float(time),vector(pre),vector(post),key.get('lerp_mode')=='catmullrom'])
        else:out.append([float(time),vector(key),vector(key),False])
    return out

def main():
    a=argparse.ArgumentParser();a.add_argument('pack',type=pathlib.Path);args=a.parse_args()
    assert hashlib.sha256(args.pack.read_bytes()).hexdigest() == EXPECTED_SHA256, 'Different source pack: audit it before regenerating'
    with zipfile.ZipFile(args.pack) as z:
        entity=json.loads(z.read('entity/dtr.json'))['minecraft:client_entity']['description']
        controllers=json.loads(z.read('animation_controllers/616f2ff7.json'))['animation_controllers']
        animations=json.loads(z.read('animations/f2da1071.json'))['animations']
        controller=controllers[entity['animations']['agyfrv']]
        raw={'pack_sha256':hashlib.sha256(args.pack.read_bytes()).hexdigest(),
             'entity':'entity/dtr.json','controller_file':'animation_controllers/616f2ff7.json',
             'animation_file':'animations/f2da1071.json',
             'animate_entry':next(x for x in entity['scripts']['animate'] if isinstance(x,dict) and 'rzkmtm' in x),
             'parent':controllers[entity['animations']['rzkmtm']],
             'controller_id':entity['animations']['agyfrv'],'controller':controller,
             'pre_animation':{str(i):entity['scripts']['pre_animation'][i] for i in [27,29,30]},
             'clips':{a:{'id':entity['animations'][a],'data':animations[entity['animations'][a]]} for a in ['rjfeeq','ejnecs']}}
    states={}
    for name,state in controller['states'].items():
        layers=[]
        for item in state.get('animations',[]):
            layers.extend([[k,expression(v)] for k,v in item.items()] if isinstance(item,dict) else [[item,expression(1)]])
        states[name]={'animations':layers,'transitions':[[k,expression(v)] for row in state.get('transitions',[]) for k,v in row.items()],
                      'on_entry':[expression(s) for s in state.get('on_entry',[])],'on_exit':[expression(s) for s in state.get('on_exit',[])],
                      'blend_transition':state.get('blend_transition',0)}
    clips={}
    for alias,row in raw['clips'].items():
        clip=row['data'];bones={}
        for bone in BONES:
            bones[bone]={key:channel(clip.get('bones',{}).get(bone,{}).get(key,1 if key=='scale' else 0)) for key in ['rotation','position','scale']}
        clips[alias]={'id':row['id'],'animation_length':clip['animation_length'],'loop':clip.get('loop',False),
                      'blend_weight':expression(clip.get('blend_weight',1)),'anim_time_update':expression(clip['anim_time_update']),
                      'timeline':[],'bones':bones}
    program={'source_sha256':raw['pack_sha256'],
             'variable_names':sorted(set(re.findall(r'v\.[a-z_0-9]+',json.dumps(raw)))),
             'programs':[expression(raw['pre_animation'][str(i)]) for i in [27,29,30]],
             'controllers':{'agyfrv':{'initial_state':controller.get('initial_state','default'),'states':states}},'clips':clips}
    directory=pathlib.Path(__file__).parent
    for name,data in [('source_evidence.json',raw),('turn_program.json',program)]:
        (directory/name).write_text((json.dumps(data,indent=2) if name=='source_evidence.json' else json.dumps(data,separators=(',',':')))+'\n')
        print(name,(directory/name).stat().st_size,'bytes')
if __name__=='__main__': main()
