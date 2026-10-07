"""Versioned GLB: unchanged R13 geometry/12 clips + native R12/R13 + R15 Actions."""
import json,struct,hashlib,math
from pathlib import Path
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[3]/'game_mobile_3d'
OUT=ROOT/'assets/characters/r15'
original=ROOT/'assets/characters/r13/player_r13.glb'
data=original.read_bytes();size=struct.unpack_from('<I',data,12)[0]
glb=json.loads(data[20:20+size]);binary=bytearray(data[28+size:])
names={n['name']:i for i,n in enumerate(glb['nodes'])}
upper=json.loads((ROOT/'assets/characters/r13/source.json').read_text())
strafe=json.loads((OUT/'source.json').read_text())
def accessor(values,width):
    while len(binary)%4:binary.append(0)
    offset=len(binary);flat=[x for v in values for x in (v if isinstance(v,list) else [v])]
    binary.extend(struct.pack('<'+'f'*len(flat),*flat))
    view=len(glb['bufferViews']);glb['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(flat)*4})
    item={'bufferView':view,'componentType':5126,'count':len(values),'type':{1:'SCALAR',3:'VEC3',4:'VEC4'}[width]}
    if width==1:item.update(min=[min(flat)],max=[max(flat)])
    index=len(glb['accessors']);glb['accessors'].append(item);return index
for source,hz in [(upper,48),(strafe,192)]:
    for name,clip in source['clips'].items():
        anim={'name':name,'channels':[],'samplers':[],'extras':{'native_action':clip['action'],'loop':clip['loop']}}
        times=accessor([i/hz for i in range(len(clip['samples']))],1)
        for bone,channels in clip['samples'][0].items():
            assert bone in names
            for prop,path,width in [('p','translation',3),('q','rotation',4)]:
                if prop not in channels:continue
                values=[s[bone][prop] for s in clip['samples']]
                if prop=='q':
                    for i in range(1,len(values)):
                        if sum(a*b for a,b in zip(values[i-1],values[i]))<0:values[i]=[-v for v in values[i]]
                output=accessor(values,width);sampler=len(anim['samplers'])
                anim['samplers'].append({'input':times,'output':output,'interpolation':'LINEAR'})
                anim['channels'].append({'sampler':sampler,'target':{'node':names[bone],'path':path}})
        glb['animations'].append(anim)
glb['buffers']=[{'byteLength':len(binary)}]
j=json.dumps(glb,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
binary+=b'\0'*((-len(binary))%4)
out=OUT/'player_r15_combat_strafe_v1.glb'
out.write_bytes(struct.pack('<III',0x46546c67,2,28+len(j)+len(binary))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(binary),0x004e4942)+binary)
(OUT/'export_manifest.json').write_text(json.dumps({'base':str(original),'base_sha256':hashlib.sha256(data).hexdigest(),'output':str(out),'clips':[a['name'] for a in glb['animations']],'native_strafe_source':strafe['source']},indent=2))
print('R15 GLB assembled:',len(glb['animations']),'clips;',out)
