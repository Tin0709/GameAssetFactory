"""Retain the tested local right-arm correction; all other V2 curves are copied."""
import bpy,json,math,time
from pathlib import Path
from mathutils import Vector
import living_r9w2_common as h
import contact_probe_r9w3 as probe
BASE=Path(__file__).resolve().parent;OUT=BASE/'living_r9w3_review'
assert Path(bpy.data.filepath).name=='player_longgun_living_r9w3_study.blend'
name='LongGunAimAround_LeftRight_V3';assert name not in bpy.data.actions
s=probe.s;r=probe.r;w=probe.w;bpy.context.window.scene=s
src=bpy.data.actions['LongGunAimAround_LeftRight_V2'];a=src.copy();a.name=name;a.use_fake_user=True
a['scope']='R9-W3 upper-body/helper study: local right-arm contact correction only'
records=json.loads((BASE/'living_r9w1_review/design.json').read_text())['actions']['LongGunAimAround_LeftRight_V1']['records']
def weight(drive):
    x=max(0,min(1,(-drive-.40)/.45))
    return x*x*x*(x*(x*6-15)+10)
rows=[]
for i,record in enumerate(records):
    f=i+1;amount=weight(record['drive'])
    if amount<=1e-10:continue
    h.sample(r,s,src,f);pose={p.name:p.matrix_basis.copy() for p in r.pose.bones}
    gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
    before=r.pose.bones['ForeArm.R'].matrix@Vector((0,.2625,0))
    target=probe.orbit_right(pose,gm,6*amount,True)
    # Only author the two right quaternion curves. Shoulder position, support,
    # Chest/head and the WeaponCarrier authority remain the source V2 values.
    quats={n:r.pose.bones[n].rotation_quaternion.copy() for n in ['UpperArm.R','ForeArm.R']}
    h.assign(r,a)
    for n,q in quats.items():
        if q.dot(pose[n].to_quaternion())<0:q.negate()
        r.pose.bones[n].rotation_quaternion=q
        r.pose.bones[n].keyframe_insert('rotation_quaternion',frame=f,group=n)
    rows.append({'frame':f,'weight':amount,'orbit_degrees':6*amount,'target_weapon_local':target,
        'terminal_center_shift_m':(r.pose.bones['ForeArm.R'].matrix@Vector((0,.2625,0))-before).length})
for c in h.curves(a):
    if c.data_path not in ['pose.bones["UpperArm.R"].rotation_quaternion','pose.bones["ForeArm.R"].rotation_quaternion']:continue
    keys=c.keyframe_points;ys=[k.co.y for k in keys];N=len(keys)-1
    for i,k in enumerate(keys):
        j=i%N;slope=(ys[(j+1)%N]-ys[(j-1)%N])/2
        k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
        k.handle_left=(k.co.x-1/3,k.co.y-slope/3);k.handle_right=(k.co.x+1/3,k.co.y+slope/3)
    c.update()
(OUT/'design.json').write_text(json.dumps({'candidate':a.name,'source':src.name,'period_frames':288,'fps':24,
    'correction':'6 degree right elbow-plane orbit × quintic weight of original negative aim drive; grip-side refit',
    'weight':'smootherstep(clamp((-drive-0.40)/0.45,0,1))','weapon_curve_changes':False,'support_curve_changes':False,
    'records':rows},indent=2))
h.assign(r,a);s.frame_set(191,subframe=.5)
# Reuse the W2 unique live-checkpoint method: the current pathname can be locked.
# Copy the resulting live-saved binary to the owned W3 target after checking it.
checkpoint=OUT/('checkpoint_'+str(time.time_ns())+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(checkpoint),check_existing=False,copy=True)
(OUT/'checkpoint.json').write_text(json.dumps({'checkpoint':str(checkpoint),'target':bpy.data.filepath}))
result={'action':a.name,'modified_curves':8,'corrected_integer_frames':len(rows),
    'max_terminal_center_shift_mm':max(x['terminal_center_shift_m'] for x in rows)*1000,
    'source_and_ready_move_unchanged':True,'study':bpy.data.filepath}
