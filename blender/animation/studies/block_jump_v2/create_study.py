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
FPS=24; END=104; TOTAL=208; FRONT=.2; BACK=-2.3; HALF_WIDTH=1.0; HEIGHT=1.0
(OUT/'.validation').mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def mesh_sig(m):
    return hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in m.data.vertices],[tuple(p.vertices) for p in m.data.polygons],[(g.name,g.index) for g in m.vertex_groups],[[tuple(x.uv) for x in l.data] for l in m.data.uv_layers])).encode()).hexdigest()
def rig_sig(r):
    return {b.name: {'matrix':[list(x) for x in b.matrix_local],'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None,'deform':b.use_deform,'connected':b.use_connect} for b in r.data.bones}
source_sha=sha(SRC)
V1=OUT.parent/'block_jump_v1'
protected_v1={name:sha(V1/name) for name in ['block_jump_v1_review.blend','block_jump_gameplay.mp4','block_jump_side.mp4']}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(str(SRC),link=False) as (a,b):b.objects=[SOURCE_RIG,SOURCE_MESH]
source_r,source_m=b.objects
source_geometry=mesh_sig(source_m);source_rest=rig_sig(source_r)
scene=bpy.context.scene;scene.name='BLOCK_JUMP_V2_REVIEW'
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
def action_sig(a):
    return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
source_upper_hash=action_sig(source_upper)
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
AIR_RATE=.025
def next_extremum(entry):
    # Select from gait phase, rather than selecting anatomical L/R perjump.
    return (math.floor((entry-.5)/8)+1)*8+.5
def catch_phase(entry,target,u):
    # Cubic Hermite: continuity of phase and derivative at entry/plateau.
    u=max(0,min(1,u));h00=2*u**3-3*u**2+1;h10=u**3-2*u**2+u;h01=-2*u**3+3*u**2;h11=u**3-u**2
    return h00*entry+h10*3+h01*target+h11*3*AIR_RATE
def release_progress(u):
    # Integrate a2frame smooth change of stride rate fromAIR_RATE to1.
    return 2*(AIR_RATE*u+(1-AIR_RATE)*(u**3-.5*u**4))
UP_ENTRY=20.0;UP_TARGET=next_extremum(UP_ENTRY)
UP_CONTACT=UP_TARGET+10*AIR_RATE
UP_RELEASED=UP_CONTACT+release_progress(1)
DOWN_ENTRY=UP_RELEASED+(75-33);DOWN_TARGET=next_extremum(DOWN_ENTRY)
DOWN_CONTACT=DOWN_TARGET+8*AIR_RATE
DOWN_RELEASED=DOWN_CONTACT+release_progress(1)
def gait_phase(t):
    if t<18:return t+2
    if t<21:return catch_phase(UP_ENTRY,UP_TARGET,(t-18)/3)
    if t<31:return UP_TARGET+(t-21)*AIR_RATE
    if t<33:return UP_CONTACT+release_progress((t-31)/2)
    if t<75:return UP_RELEASED+t-33
    if t<78:return catch_phase(DOWN_ENTRY,DOWN_TARGET,(t-75)/3)
    if t<86:return DOWN_TARGET+(t-78)*AIR_RATE
    if t<88:return DOWN_CONTACT+release_progress((t-86)/2)
    return DOWN_RELEASED+t-88
def event_angles(t,offset=0):
    phase=gait_phase(t)+offset
    angles={s:leg_gait(phase,s) for s in ['L','R']};pitch=math.radians(1.8);arm_factor=.62
    # Quiet torso: a small short recovery, no large airborne dip or torso roll.
    if 18<=t<31:pitch=math.radians(1.25);arm_factor=.68
    elif 31<=t<34:pitch=math.radians(lerp(2.8,1.8,(t-31)/3))
    elif 75<=t<86:pitch=math.radians(1.3);arm_factor=.68
    elif 86<=t<89:pitch=math.radians(lerp(2.8,1.8,(t-86)/3))
    return angles,pitch,arm_factor
def pose(t,offset=0):
    angles,pitch,arm_factor=event_angles(t,offset)
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
    values['Hips']=REST['Hips'].inverted()@Matrix.Translation((.002*math.sin(2*math.pi*(gait_phase(t)+offset)/16),0,hz))@REST['Hips']
    values['Spine']=axis_local('Spine',pitch*.45)
    values['Chest']=axis_local('Chest',pitch*.55)
    values['Head']=axis_local('Head',-.65*pitch+math.radians(.25)*math.sin(2*math.pi*(gait_phase(t-1)+offset)/16))
    for s,(a,lift) in angles.items():
        n='UpperArm.'+s
        # Unequal forward/down arms follow the same held phase; no outward fan.
        values[n]=Matrix.Translation(APPROVED_INSET[n])@axis_local(n,-a*arm_factor-pitch)
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
body=bpy.data.actions.new('PREVIEW_ONLY_ContinuousJumpReview_V2');body.use_fake_user=True
body['scope']='DEMO ONLY. Custom runin/out provides context; not production Walk/Sprint/Idle. Only jump clips proposed for addition. No Root/scale/worldtranslation.'
for segment,offset in [(0,0),(1,8)]:
    for i in range((END-1)*4+1):
        t=i/4;key_pose(body,1+segment*END+t,pose(t,offset))
linear(body)
clip_names=[]
for offset,label in [(0,''),(8,'_OppositeLead')]:
    for name,start,end in [('BlockJump_Up_V2',16,36),('BlockHop_Down_V2',73,91)]:
        a=bpy.data.actions.new(name+label);a.use_fake_user=True;a['scope']='POSE ONLY. World arc separate. Lead selected from entry gait phase. Pending user review.';a['fps']=FPS;a['entry_phase_offset_frames']=offset;a['event_global_frames']=[start+1,end+1]
        for i in range((end-start)*4+1):key_pose(a,1+i/4,pose(start+i/4,offset))
        linear(a);clip_names.append(a.name)
assign(rig,body)
travel=bpy.data.actions.new('PREVIEW_ONLY_StudyTravel_V2');assign(stage,travel)
corrections=[]
for segment in [0,1]:
    for i in range((END-1)*4+1):
        t=i/4;f=1+segment*END+t;scene.frame_set(int(f),subframe=f-int(f))
        if t<18:z=0
        elif t<=31:u=(t-18)/13;z=u+2.8*u*(1-u)
        elif t<75:z=1
        elif t<=86:u=(t-75)/11;z=1-u*u
        else:z=0
        stage.location=(0,2.0-.0625*t,z)
        floor,top=eval_mesh();correction=max(0,-floor,.001+HEIGHT-top if top is not None and top<HEIGHT+.001 else 0)
        if correction:stage.location.z+=correction;corrections.append({'frame':f,'meters':correction})
        stage.keyframe_insert('location',frame=f)
linear(travel)
# Intentional preview reset between104frame journeys, not a runtime transition.
for a in [body,travel]:
    for c in curves(a):
        for k in c.keyframe_points:
            if abs(k.co.x-END)<1e-5:k.interpolation='CONSTANT'
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
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=16;scene.render.resolution_x=960;scene.render.resolution_y=540;scene.render.resolution_percentage=100;scene.render.fps=FPS;scene.frame_start=1;scene.frame_end=TOTAL;scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.film_transparent=False
for segment,label in [(0,'A'),(1,'B OPPOSITE LEAD')]:
    for f,text in [(1,'RUN IN'),(19,'UP TAKEOFF'),(22,'UP HELD STRIDE'),(27,'UP APEX'),(32,'UP CONTACT / STRIDE RESUME'),(37,'PLATFORM STRIDE'),(76,'DOWN RELEASE — SHOES CLEAR'),(79,'DOWN HELD STRIDE'),(87,'DOWN CONTACT / STRIDE RESUME'),(92,'RUN OUT')]:scene.timeline_markers.new(label+' / '+text,frame=f+segment*END)
assert mesh_sig(mesh)==source_geometry
assert rig_sig(rig)==source_rest
assert not any('pose.bones["Root"]' in c.data_path or c.data_path.endswith('scale') for c in curves(body))
samples=[];fail=[]
for i in range((TOTAL-1)*4+1):
    f=1+i/4;scene.frame_set(int(f),subframe=f-int(f));floor,top=eval_mesh();gap=top-HEIGHT if top is not None else None
    arm=max(rig.pose.bones['ForeArm.'+s].matrix_basis.to_quaternion().angle for s in ['L','R'])
    inset_error=max((rig.pose.bones[n].matrix_basis.translation-v).length for n,v in APPROVED_INSET.items())
    samples.append({'frame':f,'floor_min_z':floor,'platform_projected_min_z':top,'forearm_local_angle':arm,'shoulder_inset_error':inset_error})
    if floor<-.0001 or (gap is not None and gap<-.0001) or arm>.0001 or inset_error>1e-6:fail.append(samples[-1])
assert not fail,fail[:5]
assert sha(SRC)==source_sha
assert all(sha(V1/name)==value for name,value in protected_v1.items())
assert action_sig(source_upper)==source_upper_hash
plateau_samples=[];mirror_error=0
for start,end in [(21,31),(78,86)]:
    for i in range(int((end-start)*4)+1):
        t=start+i/4;aa,_,af=event_angles(t,0);bb,_,_=event_angles(t,8)
        split=abs(math.degrees(aa['L'][0]-aa['R'][0]));assert aa['L'][0]*aa['R'][0]<0 and split>35
        mirror_error=max(mirror_error,abs(aa['L'][0]-bb['R'][0]),abs(aa['R'][0]-bb['L'][0]))
        plateau_samples.append({'time':t,'leg_split_deg':split,'arm_split_deg':split*af})
assert mirror_error<1e-6
summary={'status':'PENDING USER ARTISTIC REVIEW','source':str(SRC),'source_sha256':source_sha,'source_rig':SOURCE_RIG,'source_mesh':SOURCE_MESH,'mesh_geometry_weights_uv_sha256':source_geometry,'rest_bone_signature':source_rest,'selected_mesh_signature_preserved':True,'selected_rest_rig_preserved':True,'source_file_unchanged':True,'protected_v1_sha256':protected_v1,'fps':FPS,'frames':[1,TOTAL],'preview_reset_frame':105,'entry_phase_offsets':[0,8],'gait_extremum_rule':'Nextphase k*8+0.5 from entry;3frame catch then0.025frame/frame drift. No fixed anatomical lead.','plateau_phases':{'up':[UP_TARGET,UP_CONTACT],'down':[DOWN_TARGET,DOWN_CONTACT]},'block_height_m':HEIGHT,'block_height_is_authored_test_assumption':True,'horizontal_preview_speed_mps':1.5,'pose_actions':clip_names+[body.name],'preview_travel_action':travel.name,'cameras':[gamecam.name,sidecam.name],'validation':{'quarter_frame_samples':len(samples),'floor_min_z':min(x['floor_min_z'] for x in samples),'platform_min_clearance':min(x['platform_projected_min_z']-HEIGHT for x in samples if x['platform_projected_min_z'] is not None),'max_forearm_angle':max(x['forearm_local_angle'] for x in samples),'failures':len(fail),'collision_check':'Evaluated final mesh polygons clipped to block XY footprint, minimum Z against top; all mesh vertices against floor. No bone-origin-only test.'},'preview_safety_lift':{'max_m':max((x['meters'] for x in corrections),default=0),'affected_samples':len(corrections)}}
(OUT/'study_manifest.json').write_text(json.dumps(summary,indent=2))
summary['approved_shoulders']={'inward_per_side_m':.032,'source_action':source_upper.name,'source_pose_location':{n:list(v) for n,v in APPROVED_INSET.items()},'maximum_authored_pose_translation_error_m':max(x['shoulder_inset_error'] for x in samples)}
summary['additive_scope']={'only_new_jump_clips_proposed':True,'original_file_and_all_old_animation_bytes_unchanged':True,'loaded_source_hold_action_unchanged':True,'loaded_source_hold_action_sha256':source_upper_hash,'custom_run_in_out_preview_only':True,'preview_body_action':body.name,'no_production_walk_sprint_idle_weapon_combat_updates':True}
summary['airborne_asymmetry_validation']={'plateau_samples':len(plateau_samples),'minimum_leg_foreaft_split_deg':min(x['leg_split_deg'] for x in plateau_samples),'minimum_arm_foreaft_split_deg':min(x['arm_split_deg'] for x in plateau_samples),'maximum_phase8_left_right_swap_angle_error_radians':mirror_error,'strong_opposed_legs_on_all_plateau_samples':True,'offset8_mirrors_entry_selected_lead':True}
(OUT/'.validation/plateau_samples.json').write_text(json.dumps(plateau_samples))
(OUT/'study_manifest.json').write_text(json.dumps(summary,indent=2))
(OUT/'.validation/foot_samples.json').write_text(json.dumps(samples))
(OUT/'.validation/travel_safety_lifts.json').write_text(json.dumps(corrections))
for old in [source_m,source_r]:bpy.data.objects.remove(old,do_unlink=True)
scene.frame_set(27);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
    if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'block_jump_v2_review.blend'))
print('BLOCK_JUMP_STUDY_SAVED',json.dumps(summary['validation']),flush=True)
