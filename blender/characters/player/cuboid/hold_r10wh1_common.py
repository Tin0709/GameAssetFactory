"""New right-owned, right-eye-biased FK studies; original W4 helpers read-only."""
from onearm_r9w4_common import *
OUT=BASE/'weapon_hold_r10wh1_review'
PREFIX={'Rifle':'LongGun','Shotgun':'Shotgun','Pistol':'Pistol'}
EYE=Vector((-.1125,.275,.225))  # right eye on the original head's front face
SETTINGS={'Rifle':{'front':.39,'sight_z':.285,'right':(.10,-.10,-.055),'left':(-.15,-.14,.020)},
          'Shotgun':{'front':.45,'sight_z':.180,'right':(.10,-.16,-.055),'left':(-.15,-.19,.010)},
          'Pistol':{'front':.29,'sight_z':.162,'right':(.10,-.10,-.160),'left':(-.15,-.10,.005)}}

def clone_r10(label,s,category):
    asset_scene=bpy.data.scenes['R9W4_ASSETS'];assets={k:[o for o in asset_scene.objects if o.name.startswith('R9W4_Asset_'+k+'_')] for k in ['Pistol','Shotgun']}
    r,m,ws=clone_actor('R10_'+label,s,category,assets)
    for o in list(s.objects):
        if o.name.startswith('R9W4_R10_'):o.name=o.name.replace('R9W4_R10_','R10WH1_',1)
    return r,m,ws

def body_pose(r,base,phase,drive,follow,breath):
    assign(r,None)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    for n in UPPER:r.pose.bones[n].matrix_basis=base[n].copy()
    for n,angles in [('Spine',(.6*breath,3*drive,.3*breath)),('Chest',(1+.85*breath,12*drive,-.4*drive)),('Neck',(0,1.5*drive,1.0))]:
        # Rebase old carry yaw biases; scanning turns the chest rather than
        # dragging the receiver across the torso away from right ownership.
        r.pose.bones[n].matrix_basis=Euler(tuple(math.radians(x) for x in angles),'XYZ').to_matrix().to_4x4()
    r.pose.bones['Head'].rotation_quaternion=Euler(tuple(math.radians(x) for x in (2.0+.35*breath,5*drive+.8*(drive-follow),3.0+.25*breath)),'XYZ').to_quaternion()
    bpy.context.view_layer.update()

def pose_hold(r,ws,socket,category,drive=0,follow=0,breath=0):
    cfg=SETTINGS[category];ch=r.pose.bones['Chest'].matrix;head=r.pose.bones['Head'].matrix;eye=head@EYE
    fwd=(head.to_3x3()@Vector((0,0,1))).normalized();up=(ch.to_3x3()@Vector((0,1,0))).normalized();x=fwd.cross(up).normalized();up=x.cross(fwd).normalized()
    orient=Matrix((x,fwd,up)).transposed();scale=socket.to_scale();gm=(orient@Matrix.Diagonal(scale)).to_4x4();gm.translation=eye+fwd*cfg['front']-up*(cfg['sight_z']*scale.z)
    r.pose.bones['WeaponCarrier'].matrix=gm@socket.inverted();bpy.context.view_layer.update()
    targets={side:Vector(cfg['right' if side=='R' else 'left']) for side in ['R','L']}
    targets['L'].y+=.012*(follow-drive);targets['L'].z+=.003*math.sin(phase_offset(follow))
    metrics={}
    for side in ['R','L']:
        target=targets[side];shoulder=r.pose.bones['UpperArm.'+side].head.copy()
        pole=shoulder+ch.to_3x3()@Vector((-.10 if side=='R' else .18,-.32 if side=='R' else -.23,.18))
        if side=='L':pole+=ch.to_3x3()@Vector((.015*follow,0,.018*follow))
        twist=x if side=='R' else up
        wanted_y=target.y
        def place_target():
            # Slide the contact control slightly back along the gun if a scan
            # would overextend the existing rigid arm. Gun/eye placement stays
            # fixed; this preserves bone lengths and a soft elbow bend.
            target.y=wanted_y
            delta=gm@target-shoulder;along=delta.dot(fwd);perp=delta-fwd*along
            reach=.575 if side=='R' else .595
            if delta.length>reach:
                limit=math.sqrt(max(.001,reach**2-perp.length_squared));target.y-=max(0,along-limit)/scale.y
            arm(r,side,gm@target,pole,twist)
        desired=-.003 if side=='R' else -.0006
        def error_at(value):
            target.x=value;place_target();return triangle_box(r,ws,'ForeArm.'+side,TERMINAL)['signed_vertex_m']-desired
        # Select the exterior contact root on the anatomically correct side.
        # A bracketed solve handles changing cuboid contact faces without the
        # overshoot of a derivative fit or accumulating reach corrections.
        # Rifle receiver/stock presents a narrow contact interval during the
        # left scan. A coarse grid skipped that interval and selected another
        # surface, causing an abrupt 22 mm support-hand jump.
        grid=np.linspace(-.08,.30,16) if side=='R' else np.linspace(-.35,.03,96 if category=='Rifle' else 16)
        values=[(float(v),error_at(float(v))) for v in grid]
        brackets=[(values[i],values[i+1]) for i in range(len(values)-1) if values[i][1]*values[i+1][1]<=0]
        if brackets:
            (lo,elo),(hi,ehi)=brackets[-1 if side=='R' else 0]
            for _ in range(11):
                mid=(lo+hi)/2;em=error_at(mid)
                if elo*em<=0:hi=mid;ehi=em
                else:lo=mid;elo=em
            target.x=(lo+hi)/2
        else:target.x=min(values,key=lambda v:abs(v[1]))[0]
        place_target()
        targets[side]=target.copy()
        metrics[side]=triangle_box(r,ws,'ForeArm.'+side,TERMINAL)
    sight=gm@Vector((0,0,cfg['sight_z']));direction=(gm.to_3x3()@Vector((0,1,0))).normalized();delta=eye-sight
    return {'right':metrics['R'],'left':metrics['L'],'eye_line_error_m':delta.cross(direction).length,'eye':list(eye),'sight':list(sight),'gun_root':list(gm.translation),'targets':{k:list(v) for k,v in targets.items()}}

def phase_offset(follow):return follow*.5

def checkpoint():
    # The delivery file remains beside the source .blend. Keep its relative
    # asset paths unchanged when saving a temporary checkpoint elsewhere.
    p=OUT/('checkpoint_'+str(time.time_ns())+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(p),check_existing=False,copy=True,relative_remap=False);(OUT/'checkpoint.json').write_text(json.dumps({'checkpoint':str(p),'target':bpy.data.filepath}));return str(p)

def validate_public():
    baseline=json.loads((OUT/'baseline.json').read_text());failures=[]
    for n,d in baseline['actions'].items():
        if digest(bpy.data.actions[n])!=d:failures.append('Original Action changed: '+n)
    geo=geometry()
    for n,d in baseline['geometry'].items():
        if geo[n]!=d:failures.append('Original mesh/weights changed: '+n)
    for n,sig in baseline['rigs'].items():
        if json.dumps(bone_signature(bpy.data.objects[n]))!=json.dumps(sig):failures.append('Original rig changed: '+n)
    design=json.loads((OUT/'design.json').read_text());stats={}
    for category,data in design['categories'].items():
        s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];ws=[bpy.data.objects[n] for n in data['weapons']];base_mesh=next(w for w in ws if '_Base' in w.name);body_mesh=bpy.data.objects[data['mesh']];inset=boxes_for(r,body_mesh,.005)
        for mode,name in list(data['actions'].items())+[('Turn',data['turn_action'])]:
            a=bpy.data.actions[name];N=455 if mode=='Turn' else PERIOD[mode];first=None;last=None;previous=None
            row={'eye_line_error_max_m':0,'right_contact_gap_upper_max_m':0,'left_contact_gap_upper_max_m':0,'right_vertex_depth_max_m':0,'left_vertex_depth_max_m':0,'head_chest_inset_intersections_max':0,'weapon_chest_local_x_max':-99,'left_cross_body_min_m':99,'elbow_gap_max_m':0,'scale_error_max':0,'half_frame_angle_max_deg':0,'samples':2*N+1}
            if any(any('"'+n+'"' in c.data_path for n in LOWER) or c.data_path.endswith('scale') for c in curves(a)):failures.append(name+' modifies lower body/scale')
            for i in range(2*N+1):
                f=1+i/2;sample(r,s,a,f);mw=base_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world;eye=r.matrix_world@r.pose.bones['Head'].matrix@EYE;sight=mw@Vector((0,0,SETTINGS[category]['sight_z']));direction=(mw.to_3x3()@Vector((0,1,0))).normalized();row['eye_line_error_max_m']=max(row['eye_line_error_max_m'],(eye-sight).cross(direction).length)
                for side,key in [('R','right'),('L','left')]:
                    contact=triangle_box(r,ws,'ForeArm.'+side,TERMINAL);row[key+'_contact_gap_upper_max_m']=max(row[key+'_contact_gap_upper_max_m'],contact['gap_upper_m']);row[key+'_vertex_depth_max_m']=max(row[key+'_vertex_depth_max_m'],contact['vertex_depth_m']);u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];row['elbow_gap_max_m']=max(row['elbow_gap_max_m'],(u.tail-fo.head).length)
                ch=r.matrix_world@r.pose.bones['Chest'].matrix;row['weapon_chest_local_x_max']=max(row['weapon_chest_local_x_max'],(ch.inverted()@mw.translation).x);inv_ch=r.pose.bones['Chest'].matrix.inverted();left=inv_ch@r.pose.bones['ForeArm.L'].matrix@Vector((0,.2625,0));shoulder=inv_ch@r.pose.bones['UpperArm.L'].head;row['left_cross_body_min_m']=min(row['left_cross_body_min_m'],shoulder.x-left.x)
                for n in ['Head','Chest']:row['head_chest_inset_intersections_max']=max(row['head_chest_inset_intersections_max'],triangle_box(r,ws,n,inset[n])['triangles'])
                pose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
                for p in r.pose.bones:row['scale_error_max']=max(row['scale_error_max'],(p.scale-Vector((1,1,1))).length)
                if previous:
                    for n in UPPER:
                        angle=math.degrees(previous[n].to_quaternion().rotation_difference(pose[n].to_quaternion()).angle);row['half_frame_angle_max_deg']=max(row['half_frame_angle_max_deg'],min(angle,360-angle))
                previous=pose
                if first is None:first=pose
                last=pose
            row['loop_error']=None if mode=='Turn' else max(abs(first[n][x][y]-last[n][x][y]) for n in UPPER for x in range(4) for y in range(4))
            if row['eye_line_error_max_m']>.005:failures.append(name+' sight line misses actual right-eye proxy')
            if row['weapon_chest_local_x_max']>-.025 or row['left_cross_body_min_m']<.15:failures.append(name+' right ownership/cross-body support lost')
            if row['left_contact_gap_upper_max_m']>.004 or row['right_contact_gap_upper_max_m']>.004:failures.append(name+' contact floats')
            if row['left_vertex_depth_max_m']>.003 or row['right_vertex_depth_max_m']>.008:failures.append(name+' contact too deep for light/primary roles')
            if row['head_chest_inset_intersections_max']:failures.append(name+' deep head/chest intersection')
            if row['half_frame_angle_max_deg']>8 or row['elbow_gap_max_m']>1e-5 or row['scale_error_max']>1e-5 or (row['loop_error'] or 0)>1e-5:failures.append(name+' motion/rig integrity failed')
            stats[name]=row
    return {'passed':not failures,'failures':failures,'actions':stats,'original_actions':len(baseline['actions']),'original_meshes':len(baseline['geometry']),'original_rigs':len(baseline['rigs']),'note':'Right-eye proxy is a point on the existing head face; shallow vertex-depth measurements are contact proxies, not penetration-volume measures. Artistic approval requires viewing the renders.'}
