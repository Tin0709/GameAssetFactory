import bpy,json,math,hashlib,sys
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
BASE=Path(__file__).resolve().parent;OUT=BASE/'reference_study_r1_review'
src=(BASE/'create_ready_e1.py').read_text();exec(src[src.index('def curves('):src.index('def sample(')])
protected=json.loads((OUT/'preservation_before.json').read_text());rig=bpy.data.objects['Player_Cuboid_Rig']
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert all(geometry()[n]==h for n,h in protected['geometry'].items())
assert json.dumps(bones(),sort_keys=True)==json.dumps(protected['bones'],sort_keys=True)
assert hashlib.sha256((BASE/'player_cuboid_weapon_animation_dev.blend').read_bytes()).hexdigest()==protected['weapon_dev_sha256']
rig=bpy.data.objects['R1_Study_Rig'];mesh=bpy.data.objects['R1_Study_Mesh'];scene=bpy.data.scenes['R1_Authoring'];bpy.context.window.scene=scene
points={}
for n in ['Head','Chest','Arm.L','Arm.R','Leg.L','Leg.R']:
    gi=mesh.vertex_groups[n].index
    points[n]=np.array([tuple(v.co) for v in mesh.data.vertices if any(g.group==gi and g.weight>.999 for g in v.groups)])
def sample(action,f):
    rig.animation_data.action=action
    for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
    scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
def box(n,margin=.015):
    ps=points[n];lo=ps.min(0)+margin;hi=ps.max(0)-margin
    if n.startswith('Leg'):hi[2]-=.07 # exclude the intentional rigid hip seam
    m=np.array(rig.pose.bones[n].matrix@rig.data.bones[n].matrix_local.inverted())
    return m[:3,:3]@((lo+hi)/2)+m[:3,3],m[:3,:3],(hi-lo)/2
def overlap(a,b):
    ca,ra,ea=a;cb,rb,eb=b
    axes=[*ra.T,*rb.T]+[np.cross(x,y) for x in ra.T for y in rb.T]
    for ax in axes:
        if np.linalg.norm(ax)<1e-6:continue
        if abs((cb-ca)@ax)>=np.abs(ra.T@ax)@ea+np.abs(rb.T@ax)@eb:return False
    return True
report={'preserved_existing_actions':len(protected['actions']),'original_geometry_weights_bones_unchanged':True,'weapon_development_file_unchanged':True,'gaits':{}}
for gait,period in [('Walk',16),('Sprint',13)]:
    action=bpy.data.actions[gait+'_ReferenceStudy_V1'];feet=[];heads=[];hips=[];hits=[];angle=[];rooterror=0
    for i in range(period*16+1):
        f=1+i/16;sample(action,f)
        bottom=[]
        for n in ['Leg.L','Leg.R']:
            m=np.array(rig.pose.bones[n].matrix@rig.data.bones[n].matrix_local.inverted());p=points[n]@m[:3,:3].T+m[:3,3];bottom.append(float(p[:,2].min()))
        feet.append(bottom);heads.append(list(rig.pose.bones['Head'].matrix.translation));hips.append(list(rig.pose.bones['Hips'].matrix.translation))
        angle.append(math.degrees((rig.pose.bones['Head'].matrix.to_quaternion()@rig.data.bones['Head'].matrix_local.to_quaternion().inverted()).angle))
        rooterror=max(rooterror,max(abs(rig.pose.bones['Root'].matrix_basis[r][c]-(1 if r==c else 0)) for r in range(4) for c in range(4)))
        pairs=[('Arm.L','Chest'),('Arm.R','Chest'),('Arm.L','Head'),('Arm.R','Head'),('Leg.L','Leg.R'),('Leg.L','Chest'),('Leg.R','Chest'),('Head','Chest')]
        for a,b in pairs:
            if overlap(box(a),box(b)):hits.append({'frame':f,'pair':[a,b]})
    seam=max(abs(c.evaluate(1)-c.evaluate(period+1)) for c in curves(action));slopes=[]
    for c in curves(action):
        k,j=c.keyframe_points[0],c.keyframe_points[-1]
        slopes.append(abs((k.handle_right.y-k.co.y)/(k.handle_right.x-k.co.x)-(j.co.y-j.handle_left.y)/(j.co.x-j.handle_left.x)))
    report['gaits'][gait]={'period_frames':period,'seconds':period/24,'samples':len(feet),'min_leg_bottom_m':float(np.min(feet)),
        'minimum_of_both_feet_range_m':[float(np.min(np.min(feet,axis=1))),float(np.max(np.min(feet,axis=1)))],
        'head_vertical_excursion_m':float(np.ptp(np.array(heads)[:,2])),'hips_vertical_excursion_m':float(np.ptp(np.array(hips)[:,2])),
        'head_orientation_from_rest_deg_range':[min(angle),max(angle)],'root_basis_error':rooterror,'endpoint_curve_error':seam,'seam_slope_error':max(slopes),
        'inset_body_box_overlaps':hits,'scale_tracks':sum(c.data_path.endswith('scale') for c in curves(action)),
        'weapon_tracks':sum('WeaponCarrier' in c.data_path for c in curves(action))}
    assert seam<1e-6 and max(slopes)<1e-4 and rooterror<1e-6
    assert np.min(feet)>-.002
    assert not hits, (gait,hits[:3])
preview=bpy.data.scenes['R1_Walk_Sprint_Comparison'];bpy.context.window.scene=preview
preview_error=0.
for f in [1,5,9,13,17,25]:
    preview.frame_set(f);bpy.context.view_layer.update()
    for gait in ['Walk','Sprint']:
        rr=bpy.data.objects['R1_'+gait+'_Rig'];assert rr.animation_data.action_slot is not None
        for c in curves(rr.animation_data.action):
            preview_error=max(preview_error,abs(rr.path_resolve(c.data_path)[c.array_index]-c.evaluate(f)))
assert preview_error<1e-5,preview_error
report['comparison_rig_curve_evaluation_error']=preview_error
bpy.context.window.scene=scene
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print('R1_VALIDATION '+json.dumps(report),flush=True)
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB'
scene.render.resolution_percentage=100
draft='--draft' in sys.argv
for gait,period in [('Walk',16),('Sprint',13)]:
    action=bpy.data.actions[gait+'_ReferenceStudy_V1']
    for view in ['Front','Rear']:
        scene.camera=bpy.data.objects['R1_'+view+'_Study']
        scene.camera.data.ortho_scale=({'Front':2.5,'Rear':2.6} if gait=='Walk' else {'Front':3.0,'Rear':3.1})[view]
        scene.render.resolution_x=322 if view=='Front' else 288;scene.render.resolution_y=538 if view=='Front' else 400
        folder=OUT/(gait.lower()+'_'+view.lower());folder.mkdir(exist_ok=True)
        for i in ([0,period//4,period//2,3*period//4] if draft else range(period)):
            sample(action,1+i);scene.render.filepath=str(folder/('%03d.png'%i));bpy.ops.render.render(write_still=True)
game=bpy.data.scenes['R1_GameplayScale'];bpy.context.window.scene=game
for f in [1,5,9,13]:
    game.frame_set(f);game.render.filepath=str(OUT/('gameplay_scale_f%02d.png'%f));bpy.ops.render.render(write_still=True)
game.frame_set(1);game.render.filepath=str(OUT/'gameplay_scale.png');bpy.ops.render.render(write_still=True)
print('R1_RENDER_DONE',flush=True)
