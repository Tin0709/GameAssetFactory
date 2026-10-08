import bpy,json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent;V1=ROOT.parent/'dungeons_grass_style_v1';WORK=ROOT.parents[3];VALID=WORK/'.validation/dungeons_grass_style_v1'
m=json.loads((ROOT/'manifest.json').read_text());checks=[]
def check(name,value,detail=None):
    checks.append({'test':name,'pass':bool(value),'detail':detail});assert value,(name,detail)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'dungeons_ground_style_v2.blend'))
assets=list(bpy.data.collections['ASSETS_Export'].objects)
check('five marked asset meshes',len(assets)==5 and all(o.type=='MESH' and o.asset_data for o in assets))
check('one complete five asset review scene',bpy.context.scene.name=='REVIEW_DungeonsGround_Style_V2' and len(bpy.data.scenes)==1 and all(not o.hide_render for o in assets))
for o in assets:
    tris=sum(len(p.vertices)-2 for p in o.data.polygons)
    isblock='Block' in o.name
    check(o.name+' triangles',tris==(12 if isblock else 4),tris)
    if isblock:check(o.name+' exact 1m cube',all(abs(x-1)<1e-6 for x in o.dimensions),list(o.dimensions))
    co=[v.co for v in o.data.vertices];check(o.name+' local bottom center',min(v.z for v in co)==0 and all(abs(min(v[i] for v in co)+max(v[i] for v in co))<1e-6 for i in [0,1]))
    check(o.name+' no rig animation modifier',not o.modifiers and not o.animation_data and not o.parent)
    check(o.name+' packed closest own atlas',all(n.image.name=='meadow_atlas' and n.image.packed_file and n.interpolation=='Closest' for mat in o.data.materials for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'))
for n,data in m['V1_original_geometry'].items():
    o=bpy.data.objects[n];now={'vertices':[list(v.co) for v in o.data.vertices],'faces':[list(p.vertices) for p in o.data.polygons],'uv':[list(u.uv) for u in o.data.uv_layers.active.data]}
    check(n+' original vertex face UV exact',now==data)
check('all V1 files unchanged',all((V1/p).exists() and sha(V1/p)==h for p,h in m['V1_file_hashes_before'].items()))
check('all V1 individual region PNG files unchanged',all(sha(ROOT/'textures'/n)==sha(V1/'textures'/n) for n in ['grass_top.png','dirt.png','grass_side.png','short_grass.png','tall_grass.png']))
check('all seven source images packed',all(bpy.data.images[n].packed_file for n in ['grass_top','dirt','grass_side','short_grass','tall_grass','stone','meadow_atlas']))
def load(p):
    im=bpy.data.images.load(str(p),check_existing=False);return im,list(im.pixels)
oldim,old=load(V1/'textures/meadow_atlas.png');newim,new=load(ROOT/'textures/meadow_atlas.png')
check('atlas size retained 128',list(newim.size)==[128,128])
check('atlas all pixels outside new stone gutter preserved',all(old[(y*128+x)*4:(y*128+x+1)*4]==new[(y*128+x)*4:(y*128+x+1)*4] for y in range(128) for x in range(128) if not (72<=x<108 and 36<=y<72)))
check('new stone gutter no original region overlap',all(not (72<r[0]+r[2] and 108>r[0] and 36<r[1]+r[3] and 72>r[1]) for r in m['atlas']['previous_regions'].values()))
stone,p=load(ROOT/'textures/stone.png');w=32
check('stone x tiling exact edge',all(p[y*w*4:y*w*4+4]==p[(y*w+31)*4:(y*w+32)*4] for y in range(32)))
check('stone y tiling exact edge',p[:w*4]==p[-w*4:])
check('stone atlas own source exact',all(p[(y*32+x)*4:(y*32+x+1)*4]==new[((y+38)*128+x+74)*4:((y+38)*128+x+75)*4] for y in range(32) for x in range(32)))
check('dirt six faces reuse original UV region',all(tuple(uv.uv) in [(38/128,2/128),(70/128,2/128),(70/128,34/128),(38/128,34/128)] for uv in bpy.data.objects['ENV_DirtBlock_DI_Study_V2'].data.uv_layers.active.data))
check('binary atlas alpha',set(new[3::4])=={0.,1.})
for path in (ROOT/'exports').glob('*.glb'):
    raw=path.read_bytes();size,kind=struct.unpack_from('<II',raw,12);d=json.loads(raw[20:20+size]);bin=raw[28+size:];filename=path.name
    check(filename+' single mesh identity node',len(d['meshes'])==len(d['nodes'])==1 and all(k not in d['nodes'][0] for k in ['translation','rotation','scale','matrix']))
    check(filename+' no skin animation camera',all(not d.get(k) for k in ['skins','animations','cameras']))
    isblock='block_' in filename;mat=d['materials'][0]
    check(filename+' proper alpha state',mat.get('alphaMode','OPAQUE')==('OPAQUE' if isblock else 'MASK') and (isblock or mat.get('doubleSided') is True))
    check(filename+' nearest sampler',all(s.get('magFilter')==9728 and s.get('minFilter') in [9728,9984] for s in d['samplers']))
    pos=d['accessors'][d['meshes'][0]['primitives'][0]['attributes']['POSITION']]
    check(filename+' Y up bottom center',abs(pos['min'][1])<1e-6 and all(abs(pos['min'][i]+pos['max'][i])<1e-6 for i in [0,2]))
    if isblock:check(filename+' 1m exported bounds',all(abs(pos['max'][i]-pos['min'][i]-1)<1e-6 for i in [0,1,2]))
    check(filename+' one embedded own PNG',len(d['images'])==1 and d['images'][0].get('mimeType')=='image/png' and 'uri' not in d['images'][0])
    view=d['bufferViews'][d['images'][0]['bufferView']];png=bin[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']];tmp=VALID/('v2_'+filename+'.png');tmp.write_bytes(png);im,pix=load(tmp)
    check(filename+' embedded V2 original atlas pixel equality',len(pix)==len(new) and max(abs(x-y) for x,y in zip(pix,new))<1e-5)
check('stone/dirt pack references unchanged',all(sha(WORK/'references/resource_packs/dungeons_ii_style/extracted/assets/minecraft/textures/block'/n)==h for n,h in m['reference_hashes'].items()))
check('all requested rendered views exist',all((ROOT/n).stat().st_size>10000 for n in m['preview_paths']))
check('all three blocks same row height',len(set(bpy.data.objects[n].location.z for n in ['ENV_GrassBlock_DI_Study_V1','ENV_DirtBlock_DI_Study_V2','ENV_StoneBlock_DI_Study_V2']))==1)
result={'status':'PASS','checks':checks,'passed':len(checks),'failed':0}
(m.update({'validation':{'status':'PASS','checks':len(checks),'evidence':'.validation/dungeons_grass_style_v1/v2-verification.json'}}))
(ROOT/'manifest.json').write_text(json.dumps(m,indent=2))
(VALID/'v2-verification.json').write_text(json.dumps(result,indent=2));print('V2_VERIFICATION_PASS',len(checks))
