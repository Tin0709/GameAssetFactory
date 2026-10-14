"""Original authoring. Never reads the reference pack or copied animation data."""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Matrix,Vector
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT))
import gaf_mobs_animation_library as lib
SOURCE=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation_v2/zombie_animation_v2.blend')
TARGET=OUT/'Mobs_Animation_Library.blend'
if TARGET.exists():raise RuntimeError('Library exists; preserve it before rebuilding')
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.name='Mobs Animation Library';scene[lib.TAG]=True
scene['mobs_registry']=json.dumps({'schema':1,'mobs':[],'clips':[]})
lib.register()
stage=bpy.data.collections.new('Preview Environment');scene.collection.children.link(stage)
mobs=bpy.data.collections.new('Mobs');scene.collection.children.link(mobs)
zcol=bpy.data.collections.new('MOB_Zombie');mobs.children.link(zcol)
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.objects=['Zombie_Cuboid_Rig','Zombie_Cuboid_Base']
for ob in dst.objects:zcol.objects.link(ob)
rig=bpy.data.objects['Zombie_Cuboid_Rig'];mesh=bpy.data.objects['Zombie_Cuboid_Base']
rig.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_euler=(0,0,0);pb.scale=(1,1,1)
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
lib.register_mob(scene,'Zombie','Zombie',zcol,rig)
scene.mobs_mob='Zombie'

def R(x=0,y=0,z=0):
    return Matrix.Rotation(math.radians(z),4,'Z')@Matrix.Rotation(math.radians(y),4,'Y')@Matrix.Rotation(math.radians(x),4,'X')
def smooth(u):
    u=min(1,max(0,u));return u*u*u*(10+u*(-15+6*u))
def lerp(a,b,u):return a+(b-a)*u
def sin(t):return math.sin(2*math.pi*t)
def hermite5(a,b,va,vb,u):
    # Quintic interpolation with specified endpoint velocities, zero accelerations.
    return a+va*u+(10*(b-a)-6*va-4*vb)*u**3+(-15*(b-a)+8*va+7*vb)*u**4+(6*(b-a)-3*va-3*vb)*u**5

legverts={s:[v.co.copy() for v in mesh.data.vertices if any(mesh.vertex_groups[g.group].name=='Leg.'+s for g in v.groups)] for s in ['L','R']}
def delta_at_sole(side,rotation,center,clearance=.0005):
    rest_center=Vector((rest['Leg.'+side].translation.x,0,0))
    points=[rotation@(v-rest_center) for v in legverts[side]]
    offset=Vector((center[0],center[1],clearance-min(p.z for p in points)))
    return Matrix.Translation(offset)@rotation@Matrix.Translation(-rest_center)

def walk_leg(side,p):
    p=p%1;sign=1 if side=='L' else -1
    yaw=4 if side=='L' else -5;track=.137 if side=='L' else -.134
    D=.64;stride=.728;initial=-.164 if side=='L' else -.157
    entry=-18 if side=='L' else -16.5;exit=20 if side=='L' else 18.5
    rest_x=rest['Leg.'+side].translation.x
    def stance(q):
        u=q/D
        if u<.43:angle=entry*(1-smooth(u/.43));sole_y=.1125
        elif u<=.52:angle=0;sole_y=.1125
        else:angle=exit*smooth((u-.52)/.48);sole_y=-.1125
        rot=R(angle,0,yaw)
        # Heel remains fixed until flat, then the toe becomes the new pivot.
        pivot=Vector((rest_x,sole_y,0))
        anchor=Vector((track,initial+stride*q,.0005))
        if u>.52:anchor+=R(0,0,yaw)@Vector((0,-.225,0))
        return Matrix.Translation(anchor)@rot@Matrix.Translation(-pivot)
    if p<=D:delta=stance(p)
    else:
        u=(p-D)/(1-D);start=stance(D);end=stance(0)
        foot=Vector((rest_x,0,0));a=start@foot;b=end@foot
        angle=lerp(exit,entry,smooth(u))-3.2*math.sin(math.pi*u)**4
        center=(hermite5(a.x,b.x,0,0,u),hermite5(a.y,b.y,stride*(1-D),stride*(1-D),u))
        lift=(.058 if side=='L' else .047)*math.sin(math.pi*u)**4
        delta=delta_at_sole(side,R(angle,0,yaw),center,.0005+lift)
    return delta@rest['Leg.'+side]

def pose_values(kind,t):
    t=t%1;w={'Root':rest['Root'].copy()}
    if kind=='Idle':
        for s in ['L','R']:
            delta=delta_at_sole(s,R(-2.8 if s=='L' else 1.8,0,5 if s=='L' else -7),(.136 if s=='L' else -.133,-.026 if s=='L' else .023))
            w['Leg.'+s]=delta@rest['Leg.'+s]
        hip=Vector((.008*sin(t-.06)+.002*sin(2*t+.1),-.009,.660+.0045*sin(2*t-.12)))
        lean=8.5+1.1*sin(2*t-.10);roll=1.1*sin(t-.10);yaw=-2.5+1.6*sin(t-.13)
        chestlean=lean+.7*sin(2*t-.16)
        head_rot=R(7+1.8*sin(2*t-.21),-2.4+1.1*sin(t-.20),-3.0+4.5*sin(t-.22)+1.2*sin(2*t-.31))
        arm_pitch={'L':-62+2.3*sin(2*t-.18),'R':-49+3.1*sin(2*t-.25)}
    else:
        w['Leg.L']=walk_leg('L',t);w['Leg.R']=walk_leg('R',t-.52)
        tops={s:w['Leg.'+s].translation for s in ['L','R']}
        def load(p):
            p%=1
            if p>.64:return 0
            return smooth(p/.07)*(1-smooth((p-.56)/.08))
        wl=load(t);wr=load(t-.52);total=max(wl+wr,.001)
        support_z=(tops['L'].z*wl+tops['R'].z*wr)/total
        support_y=(tops['L'].y*wl+tops['R'].y*wr)/total
        hip=Vector((.012*sin(t-.09),support_y*.45-.007,support_z-.007))
        lean=10.4+1.1*sin(2*t-.07);roll=1.8*sin(t-.03);yaw=-1.8+2.3*sin(t-.08)
        chestlean=lean+1.2*sin(2*t-.13)
        head_rot=R(8.3+2.4*sin(2*t-.19),-2+1.2*sin(t-.17),-2.8+3.1*sin(t-.19))
        arm_pitch={'L':-65+4.1*sin(t-.16)+1.1*sin(2*t-.14),'R':-52+3.4*sin(t-.24)+1.5*sin(2*t-.23)}
    # Lower torso follows the hips; the rigid chest/head trail the weight shift.
    hdelta=Matrix.Translation(hip)@R(lean*.32,roll*.5,yaw*.4)@Matrix.Translation(-rest['Hips'].translation)
    torso=Matrix.Translation(hip)@R(chestlean,roll,yaw)@Matrix.Translation(-rest['Hips'].translation)
    w['Hips']=hdelta@rest['Hips'];w['Spine']=torso@rest['Spine'];w['Chest']=torso@rest['Chest'];w['Neck']=torso@rest['Neck']
    headpos=torso@rest['Head'].translation
    w['Head']=Matrix.Translation(headpos)@head_rot@rest['Head'].to_3x3().to_4x4()
    for s in ['L','R']:
        shoulder=torso@rest['Arm.'+s].translation
        side=1 if s=='L' else -1
        ar=R(arm_pitch[s],-side*(6 if s=='L' else 8),yaw*.35+side*.8*sin(t-.20))
        w['Arm.'+s]=Matrix.Translation(shoulder)@ar@rest['Arm.'+s].to_3x3().to_4x4()
    values={}
    for pb in rig.pose.bones:
        n=pb.name
        if n=='Root':continue
        basis=(rest[pb.parent.name].inverted()@rest[n]).inverted()@w[pb.parent.name].inverted()@w[n]
        values[n]={'location':tuple(basis.to_translation()),'rotation_euler':tuple(basis.to_euler('XYZ'))}
    return values

rig.animation_data_create()
for kind,N in [('Idle',120),('Walk',42)]:
    action=bpy.data.actions.new('Zombie_'+kind+'_Original_V1');action.use_fake_user=True;rig.animation_data.action=action
    frames=[1+i*.5 for i in range(N*2+1)]
    samples=[pose_values(kind,(f-1)/N) for f in frames]
    eps=1e-5
    derivatives=[]
    for f in frames:
        a=pose_values(kind,(f-1)/N-eps);b=pose_values(kind,(f-1)/N+eps)
        derivatives.append({n:{prop:tuple((b[n][prop][axis]-a[n][prop][axis])/(2*eps*N) for axis in range(3)) for prop in a[n]} for n in a})
    for n in samples[0]:
        for prop in ['location','rotation_euler']:
            for axis in range(3):
                vals=[sample[n][prop][axis] for sample in samples]
                if max(abs(v) for v in vals)<1e-6:continue
                dynamic=max(vals)-min(vals)>1e-6
                curve=action.fcurve_ensure_for_datablock(rig,f'pose.bones["{n}"].{prop}',index=axis,group_name=n)
                use=list(range(len(frames))) if dynamic else [0,len(frames)-1]
                curve.keyframe_points.add(len(use))
                for key,i in zip(curve.keyframe_points,use):
                    f=frames[i];v=vals[i];d=derivatives[i][n][prop][axis] if dynamic else 0
                    key.co=(f,v);key.interpolation='BEZIER';key.handle_left_type='FREE';key.handle_right_type='FREE'
                    span=.5 if dynamic else N
                    key.handle_left=(f-span/3,v-d*span/3);key.handle_right=(f+span/3,v+d*span/3)
                curve.modifiers.new('CYCLES');curve.update()
    action['authoring']='Original independent poses and periodic curves; no third-party keyframe or expression data'
    action['nominal_speed_m_s']=0 if kind=='Idle' else .52
    action['loop_frames']=N;action['closing_key']=N+1;action['fps']=30
    action['contact_notes']='Rigid sole heel-to-flat-to-toe rocking. Offline local compensation. Root is stationary.'
    lib.register_clip(scene,'Zombie',action,1,N,30,action.slots[0])

# Ground and consistent light/cameras. No stage animation or extra mob Actions.
def move_to(ob,col):
    for old in list(ob.users_collection):old.objects.unlink(ob)
    col.objects.link(ob)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.0001))
floor=bpy.context.object;floor.name='Preview Ground';move_to(floor,stage)
mat=bpy.data.materials.new('Preview Ground Matte');mat.diffuse_color=(.105,.135,.16,1);mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=mat.diffuse_color;bs.inputs['Roughness'].default_value=.9
floor.data.materials.append(mat)
def aim(ob,target):ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,color,size in [('Key',(-3,-4,6),650,(1,.89,.76),4),('Fill',(4,-2,3),430,(.70,.83,1),4),('Rim',(1,3,5),780,(.78,.88,1),3)]:
    data=bpy.data.lights.new('Mobs '+name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new('Mobs '+name,data);stage.objects.link(ob);ob.location=loc;aim(ob,(0,0,.9))
for name,loc in [('THREE_QUARTER',(3,-5,2.8)),('FRONT',(0,-6,1.35)),('SIDE',(6,0,1.35))]:
    data=bpy.data.cameras.new('Mobs Camera '+name);data.type='ORTHO';data.ortho_scale=2.75
    ob=bpy.data.objects.new('Mobs Camera '+name,data);stage.objects.link(ob);ob.location=loc;aim(ob,(0,-.06,.88))
scene.camera=bpy.data.objects['Mobs Camera THREE_QUARTER']
world=bpy.data.worlds.new('Mobs Preview World');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.22,.28,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35;scene.world=world
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.render.film_transparent=False
scene.unit_settings.system='METRIC'
scene.mobs_active_index=0;scene.mobs_loop=True;lib.rebuild(scene);lib.activate(scene)
rig.show_in_front=False;rig.hide_render=True
for ob in stage.objects:
    if ob.type in ['LIGHT','CAMERA']:ob.hide_set(True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.show_region_ui=True;space.overlay.show_overlays=False
            space.shading.type='MATERIAL';space.region_3d.view_perspective='CAMERA'
            space.region_3d.view_camera_zoom=8
scene['library_help']='Press N > Mobs Animation Library. Choose Zombie then an Action. Pending until explicit visual approval. Use New Revision Copy to preserve an approved Action.'
text=bpy.data.texts.new('START HERE — Mobs Animation Library')
text.write('MOBS ANIMATION LIBRARY\n\nPress N in the viewport, then select Mobs Animation Library.\nChoose Zombie and click Idle or Walk. Use Play/Pause, Restart and Loop.\nBoth V1 Actions are Pending. Save the file to retain status changes.\n\nDedicated add-on: gaf_mobs_animation_library.py (installed/enabled separately).\nNo embedded Python auto-run is needed.\nNo player or Godot files are part of this library.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print('BUILT',TARGET)
