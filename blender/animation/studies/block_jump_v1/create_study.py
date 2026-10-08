"""Isolated native Blender review. Run with --factory-startup; no source save or export.
Full rigid arms and selected R12 geometry are appended from R14 pass2 and copied.
World displacement belongs to a preview Empty, never Root or the reusable pose clips.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector
OUT=Path(__file__).resolve().parent
SRC=OUT.parents[2]/'characters/player/cuboid/player_combat_strafe_r14_pass2_study.blend'
SOURCE_RIG='R12_Hold_Unarmed_Rig'; SOURCE_MESH='R11_R12_Hold_Unarmed_R9W1_Author_Mesh'
FPS=24; END=104; FRONT=.2; BACK=-2.3; HALF_WIDTH=1.0; HEIGHT=1.0
(OUT/'.validation').mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def mesh_sig(m):
    return hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in m.data.vertices],[tuple(p.vertices) for p in m.data.polygons],[(g.name,g.index) for g in m.vertex_groups],[[tuple(x.uv) for x in l.data] for l in m.data.uv_layers])).encode()).hexdigest()
def rig_sig(r):
    return {b.name: {'matrix':[list(x) for x in b.matrix_local],'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None,'deform':b.use_deform,'connected':b.use_connect} for b in r.data.bones}
source_sha=sha(SRC)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(str(SRC),link=False) as (a,b):b.objects=[SOURCE_RIG,SOURCE_MESH]
source_r,source_m=b.objects
source_geometry=mesh_sig(source_m);source_rest=rig_sig(source_r)
scene=bpy.context.scene;scene.name='BLOCK_JUMP_V1_REVIEW'
rig=source_r.copy();rig.data=source_r.data.copy();rig.animation_data_clear();rig.name='BlockJump_Study_Rig';scene.collection.objects.link(rig)
mesh=source_m.copy();mesh.data=source_m.data.copy();mesh.animation_data_clear();mesh.name='BlockJump_SelectedFullBody';scene.collection.objects.link(mesh)
mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
for md in mesh.modifiers:
    if md.type=='ARMATURE':md.object=rig
for o in [rig,mesh]:o.hide_render=False;o.hide_viewport=False;o.hide_set(False);o.location=(0,0,0);o.rotation_euler=(0,0,0);o.scale=(1,1,1)
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4);p.rotation_mode='QUATERNION'
stage=bpy.data.objects.new('PREVIEW_ONLY_WorldTravel',None);scene.collection.objects.link(stage);rig.parent=stage;rig.matrix_parent_inverse=Matrix.Identity(4)
stage['purpose']='Study world trajectory only; future controller owns displacement. Root is never keyed.'
rig['review_status']='PENDING USER ARTISTIC REVIEW — Blender only'
rig['source_geometry_sha256']=source_geometry
REST={b.name:b.matrix_local.copy() for b in rig.data.bones}
PTS={g.name:[v.co.copy() for v in mesh.data.vertices if any(x.group==g.index and x.weight>.999 for x in v.groups)] for g in mesh.vertex_groups}
def curves(a):return [c for l in a.layers for st in l.strips for cb in st.channelbags for c in cb.fcurves]
APPROVED_INSET={}
source_upper=source_r.animation_data.action
assert source_upper.name=='R12_Hold_Unarmed_Upper'
for side in ['L','R']:
    name='UpperArm.'+side;b=rig.data.bones[name];rest=b.parent.matrix_local.inverted()@b.matrix_local
    expected=rest.to_3x3().inverted()@Vector((.032 if side=='R' else -.032,0,0))
    fc={c.array_index:c for c in curves(source_upper) if c.data_path==f'pose.bones["{name}"].location'}
    observed=Vector(tuple(fc[i].evaluate(1) for i in range(3)))
    assert (observed-expected).length<1e-6,(name,list(observed),list(expected))
    APPROVED_INSET[name]=observed
def assign(o,a):
    o.animation_data_create();o.animation_data.action=a
    if a.slots:o.animation_data.action_slot=a.slots[0]
def smooth(u):u=max(0,min(1,u));return u*u*(3-2*u)
def lerp(a,b,u):return a+(b-a)*smooth(u)
def axis_local(n,angle,axis='X'):
    q=REST[n].to_quaternion().to_matrix().to_4x4()
    return q.inverted()@Matrix.Rotation(angle,4,axis)@q
def leg_gait(t,side):
    p=(t+(8 if side=='R' else 0))%16
    if p<=8:return math.asin((-.25+.0625*p)/.675),0
    u=(p-8)/8;return math.asin(lerp(.25,-.25,u)/.675),.055*math.sin(math.pi*u)**2
def event_angles(t):
    angles={s:leg_gait(t,s) for s in ['L','R']};pitch=math.radians(4.0);arm_factor=.85
    if 18<=t<=32:
        u=(t-18)/14
        start={s:leg_gait(18,s)[0] for s in ['L','R']};end={s:leg_gait(32,s)[0] for s in ['L','R']}
        apex={'L':math.radians(-26),'R':math.radians(17)}
        angles={s:(lerp(start[s],apex[s],u/.55) if u<.55 else lerp(apex[s],end[s],(u-.55)/.45),0) for s in ['L','R']}
        pitch=math.radians(lerp(4,1,u) if u<.7 else lerp(1,7,(u-.7)/.3));arm_factor=.72
    elif 66<=t<=84:
        u=(t-66)/18;start={s:leg_gait(66,s)[0] for s in ['L','R']};end={s:leg_gait(84,s)[0] for s in ['L','R']}
        apex={'L':math.radians(8),'R':math.radians(-23)}
        angles={s:(lerp(start[s],apex[s],u/.55) if u<.55 else lerp(apex[s],end[s],(u-.55)/.45),0) for s in ['L','R']}
        pitch=math.radians(lerp(4,3,u) if u<.7 else lerp(3,8,(u-.7)/.3));arm_factor=.72
    elif 32<t<37:pitch=math.radians(lerp(7,4,(t-32)/5))
    elif 84<t<90:pitch=math.radians(lerp(8,4,(t-84)/6))
    return angles,pitch,arm_factor
def pose(t):
    angles,pitch,arm_factor=event_angles(t)
    values={n:Matrix.Identity(4) for n in REST if n!='Root'}
    minimum=[]
    for side,(a,lift) in angles.items():
        n='Leg.'+side;head=REST[n].translation
        deform=Matrix.Translation(head)@Matrix.Rotation(a,4,'X')@Matrix.Translation(-head)
        minimum.append(min((deform@v).z for v in PTS[n])+lift)
        values[n]=axis_local(n,a)
        if lift:values[n]=REST[n].inverted()@Matrix.Translation((0,0,lift))@REST[n]@values[n]
    # Rigid cuboid legs need a modest pelvis lift for floor clearance; no fake knee/squash.
    hz=-min(minimum)+.001
    values['Hips']=REST['Hips'].inverted()@Matrix.Translation((.009*math.sin(2*math.pi*t/16),0,hz))@REST['Hips']
    values['Spine']=axis_local('Spine',pitch*.45)
    values['Chest']=axis_local('Chest',pitch*.55)
    values['Head']=axis_local('Head',-.5*pitch+math.radians(.7)*math.sin(2*math.pi*(t-1)/16))
    for s,(a,lift) in angles.items():
        n='UpperArm.'+s
        values[n]=Matrix.Translation(APPROVED_INSET[n])@axis_local(n,-a*arm_factor-pitch)@axis_local(n,math.radians(3 if s=='L' else -3),'Y')
        # Connected forearms stay identity: full straight arm/hand silhouette preserved.
    return values
def key_pose(a,f,values):
    assign(rig,a)
    for n,m in values.items():
        p=rig.pose.bones[n];p.matrix_basis=m
        p.keyframe_insert('location',frame=f,group=n);p.keyframe_insert('rotation_quaternion',frame=f,group=n)
def linear(a):
    for c in curves(a):
        for k in c.keyframe_points:k.interpolation='LINEAR'
def clip_poly(poly,axis,edge,keepgreater):
    result=[]
    for i,a in enumerate(poly):
        b=poly[(i+1)%len(poly)];ia=(a[axis]>=edge) if keepgreater else (a[axis]<=edge);ib=(b[axis]>=edge) if keepgreater else (b[axis]<=edge)
        if ia:result.append(a)
        if ia!=ib:result.append(a.lerp(b,(edge-a[axis])/(b[axis]-a[axis])))
    return result
def projected_top_clearance(vertices,polygons):
    lowest=None
    for p in polygons:
        poly=[vertices[i] for i in p.vertices]
        for axis,edge,greater in [(0,-HALF_WIDTH,True),(0,HALF_WIDTH,False),(1,BACK,True),(1,FRONT,False)]:
            if poly:poly=clip_poly(poly,axis,edge,greater)
        if poly:
            z=min(v.z for v in poly);lowest=z if lowest is None else min(z,lowest)
    return lowest
def eval_mesh():
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ob=mesh.evaluated_get(dg);me=ob.to_mesh();verts=[ob.matrix_world@v.co for v in me.vertices];polys=list(me.polygons)
    # Use before to_mesh_clear: callers need min values, no dangling mesh references.
    floor=min(v.z for v in verts);top=projected_top_clearance(verts,polys)
    ob.to_mesh_clear();return floor,top
body=bpy.data.actions.new('STUDY_Body_Continuous_V1');body.use_fake_user=True
body['scope']='Pose-only, full selected actor; no Root, no scale, no world translation.'
for i in range((END-1)*4+1):
    t=i/4;key_pose(body,1+t,pose(t))
linear(body)
for name,start,end in [('BlockJump_Up_V1',16,37),('BlockHop_Down_V1',64,90)]:
    a=bpy.data.actions.new(name);a.use_fake_user=True;a['scope']='POSE ONLY. World arc is separate preview Empty. Pending user review.';a['fps']=FPS;a['event_global_frames']=[start+1,end+1]
    for i in range((end-start)*4+1):key_pose(a,1+i/4,pose(start+i/4))
    linear(a)
assign(rig,body)
travel=bpy.data.actions.new('PREVIEW_ONLY_StudyTravel_V1');assign(stage,travel)
corrections=[]
for i in range((END-1)*4+1):
    t=i/4;f=1+t;scene.frame_set(int(f),subframe=f-int(f))
    if t<18:z=0
    elif t<=32:u=(t-18)/14;z=u+2.8*u*(1-u)
    elif t<73:z=1
    elif t<=84:u=(t-73)/11;z=1-u*u
    else:z=0
    stage.location=(0,2.0-.0625*t,z)
    floor,top=eval_mesh();correction=max(0,-floor,.001+HEIGHT-top if top is not None and top<HEIGHT+.001 else 0)
    if correction:stage.location.z+=correction;corrections.append({'frame':f,'meters':correction})
    stage.keyframe_insert('location',frame=f)
linear(travel)
travel['scope']='PREVIEW ONLY. Authoring platform arc and locomotion; never export as pose animation.'
def mat(name,c):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.8;return m
def box(name,loc,size,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);return o
floor_mat=mat('Study_Ground',(.12,.16,.18));dirt=mat('Study_BlockSide',(.21,.135,.085));grass=mat('Study_BlockTop',(.27,.40,.15));line=mat('Study_MeterMarks',(.26,.32,.34))
box('Ground',(0,-1,-.025),(10,11,.05),floor_mat)
block=box('ONE_METER_REVIEW_BLOCK',(0,(FRONT+BACK)/2,.5),(2*HALF_WIDTH,FRONT-BACK,1),dirt);block.data.materials.append(grass)
for p in block.data.polygons:
    if p.normal.z>.5:p.material_index=1
for y in range(-5,4):box('Ground_meter_'+str(y),(1.65,y,.002),(.16,.012,.003),line)
def camera(name,pos,target,scale):
    d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
gamecam=camera('Gameplay_Oblique_FIXED',(6,-.4,6.3),(0,-1.15,1.05),7.5)
sidecam=camera('Side_Diagnostic_FIXED',(9,-1.2,2.5),(0,-1.2,1.1),7.6)
scene.camera=gamecam
for name,loc,energy,size in [('Key',(3,2,7),1250,5),('Fill',(-4,-2,5),800,5)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;d.normalize=True;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,-1,1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('Study_World');scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.12,.15,.19,1);scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.55
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=16;scene.render.resolution_x=960;scene.render.resolution_y=540;scene.render.resolution_percentage=100;scene.render.fps=FPS;scene.frame_start=1;scene.frame_end=END;scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.film_transparent=False
for f,label in [(1,'RUN IN'),(17,'UP PREP'),(19,'UP TAKEOFF'),(27,'UP APEX'),(33,'UP CONTACT / RECOVER'),(38,'PLATFORM STRIDE'),(65,'DOWN EDGE PREP'),(67,'DOWN UNLOAD'),(74,'DOWN FALL — SHOES CLEAR EDGE'),(85,'DOWN CONTACT'),(91,'RUN OUT')]:scene.timeline_markers.new(label,frame=f)
assert mesh_sig(mesh)==source_geometry
assert rig_sig(rig)==source_rest
assert not any('pose.bones["Root"]' in c.data_path or c.data_path.endswith('scale') for c in curves(body))
samples=[];fail=[]
for i in range((END-1)*4+1):
    f=1+i/4;scene.frame_set(int(f),subframe=f-int(f));floor,top=eval_mesh();gap=top-HEIGHT if top is not None else None
    arm=max(rig.pose.bones['ForeArm.'+s].matrix_basis.to_quaternion().angle for s in ['L','R'])
    inset_error=max((rig.pose.bones[n].matrix_basis.translation-v).length for n,v in APPROVED_INSET.items())
    samples.append({'frame':f,'floor_min_z':floor,'platform_projected_min_z':top,'forearm_local_angle':arm,'shoulder_inset_error':inset_error})
    if floor<-.0001 or (gap is not None and gap<-.0001) or arm>.0001 or inset_error>1e-6:fail.append(samples[-1])
assert not fail,fail[:5]
assert sha(SRC)==source_sha
summary={'status':'PENDING USER ARTISTIC REVIEW','source':str(SRC),'source_sha256':source_sha,'source_rig':SOURCE_RIG,'source_mesh':SOURCE_MESH,'mesh_geometry_weights_uv_sha256':source_geometry,'rest_bone_signature':source_rest,'selected_mesh_signature_preserved':True,'selected_rest_rig_preserved':True,'source_file_unchanged':True,'fps':FPS,'frames':[1,END],'block_height_m':HEIGHT,'block_height_is_authored_test_assumption':True,'pose_actions':['BlockJump_Up_V1','BlockHop_Down_V1',body.name],'preview_travel_action':travel.name,'cameras':[gamecam.name,sidecam.name],'validation':{'quarter_frame_samples':len(samples),'floor_min_z':min(x['floor_min_z'] for x in samples),'platform_min_clearance':min(x['platform_projected_min_z']-HEIGHT for x in samples if x['platform_projected_min_z'] is not None),'max_forearm_angle':max(x['forearm_local_angle'] for x in samples),'failures':len(fail),'collision_check':'Evaluated final mesh polygons clipped to block XY footprint, minimum Z against top; all mesh vertices against floor. No bone-origin-only test.'},'preview_safety_lift':{'max_m':max((x['meters'] for x in corrections),default=0),'affected_samples':len(corrections)}}
(OUT/'study_manifest.json').write_text(json.dumps(summary,indent=2))
summary['approved_shoulders']={'inward_per_side_m':.032,'source_action':source_upper.name,'source_pose_location':{n:list(v) for n,v in APPROVED_INSET.items()},'maximum_authored_pose_translation_error_m':max(x['shoulder_inset_error'] for x in samples)}
(OUT/'study_manifest.json').write_text(json.dumps(summary,indent=2))
(OUT/'.validation/foot_samples.json').write_text(json.dumps(samples))
(OUT/'.validation/travel_safety_lifts.json').write_text(json.dumps(corrections))
for old in [source_m,source_r]:bpy.data.objects.remove(old,do_unlink=True)
scene.frame_set(27);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
    if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'block_jump_v1_review.blend'))
print('BLOCK_JUMP_STUDY_SAVED',json.dumps(summary['validation']),flush=True)
