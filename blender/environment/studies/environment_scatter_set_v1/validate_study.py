"""Fresh-open, study-only structural validation and preservation audit."""
import bpy,bmesh,json,hashlib
from pathlib import Path
from collections import Counter
D=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(D/'environment_scatter_set_v1.blend'))
assets=[o for o in bpy.context.scene.objects if o.get('scatter_asset')]
checks={};details=[]
checks['exactly_one_scene']=len(bpy.data.scenes)==1
checks['18_new_mesh_assets']=len(assets)==18 and all(o.type=='MESH' for o in assets)
counts=Counter(o['category'] for o in assets);checks['category_counts']=dict(counts)=={'rock':6,'dirt':4,'flower':8}
checks['rock_sizes']=Counter(o['variant'] for o in assets if o['category']=='rock')=={'small':2,'medium':2,'large':2}
checks['flower_colors']=Counter(o['variant'] for o in assets if o['category']=='flower')=={'purple':2,'yellow':2,'white':2,'red':2}
for o in assets:
 lo=[min(v.co[i] for v in o.data.vertices) for i in range(3)];hi=[max(v.co[i] for v in o.data.vertices) for i in range(3)]
 pivot=abs(lo[2])<1e-6 and all(abs(lo[i]+hi[i])<1e-6 for i in (0,1))
 scale=all(abs(v-1)<1e-6 for v in o.scale);rot=all(abs(v)<1e-6 for v in o.rotation_euler)
 uv=len(o.data.uv_layers)>0 and all(0<=v<=1 for loop in o.data.uv_layers[0].data for v in loop.uv)
 dim=list(o.dimensions);fit=(.2<=dim[0]<=.96 if o['category']=='rock' else .49<=dim[0]<=1.01 and .099<=dim[2]<=.251 if o['category']=='dirt' else .20<=dim[2]<=.401 and .28<=dim[0]<=.61)
 bm=bmesh.new();bm.from_mesh(o.data);nonmanifold=sum(not e.is_manifold for e in bm.edges);bm.free()
 details.append({'name':o.name,'dimensions_m':dim,'bottom_center_pivot':pivot,'identity_scale':scale,'identity_rotation':rot,'uv_valid':uv,'size_brief_met':fit,'no_modifiers':len(o.modifiers)==0,'asset_metadata':o.asset_data is not None,'nonmanifold_edges':nonmanifold})
checks['all_mesh_pivots_scales_rotations_uvs_dimensions']=all(all(d[k] for k in ('bottom_center_pivot','identity_scale','identity_rotation','uv_valid','size_brief_met')) for d in details)
checks['all_asset_metadata']=all(d['asset_metadata'] for d in details)
checks['no_modifiers_or_animation']=all(not o.modifiers and not o.animation_data and (o.type!='MESH' or not o.data.shape_keys) for o in bpy.context.scene.objects)
checks['no_linked_external_libraries']=len(bpy.data.libraries)==0
image_data=[{'name':i.name,'size':list(i.size),'packed':bool(i.packed_file),'source':i.source,'alpha_all_one':all(abs(a-1)<1e-5 for a in list(i.pixels)[3::4])} for i in bpy.data.images if i.type!='RENDER_RESULT']
checks['all_images_packed_opaque']=all(i['packed'] and i['alpha_all_one'] for i in image_data)
checks['all_image_textures_nearest']=all(n.interpolation=='Closest' for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes if n.type=='TEX_IMAGE')
checks['welded_closed_rock_dirt_surfaces']=all(d['nonmanifold_edges']==0 for d in details if bpy.data.objects[d['name']]['category'] in ('rock','dirt'))
refs=[o for o in bpy.context.scene.objects if o.get('reference_only')];checks['three_static_v4_reference_objects']=len(refs)==3
before=json.loads((D/'reference_hash_before.json').read_text(encoding='utf-8-sig'));source_after=hashlib.sha256(Path(before['Path']).read_bytes()).hexdigest();checks['source_v4_unchanged']=source_after.lower()==before['Hash'].lower()
prod=json.loads((D/'production_hashes_before.json').read_text(encoding='utf-8-sig'));audit=[]
for entry in prod:
 path=Path(entry['Path']);digest=hashlib.sha256(path.read_bytes()).hexdigest();audit.append({'path':str(path),'before':entry['Hash'].lower(),'after':digest,'unchanged':digest==entry['Hash'].lower()})
checks['all_production_environment_files_unchanged']=all(v['unchanged'] for v in audit)
report={'passed':all(checks.values()),'checks':checks,'counts':dict(counts),'assets':details,'images':image_data,'source_after_sha256':source_after,'production_preservation':audit,'fresh_reopen':True,'scene_name':bpy.context.scene.name,'artistic_status':'AWAITING HUMAN REVIEW'}
(D/'validation_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'passed':report['passed'],'checks':checks,'counts':dict(counts)},indent=2))
assert report['passed'],'Study validation failed; see validation_report.json'
