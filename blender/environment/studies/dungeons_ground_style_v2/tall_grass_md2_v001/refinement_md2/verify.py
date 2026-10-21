import bpy,sys,json,math,hashlib
from pathlib import Path
D=Path(__file__).resolve().parent;T=D.parent;P=T.parent;R=T.parents[4];E=R/'.validation/grass_md2_single_window_v001';sys.path[:0]=[str(P),str(T)]
from flower_preservation import snapshot,compare,mesh_content
from geometry import asset_record
path=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else P/'dungeons_ground_style_v2.blend';bpy.ops.wm.open_mainfile(filepath=str(path));s=bpy.context.scene;manifest=json.loads((D/'manifest.json').read_text());baseline=json.loads((E/'before_fingerprints.json').read_text());old=json.loads((E/'before_tall_meshes.json').read_text())
def restore(m,data):
 for uv in list(m.uv_layers):m.uv_layers.remove(uv)
 m.clear_geometry();m.from_pydata(data['vertices'],[],[x[0] for x in data['faces']]);m.materials.clear()
 for name in data['materials']:m.materials.append(bpy.data.materials[name])
 for p,rec in zip(m.polygons,data['faces']):p.material_index=rec[1];p.use_smooth=rec[2]
 for name,coords in data['uv'].items():
  uv=m.uv_layers.new(name=name)
  for dst,xy in zip(uv.data,coords):dst.uv=xy
 m.update()
new={n:mesh_content(bpy.data.objects[n].data) for n in old}
for n,raw in old.items():restore(bpy.data.objects[n].data,raw)
for name in ['Tall Grass MD2','Short Grass MD2','ViewLayer']:
 bpy.context.window.view_layer=s.view_layers[name];bpy.context.view_layer.update()
errors=compare(baseline)
for n,raw in new.items():restore(bpy.data.objects[n].data,raw)
assert not errors,errors
assert len(bpy.data.scenes)==1 and not bpy.data.actions
records=[];mat_ids=set();planar=0
for item in manifest['assets']:
 o=bpy.data.objects[item['name']];m=o.data;mat=m.materials[0];mat_ids.add(mat.as_pointer());image=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');r=asset_record(o,image);records.append(r)
 assert o.asset_data and o['review_status']=='Pending' and not o.modifiers and not o.animation_data
 assert .70<=r['visible_height']<=.96 and min(r['visible_xy_size'])>=1.0 and r['triangles']==item['triangles']
 assert max(r['root_xy_size'])<1.0
 for p in m.polygons:
  co=m.vertices[p.vertices[0]].co
  for vi in p.vertices:planar=max(planar,abs((m.vertices[vi].co-co).dot(p.normal)))
assert len(mat_ids)==1 and planar<1e-6
im=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');pixels=list(im.pixels);assert {pixels[i] for i in range(3,len(pixels),4)}=={0.,1.};assert any(pixels[i]>.6 and pixels[i+1]>.6 and pixels[i+2]>.35 and pixels[i+3]>.5 for i in range(0,len(pixels),4))
import grass_library_ui as ui;ui.register();assert hasattr(bpy.types,'MD2_PT_grass_library') and not hasattr(bpy.types,'MD2_PT_short_grass') and not hasattr(bpy.types,'MD2_PT_tall_grass')
routes=['All','S:Overview','S:Low Cushion','S:Broad Fan','S:Soft Rosette','S:Uneven Tuft','S:Cluster','T:Overview','T:Compare','T:Soft Meadow','T:Open Fan','T:Low Sweep','T:Uneven Crown','T:Meadow Cluster','T:Upright Cluster','T:Grouped','T:Gameplay','T:Side','T:Opposite','S:Original','All']
for key in routes:ui.select(bpy.context,key)
info=ui.record();layer=bpy.context.view_layer;assert layer.name==info['layer'];combined=bpy.data.collections[info['combined_collection']];assert sum(o.name.startswith('MD2_Combined_Tall_') for o in combined.objects)==6
assert all(o.visible_get(view_layer=layer) for o in combined.objects if o.type=='MESH')
assert all(bpy.data.objects[n].visible_get(view_layer=layer) for n in json.loads(s['md2_review'])['masters'])
report={'passed':True,'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'preservation':'All pre-existing native content exact when authorized six tall candidate meshes are restored; short half-block geometry/materials untouched.','assets':records,'one_shared_panel':True,'same_scene':True,'same_short_review_layer':layer.name,'combined_tall_copies':6,'routes':routes,'max_quad_planarity_error_m':planar,'new_actions':0,'new_scenes':0}
(D/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print('UNIFIED_MD2_VALIDATION',json.dumps(report),flush=True)
