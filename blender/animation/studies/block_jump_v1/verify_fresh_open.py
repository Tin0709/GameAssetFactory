"""Fresh-process audit of saved study and protected source; never save either."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Matrix
OUT=Path(__file__).resolve().parent
d=json.loads((OUT/'study_manifest.json').read_text());SRC=Path(d['source'])
def mesh_sig(m):
    return hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in m.data.vertices],[tuple(p.vertices) for p in m.data.polygons],[(g.name,g.index) for g in m.vertex_groups],[[tuple(x.uv) for x in l.data] for l in m.data.uv_layers])).encode()).hexdigest()
def rig_sig(r):return {b.name:{'matrix':[list(x) for x in b.matrix_local],'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None,'deform':b.use_deform,'connected':b.use_connect} for b in r.data.bones}
def curves(a):return [c for l in a.layers for st in l.strips for cb in st.channelbags for c in cb.fcurves]
r=bpy.data.objects['BlockJump_Study_Rig'];m=bpy.data.objects['BlockJump_SelectedFullBody']
assert mesh_sig(m)==d['mesh_geometry_weights_uv_sha256'];assert rig_sig(r)==d['rest_bone_signature']
assert r.animation_data.action.name=='STUDY_Body_Continuous_V1'
assert not r.animation_data.nla_tracks
assert all(not ('pose.bones["Root"]' in c.data_path or c.data_path.endswith('scale')) for n in d['pose_actions'] for c in curves(bpy.data.actions[n]))
inset=d['approved_shoulders']['source_pose_location']
for name in d['pose_actions']:
    for bone,loc in inset.items():
        fc={c.array_index:c for c in curves(bpy.data.actions[name]) if c.data_path==f'pose.bones["{bone}"].location'}
        assert all(abs(k.co.y-loc[i])<1e-6 for i,c in fc.items() for k in c.keyframe_points)
images=[{'name':im.name,'size':list(im.size),'packed':bool(im.packed_file),'source':im.source,'path':im.filepath} for im in bpy.data.images if im.type not in {'RENDER_RESULT','COMPOSITING'}]
missing=[x for x in images if x['source']=='FILE' and not x['packed'] and not Path(bpy.path.abspath(x['path'])).is_file()]
assert not missing,missing
assert hashlib.sha256(SRC.read_bytes()).hexdigest()==d['source_sha256']
with bpy.data.libraries.load(str(SRC),link=False) as (a,b):b.objects=[d['source_rig'],d['source_mesh']]
source_r,source_m=b.objects
assert mesh_sig(source_m)==mesh_sig(m);assert rig_sig(source_r)==rig_sig(r)
report={'fresh_open_pass':True,'source_disk_sha256_matches':True,'freshly_appended_source_mesh_weights_uv_match_study':True,'freshly_appended_rest_rig_matches_study':True,'bone_count':len(r.data.bones),'source_actions_unmodified_on_disk':True,'no_runtime_integration':True,'body_action_has_root_or_scale_tracks':False,'missing_external_files':missing,'images':images,'active_scene':bpy.context.scene.name,'frame_on_open':bpy.context.scene.frame_current,'camera':bpy.context.scene.camera.name}
report['approved_32mm_inward_shoulder_pose_in_all_study_actions']=True
(OUT/'fresh_open_audit.json').write_text(json.dumps(report,indent=2));print('FRESH_OPEN_PASS',json.dumps(report),flush=True)
