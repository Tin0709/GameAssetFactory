"""WH2: arm-only refinement over approved WH1; gun/head/gait unchanged."""
from hold_r10wh1_common import *
import hold_r10wh1_common as wh1
OUT=BASE/'weapon_hold_r10wh2_review'
ARMS=['UpperArm.R','ForeArm.R','UpperArm.L','ForeArm.L']
BACK={'Rifle':(-.065,-.08),'Shotgun':(-.06,-.08),'Pistol':(0,0)}
POLES={'R':(-.08,-.50,.01),'L':(.12,-.44,.04)}
REACH={'Rifle':(.55,.55),'Shotgun':(.55,.55),'Pistol':(.575,.595)}
LEFT_Z={'Rifle':0,'Shotgun':0,'Pistol':0}
LEFT_ROLL={'Rifle':0,'Shotgun':0,'Pistol':30}

def clone_wh2(label,s,category):
    r,m,ws=wh1.clone_r10('WH2_'+label,s,category)
    for ob in list(s.objects):
        if ob.name.startswith('R10WH1_WH2_'):ob.name=ob.name.replace('R10WH1_WH2_','R10WH2_',1)
    return r,m,ws

def matrices(r,side,target,pole,twist):
    u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];sh=u.head.copy();a=u.length;b=fo.length-.075
    delta=target-sh;d=delta.length;assert abs(a-b)+.001<d<a+b-.001,(side,'reach',d)
    axis=delta.normalized();along=(a*a-b*b+d*d)/(2*d);height=math.sqrt(max(0,a*a-along*along))
    v=pole-sh;v=(v-axis*v.dot(axis)).normalized();el=sh+axis*along+v*height;out=[]
    for h,t in [(sh,el),(el,el+(target-el).normalized()*fo.length)]:
        y=(t-h).normalized();x=(twist-y*twist.dot(y)).normalized();z=x.cross(y).normalized();m=Matrix((x,y,z)).transposed().to_4x4();m.translation=h;out.append(m)
    return out

def refine_arms(r,ws,category,drive=0,follow=0):
    ch=r.pose.bones['Chest'].matrix.copy();main=next(w for w in ws if '_Base' in w.name);dg=bpy.context.evaluated_depsgraph_get();inv=r.matrix_world.inverted();gm=inv@main.evaluated_get(dg).matrix_world
    x=(gm.to_3x3()@Vector((1,0,0))).normalized();up=(ch.to_3x3()@Vector((0,1,0))).normalized();fwd=(gm.to_3x3()@Vector((0,1,0))).normalized();scale=gm.to_scale()
    pieces=[]
    for w in ws:
        w.data.calc_loop_triangles();ids=sorted({i for t in w.data.loop_triangles for i in t.vertices});pts=np.array([tuple(w.data.vertices[i].co) for i in ids]);wm=np.array(inv@w.evaluated_get(dg).matrix_world);pieces.append(pts@wm[:3,:3].T+wm[:3,3])
    points=np.concatenate(pieces);center=(TERMINAL[0]+TERMINAL[1])/2;extent=(TERMINAL[1]-TERMINAL[0])/2;rows={}
    for side,index in [('R',0),('L',1)]:
        target=Vector(SETTINGS[category]['right' if side=='R' else 'left']);target.y+=BACK[category][index]
        if side=='L':target.y+=.012*(follow-drive);target.z+=LEFT_Z[category]+.003*math.sin(follow*.5)
        shoulder=r.pose.bones['UpperArm.'+side].head.copy();pole=shoulder+ch.to_3x3()@Vector(POLES[side])
        if side=='L':pole+=ch.to_3x3()@Vector((.015*follow,0,.018*follow))
        twist=x if side=='R' else Quaternion(fwd,math.radians(LEFT_ROLL[category]))@up;wanted_y=target.y
        def place(value):
            target.x=value;target.y=wanted_y;delta=gm@target-shoulder;along=delta.dot(fwd);perp=delta-fwd*along;reach=REACH[category][index]
            if delta.length>reach:
                target.y-=max(0,along-math.sqrt(max(.001,reach**2-perp.length_squared)))/scale.y
            return matrices(r,side,gm@target,pole,twist)
        desired=-.003 if side=='R' else -.0006
        def error(value):
            pair=place(value);m=np.array(pair[1].inverted());v=points@m[:3,:3].T+m[:3,3]-center;return float(np.max(np.abs(v)-extent,axis=1).min())-desired
        grid=np.linspace(-.22,.35,96) if side=='R' else np.linspace(-.35,.03,96)
        values=[(float(v),error(float(v))) for v in grid];brackets=[(values[i],values[i+1]) for i in range(len(values)-1) if values[i][1]*values[i+1][1]<=0]
        assert brackets,(category,side,'no shallow contact bracket',min(values,key=lambda v:abs(v[1])))
        (lo,elo),(hi,ehi)=brackets[-1 if side=='R' else 0]
        for _ in range(14):
            mid=(lo+hi)/2;em=error(mid)
            if elo*em<=0:hi=mid;ehi=em
            else:lo=mid;elo=em
        value=(lo+hi)/2;pair=place(value)
        for n,m in zip(['UpperArm.'+side,'ForeArm.'+side],pair):r.pose.bones[n].matrix=m;bpy.context.view_layer.update()
        actual=triangle_box(r,ws,'ForeArm.'+side,TERMINAL)
        assert abs(actual['signed_vertex_m']-desired)<.00003,(category,side,'candidate/actual contact disagree',actual)
        u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];hand=fo.matrix@Vector((0,.2625,0));el=u.tail
        rows[side]={'contact':actual,'target':list(target),'bend_deg':math.degrees((el-u.head).angle(hand-el)),'forearm_rise_m':(ch.inverted()@hand).y-(ch.inverted()@el).y}
    return rows

def checkpoint():
    p=OUT/('checkpoint_'+str(time.time_ns())+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(p),check_existing=False,copy=True,relative_remap=False);(OUT/'checkpoint.json').write_text(json.dumps({'checkpoint':str(p),'target':bpy.data.filepath}));return str(p)

def validate():
    baseline=json.loads((OUT/'baseline.json').read_text());failures=[];stats={}
    for n,h in baseline['actions'].items():
        if digest(bpy.data.actions[n])!=h:failures.append('Original Action changed: '+n)
    geo=geometry()
    for n,h in baseline['geometry'].items():
        if geo[n]!=h:failures.append('Original geometry/weights changed: '+n)
    for n,h in baseline['rigs'].items():
        if json.dumps(bone_signature(bpy.data.objects[n]))!=json.dumps(h):failures.append('Original rest rig changed: '+n)
    design=json.loads((OUT/'design.json').read_text())
    def signature(a):
        return [(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points],[(m.type,m.mode_before,m.mode_after) for m in c.modifiers if m.type=='CYCLES']) for c in curves(a) if not any('"'+n+'"' in c.data_path for n in ARMS)]
    for cat,d in design['categories'].items():
        s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;r=bpy.data.objects[d['rig']];ws=[bpy.data.objects[n] for n in d['weapons']];main=next(w for w in ws if '_Base' in w.name);inset=boxes_for(r,bpy.data.objects[d['mesh']],.005)
        for mode,name in list(d['actions'].items())+[('Turn',d['turn_action'])]:
            a=bpy.data.actions[name];old=bpy.data.actions[d['baseline_turn'] if mode=='Turn' else d['baseline_actions'][mode]];N=455 if mode=='Turn' else PERIOD[mode]
            if signature(a)!=signature(old):failures.append(name+' changed approved non-arm curves')
            row={'samples':2*N+1,'eye_error_max_m':0,'contact_gap_max_m':0,'left_depth_max_m':0,'right_depth_max_m':0,'head_chest_hits_max':0,'elbow_gap_max_m':0,'scale_error_max':0,'angle_step_max_deg':0,'forearm_rise_min_m':99,'bend_min_deg':99,'weapon_chest_x_max':-99,'left_cross_body_min_m':99};first=None;prev=None;last=None
            for i in range(2*N+1):
                sample(r,s,a,1+i*.5);mw=main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world;eye=r.matrix_world@r.pose.bones['Head'].matrix@EYE;sight=mw@Vector((0,0,SETTINGS[cat]['sight_z']));direction=(mw.to_3x3()@Vector((0,1,0))).normalized();row['eye_error_max_m']=max(row['eye_error_max_m'],(eye-sight).cross(direction).length)
                ch=r.matrix_world@r.pose.bones['Chest'].matrix;row['weapon_chest_x_max']=max(row['weapon_chest_x_max'],(ch.inverted()@mw.translation).x);inv=r.pose.bones['Chest'].matrix.inverted()
                for side,key in [('R','right'),('L','left')]:
                    contact=triangle_box(r,ws,'ForeArm.'+side,TERMINAL);row['contact_gap_max_m']=max(row['contact_gap_max_m'],contact['gap_upper_m']);row[key+'_depth_max_m']=max(row[key+'_depth_max_m'],contact['vertex_depth_m']);u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];hand=fo.matrix@Vector((0,.2625,0));row['forearm_rise_min_m']=min(row['forearm_rise_min_m'],(inv@hand).y-(inv@u.tail).y);row['bend_min_deg']=min(row['bend_min_deg'],math.degrees((u.tail-u.head).angle(hand-u.tail)));row['elbow_gap_max_m']=max(row['elbow_gap_max_m'],(u.tail-fo.head).length)
                    if side=='L':row['left_cross_body_min_m']=min(row['left_cross_body_min_m'],(inv@u.head).x-(inv@hand).x)
                for n in ['Head','Chest']:row['head_chest_hits_max']=max(row['head_chest_hits_max'],triangle_box(r,ws,n,inset[n])['triangles'])
                for p in r.pose.bones:row['scale_error_max']=max(row['scale_error_max'],(p.scale-Vector((1,1,1))).length)
                pose={n:r.pose.bones[n].matrix_basis.copy() for n in ARMS}
                if prev:
                    for n in ARMS:
                        angle=math.degrees(prev[n].to_quaternion().rotation_difference(pose[n].to_quaternion()).angle);row['angle_step_max_deg']=max(row['angle_step_max_deg'],min(angle,360-angle))
                prev=pose;last=pose
                if first is None:first=pose
            row['loop_error']=None if mode=='Turn' else max(abs(first[n][x][y]-last[n][x][y]) for n in ARMS for x in range(4) for y in range(4))
            if row['eye_error_max_m']>.005 or row['weapon_chest_x_max']>-.025 or row['left_cross_body_min_m']<.15:failures.append(name+' lost approved eye/right ownership/cross-body support')
            if row['contact_gap_max_m']>.004 or row['left_depth_max_m']>.003 or row['right_depth_max_m']>.008:failures.append(name+' contact invalid')
            if row['head_chest_hits_max'] or row['elbow_gap_max_m']>1e-5 or row['scale_error_max']>1e-5:failures.append(name+' rig/clearance failed')
            if row['angle_step_max_deg']>8 or (row['loop_error'] or 0)>1e-5:failures.append(name+' motion discontinuity')
            if row['bend_min_deg']<30 or row['forearm_rise_min_m']<.035:failures.append(name+' elbow fold collapses')
            stats[name]=row
    return {'passed':not failures,'failures':failures,'actions':stats,'original_actions':len(baseline['actions']),'original_meshes':len(baseline['geometry']),'original_rigs':len(baseline['rigs']),'note':'Only four arm rotation channels change. Eye and contact are proxies; artistic status awaits review.'}
