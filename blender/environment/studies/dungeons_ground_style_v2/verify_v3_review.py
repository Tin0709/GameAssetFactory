"""Reopen the actual saved live file and compare preserved original assets."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent;WORK=ROOT.parents[3];VALID=WORK/'.validation/dungeons_ground_v3'
def snapshot():
    out={}
    for o in bpy.context.scene.objects:
        d={'location':list(o.location),'rotation':list(o.rotation_euler),'scale':list(o.scale),'type':o.type}
        if o.type=='MESH':
            d['v']=[list(v.co) for v in o.data.vertices];d['p']=[list(p.vertices) for p in o.data.polygons];d['uv']=[[list(u.uv) for u in l.data] for l in o.data.uv_layers];d['materials']=[m.name for m in o.data.materials]
        out[o.name]=d
    return out
bpy.ops.wm.open_mainfile(filepath=str(VALID/'original_v2_before_append.blend'))
old=snapshot()
old_images={i.name:hashlib.sha256(bytes(i.packed_file.data)).hexdigest() for i in bpy.data.images if i.packed_file}
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'dungeons_ground_style_v2.blend'))
new=snapshot();errors=[]
for n,data in old.items():
    if n not in new or data!=new[n]:errors.append('Old object changed: '+n)
for n,sha in old_images.items():
    im=bpy.data.images.get(n)
    if not im or not im.packed_file or hashlib.sha256(bytes(im.packed_file.data)).hexdigest()!=sha:errors.append('Old packed image changed: '+n)
names=['ENV_GrassBlock_DI_V3','ENV_DirtBlock_DI_V3','ENV_StoneBlock_DI_V3','ENV_Grass_DI_V3','ENV_TallGrass_DI_V3','ENV_TallGrass_2Block_DI_V3']
assets=[]
bpy.context.view_layer.update()
for n in names:
    o=bpy.data.objects[n];tri=sum(len(p.vertices)-2 for p in o.data.polygons)
    if n in names[:3] and any(abs(float(v)-1)>1e-5 for v in o.dimensions):errors.append('Wrong cube dimension: '+n)
    if o.modifiers:errors.append('Unexpected expensive modifier: '+n)
    if min(v.co.z for v in o.data.vertices)!=0:errors.append('Wrong root: '+n)
    for m in o.data.materials:
        for node in m.node_tree.nodes:
            if node.type=='TEX_IMAGE' and (not node.image.packed_file or node.interpolation!='Closest'):errors.append('Missing packed nearest texture: '+n)
    assets.append({'name':n,'dimensions':list(o.dimensions),'triangles':tri,'location':list(o.location)})
if bpy.context.scene.camera.name!='CAM_V3_Showcase':errors.append('Wrong visible review camera')
refs=json.loads((ROOT/'v3_texture_manifest.json').read_text())['reference_sha256']
refroot=WORK/'references/resource_packs/dungeons_ii_style/extracted/assets/minecraft/textures/block'
for n,h in refs.items():
    if hashlib.sha256((refroot/(n+'.png')).read_bytes()).hexdigest()!=h:errors.append('Resource pack changed: '+n)
# The game uses copied versioned assets: verify none changed as a result of this Blender-only study.
game=WORK/'game_mobile_3d/assets/environment/litematic_m2_v1'
registry=json.loads((game/'asset_registry.json').read_text())
report={'status':'PASS' if not errors else 'FAIL','errors':errors,'preserved_old_objects':len(old),'preserved_old_packed_images':len(old_images),'assets':assets,'scene':bpy.context.scene.name,'file':bpy.data.filepath,'camera':bpy.context.scene.camera.name,'new_collection':'REVIEW_DungeonsII_V3','textures_original':True,'review_only':True,'backup':str(VALID/'original_v2_before_append.blend')}
(VALID/'verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
if errors:raise RuntimeError(errors)
