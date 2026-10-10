"""Saved higher preview vs original: unchanged pose/assets, changed height only."""
import bpy,json,sys,hashlib,ast
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;BASE=OUT.parent;ROOT=BASE.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
# Reuse only the two pure fingerprint helpers, without running the older audit.
tree=ast.parse((BASE/'verify_assets.py').read_text(encoding='utf8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['digest','assets']],type_ignores=[]),'<asset fingerprint helpers>','exec'))
data=json.loads((OUT/'manifest.json').read_text());assert bpy.data.filepath.endswith('full_jump_higher_preview_v002.blend')
s=bpy.context.scene;r=bpy.data.objects['FJ_Test_Rig'];m=bpy.data.objects['FJ_Test_Mesh'];travel=bpy.data.objects[data['preview_parent']]
reference=json.loads((BASE/'asset_verification.json').read_text())['full_jump_preview.blend']['asset_fingerprints']
current_assets=json.loads(json.dumps(assets(r,m))) # Stored JSON turns binding tuples into lists.
assert current_assets==reference,'Appearance/rest/weights/UV/material/light change'
assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in data['original_action_signatures'].items())
assert len(bpy.data.actions)==10 and len(bpy.data.armatures)==1 and len(bpy.data.meshes)==2
assert r.parent==travel and travel.animation_data.action.name==data['preview_action']
old=bpy.data.actions['PREVIEW_ONLY_FullJump_Height'];new=travel.animation_data.action
assert len(old.slots)==len(new.slots)==1 and old.slots[0].identifier==new.slots[0].identifier
old_curves={(c.data_path,c.array_index):c for c in ui.curves(old)}
for c in ui.curves(new):
    assert c.data_path=='location';previous=old_curves[(c.data_path,c.array_index)];assert len(c.keyframe_points)==len(previous.keyframe_points)
    for k,p in zip(c.keyframe_points,previous.keyframe_points):
        assert k.co.x==p.co.x and k.interpolation==p.interpolation=='LINEAR'
        assert abs(k.co.y-p.co.y*(data['height_ratio'] if c.array_index==2 else 1))<1e-6
assert [s.frame_start,s.frame_end,s.render.fps,s.render.fps_base]==[1,93,30,1]
report={'appearance_and_binding_unchanged':True,'all_nine_original_actions_unchanged':True,'no_new_skeletal_action':True,'same_action_slots':True,'same_93_frame_30fps_timing':True,'height_only_change':True,'samples':1473,'max_height_ratio_error_m':0,'minimum_floor_clearance_m':1,'minimum_supported_floor_clearance_m':1,'camera_bounds':{},'max_grounded_travel_m':0}
heights=[]
for j in range(report['samples']):
    f=1+j/16;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();h=travel.location.z;heights.append(h)
    old_height=old_curves[('location',2)].evaluate(f);report['max_height_ratio_error_m']=max(report['max_height_ratio_error_m'],abs(h-old_height*data['height_ratio']))
    obj=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[obj.matrix_world@v.co for v in obj.data.vertices]
    z=min(p.z for p in points);report['minimum_floor_clearance_m']=min(report['minimum_floor_clearance_m'],z)
    if f<=19 or f>=46:
        report['max_grounded_travel_m']=max(report['max_grounded_travel_m'],abs(h));report['minimum_supported_floor_clearance_m']=min(report['minimum_supported_floor_clearance_m'],z)
    if j%2==0:
        for view in ['FRONT','THREE_QUARTER','SIDE']:
            q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in points];b=report['camera_bounds'].setdefault(view,[1,1,0,0]);b[:]=[min(b[0],min(x.x for x in q)),min(b[1],min(x.y for x in q)),max(b[2],max(x.x for x in q)),max(b[3],max(x.y for x in q))]
peak=heights.index(max(heights));report['apex_height_m']=max(heights);report['apex_frame']=1+peak/16
report['single_rise_and_descent']=all(b>=a-1e-8 for a,b in zip(heights[:peak],heights[1:peak+1])) and all(b<=a+1e-8 for a,b in zip(heights[peak:],heights[peak+1:]))
# Compare camera transforms/data and markers with the unchanged source presentation.
def presentation():
    return {'cameras':{v:{'matrix':list(sum((list(row) for row in bpy.data.objects['Showcase_'+v].matrix_world),[])),'ortho_scale':bpy.data.objects['Showcase_'+v].data.ortho_scale,'lens':bpy.data.objects['Showcase_'+v].data.lens} for v in ['FRONT','THREE_QUARTER','SIDE']},'markers':[(x.name,x.frame) for x in bpy.context.scene.timeline_markers]}
new_presentation=presentation();bpy.ops.wm.open_mainfile(filepath=str(BASE/'full_jump_preview.blend'));assert presentation()==new_presentation
report['cameras_and_phase_markers_unchanged']=True
before=json.loads((ROOT/'.validation/full_jump_higher_preview_v002/backup_manifest.json').read_text());allowed={str(ROOT/p) for p in before['authorized_metadata_changes']};protected=[p for p in before['files'] if p not in allowed]
report['protected_files_unchanged']=all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==before['files'][p] for p in protected);report['protected_file_count']=len(protected)
report['passed']=report['max_height_ratio_error_m']<1e-6 and report['minimum_floor_clearance_m']>-.00001 and report['max_grounded_travel_m']==0 and abs(report['apex_height_m']-.72)<1e-6 and report['single_rise_and_descent'] and report['apex_frame']==32.5 and report['protected_files_unchanged'] and all(min(b[:2])>0 and max(b[2:])<.985 for b in report['camera_bounds'].values())
(OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report),flush=True);assert report['passed']
