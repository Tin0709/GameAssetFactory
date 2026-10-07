"""Read-only saved-file preservation, preview equivalence and rifle-marker checks."""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix
BASE=Path(__file__).resolve().parent
source_scene=bpy.data.scenes['Player_Cuboid_Classic_Asset'];bpy.context.window.scene=source_scene
src=(BASE/'create_ready_e1.py').read_text();exec(src[:src.index("assert 'LongGunReady_Loop_V1' not in")])
p=json.loads((BASE/'ready_run_e2_protection.json').read_text())
assert all(digest(bpy.data.actions[n])==h for n,h in p['actions'].items())
current=geometry();assert all(current[n]==h for n,h in p['geometry'].items())
assert json.dumps(bones(),sort_keys=True)==json.dumps(p['bones'],sort_keys=True)
actions={'A':bpy.data.actions['LongGunHold_V2'],'B':bpy.data.actions['LongGunReady_Loop_V1'],'C':bpy.data.actions['LongGunReady_Run_V1']}
run=bpy.data.actions['Player_Run_Blocky_V7_Final']
review=(BASE/'review_ready_run_e2.py').read_text()
exec(review[review.index('def compose('):review.index('# Same conservative')])
def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
markers={};expected={}
for label in 'ABC':
    values={n:[] for n in ['Muzzle_Point','Grip_Point','Support_Hand_Point']}
    for i in range(641):
        pose,_=compose(label,i/4)
        if i%4==0:expected[(label,i//4+1)]=pose
        deps=bpy.context.evaluated_depsgraph_get()
        for n in values:values[n].append(bpy.data.objects[n].evaluated_get(deps).matrix_world.translation.z)
    markers[label]={n:max(v)-min(v) for n,v in values.items()}
preview=bpy.data.scenes['E2_Run_ABC_Detail'];bpy.context.window.scene=preview
maxerr=0.
for f in [1,2,5,7,10,41,80,120,160]:
    preview.frame_set(f);bpy.context.view_layer.update()
    for label in 'ABC':
        rr=next(o for o in preview.objects if o.type=='ARMATURE' and o.animation_data.action.name.endswith('_'+label))
        for n,m in expected[(label,f)].items():maxerr=max(maxerr,err(rr.pose.bones[n].matrix_basis,m))
assert maxerr<3e-6,maxerr
assert 'E2_Run_ABC_GameplayScale' in bpy.data.scenes
lower={n:sum(len(c.keyframe_points) for c in curves(actions['C']) if c.data_path.startswith('pose.bones["'+n+'"]')) for n in LOWER}
assert not any(lower.values()) and not any(c.data_path.endswith('scale') for c in curves(actions['C']))
report=json.loads((BASE/'ready_run_e2_validation.json').read_text())
report['saved_file_verified']=True;report['preview_pose_max_matrix_error']=maxerr
report['rifle_marker_vertical_excursion_m']=markers
(BASE/'ready_run_e2_validation.json').write_text(json.dumps(report,indent=2))
print('E2_SAVED_FILE_VERIFIED '+json.dumps({'protected_actions':len(p['actions']),'preview_pose_error':maxerr,'marker_excursion_m':markers,'lower_keys':lower}))
