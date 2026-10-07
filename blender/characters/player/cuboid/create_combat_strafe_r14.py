"""R14: isolated FK shuffle study; never exports or mutates source Actions."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
from turning_r2_common import curves, assign, camera
OUT=BASE/'combat_strafe_r14_review';OUT.mkdir(exist_ok=True)
PERIOD=20;DIST=.16;FPS=24
UPPER=bpy.data.actions['R12_Hold_Rifle_Upper_Center10']
SOURCE=bpy.data.objects['R12_Hold_Rifle_Rig']
SOURCE_MESH=bpy.data.objects['R11_R12_Hold_Rifle_R9W1_Author_Mesh']
SOURCE_OBS=[o for o in bpy.data.scenes['R12_HOLD_ALL'].objects if 'Hold_Rifle' in o.name]
NAMES=['Hips','Leg.L','Leg.R','Spine']
REST={b.name:b.matrix_local.copy() for b in SOURCE.data.bones}
LEGPTS={n:[v.co.copy() for v in SOURCE_MESH.data.vertices if any(g.group==SOURCE_MESH.vertex_groups[n].index and g.weight>.999 for g in v.groups)] for n in ['Leg.L','Leg.R']}

def ease(u):
    u=max(0,min(1,u));return u*u*u*(10+u*(-15+6*u))

def pose(t,direction):
    t=t%20;sgn=-1 if direction=='Right' else 1
    phase=2*math.pi*t/20
    hx=sgn*.010*math.sin(phase-.35)
    hz=.010+.007*math.cos(2*phase-1.8)
    yaw=sgn*math.radians(2.0)*math.sin(phase)
    lean=sgn*math.radians(1.3+.4*math.sin(phase))
    hm=Matrix.Translation((hx,0,hz))@REST['Hips']
    hm=Matrix.Translation(hm.translation)@Matrix.Rotation(yaw,4,'Z')@Matrix.Rotation(lean,4,'Y')@REST['Hips'].to_quaternion().to_matrix().to_4x4()
    hb=REST['Hips'].inverted()@hm
    values={'Hips':hb}
    # Intentional small balance layer; arms/weapon/Head/Chest retain ready channels.
    delayed=phase-2*math.pi*1.3/20
    values['Spine']=Matrix.Rotation(-sgn*math.radians(1.3)*math.sin(delayed),4,'Y')@Matrix.Rotation(sgn*math.radians(.85+.26*math.sin(delayed)),4,'Z')
    for side in ['R','L']:
        lead=(side=='R')==(direction=='Right');start=0 if lead else 10
        u=(t-start)/7
        advance=ease(u)
        q=(.145 if lead else -.145)+DIST*(advance-t/20)
        # Constant-velocity support stroke, separate 7-frame flights, 3-frame double support.
        clearance=.003+(.038*math.sin(math.pi*u)**2 if 0<u<1 else 0)
        n='Leg.'+side
        head=(hm@REST['Hips'].inverted()@REST[n]).translation
        dx=sgn*q-head.x
        theta=-math.asin(max(-.8,min(.8,dx/(.675*math.cos(yaw)))))
        rot=Matrix.Rotation(yaw,4,'Z')@Matrix.Rotation(theta,4,'Y')@REST[n].to_quaternion().to_matrix().to_4x4()
        lm=Matrix.Translation(head)@rot
        deform=lm@REST[n].inverted()
        lm.translation.z+=clearance-min((deform@v).z for v in LEGPTS[n])
        values[n]=(hm@REST['Hips'].inverted()@REST[n]).inverted()@lm
    return values

def key_values(r,a,f,values):
    assign(r,a)
    for n,mat in values.items():
        p=r.pose.bones[n];p.rotation_mode='QUATERNION';p.matrix_basis=mat
        if n!='Spine':p.keyframe_insert('location',frame=f,group=n)
        p.keyframe_insert('rotation_quaternion',frame=f,group=n)

def bezier(a,periodic=False):
    for c in curves(a):
        ks=c.keyframe_points;count=len(ks)-1;ys=[k.co.y for k in ks]
        for i,k in enumerate(ks):
            step=.5
            if periodic:
                j=i%count;slope=(ys[(j+1)%count]-ys[(j-1)%count])/(2*step)
            elif i==0 or i==count:slope=0
            else:slope=(ys[i+1]-ys[i-1])/(ks[i+1].co.x-ks[i-1].co.x)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-step/3,k.co.y-slope*step/3);k.handle_right=(k.co.x+step/3,k.co.y+slope*step/3)
        if periodic:c.modifiers.new('CYCLES')
        c.update()

def clone(s,label,lower):
    mp={}
    for old in SOURCE_OBS:
        ob=old.copy();ob.name='R14_'+label+'_'+('Body' if old==SOURCE_MESH else 'Rig' if old==SOURCE else old.name.split('Author_')[-1]);ob.animation_data_clear()
        if old.type=='ARMATURE':ob.data=old.data.copy()
        s.collection.objects.link(ob);mp[old]=ob;ob.hide_render=False;ob.hide_viewport=False
    for old,ob in mp.items():
        if old.parent in mp:ob.parent=mp[old.parent]
        for md in ob.modifiers:
            if md.type=='ARMATURE' and md.object in mp:md.object=mp[md.object]
        for c in ob.constraints:
            if hasattr(c,'target') and c.target in mp:c.target=mp[c.target]
    r=mp[SOURCE];r.location=(0,0,0);r.rotation_euler=(0,0,0)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4);p.rotation_mode='QUATERNION'
    r.animation_data_create()
    tr=r.animation_data.nla_tracks.new();tr.name='APPROVED RIFLE READY — unchanged';st=tr.strips.new(UPPER.name,1,UPPER);st.action_slot=UPPER.slots[0];st.repeat=4;st.extrapolation='HOLD';st.blend_type='REPLACE'
    if lower:
        assign(r,lower)
        if lower.name.startswith('PREVIEW_ONLY_R9W4'):
            for n in ['Root','Hips','Leg.L','Leg.R']:r.pose.bones[n].rotation_mode='XYZ'
    stage=bpy.data.objects.new('R14_'+label+'_PreviewTravel',None);s.collection.objects.link(stage);r.parent=stage;r.matrix_parent_inverse=Matrix.Identity(4)
    return r,mp[SOURCE_MESH],stage

def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1);return m
FLOOR=material('R14_Floor',(.075,.09,.12));GRID=material('R14_Grid',(.16,.20,.25));TARGETMAT=material('R14_Target',(.82,.25,.12))

def box(s,name,center,scale,mat):
    vs=[(x,y,z) for x in [-1,1] for y in [-1,1] for z in [-1,1]]
    faces=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],faces);me.materials.append(mat);ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);ob.location=center;ob.scale=scale;return ob

def new_scene(name):
    s=bpy.data.scenes.new(name);bpy.context.window.scene=s;s.world=bpy.data.scenes['R12_HOLD_ALL'].world
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16;s.render.resolution_x=1100;s.render.resolution_y=820;s.render.resolution_percentage=100;s.render.fps=24;s.frame_end=80;s.sync_mode='FRAME_DROP'
    s.view_settings.view_transform='Standard';s.view_settings.look='None'
    for old in bpy.data.scenes['R12_HOLD_ALL'].objects:
        if old.type=='LIGHT':s.collection.objects.link(old)
    box(s,name+'_Ground',(0,0,-.025),(5,5,.025),FLOOR)
    for k in range(-10,11):
        box(s,name+'_GridX',(k*.4,0,.0002),(.003,4,.0003),GRID)
        box(s,name+'_GridY',(0,k*.4,.0002),(4,.003,.0003),GRID)
    # Fixed enemy marker beyond the camera-side ground; the facing axis stays -Y.
    box(s,name+'_EnemyTarget',(0,-3,.7),(.13,.08,.35),TARGETMAT)
    box(s,name+'_EnemyHead',(0,-3,1.17),(.15,.10,.15),TARGETMAT)
    cams={}
    for label,pos,target,scale in [('Gameplay',(3,5,4),(0,0,.75),3.65),('ThreeQuarter',(3,-5,2.7),(0,0,.92),3.4),('Front',(0,-6,1.3),(0,0,.90),3.25),('Side',(6,0,1.6),(0,0,.9),3.15)]:
        cams[label]=camera(s,name+'_'+label,pos,target,scale).name
    s.camera=bpy.data.objects[cams['Gameplay']]
    return s,cams

def blend(a,b,w):
    out={}
    for n in NAMES:
        la,qa,sa=a[n].decompose();lb,qb,sb=b[n].decompose()
        out[n]=Matrix.LocRotScale(la.lerp(lb,w),qa.slerp(qb,w),Vector((1,1,1)))
    return out

assert not bpy.data.actions.get('Combat_StrafeRight_V1')
author,cams=new_scene('R14_B_STRAFE_RIGHT')
rig,mesh,stage=clone(author,'Right',None)
actions={}
for direction in ['Right','Left']:
    a=bpy.data.actions.new('Combat_Strafe'+direction+'_V1');a.use_fake_user=True
    a['scope']='R14 Blender-only study; no root motion or scale. Upper rifle ready stays separate.'
    a['cycle_frames']=20;a['fps']=24;a['leading_flight']='frames 1–8';a['trailing_flight']='frames 11–18';a['preview_speed_mps']=DIST*24/20
    for i in range(41):key_values(rig,a,1+i*.5,pose(i*.5,direction))
    bezier(a,True);actions[direction]=a
assign(rig,actions['Right'])
reviews={'B':{'scene':author.name,'rig':rig.name,'mesh':mesh.name,'stage':stage.name,'cameras':cams,'action':actions['Right'].name}}
for key,title,act in [('A','EXISTING_WALK_SIDEWAYS',bpy.data.actions['PREVIEW_ONLY_R9W4_Walk_LOWER']),('C','STRAFE_LEFT',actions['Left'])]:
    s,cs=new_scene('R14_'+key+'_'+title);r,m,st=clone(s,title,act)
    reviews[key]={'scene':s.name,'rig':r.name,'mesh':m.name,'stage':st.name,'cameras':cs,'action':act.name}
for key,data in reviews.items():
    s=bpy.data.scenes[data['scene']];st=bpy.data.objects[data['stage']]
    for f in [1,81]:
        st.location.x=(1 if key=='C' else -1)*DIST*((f-1)/20-2);st.keyframe_insert('location',frame=f)
    st.animation_data.action.name='PREVIEW_ONLY_R14_'+key+'_LateralTravel'
    for c in curves(st.animation_data.action):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    s.timeline_markers.new('4 CYCLES / 24 FPS',frame=1)

s,cs=new_scene('R14_D_RIGHT_STOP_LEFT_RIGHT');s.frame_end=268
r,m,st=clone(s,'Continuous',None)
a=bpy.data.actions.new('PREVIEW_ONLY_R14_Right_Stop_Left_Right');a.use_fake_user=True
neutral=blend(pose(0,'Right'),pose(0,'Left'),.5)
def sequence(t):
    # Integrate quintic velocity easing so foot clock and world travel agree.
    def integral(u):return 2.5*u**4-3*u**5+u**6
    if t<50:return pose(t,'Right'),-1
    if t<70:
        u=(t-50)/20;return pose(50+20*(u-integral(u)),'Right'),-(1-ease(u))
    if t<82:return blend(pose(0,'Right'),neutral,ease((t-70)/12)),0
    if t<106:return neutral,0
    if t<126:
        u=(t-106)/20;return blend(neutral,pose(20*integral(u),'Left'),ease(u)),ease(u)
    if t<166:return pose(t-116,'Left'),1
    if t<186:
        u=(t-166)/20;return pose(50+20*(u-integral(u)),'Left'),1-ease(u)
    if t<198:return blend(pose(0,'Left'),pose(0,'Right'),ease((t-186)/12)),0
    if t<218:
        u=(t-198)/20;return pose(20*integral(u),'Right'),-ease(u)
    return pose(t-208,'Right'),-1
x=.24;prev=sequence(0)[1]
for i in range(537):
    t=i*.5;vals,speed=sequence(t)
    if i:x+=(prev+speed)*.5*.5*DIST/20
    prev=speed;key_values(r,a,1+t,vals)
    st.location.x=x;st.keyframe_insert('location',frame=1+t)
bezier(a);st.animation_data.action.name='PREVIEW_ONLY_R14_ContinuousTravel';bezier(st.animation_data.action)
for f,label in [(1,'RIGHT'),(51,'BRAKE'),(83,'STOP'),(107,'LEFT'),(167,'BRAKE / REVERSE'),(187,'LEFT → RIGHT'),(199,'RIGHT')]:s.timeline_markers.new(label,frame=f)
reviews['D']={'scene':s.name,'rig':r.name,'mesh':m.name,'stage':st.name,'cameras':cs,'action':a.name}
(OUT/'design.json').write_text(json.dumps({'period':20,'fps':24,'step_distance_m':DIST,'reviews':reviews},indent=2))
for data in reviews.values():bpy.data.scenes[data['scene']].frame_set(1)
bpy.context.window.scene=bpy.data.scenes[reviews['D']['scene']]
result={'actions':[a.name for a in actions.values()],'scenes':reviews}
