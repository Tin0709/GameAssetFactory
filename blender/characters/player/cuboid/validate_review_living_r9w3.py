"""Temporal and composed phase evidence for the isolated A/B scenes."""
from living_r9w2_common import *
OUT=BASE/'living_r9w3_review';d=json.loads((OUT/'review.json').read_text());results={};failures=[]
def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
for mode,row in d.items():
    s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s
    a,b=[bpy.data.objects[row['actors'][k]['rig']] for k in ['A','B']]
    maximum={'protected_pose_error':0,'weapon_carrier_world_error':0,'elbow_gap_m':0}
    for f in [1,73,145,175,176,179,187,189,191.5,194,196,211,217,231,244.5,256.5,262,288,289]:
        s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        for n in LOWER+['Spine','Chest','Neck','Head','UpperArm.L','ForeArm.L','WeaponCarrier']:
            maximum['protected_pose_error']=max(maximum['protected_pose_error'],err(a.pose.bones[n].matrix,b.pose.bones[n].matrix))
        for r in [a,b]:
            maximum['elbow_gap_m']=max(maximum['elbow_gap_m'],(r.pose.bones['UpperArm.R'].tail-r.pose.bones['ForeArm.R'].head).length)
        ma=a.matrix_world@a.pose.bones['WeaponCarrier'].matrix;mb=b.matrix_world@b.pose.bones['WeaponCarrier'].matrix
        ma.translation-=Vector(row['actors']['A']['offset']);mb.translation-=Vector(row['actors']['B']['offset'])
        maximum['weapon_carrier_world_error']=max(maximum['weapon_carrier_world_error'],err(ma,mb))
    strips={k:[{'action':st.action.name,'action_frame_start':st.action_frame_start,'action_frame_end':st.action_frame_end,'frame_start':st.frame_start,'frame_end':st.frame_end,'scale':st.scale,'repeat':st.repeat} for tr in r.animation_data.nla_tracks for st in tr.strips] for k,r in [('A',a),('B',b)]}
    if strips['A']!=strips['B']:failures.append(mode+' mismatched lower phase')
    if maximum['protected_pose_error']>1e-5 or maximum['weapon_carrier_world_error']>1e-5:failures.append(mode+' protected pose/path changed')
    results[mode]={'maximum':maximum,'lower_strips':strips}

s=bpy.data.scenes['R9W3_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W3_Probe_Rig']
temporal={};elbows={}
for label,ver in [('A',2),('B',3)]:
    a=bpy.data.actions[f'LongGunAimAround_LeftRight_V{ver}'];qprev=None;prev=None;vel=[];dots=[];samples=[]
    for i in range(1153):
        f=1+i/4;sample(r,s,a,f)
        q=[r.pose.bones[n].rotation_quaternion.normalized().copy() for n in ['UpperArm.R','ForeArm.R']]
        elbow=r.pose.bones['ForeArm.R'].head.copy();samples.append(list(elbow))
        if qprev:
            dots.extend(abs(x.dot(y)) for x,y in zip(qprev,q))
            vel.append((elbow-prev)*96)
        qprev=q;prev=elbow
    acceleration=[(vel[i]-vel[i-1]).length*96 for i in range(1,len(vel))]
    temporal[label]={'quarter_frame_samples':len(samples),'max_elbow_speed_m_s':max(v.length for v in vel),'max_elbow_acceleration_m_s2':max(acceleration),'min_adjacent_quaternion_abs_dot':min(dots)}
    elbows[label]=samples
opposite=max((Vector(a)-Vector(b)).length for a,b in zip(elbows['A'][:577],elbows['B'][:577]))
if opposite>1e-5:failures.append('Unaffected opposite sweep changed')
def slopes(action):
    out={}
    for c in curves(action):
        if 'Arm.R' not in c.data_path:continue
        k0,k1=c.keyframe_points[0],c.keyframe_points[-1]
        out[c.data_path+str(c.array_index)]=[(k0.handle_right.y-k0.co.y)/(k0.handle_right.x-k0.co.x),(k1.co.y-k1.handle_left.y)/(k1.co.x-k1.handle_left.x)]
    return out
loop={str(v):slopes(bpy.data.actions[f'LongGunAimAround_LeftRight_V{v}']) for v in [2,3]}
loop_error=max(abs(loop['2'][n][i]-loop['3'][n][i]) for n in loop['2'] for i in [0,1])
if loop_error>1e-5:failures.append('Loop tangent changed')
result={'passed':not failures,'failures':failures,'composition':results,'temporal':temporal,'opposite_sweep_max_elbow_difference_m':opposite,'loop_tangent_change':loop_error,'inspection':'Dense pose sampling and ordered rendered frames; continuous perceptual playback requires human review.'}
(OUT/'review_validation.json').write_text(json.dumps(result,indent=2))
