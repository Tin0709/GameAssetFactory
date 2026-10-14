"""Bake the supplied Bedrock walking clip onto the unchanged native rigid rig."""
import bpy,json,math,sys,ast
from pathlib import Path
from mathutils import Matrix,Vector,Euler
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import gaf_animation_library as lib
NAME='Walk_ActionsStuff_Source_Test_v001';RIG='ASW_Player_Rig_v001';MESH='ASW_Player_Mesh_v001';SCENE='ASW_Walking_Review_v001'
source=json.loads((HERE/'source_walking.animation.json').read_text());clip=source['animation']
assert NAME not in bpy.data.actions and SCENE not in bpy.data.scenes
neutral=json.loads(bpy.data.texts['GAF_Neutral_Pose.json'].as_string())
sc=bpy.data.scenes.new(SCENE);sc.world=bpy.context.scene.world
rig=bpy.data.objects['Showcase_Player_Rig'].copy();rig.name=RIG;rig.animation_data_clear();sc.collection.objects.link(rig)
mesh=bpy.data.objects['Showcase_Player_Mesh'].copy();mesh.name=MESH;mesh.parent=rig;sc.collection.objects.link(mesh)
for modifier in mesh.modifiers:
    if modifier.type=='ARMATURE':modifier.object=rig
rig.hide_render=False;mesh.hide_render=False;rig.hide_set(False);mesh.hide_set(False)
for ob in bpy.context.scene.objects:
    if ob.type in ['CAMERA','LIGHT']:sc.collection.objects.link(ob)
floor=bpy.data.objects['Showcase_FixedFloor'].copy();floor.name='ASW_FixedFloor';floor.location.z=-0.038;sc.collection.objects.link(floor)
sc.camera=bpy.data.objects['Showcase_THREE_QUARTER']
sc.render.engine='CYCLES';sc.cycles.samples=16;sc.cycles.use_denoising=True
sc.render.resolution_x=640;sc.render.resolution_y=640;sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG';sc.render.fps=30;sc.render.fps_base=1
sc.frame_start=1;sc.frame_end=24;sc.use_preview_range=False
sc['review_cameras']=json.dumps({'FRONT':'Showcase_FRONT','SIDE':'Showcase_SIDE','THREE_QUARTER':'Showcase_THREE_QUARTER','BACK':'Showcase_FRONT'})
sc['review_status']='pending';sc['source_animation']=source['animation_id'];sc['cycle_seconds']=0.8
bpy.context.window.scene=sc
for p in rig.pose.bones:
    for key,value in neutral[p.name].items():setattr(p,key,value)
bpy.context.view_layer.update()
rest={p.name:p.bone.matrix_local.copy() for p in rig.pose.bones}
base={p.name:p.matrix.copy() for p in rig.pose.bones}
unit=base['Hips'].translation.z/12
# Bedrock -> Blockbench: rotation(-x,-y,z), position(-x,y,z).
# Match native left/right and front-facing -Y: BB -> native(-x,z,y).
C=Matrix(((-1,0,0),(0,0,1),(0,1,0)));Ci=C.inverted()
fncache={}
def expression(text,p):
    if text not in fncache:
        text2=text.replace('q.anim_time','phase').replace('Math.sin','sind').replace('Math.cos','cosd')
        tree=ast.parse(text2,mode='eval')
        permitted=(ast.Expression,ast.BinOp,ast.UnaryOp,ast.Add,ast.Sub,ast.Mult,ast.Div,ast.USub,ast.UAdd,ast.Constant,ast.Name,ast.Load,ast.Call)
        for node in ast.walk(tree):
            if not isinstance(node,permitted):raise ValueError('Unsupported expression node '+type(node).__name__)
            if isinstance(node,ast.Name) and node.id not in ['phase','sind','cosd']:raise ValueError('Unsupported expression name')
            if isinstance(node,ast.Call) and (not isinstance(node.func,ast.Name) or node.func.id not in ['sind','cosd'] or len(node.args)!=1 or node.keywords):raise ValueError('Unsupported expression call')
        fncache[text]=compile(tree,'<walking-math>','eval')
    return eval(fncache[text],{'__builtins__':{}},{'phase':p,'sind':lambda x:math.sin(math.radians(x)),'cosd':lambda x:math.cos(math.radians(x))})
def channel(bone,key,p):
    value=clip['bones'].get(bone,{}).get(key,[0,0,0])
    if isinstance(value,dict):
        frames=sorted((float(t),v) for t,v in value.items())
        if p<=frames[0][0]:value=frames[0][1]
        elif p>=frames[-1][0]:value=frames[-1][1]
        else:
            for (a,x),(b,y) in zip(frames,frames[1:]):
                if a<=p<=b:
                    w=(p-a)/(b-a);value=[u+(v-u)*w for u,v in zip(x,y)];break
    return [expression(v,p) if isinstance(v,str) else float(v) for v in value]
def transform(bone,p,pivot):
    x,y,z=channel(bone,'rotation',p)
    rotation=(C@Euler(tuple(math.radians(v) for v in (-x,-y,z)),'ZYX').to_matrix()@Ci).to_4x4()
    x,y,z=channel(bone,'position',p);translation=Vector((x,z,y))*unit
    return Matrix.Translation(translation)@Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)
def desired(p):
    d={};I=Matrix.Identity(4)
    waist=transform('waist',p,base['Hips'].translation)
    body=waist@transform('body',p,base['Head'].translation)
    for n in base:d[n]=I@base[n]
    for n in ['Hips','Spine']:d[n]=waist@base[n]
    for n in ['Chest','Neck','WeaponCarrier']:d[n]=body@base[n]
    d['Head']=body@transform('head',p,base['Head'].translation)@base['Head']
    for side,sourcebone in [('L','leftarm'),('R','rightarm')]:
        n='UpperArm.'+side
        # Retain the source's shoulder pivot two model units below the top cap.
        pivot=base[n].translation-Vector((0,0,2*unit))
        arm=body@transform(sourcebone,p,pivot)
        d[n]=arm@base[n];d['ForeArm.'+side]=arm@base['ForeArm.'+side]
        n='Leg.'+side
        # Source legs inherit root, not waist. Solve the native hips parent away.
        d[n]=transform('leftleg' if side=='L' else 'rightleg',p,base[n].translation)@base[n]
    return d
source_phases={0.0,1.0}
for b in clip['bones'].values():
    for v in b.values():
        if isinstance(v,dict):source_phases.update(float(t) for t in v)
# Blender FCurve.update merges keys separated by less than about .01 frame.
# Prioritize original source breakpoints and keep dense samples away from them.
phases=sorted(source_phases|{i/384 for i in range(385) if min(abs(i/384-p) for p in source_phases)>.001})
baked=[];max_scale_error=0;forearm_error=0
for p in phases:
    world=desired(p);row={}
    for bone in rig.data.bones:
        kwargs={} if not bone.parent else {'parent_matrix':world[bone.parent.name],'parent_matrix_local':bone.parent.matrix_local}
        basis=bone.convert_local_to_pose(world[bone.name],bone.matrix_local,invert=True,**kwargs)
        scale=basis.to_scale();max_scale_error=max(max_scale_error,max(abs(v-1) for v in scale))
        if bone.name.startswith('ForeArm.'):
            forearm_error=max(forearm_error,max(abs(basis[i][j]-Matrix.Identity(4)[i][j]) for i in range(4) for j in range(4)))
            basis=Matrix.Identity(4)
        row[bone.name]=basis
    baked.append((1+p*24,row))
assert max_scale_error<2e-6 and forearm_error<2e-6
baked[-1]=(25,{n:m.copy() for n,m in baked[0][1].items()})
a=bpy.data.actions.new(NAME);slot=a.slots.new(id_type='OBJECT',name=rig.name)
bag=a.layers.new('Walking source bake').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
for bone in rig.pose.bones:
    rotation='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler'
    channels={'location':[],'scale':[],rotation:[]};previous=None
    for frame,row in baked:
        loc,q,scale=row[bone.name].decompose()
        if rotation=='rotation_quaternion':
            if previous is not None and q.dot(previous)<0:q.negate()
            val=q;previous=q.copy()
        else:
            val=q.to_euler(bone.rotation_mode,previous) if previous is not None else q.to_euler(bone.rotation_mode);previous=val.copy()
        channels['location'].append(list(loc));channels[rotation].append(list(val));channels['scale'].append([1,1,1])
    for prop,values in channels.items():
        for axis in range(len(values[0])):
            f=bag.fcurves.new(bone.path_from_id(prop),index=axis);f.keyframe_points.add(len(baked))
            f.keyframe_points.foreach_set('co',[v for (frame,_),value in zip(baked,values) for v in (frame,value[axis])])
            for k in f.keyframe_points:k.interpolation='LINEAR'
            f.modifiers.new('CYCLES');f.update()
a.use_fake_user=True;a['review_status']='pending';a['source_animation']=source['animation_id'];a['source_pack_sha256']=source['source_pack_sha256'];a['period_s']=0.8;a['source_phase_bake_rate_hz']=480;a['closing_key']=25
rig.animation_data_create();rig.animation_data.action=a;rig.animation_data.action_slot=slot
sc.frame_set(1);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
for phase,label in [(0,'Cycle start'),(.2222,'Left forward'),(.3889,'Right back'),(.5,'Opposite step'),(.7222,'Right forward'),(1,'Closing key excluded')]:sc.timeline_markers.new(label,frame=round(1+phase*24))
# Record independent expected transforms for fresh-process verification.
expected=[{'phase':p,'frame':1+24*p,'matrices':{n:[list(v) for v in m] for n,m in desired(p).items()}} for p in [i/241 for i in range(242)]]
(HERE/'expected_matrices.json').write_text(json.dumps(expected))
manifest={'action':NAME,'scene':SCENE,'source_rig':RIG,'source_mesh':MESH,'status':'pending','source_animation':source['animation_id'],'source_pack_sha256':source['source_pack_sha256'],'start':1,'end':24,'closing_key':25,'fps':30,'period_s':0.8,'preview_floor_z_m':-0.038,'phase_sample_count':len(baked),'source_model_unit_m':unit,'rig_sha256':lib.rest_signature(rig.data),'action_sha256':lib.action_signature(a),'maximum_basis_scale_error':max_scale_error,'maximum_forearm_identity_error':forearm_error,'adaptations':['Source walking cycle fixed to 0.8 s for preview (normalized forward speed ~0.61035).','Native 1.8 m proportions, shoulder inset and unchanged rest rig retained.','Source shoulder pivot two model units below native shoulder cap.','Source independent leg hierarchy compensated into native hips parent.','No foot locking, smoothing or procedural ground correction added. Preview floor is 38 mm lower to align the original lowest sole excursion.','Source body, arm and leg channels at full forward walking weights; other layers/controllers omitted.']}
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'walk_actions_stuff_review.blend'))
print('WALK_BUILT',json.dumps(manifest))
