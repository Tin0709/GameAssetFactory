"""Retarget the existing holster motion into an isolated current-hold review."""
from locomotion_sway_r12_common import *

R13OUT=BASE/'weapon_stow_r13_review';R13OUT.mkdir(exist_ok=True)
assert not bpy.data.scenes.get('R13_STOW_REVIEW')
approved=json.loads((R12OUT/'design.json').read_text())
baseline={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'}}
(R13OUT/'baseline.json').write_text(json.dumps(baseline,indent=2))
sc=studio('R13_STOW_REVIEW');sc.render.resolution_x=1800;sc.render.resolution_y=850;sc.render.fps=24;sc.frame_end=108
front=camera(sc,'R13_Front_Camera',(3,-5,3),(0,0,1.1),8.8)
rear=camera(sc,'R13_Back_Camera',(-3,5,3),(0,0,1.1),8.8);sc.camera=rear

# Sample on a temporary copy, leaving the legacy source rig/action untouched.
proto=bpy.data.objects['Player_Cuboid_Rig'];sampler=proto.copy();sampler.data=proto.data.copy();sampler.animation_data_clear();sampler.name='R13_TEMP_SourceSampler';sc.collection.objects.link(sampler)
source=bpy.data.actions['Holster_LongGun_V3_Final'];assign(sampler,source)
for p in sampler.pose.bones:p.matrix_basis=Matrix.Identity(4)
cache={}
for i in range(205):
    f=1+i/12;sc.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    ch=sampler.pose.bones['Chest'].matrix.copy()
    cache[i]={'body':{n:sampler.pose.bones[n].matrix_basis.to_quaternion() for n in ['Spine','Chest','Neck','Head']},
              'arms':{s:sampler.pose.bones['Arm.'+s].matrix_basis.to_quaternion() for s in ['L','R']},
              'weapon':ch.inverted()@sampler.pose.bones['WeaponCarrier'].matrix}
temp_data=sampler.data;bpy.data.objects.remove(sampler,do_unlink=True);bpy.data.armatures.remove(temp_data)

def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
def lerp_matrix(a,b,t):
    pa,qa,sa=a.decompose();pb,qb,sb=b.decompose();q=qa.slerp(qb,t)
    m=(q.to_matrix()@Matrix.Diagonal(sa.lerp(sb,t))).to_4x4();m.translation=pa.lerp(pb,t);return m
def source_at(f):return cache[max(0,min(204,round((f-1)*12)))]
def source_frame(f):
    if f<=12:return 1
    if f<=38:return 1+(f-12)*17/26
    if f<=70:return 18
    if f<=96:return 18-(f-70)*17/26
    return 1

actors={};right=front.rotation_euler.to_quaternion()@Vector((1,0,0))
for i,kind in enumerate(['Pistol','Rifle','Shotgun']):
    # Capture the newest approved hold, including all size/position refinements.
    v=approved['idle'];old_sc=bpy.data.scenes[v['scene']];bpy.context.window.scene=old_sc;old_sc.frame_set(1);bpy.context.view_layer.update()
    old_rig=bpy.data.objects[v['actors'][kind]['rig']]
    start={n:(old_rig.pose.bones[n].location.copy(),old_rig.pose.bones[n].rotation_quaternion.copy()) for n in UPPER}
    bpy.context.window.scene=sc;rig,mesh,ws=new_actor(sc,'Stow',kind,False);rig.name='R13_'+kind+'_Rig'
    assign(rig,None)
    for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4);p.rotation_mode='QUATERNION'
    for n,(l,q) in start.items():rig.pose.bones[n].location=l;rig.pose.bones[n].rotation_quaternion=q
    bpy.context.view_layer.update();main=next(w for w in ws if '_Base' in w.name)
    wm=rig.matrix_world.inverted()@main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
    socket=rig.pose.bones['WeaponCarrier'].matrix.inverted()@wm
    start_gun=rig.pose.bones['Chest'].matrix.inverted()@wm
    grip=wm.inverted()@rig.pose.bones['ForeArm.R'].tail
    scale=wm.to_scale();target_q=(cache[204]['weapon']@socket).to_quaternion()
    target=(target_q.to_matrix()@Matrix.Diagonal(scale)).to_4x4()
    # Keep the resized gun wholly outside the back: align its actual mesh bounds.
    pts=[target@v.co for w in ws for v in w.data.vertices] if len(ws)==1 else [target@(main.matrix_world.inverted()@w.matrix_world@v.co) for w in ws for v in w.data.vertices]
    lo=Vector(tuple(min(p[j] for p in pts) for j in range(3)));hi=Vector(tuple(max(p[j] for p in pts) for j in range(3)))
    target.translation=Vector((-(lo.x+hi.x)/2,.03-(lo.y+hi.y)/2,-.165-hi.z))
    action=bpy.data.actions.new('R13_'+kind+'_Holster_Review');action.use_fake_user=True;assign(rig,action)
    previous={}
    for j in range(217):
        frame=1+j/2;sf=source_frame(frame);src=source_at(sf);blend=smooth((sf-1)/4)
        # Keep approved shoulders and the simple rigid arm shape throughout.
        for n,(l,q) in start.items():rig.pose.bones[n].location=l;rig.pose.bones[n].rotation_quaternion=q
        for n in ['Spine','Chest','Neck','Head']:
            delta=cache[0]['body'][n].inverted()@src['body'][n]
            rig.pose.bones[n].rotation_quaternion=start[n][1]@delta
        for side in ['L','R']:
            p=rig.pose.bones['UpperArm.'+side]
            p.rotation_quaternion=start[p.name][1].slerp(src['arms'][side],blend)
            rig.pose.bones['ForeArm.'+side].rotation_quaternion=(1,0,0,0)
        bpy.context.view_layer.update();ch=rig.pose.bones['Chest'].matrix.copy()
        source_gun=src['weapon']@socket
        gun_q=start_gun.to_quaternion().slerp(source_gun.to_quaternion(),blend)
        gm=(gun_q.to_matrix()@Matrix.Diagonal(scale)).to_4x4()
        hand=ch.inverted()@rig.pose.bones['ForeArm.R'].tail
        gm.translation=hand-gm.to_3x3()@grip
        # Continuous back handoff: hand releases as the gun settles on the back.
        handoff=smooth((sf-13.5)/2.2)
        gm=lerp_matrix(gm,target,handoff)
        rig.pose.bones['WeaponCarrier'].matrix=ch@gm@socket.inverted();bpy.context.view_layer.update()
        for n in UPPER:
            p=rig.pose.bones[n];q=p.rotation_quaternion.copy()
            if n in previous and q.dot(previous[n])<0:q.negate();p.rotation_quaternion=q
            previous[n]=q.copy();p.keyframe_insert('location',frame=frame,group=n);p.keyframe_insert('rotation_quaternion',frame=frame,group=n)
    for fc in curves(action):
        for k in fc.keyframe_points:k.interpolation='LINEAR'
        fc.modifiers.new('CYCLES')
    for f,name in [(12,'HOLSTER_BEGIN'),(20,'LEFT_RELEASE'),(35,'BACK_HANDOFF'),(38,'STOWED'),(70,'REVIEW_RETURN'),(96,'READY')]:action.pose_markers.new(name).frame=f
    action['scope']='Study review only; reverse path is review reset, not production draw';action['source']=source.name
    rig.location=right*((i-1)*2.65)
    actors[kind]={'rig':rig.name,'mesh':mesh.name,'weapons':[w.name for w in ws],'action':action.name,'start':{n:{'location':list(l),'rotation_quaternion':list(q)} for n,(l,q) in start.items()}}

# Rear angle is the default; the companion scene presents the same actors in front.
front_sc=bpy.data.scenes.new('R13_STOW_FRONT_REVIEW');front_sc.world=sc.world
for o in sc.objects:front_sc.collection.objects.link(o)
front_sc.camera=front;front_sc.frame_start=1;front_sc.frame_end=108;front_sc.render.fps=24;front_sc.render.resolution_x=1800;front_sc.render.resolution_y=850
for view,cam in [(sc,rear),(front_sc,front)]:
    for kind,a in actors.items():
        r=bpy.data.objects[a['rig']];x=(cam.matrix_world.inverted()@r.location).x
        label(view,cam,kind.upper(),x)
    for f,name in [(12,'CẤT SÚNG'),(38,'SAU LƯNG'),(70,'TRỞ VỀ ĐỂ LẶP REVIEW')]:view.timeline_markers.new(name,frame=f)
    view.sync_mode='FRAME_DROP';view.frame_set(1)
assert all(digest(bpy.data.actions[n])==h for n,h in baseline['actions'].items())
d={'scope':'Study/dev only; no production migration','source':'Holster_LongGun_V3_Final','source_hold_file':approved['delivery_file'],'scene':sc.name,'front_scene':front_sc.name,'actors':actors,'frames':{'ready':[1,12],'holster':[12,38],'stowed':[38,70],'review_return':[70,96]},'fps':24}
(R13OUT/'design.json').write_text(json.dumps(d,indent=2))
bpy.context.window.scene=sc;sc.frame_set(38)
# The final clearance adaptation follows creation; keep the initial pass for comparison.
p=BASE/'refine_stow_r13_review.py';ns={'__file__':str(p)}
exec(compile(p.read_text(encoding='utf-8'),str(p),'exec'),ns)
result={'scenes':[sc.name,front_sc.name],'actors':list(actors),'frames':d['frames'],'source_preserved':True,'clearance_refinement':True}
