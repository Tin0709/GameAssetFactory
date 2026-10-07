from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text());baseline=json.loads((OUT/'baseline.json').read_text());fail=[];stats={}
def obb_gap(m1,b1,m2,b2):
    c1=m1@Vector((b1[0]+b1[1])/2);c2=m2@Vector((b2[0]+b2[1])/2)
    a1=[m1.to_3x3().col[i].normalized() for i in range(3)];a2=[m2.to_3x3().col[i].normalized() for i in range(3)]
    e1=(b1[1]-b1[0])/2;e2=(b2[1]-b2[0])/2;axes=a1+a2+[x.cross(y) for x in a1 for y in a2];gaps=[]
    for axis in axes:
        if axis.length<1e-8:continue
        axis.normalize();gaps.append(abs((c2-c1).dot(axis))-sum(e1[i]*abs(a1[i].dot(axis))+e2[i]*abs(a2[i].dot(axis)) for i in range(3)))
    return float(max(gaps))
for n,v in baseline['actions'].items():
    if digest(bpy.data.actions[n])!=v:fail.append('source action changed '+n)
geo=geometry()
for n,v in baseline['geometry'].items():
    if geo[n]!=v:fail.append('source mesh changed '+n)
for n,v in baseline['rigs'].items():
    if json.dumps(bone_signature(bpy.data.objects[n]))!=json.dumps(v):fail.append('source rig changed '+n)
for cat,d in design['categories'].items():
    s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;r=bpy.data.objects[d['rig']];ws=[bpy.data.objects[n] for n in d['weapons']];main=next(w for w in ws if '_Base' in w.name);boxes=boxes_for(r,bpy.data.objects[d['mesh']])
    for mode,name in d['actions'].items():
        a=bpy.data.actions[name];N=PERIOD[mode];row={'straight_angle_max_deg':0,'elbow_gap_max_m':0,'trigger_to_hand_end_max_m':0,'forward_error_max_deg':0,'head_intersections':0,'head_gap_lower_min_m':99,'head_gap_upper_min_m':99,'left_cross_min_m':99,'arm_separation_lower_min_m':99,'left_weapon_gap_lower_min_m':99,'loop_error':0,'samples':2*N+1};first=None;last=None
        if any(any('"'+n+'"' in c.data_path for n in LOWER) or c.data_path.endswith('scale') for c in curves(a)):fail.append(name+' forbidden gait/scale channels')
        for i in range(2*N+1):
            f=1+i/2;sample(r,s,a,f);dg=bpy.context.evaluated_depsgraph_get();gm=r.matrix_world.inverted()@main.evaluated_get(dg).matrix_world
            for side in ['R','L']:
                u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];row['straight_angle_max_deg']=max(row['straight_angle_max_deg'],math.degrees((u.tail-u.head).angle(fo.tail-fo.head)));row['elbow_gap_max_m']=max(row['elbow_gap_max_m'],(u.tail-fo.head).length)
            ch=r.pose.bones['Chest'].matrix.to_3x3();offset=ch@Vector((-GUN_RIGHT[cat],GUN_OFFSET[cat][1],GUN_OFFSET[cat][0]))
            anchor=Vector(tuple(TRIGGER[cat][j]*ATTACHMENT_SCALE[cat]/STUDY_GUN_SCALE[cat][j] for j in range(3)))
            row['trigger_to_hand_end_max_m']=max(row['trigger_to_hand_end_max_m'],(gm@anchor-r.pose.bones['ForeArm.R'].tail-offset).length)
            forward=r.pose.bones['Chest'].matrix.to_3x3()@Vector((0,0,1));row['forward_error_max_deg']=max(row['forward_error_max_deg'],math.degrees(forward.angle(gm.to_3x3()@Vector((0,1,0)))))
            inv=r.pose.bones['Chest'].matrix.inverted();row['left_cross_min_m']=min(row['left_cross_min_m'],(inv@r.pose.bones['UpperArm.L'].head).x-(inv@r.pose.bones['ForeArm.L'].tail).x)
            if i%16==0 or i==2*N:
                contact=triangle_box(r,ws,'Head',boxes['Head']);row['head_intersections']=max(row['head_intersections'],contact['triangles']);row['head_gap_lower_min_m']=min(row['head_gap_lower_min_m'],contact['gap_lower_m']);row['head_gap_upper_min_m']=min(row['head_gap_upper_min_m'],contact['gap_upper_m'])
                row['left_weapon_gap_lower_min_m']=min(row['left_weapon_gap_lower_min_m'],triangle_box(r,ws,'ForeArm.L',TERMINAL)['gap_lower_m'])
                for rn in ['UpperArm.R','ForeArm.R']:
                    for ln in ['UpperArm.L','ForeArm.L']:row['arm_separation_lower_min_m']=min(row['arm_separation_lower_min_m'],obb_gap(r.pose.bones[rn].matrix,boxes[rn],r.pose.bones[ln].matrix,boxes[ln]))
            pose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
            if first is None:first=pose
            last=pose
        row['loop_error']=max(abs(first[n][i][j]-last[n][i][j]) for n in UPPER for i in range(4) for j in range(4))
        row['attachment_alignment_max_m']=row.pop('trigger_to_hand_end_max_m')
        row['anchor_role']='primary grip placement reference after requested resizing'
        row['weapon_scale_xyz']=list(STUDY_GUN_SCALE[cat])
        if cat=='Pistol':
            sample(r,s,a,25);gm=main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world;p=r.matrix_world@r.pose.bones['ForeArm.R'].matrix
            handtop=max((p@Vector((x,y,z))).z for x in [-.1125,.1125] for y in [.1875,.3375] for z in [-.1125,.1125]);row['pistol_slide_above_hand_margin_m']=(gm@Vector((0,.10,.117))).z-handtop
            if row['pistol_slide_above_hand_margin_m']<.025:fail.append(name+' pistol hidden by block hand')
        if cat=='Shotgun':
            sample(r,s,a,25);gm=main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world;p=r.matrix_world@r.pose.bones['ForeArm.R'].matrix
            handtop=max((p@Vector((x,y,z))).z for x in [-.1125,.1125] for y in [.1875,.3375] for z in [-.1125,.1125]);bottom=min((gm@Vector((x,y,.054))).z for x in [-.0375,.0375] for y in [-.034,.237]);row['shotgun_receiver_lower_edge_above_hand_m']=bottom-handtop
            if row['shotgun_receiver_lower_edge_above_hand_m']<.005:fail.append(name+' shotgun receiver buried in hand')
        cross_required=not (cat=='Pistol' and design.get('pistol_one_hand'))
        if row['straight_angle_max_deg']>.08 or row['elbow_gap_max_m']>1e-5 or row['attachment_alignment_max_m']>1e-5 or row['forward_error_max_deg']>.08 or row['head_intersections'] or row['head_gap_lower_min_m']<.025 or row['loop_error']>1e-5 or (cross_required and row['left_cross_min_m']<.15) or row['arm_separation_lower_min_m']<.015 or row['left_weapon_gap_lower_min_m']<.02:fail.append(name+' pose/clearance failed')
        stats[name]=row
# The preview NLA retains the original lower clip and unchanged path Action.
for mode,d in design['showcases'].items():
    for cat,actor in d['actors'].items():
        r=bpy.data.objects[actor['rig']];strips=[st for tr in r.animation_data.nla_tracks for st in tr.strips]
        if d['lower'] and (len(strips)!=1 or strips[0].action.name!=d['lower']):fail.append(mode+cat+' gait composition changed')
        if not d['lower'] and strips:fail.append(mode+cat+' unexpected lower track')
        if mode=='Turn' and r.parent.animation_data.action.name!=design['locomotion']['imported_actions']['PREVIEW_ONLY_R3_Walk_Path']:fail.append(cat+' turn path changed')
for cat,d in design.get('walking',{}).items():
    r=bpy.data.objects[d['actors'][cat]['rig']];strips=[st for tr in r.animation_data.nla_tracks for st in tr.strips]
    if len(strips)!=1 or strips[0].action.name!=design['locomotion']['lower_copies']['Walk'] or strips[0].repeat!=4 or strips[0].scale!=1:fail.append(cat+' individual preview is not original Walk phase')
report={'passed':not fail,'failures':fail,'actions':stats,'walking_preview_gait':'original Walk only, 16-frame gait repeated 4 times','walking_previews':list(design.get('walking',{})),'action_digests':{name:digest(bpy.data.actions[name]) for d in design['categories'].values() for name in d['actions'].values()},'source_actions_preserved':len(baseline['actions']),'source_meshes_preserved':len(baseline['geometry']),'source_rigs_preserved':len(baseline['rigs']),'note':'Straightness and attachment alignment sampled every half-frame. Head/arm separation sampled every 8 frames. Visual similarity requires human review; no claim of pixel identity across different character/weapon assets.'}
(OUT/'validation.json').write_text(json.dumps(report,indent=2));result=report
