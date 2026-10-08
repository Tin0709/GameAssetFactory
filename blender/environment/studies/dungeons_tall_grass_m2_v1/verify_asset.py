from pathlib import Path
import json,struct,hashlib,io
from PIL import Image
ROOT=Path(__file__).resolve().parent;WORK=ROOT.parents[3];SOURCE=ROOT.parent/'dungeons_ground_style_v2'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((ROOT/'source_preservation.json').read_text())
assert all(sha(SOURCE/n)==v for n,v in before.items())
old=Image.open(SOURCE/'textures/meadow_atlas.png').convert('RGBA');new=Image.open(ROOT/'meadow_m2_atlas.png').convert('RGBA')
changes=[]
for y in range(128):
    for x in range(128):
        if old.getpixel((x,y))!=new.getpixel((x,y)):
            assert 38<=x<70 and 26<=y<90;changes.append((x,y))
assert changes
short=Image.open(SOURCE/'textures/short_grass.png').convert('RGBA');pal={p[:3] for p in short.getdata() if p[3]}
patch=new.crop((38,26,70,90));assert all(p[:3] in pal for p in patch.getdata() if p[3])
assert patch.tobytes()!=Image.open(SOURCE/'textures/tall_grass.png').convert('RGBA').tobytes()
b=(ROOT/'tall_grass_m2_v1.glb').read_bytes();ln=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+ln]);binary=b[28+ln:]
def acc(index):
    a=j['accessors'][index];v=j['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];fmt={5126:'f',5123:'H',5121:'B'}[a['componentType']];sz=struct.calcsize(fmt)*n;offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*n,binary,offset+i*v.get('byteStride',sz)) for i in range(a['count'])]
p=j['meshes'][0]['primitives'][0];at=p['attributes'];pos=acc(at['POSITION']);c=acc(at['COLOR_0']);uv2=acc(at['TEXCOORD_1']);uv=acc(at['TEXCOORD_0'])
assert j['accessors'][at['COLOR_0']]['componentType']==5126
assert j['accessors'][at['TEXCOORD_1']]['componentType']==5126
assert len(acc(p['indices']))//3==32
assert abs(max(v[1] for v in pos)-1.95)<1e-6 and min(v[1] for v in pos)==0
assert all(abs(x)<1e-7 for n in j['nodes'] for x in n.get('translation',[0,0,0]))
for v,col,root in zip(pos,c,uv2):
    t=v[1]/1.95;assert abs(col[0]-t*t)<1e-6 and abs(col[1]-t)<1e-6;assert root==(.5,.5)
assert any(col[:2]==(0,0) for col in c) and any(col[:2]==(1,1) for col in c)
assert all(.296875<=u<=.546875 and .203125<=v<=.703125 for u,v in uv)
m=j['materials'][0];assert m['alphaMode']=='MASK' and m['alphaCutoff']==.5 and m['doubleSided']
assert all(s['magFilter']==9728 and s['minFilter']==9728 for s in j['samplers'])
iv=j['bufferViews'][j['images'][0]['bufferView']];packed=Image.open(io.BytesIO(binary[iv['byteOffset']:iv['byteOffset']+iv['byteLength']])).convert('RGBA');assert packed.tobytes()==new.tobytes()
report={'status':'PASS','source_files_preserved':len(before),'source_hashes_before_and_after':before,'changed_atlas_pixels':len(changes),'only_changed_region_blender_bottom_up':[38,38,32,64],'atlas_preservation_outside_region':True,'exact_short_palette':True,'new_silhouette_not_copied':True,'triangles':32,'native_gltf_dimensions_xyz':[max(v[i] for v in pos)-min(v[i] for v in pos) for i in range(3)],'native_height_y':max(v[1] for v in pos),'origin':'bottom center, identity node transform','attributes':{k:j['accessors'][v] for k,v in at.items()},'color_float_5126':True,'uv2_float_5126':True,'root_bend_zero':True,'tip_bend_one':True,'color_formula_max_error':max(abs(col[0]-(v[1]/1.95)**2) for v,col in zip(pos,c)),'packed_texture_exact_new_atlas':True,'material':m,'samplers':j['samplers'],'commands':['Python313/python.exe prepare_atlas.py','Start-Process Blender 5.2/blender.exe --background --factory-startup --python author_tall.py -WindowStyle Hidden; WaitForExit','Python313/python.exe verify_asset.py'],'evidence':['blender/environment/studies/dungeons_tall_grass_m2_v1/author.log','blender/environment/studies/dungeons_tall_grass_m2_v1/review_render.png'],'outputs':{n:sha(ROOT/n) for n in ['tall_grass_m2_v1.blend','tall_grass_m2_v1.glb','meadow_m2_atlas.png','review_render.png']},'artistic_status':'awaiting human review'}
if (ROOT/'reopen_verification.json').exists():
    report['reopen_validation']=json.loads((ROOT/'reopen_verification.json').read_text())
    report['commands'].append('Start-Process Blender 5.2/blender.exe --background --factory-startup --python reopen_verify.py -WindowStyle Hidden; WaitForExit')
    report['evidence'].append('blender/environment/studies/dungeons_tall_grass_m2_v1/reopen_verification.json')
(WORK/'.validation/m2_litematic/tall_asset_report.json').write_text(json.dumps(report,indent=2))
print('PASS',len(before),'preserved files; 32 triangles; native +Y 1.95m; float bend attributes; exact packed atlas')
