"""Validate source copies, append six animations to v4, preserve all previous data."""
from pathlib import Path
import json,copy,hashlib
BASE=Path(__file__).resolve().parent
namespace={'__file__':str(__file__),'__name__':'r6p_validation'}
code=(BASE/'validate_export_locomotion_r4g.py').read_text().replace('export/locomotion_r4g','export/locomotion_r6p').replace('player_locomotion_turning_v2_study.blend','player_locomotion_turning_v3_study.blend').replace("TARGET = BASE.parents[3]/'game_mobile_3d/assets/test/player_cuboid_locomotion_v2_test.glb'","TARGET = OUT/'approved_locomotion.glb'")
exec(compile(code,str(__file__),'exec'),namespace)
namespace['validate']()
read,write,values=namespace['read'],namespace['write'],namespace['values']
OUT=BASE/'export/locomotion_r6p';ASSETS=BASE.parents[3]/'game_mobile_3d/assets/characters'
old,oldbuf=read(ASSETS/'player_cuboid_animated_v4.glb');doc=copy.deepcopy(old);buf=bytearray(oldbuf)
approved,newbuf=read(OUT/'approved_locomotion.glb')
names={n['name']:i for i,n in enumerate(doc['nodes'])}
assert set(names)=={n['name'] for n in approved['nodes']}
offset=len(buf);offset+=(-offset)%4;buf+=b'\0'*(offset-len(buf));buf+=newbuf
vo,ao=len(doc['bufferViews']),len(doc['accessors'])
for view in approved['bufferViews']:
    v=copy.deepcopy(view);v['byteOffset']=offset+v.get('byteOffset',0);doc['bufferViews'].append(v)
for accessor in approved['accessors']:
    a=copy.deepcopy(accessor);a['bufferView']+=vo;doc['accessors'].append(a)
for animation in approved['animations']:
    a=copy.deepcopy(animation)
    assert a['name'] not in {x['name'] for x in old['animations']}
    for s in a['samplers']:s['input']+=ao;s['output']+=ao
    for c in a['channels']:c['target']['node']=names[approved['nodes'][c['target']['node']]['name']]
    doc['animations'].append(a)
for key in ['nodes','meshes','skins','materials','images','textures','samplers','scenes']:
    assert doc.get(key)==old.get(key),key
assert doc['animations'][:len(old['animations'])]==old['animations']
assert buf[:len(oldbuf)]==oldbuf
assert set(a['name'] for a in doc['animations'])=={a['name'] for a in old['animations']}|set(namespace['NAMES'])
report=json.loads((OUT/'glb_validation.json').read_text())
report.update({'production_source':'player_cuboid_animated_v4.glb','production_output':'player_cuboid_animated_v5.glb','previous_clips':[a['name'] for a in old['animations']],'all_prior_animation_accessors_binary_preserved':True,'mesh_rig_skin_materials_images_unchanged':True,'production_source_sha256':hashlib.sha256((ASSETS/'player_cuboid_animated_v4.glb').read_bytes()).hexdigest()})
write(ASSETS/'player_cuboid_animated_v5.glb',doc,buf)
(OUT/'production_glb_validation.json').write_text(json.dumps(report,indent=2))
print('R6P_PRODUCTION_EXPORT_VALIDATED',json.dumps(report))
