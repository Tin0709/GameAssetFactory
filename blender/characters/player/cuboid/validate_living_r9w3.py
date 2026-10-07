"""Live Blender contact/preservation contract; run RED before V3 authoring."""
from living_r9w2_common import *
OUT=BASE/'living_r9w3_review'
failures=[]
def check(ok,message):
    if not ok:failures.append(message)
name='LongGunAimAround_LeftRight_V3'
if name not in bpy.data.actions:
    result={'passed':False,'failures':['Missing justified V3 contact candidate'],
            'baseline_event_inset_depth_m':.009851940412124893}
    (OUT/'contract_red.json').write_text(json.dumps(result,indent=2))
else:
    baseline=json.loads((OUT/'baseline.json').read_text())
    for n,value in baseline['old_actions'].items():check(digest(bpy.data.actions[n])==value,'Original Action altered: '+n)
    geo=geometry()
    for n,value in baseline['old_geometry'].items():check(geo[n]==value,'Original geometry/weights altered: '+n)
    for n,value in baseline['old_rigs'].items():check(json.dumps(bone_signature(bpy.data.objects[n]))==json.dumps(value),'Original rig altered: '+n)
    old=bpy.data.actions['LongGunAimAround_LeftRight_V2'];new=bpy.data.actions[name]
    allowed={'pose.bones["UpperArm.R"].rotation_quaternion','pose.bones["ForeArm.R"].rotation_quaternion'}
    def signature(c):return (c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points])
    oldcurves={(c.data_path,c.array_index):c for c in curves(old)}
    check(set(oldcurves)=={(c.data_path,c.array_index) for c in curves(new)},'No additional animation tracks')
    for c in curves(new):
        if c.data_path not in allowed:check(signature(c)==signature(oldcurves[(c.data_path,c.array_index)]),'Protected curve altered: '+c.data_path)
    check(tuple(old.frame_range)==tuple(new.frame_range),'Action duration unchanged')
    s=bpy.data.scenes['R9W3_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W3_Probe_Rig'];w=gun(s)
    m=next(o for o in s.objects if o.type=='MESH' and 'Author_Mesh' in o.name)
    boxes=boxes_for(r,m,0);inset=boxes_for(r,m,.005)
    rows=[];poses={};maximum={'shoulder_shift_m':0,'elbow_gap_m':0,'scale_error':0,'left_pose_error':0,'weapon_matrix_error':0,'head_chest_intersections':0}
    def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
    for step in range(577):
        f=1+step/2;pair={};snap={}
        for label,a in [('A',old),('B',new)]:
            sample(r,s,a,f)
            gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
            snap[label]={n:r.pose.bones[n].matrix.copy() for n in ['UpperArm.L','ForeArm.L','Spine','Chest','Neck','Head','WeaponCarrier']};snap[label]['gun']=gm.copy()
            pair[label]={'full_stock':contact(r,w,'UpperArm.R',boxes,lambda t:t[:,1]<-.05),
                'inset_stock':contact(r,w,'UpperArm.R',inset,lambda t:t[:,1]<-.05),
                'right_patch':patch_contact(r,gm,'R'),'left_patch':patch_contact(r,gm,'L'),
                'forearm':contact(r,w,'ForeArm.R',inset)}
            if label=='B':
                maximum['head_chest_intersections']=max(maximum['head_chest_intersections'],contact(r,w,'Head',inset)['triangles'],contact(r,w,'Chest',inset)['triangles'])
                for side in ['R','L']:
                    up=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side]
                    expected=r.data.bones['Chest'].matrix_local.inverted()@r.data.bones['UpperArm.'+side].head_local
                    maximum['shoulder_shift_m']=max(maximum['shoulder_shift_m'],(r.pose.bones['Chest'].matrix.inverted()@up.head-expected).length)
                    maximum['elbow_gap_m']=max(maximum['elbow_gap_m'],(up.tail-fo.head).length)
                for p in r.pose.bones:maximum['scale_error']=max(maximum['scale_error'],(p.scale-Vector((1,1,1))).length)
        maximum['left_pose_error']=max(maximum['left_pose_error'],max(err(snap['A'][n],snap['B'][n]) for n in snap['A'] if n!='gun'))
        maximum['weapon_matrix_error']=max(maximum['weapon_matrix_error'],err(snap['A']['gun'],snap['B']['gun']))
        rows.append({'frame':f,'seconds':(f-1)/24,**pair})
    event=next(x for x in rows if x['frame']==191.5)
    peak={label:max(x[label]['full_stock']['depth_m'] for x in rows) for label in ['A','B']}
    check(event['B']['full_stock']['depth_m']<event['A']['full_stock']['depth_m']*.5,'Reported penetration materially reduced')
    check(peak['B']<peak['A']*.5,'Whole sweep maximum penetration reduced')
    check(max(x['B']['right_patch']['gap_m'] for x in rows)<.002,'No obvious right grip surface separation')
    check(maximum['elbow_gap_m']<1e-5 and maximum['shoulder_shift_m']<1e-5,'Fixed connected shoulder/elbow joints')
    check(maximum['scale_error']<1e-5,'No scaling')
    check(maximum['left_pose_error']<1e-5 and maximum['weapon_matrix_error']<1e-5,'Support/body/head/weapon unchanged')
    check(maximum['head_chest_intersections']==0,'No new head/deep-Chest penetration')
    endpoints={}
    for a in [old,new]:
        values=[]
        for f in [1,289]:
            sample(r,s,a,f);values.append({n:r.pose.bones[n].matrix_basis.copy() for n in UPPER})
        endpoints[a.name]=values
        check(max(err(values[0][n],values[1][n]) for n in UPPER)<1e-5,'Loop endpoint preserved')
    check(max(err(endpoints[old.name][0][n],endpoints[new.name][0][n]) for n in UPPER)<1e-5,'Ready endpoint unchanged')
    result={'passed':not failures,'failures':failures,'samples':len(rows),'event':event,'peak_full_stock_depth_m':peak,'maximum':maximum,
        'right_gap_max_m':max(x['B']['right_patch']['gap_m'] for x in rows),
        'left_gap_max_m':max(x['B']['left_patch']['gap_m'] for x in rows),
        'inset_stock_max_depth_m':max(x['B']['inset_stock']['depth_m'] for x in rows),
        'forearm_inset_max_triangles':max(x['B']['forearm']['triangles'] for x in rows),
        'note':'Sampled rigid-box/triangle and surface-patch evidence; not artistic approval or exact penetration volume.'}
    (OUT/'validation.json').write_text(json.dumps(result,indent=2));(OUT/'comparison_samples.json').write_text(json.dumps(rows,indent=2))
