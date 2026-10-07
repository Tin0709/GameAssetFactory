"""R9-W4 isolated FK study helpers; reuse the existing rigid rig and previews."""
from living_r9w2_common import *
import time
from mathutils import Euler
OUT=BASE/'living_r9w4_review'
PREFIX={'Rifle':'LongGun','Pistol':'Pistol','Shotgun':'Shotgun'}
PERIOD={'Hold':96,'Move':64,'AimAround':288}
CONFIG={'Rifle':{'support_y':.34,'support_z':.004,'hover_x':.145,'hover_y':-.015,'hover_z':0},
        'Pistol':{'support_y':.035,'support_z':-.202,'hover_x':.195,'hover_y':.035,'hover_z':0},
        'Shotgun':{'support_y':.356,'support_z':-.080,'hover_x':.185,'hover_y':0,'hover_z':.02}}

def clone_actor(label,s,category,assets):
    r,mp=clone2('W4_'+label,s)
    for ob in mp.values():ob.name=ob.name.replace('R9W2_W4_','R9W4_')
    r.name='R9W4_'+label+'_Rig'
    m=next(o for o in mp.values() if o.type=='MESH' and 'Author_Mesh' in o.name)
    if category=='Rifle':weapons=[next(o for o in mp.values() if o.type=='MESH' and 'M4A1_Blocky_Base' in o.name)]
    else:
        mount=next(o for o in mp.values() if 'CarrierMount' in o.name)
        root=next(o for o in mp.values() if 'M4A1_Blocky_Root' in o.name)
        # Remove only this newly cloned gun branch, never any source object.
        branch=[o for o in mp.values() if o==root or o.parent==root]
        for o in branch:bpy.data.objects.remove(o,do_unlink=True)
        remap={}
        for proto in assets[category]:
            ob=proto.copy();ob.name='R9W4_'+label+'_'+proto.name;ob.animation_data_clear();s.collection.objects.link(ob);remap[proto]=ob
        for proto,ob in remap.items():
            if proto.parent in remap:ob.parent=remap[proto.parent]
            elif proto.parent is None:ob.parent=mount;ob.matrix_parent_inverse=Matrix.Identity(4)
        weapons=[o for o in remap.values() if o.type=='MESH']
    return r,m,weapons

def triangle_box(r,weapons,bone,box,region=None):
    """Exact triangle/OBB SAT plus conservative distance bounds in metres."""
    lo,hi=box;center=(lo+hi)/2;extent=(hi-lo)/2;pieces=[]
    inv=(r.matrix_world@r.pose.bones[bone].matrix).inverted()
    for w in weapons:
        w.data.calc_loop_triangles();tri=np.array([tuple(v.co) for v in w.data.vertices])[np.array([tuple(t.vertices) for t in w.data.loop_triangles])]
        if region is not None:tri=tri[region(tri.mean(1))]
        if len(tri):
            mat=np.array(inv@w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world);pieces.append(tri@mat[:3,:3].T+mat[:3,3]-center)
    v=np.concatenate(pieces);e=np.roll(v,-1,axis=1)-v
    axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1)
    norms=np.linalg.norm(axes,axis=2);axes=axes/np.maximum(norms[:,:,None],1e-12)
    proj=np.einsum('ntd,nad->nta',v,axes);reach=np.abs(axes)@extent
    sep=np.maximum(proj.min(1)-reach,-reach-proj.max(1));sep[norms<1e-10]=-np.inf
    gaps=sep.max(1);delta=np.maximum(np.abs(v)-extent,0)
    return {'triangles':int((gaps<=1e-8).sum()),'gap_lower_m':float(max(0,gaps.min())),
            'gap_upper_m':float(np.linalg.norm(delta,axis=2).min()),
            'vertex_depth_m':float(max(0,np.min(extent-np.abs(v),axis=2).max())),
            'signed_vertex_m':float(np.max(np.abs(v)-extent,axis=2).min())}

TERMINAL=(np.array([-.1125,.1875,-.1125]),np.array([.1125,.3375,.1125]))
def configure_pose(r,weapons,socket,category,drive=0,follow=0,breath=0,config=None,fit=True):
    cfg=dict(CONFIG[category] if config is None else config);ch=r.pose.bones['Chest'].matrix.copy()
    yaw=math.radians(14*drive);pitch=math.radians(.6*breath)
    orient=Euler((pitch,yaw,0),'XYZ').to_matrix()@Matrix(((-1,0,0),(0,0,1),(0,1,0)))
    scale=socket.to_scale();rot=orient@Matrix.Diagonal(scale)
    sh={side:ch.inverted()@r.pose.bones['UpperArm.'+side].head for side in ['L','R']}
    ly=cfg['support_y'];lz=cfg['support_z'];rx=cfg['hover_x']+.003*follow;ry=cfg['hover_y']+.005*(follow-drive);rz=cfg['hover_z']
    # Two equal-reach circles choose the forward solution; neither arm collapses
    # while the gun turns. This bakes ordinary FK; it creates no rig constraint.
    def place():
        vL=rot@Vector((0,ly,lz));vR=rot@Vector((rx,ry,rz));height=.24+.003*breath
        centers=[Vector((sh[k].x-v.x,-v.z)) for k,v in [('L',vL),('R',vR)]]
        radii=[math.sqrt(.587**2-(height+v.y-sh[k].y)**2) for k,v in [('L',vL),('R',vR)]]
        delta=centers[1]-centers[0];d=delta.length;axis=delta/d
        assert abs(radii[0]-radii[1])<d<sum(radii),(category,'forward reach circles',d,radii)
        along=(radii[0]**2-radii[1]**2+d*d)/(2*d);hgt=math.sqrt(radii[0]**2-along**2)
        normal=Vector((-axis.y,axis.x));p=centers[0]+axis*along
        p=max([p+normal*hgt,p-normal*hgt],key=lambda x:x.y)
        gm=(ch@rot.to_4x4());gm.translation=ch@Vector((p.x,height,p.y))
        r.pose.bones['WeaponCarrier'].matrix=gm@socket.inverted();bpy.context.view_layer.update()
        for side,target in [('L',Vector((0,ly,lz))),('R',Vector((rx,ry,rz)))]:
            shoulder=r.pose.bones['UpperArm.'+side].head
            # Low, forward elbow plane keeps rigid cuboids long and joined.
            pole=shoulder+ch.to_3x3()@Vector((-.03 if side=='L' else .03,-.30,.28))
            if side=='R':pole+=ch.to_3x3()@Vector((.012*follow,0,-.012*follow))
            arm(r,side,gm@target,pole,gm.to_3x3()@Vector((1,0,0)))
        bpy.context.view_layer.update();return gm
    gm=place()
    if fit:
        # Surface fitting is limited to the primary support height and lateral
        # hover spacing. Reach, lengths, gun scale and rig structure stay fixed.
        for _ in range(20):
            left=triangle_box(r,weapons,'ForeArm.L',TERMINAL)
            right=triangle_box(r,weapons,'ForeArm.R',TERMINAL)
            le=left['signed_vertex_m']-.0008;re=.030-right['gap_lower_m']
            if abs(le)<.0005 and abs(re)<.001:break
            lz+=max(-.008,min(.008,le*.75/scale.z))
            rx+=max(-.008,min(.008,re*.85/scale.x))
            gm=place()
    cfg['support_z']=lz;cfg['hover_x']=rx;cfg['hover_y']=ry
    return {'gun_matrix':gm,'config':cfg,'reach_m':.587}

def save_checkpoint():
    p=OUT/('checkpoint_'+str(time.time_ns())+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(p),check_existing=False,copy=True)
    (OUT/'checkpoint.json').write_text(json.dumps({'checkpoint':str(p),'target':bpy.data.filepath}));return p

def validate_all():
    baseline=json.loads((OUT/'baseline.json').read_text());failures=[]
    for n,value in baseline['actions'].items():
        if digest(bpy.data.actions[n])!=value:failures.append('Original Action altered: '+n)
    geo=geometry()
    for n,value in baseline['geometry'].items():
        if geo[n]!=value:failures.append('Original geometry altered: '+n)
    for n,value in baseline['rigs'].items():
        if json.dumps(bone_signature(bpy.data.objects[n]))!=json.dumps(value):failures.append('Original rig altered: '+n)
    design=json.loads((OUT/'design.json').read_text());rows={}
    for category,data in design['categories'].items():
        s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];m=bpy.data.objects[data['mesh']];weapons=[bpy.data.objects[n] for n in data['weapons']];boxes=boxes_for(r,m);inset=boxes_for(r,m,.005)
        for mode,name in data['actions'].items():
            a=bpy.data.actions[name];stats={'off_terminal_gap_lower_min_m':99,'off_terminal_gap_upper_max_m':0,'off_arm_intersections_max':0,'support_terminal_gap_upper_max_m':0,'arm_reach_min_m':99,'elbow_gap_max_m':0,'head_chest_inset_intersections_max':0,'scale_error_max':0};N=PERIOD[mode]
            paths={c.data_path for c in curves(a)}
            if any(n in p for p in paths for n in ['"Root"','"Hips"','"Leg.L"','"Leg.R"']) or any(p.endswith('scale') for p in paths):failures.append(name+' has forbidden channels')
            if tuple(a.frame_range)!=(1,N+1):failures.append(name+' duration wrong')
            ends=[]
            for i in range(2*N+1):
                f=1+i/2;sample(r,s,a,f)
                off=triangle_box(r,weapons,'ForeArm.R',TERMINAL);support=triangle_box(r,weapons,'ForeArm.L',TERMINAL)
                stats['off_terminal_gap_lower_min_m']=min(stats['off_terminal_gap_lower_min_m'],off['gap_lower_m']);stats['off_terminal_gap_upper_max_m']=max(stats['off_terminal_gap_upper_max_m'],off['gap_upper_m']);stats['support_terminal_gap_upper_max_m']=max(stats['support_terminal_gap_upper_max_m'],support['gap_upper_m'])
                stats['off_arm_intersections_max']=max(stats['off_arm_intersections_max'],triangle_box(r,weapons,'ForeArm.R',boxes['ForeArm.R'])['triangles'],triangle_box(r,weapons,'UpperArm.R',boxes['UpperArm.R'])['triangles'])
                stats['head_chest_inset_intersections_max']=max(stats['head_chest_inset_intersections_max'],triangle_box(r,weapons,'Head',inset['Head'])['triangles'],triangle_box(r,weapons,'Chest',inset['Chest'])['triangles'])
                for side in ['L','R']:
                    u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];stats['elbow_gap_max_m']=max(stats['elbow_gap_max_m'],(u.tail-fo.head).length);stats['arm_reach_min_m']=min(stats['arm_reach_min_m'],(fo.matrix@Vector((0,.2625,0))-u.head).length)
                for p in r.pose.bones:stats['scale_error_max']=max(stats['scale_error_max'],(p.scale-Vector((1,1,1))).length)
                if i in [0,2*N]:ends.append({n:r.pose.bones[n].matrix_basis.copy() for n in UPPER})
            loop=max(abs(ends[0][n][x][y]-ends[1][n][x][y]) for n in UPPER for x in range(4) for y in range(4));stats['loop_error']=loop;stats['samples']=2*N+1
            if stats['off_terminal_gap_lower_min_m']<.020 or stats['off_arm_intersections_max']:failures.append(name+' off arm does not maintain clear separation')
            if stats['off_terminal_gap_upper_max_m']>.10:failures.append(name+' off hand too far from gun')
            if stats['support_terminal_gap_upper_max_m']>.007:failures.append(name+' support block floats')
            if stats['arm_reach_min_m']<.56:failures.append(name+' compact arm silhouette')
            if stats['elbow_gap_max_m']>1e-5 or stats['scale_error_max']>1e-5 or loop>1e-5:failures.append(name+' rig/loop invariant failed')
            if stats['head_chest_inset_intersections_max']:failures.append(name+' head/deep chest contact')
            rows[name]=stats
    return {'passed':not failures,'failures':failures,'actions':rows,'note':'SAT intersection tests and conservative surface-distance bounds; ordered frames and human playback determine artistic readability.'}
