import bpy,json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent; WORK=ROOT.parents[3]; VALID=WORK/'.validation/dungeons_grass_style_v1'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'dungeons_grass_style_v1.blend'))
checks=[]
def check(name,value,detail=None):
    checks.append({'test':name,'pass':bool(value),'detail':detail}); assert value,(name,detail)
expected={'ENV_GrassBlock_DI_Study_V1':([1,1,1],12),'ENV_Grass_DI_Study_V1':([.58,.58,.46],4),'ENV_TallGrass_DI_Study_V1':([.72,.72,.95],4)}
assets=list(bpy.data.collections['ASSETS_Export'].objects)
check('exactly three export marked asset meshes',len(assets)==3 and set(o.name for o in assets)==set(expected) and all(o.type=='MESH' and o.asset_data for o in assets))
for o in assets:
    dim,tri=expected[o.name]; check(o.name+' dimensions',all(abs(a-b)<1e-6 for a,b in zip(o.dimensions,dim)),list(o.dimensions))
    check(o.name+' triangles',sum(len(p.vertices)-2 for p in o.data.polygons)==tri,tri)
    coords=[v.co for v in o.data.vertices]; check(o.name+' bottom center local pivot',min(v.z for v in coords)==0 and abs(min(v.x for v in coords)+max(v.x for v in coords))<1e-6 and abs(min(v.y for v in coords)+max(v.y for v in coords))<1e-6)
    check(o.name+' UV bounds',all(0<=c<=1 for uv in o.data.uv_layers.active.data for c in uv.uv))
    check(o.name+' no rig animation modifier',not o.modifiers and not o.animation_data and not o.parent)
    check(o.name+' own packed atlas',all(n.image and n.image.name=='meadow_atlas' and n.image.packed_file and n.interpolation=='Closest' for m in o.data.materials for n in m.node_tree.nodes if n.type=='TEX_IMAGE'))
manifest=json.loads((ROOT/'manifest.json').read_text())
check('all six authored texture sources packed',all(bpy.data.images[n].packed_file for n in ['grass_top','dirt','grass_side','short_grass','tall_grass','meadow_atlas']))
def pixels(n):
    im=bpy.data.images.load(str(ROOT/'textures'/(n+'.png')),check_existing=False); return list(im.pixels),im.size[0],im.size[1]
for n in ['grass_top','dirt','grass_side']:
    p,w,h=pixels(n)
    check(n+' horizontal exact seam',all(p[(y*w)*4:(y*w)*4+4]==p[(y*w+w-1)*4:(y*w+w)*4] for y in range(h)))
    if n!='grass_side': check(n+' vertical exact seam',p[:w*4]==p[-w*4:])
for n in ['short_grass','tall_grass','meadow_atlas']:
    p,w,h=pixels(n); check(n+' binary alpha',set(p[3::4])=={0.0,1.0},[w,h])
exportinfo=[]
for filename in ['grass_block','grass','tall_grass']:
    path=ROOT/'exports'/(filename+'_di_study_v1.glb'); raw=path.read_bytes(); size,kind=struct.unpack_from('<II',raw,12); doc=json.loads(raw[20:20+size]); bindata=raw[28+size:]
    check(filename+' valid GLB header',struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw)))
    check(filename+' single isolated mesh and node',len(doc['meshes'])==1 and len(doc['nodes'])==1 and len(doc['scenes'][0]['nodes'])==1)
    check(filename+' identity node',all(key not in doc['nodes'][0] for key in ['translation','rotation','scale','matrix']),doc['nodes'])
    check(filename+' no animation skin camera',all(not doc.get(k) for k in ['animations','skins','cameras']))
    check(filename+' one embedded PNG only',len(doc['images'])==1 and doc['images'][0]['mimeType']=='image/png' and 'bufferView' in doc['images'][0] and 'uri' not in doc['images'][0])
    check(filename+' nearest sampler',all(s.get('magFilter')==9728 and s.get('minFilter') in [9728,9984] for s in doc['samplers']),doc['samplers'])
    mat=doc['materials'][0]
    check(filename+' correct alpha mode',mat.get('alphaMode','OPAQUE')==('OPAQUE' if filename=='grass_block' else 'MASK') and (filename=='grass_block' or mat.get('doubleSided') is True),mat.get('alphaMode','OPAQUE'))
    pos=doc['accessors'][doc['meshes'][0]['primitives'][0]['attributes']['POSITION']]
    check(filename+' Y up bottomcenter',abs(pos['min'][1])<1e-7 and all(abs(pos['min'][i]+pos['max'][i])<1e-6 for i in [0,2]),{'min':pos['min'],'max':pos['max']})
    image=doc['images'][0]; bv=doc['bufferViews'][image['bufferView']]; png=bindata[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
    temp=VALID/(filename+'_embedded.png'); temp.write_bytes(png); embedded=bpy.data.images.load(str(temp),check_existing=False); atlas=bpy.data.images['meadow_atlas']
    a=list(atlas.pixels); b=list(embedded.pixels)
    check(filename+' embedded original atlas pixel equality',len(a)==len(b) and max(abs(x-y) for x,y in zip(a,b))<1e-5,{'size':list(embedded.size),'max_difference':max(abs(x-y) for x,y in zip(a,b))})
    exportinfo.append({'filename':path.name,'size_bytes':len(raw),'material':mat.get('alphaMode','OPAQUE'),'Yup_bounds':{'min':pos['min'],'max':pos['max']}})
refs=manifest['reference_paths_hashes']; check('seven source reference PNGs unchanged',len(refs)==7 and all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in refs.items()))
check('generated file hashes differ from all pack references',all(h not in refs.values() for h in manifest['texture_hashes'].values()))
check('three review cameras',len([o for o in bpy.data.objects if o.type=='CAMERA'])==3)
check('nine linked tile copies',len([o for o in bpy.data.collections['REVIEW_Instances'].objects if o.name.startswith('Tile_') and o.data==bpy.data.objects['ENV_GrassBlock_DI_Study_V1'].data])==9)
check('actual Blender renders exist',all((ROOT/(n+'.png')).stat().st_size>10000 for n in ['showcase','tiling','closeup']))
result={'status':'PASS','checks':checks,'exports':exportinfo,'asset_triangle_counts':{'grass_block':12,'grass':4,'tall_grass':4},'preview_inspection':'Author must view all actual rendered previews before report completion.'}
(VALID/'verification.json').write_text(json.dumps(result,indent=2)); print('VERIFICATION_PASS',len(checks))
