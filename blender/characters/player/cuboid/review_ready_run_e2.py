"""Validate and build A/B/C preview scenes in the animation-development file."""
import bpy,json,math,hashlib
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(__file__).resolve().parent
src=(BASE/'create_ready_e1.py').read_text();exec(src[:src.index("assert 'LongGunReady_Loop_V1' not in")])
protected=json.loads((BASE/'ready_run_e2_protection.json').read_text())
run=bpy.data.actions['Player_Run_Blocky_V7_Final']
actions={'A':bpy.data.actions['LongGunHold_V2'],'B':bpy.data.actions['LongGunReady_Loop_V1'],'C':bpy.data.actions['LongGunReady_Run_V1']}
assert all(digest(bpy.data.actions[n])==h for n,h in protected['actions'].items())
assert geometry()==protected['geometry']
assert json.dumps(bones(),sort_keys=True)==json.dumps(protected['bones'],sort_keys=True)
def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
new=actions['C'];first=sample(new,1);last=sample(new,17)
lower_keys={n:sum(len(c.keyframe_points) for c in curves(new) if c.data_path.startswith('pose.bones["'+n+'"]')) for n in LOWER}
seam=max(err(first[n],last[n]) for n in UPPER)
slopes=[]
for c in curves(new):
    a,b=c.keyframe_points[0],c.keyframe_points[-1]
    slopes.append(abs((a.handle_right.y-a.co.y)/(a.handle_right.x-a.co.x)-(b.co.y-b.handle_left.y)/(b.co.x-b.handle_left.x)))
assert not any(lower_keys.values()) and not any(c.data_path.endswith('scale') for c in curves(new))
assert seam<2e-6 and max(slopes)<1e-5

def compose(label,t,phase=0):
    sf=1+((t*1.60+phase)%16)
    base=sample(run,sf)
    f=sf if label=='C' else (1+t%32 if label=='B' else 1)
    overlay=sample(actions[label],f);pose={n:m.copy() for n,m in base.items()}
    for n in ['Spine','Chest','Neck','Head']:pose[n]=base[n]@overlay[n]
    for n in ['Arm.R','Arm.L','WeaponCarrier']:pose[n]=overlay[n]
    apply(pose)
    return {p.name:p.matrix_basis.copy() for p in rig.pose.bones},base

# Same conservative triangle-vs-inset body-box diagnostic used in E1.
e1=(BASE/'review_ready_e1.py').read_text()
exec(e1[e1.index("mesh = bpy.data.objects['Player_Cuboid_Base']"):e1.index('def composed(')])
cache={};measurements={};hits=[];lower_error=0.;grip_error=0.;transition={n:{'position_m':0.,'angle_deg':0.} for n in UPPER}
held=sample(actions['A'],1)
grips={n:rig.pose.bones['WeaponCarrier'].matrix.inverted()@rig.pose.bones[n].matrix for n in ['Arm.R','Arm.L']}
phase_rows=[]
for label in 'ABC':
    centers={n:[] for n in ['Hips','Spine','Chest','WeaponCarrier','Head']}
    rotations={n:[] for n in ['Chest','WeaponCarrier','Head']};poses=[]
    for i in range(641):
        t=i/4;pose,base=compose(label,t)
        lower_error=max(lower_error,max(err(pose[n],base[n]) for n in LOWER))
        if i%4==0:poses.append(pose)
        for n in centers:centers[n].append(list(rig.pose.bones[n].matrix.translation))
        for n in rotations:rotations[n].append(rig.pose.bones[n].matrix.to_quaternion().copy())
        if i%2==0:
            h=collision()
            if any(h.values()):hits.append({'variant':label,'time_frames':t,'counts':h})
        if label=='C':
            for n,g in grips.items():grip_error=max(grip_error,err(rig.pose.bones['WeaponCarrier'].matrix.inverted()@rig.pose.bones[n].matrix,g))
        if label=='C' and i<41:
            world={n:rig.pose.bones[n].matrix.copy() for n in UPPER}
            compose('A',t)
            for n in UPPER:
                old=rig.pose.bones[n].matrix;d=old.to_quaternion().rotation_difference(world[n].to_quaternion()).angle
                transition[n]['position_m']=max(transition[n]['position_m'],(old.translation-world[n].translation).length)
                transition[n]['angle_deg']=max(transition[n]['angle_deg'],math.degrees(min(d,2*math.pi-d)))
    cache[label]=poses
    measurements[label]={'vertical_excursion_m':{n:float(np.ptp(np.array(v)[:,2])) for n,v in centers.items()},
        'rotation_diameter_degrees':{n:max(math.degrees(min(q.rotation_difference(p).angle,2*math.pi-q.rotation_difference(p).angle)) for q in qs[:41] for p in qs[:41]) for n,qs in rotations.items()}}
for phase in [0,4,8,12]:
    maxerr=0.
    for i in range(41):
        pose,_=compose('C',i/4,phase)
        other,_=compose('C',i/4+phase/1.6,0)
        maxerr=max(maxerr,max(err(pose[n],other[n]) for n in UPPER))
    phase_rows.append({'phase':phase,'shared_phase_error':maxerr})
assert lower_error<2e-6 and grip_error<.001
assert not hits,hits[:3]
z=measurements['C']['vertical_excursion_m']
print('E2_HIERARCHY_DIAGNOSTIC '+json.dumps(measurements),flush=True)
assert z['Hips']>z['Chest']>z['WeaponCarrier']>z['Head']>0
report={'action':new.name,'authoring_fps':24,'keys':[1,17],'unique_frames':[1,16],'authoring_seconds':16/24,
    'runtime_cadence':1.60,'runtime_cycle_seconds':16/24/1.6,'animated_bones':UPPER,'lower_keys':lower_keys,'scale_tracks':0,
    'protected_actions_unchanged':list(protected['actions']),'geometry_weights_rest_lengths_hierarchy_unchanged':True,
    'seam_matrix_error':seam,'seam_curve_slope_error':max(slopes),'lower_overlay_error':lower_error,
    'arm_weapon_relative_matrix_error':grip_error,'measurements':measurements,'head_deep_chest_hits':hits,
    'phase_compatibility':phase_rows,'max_composed_difference_from_current_hold':transition,
    'transition_scope':'Compared to composed Run + approved Hold endpoints over all Run phases. Requires blending; does not claim zero mismatch or runtime approval.',
    'preview_scope':'Blender authoring composition, no production Godot modifications. A=Hold V2; B=independent Ready Loop V1; C=phase-locked Ready Run V1.'}
(BASE/'ready_run_e2_validation.json').write_text(json.dumps(report,indent=2))

# Preview baking is clearly named and separate from the upper-only export Action.
# Mesh datablocks remain shared and unedited; source rig hierarchy is untouched.
original_scene=scene
model_objects=[rig,mesh]+list(bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].objects)
copy_source=e1[e1.index('def copy_character('):e1.index("for layer,phase in [('Idle',0)",e1.index('def copy_character('))]
exec(copy_source)
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
q=(D@Matrix.Rotation(math.radians(36.86989764584402),3,'Y')@Matrix.Rotation(math.radians(-36.31588642394517),3,'X')).to_quaternion()
right=q@Vector((1,0,0))
s=bpy.data.scenes.new('E2_Run_ABC_Detail');s.world=original_scene.world;s.render.engine='BLENDER_EEVEE'
s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=160;s.sync_mode='FRAME_DROP'
s.render.resolution_x=1280;s.render.resolution_y=720;s.render.resolution_percentage=100
s['comparison']='A Hold V2 / B Idle Ready Loop V1 / C Run Ready V1; all Run at 1.60x'
s['preview_only']='PREVIEW_ONLY actions include composed Run only for playback; LongGunReady_Run_V1 has no lower-body keys.'
for o in original_scene.objects:
    if o.type=='LIGHT':s.collection.objects.link(o)
for label,side in [('A',-1),('B',0),('C',1)]:
    rr=copy_character(s,label,right*(2.3*side),cache[label],'E2_Run',0)
    for text,zpos,size in [(label+'  '+{'A':'Hold V2','B':'Ready Loop V1','C':'Ready Run V1'}[label],2.10,.14)]:
        font=bpy.data.curves.new('E2_Label','FONT');font.body=text;font.align_x='CENTER';font.size=size
        o=bpy.data.objects.new('E2_'+label+'_Label',font);s.collection.objects.link(o)
        o.location=right*(2.3*side)+Vector((0,0,zpos));o.rotation_euler=q.to_euler()
for name,scale in [('Detail',7.6),('GameplayScale',14.5*1280/720)]:
    c=bpy.data.cameras.new('E2_'+name);c.type='ORTHO';c.ortho_scale=scale
    o=bpy.data.objects.new(c.name,c);s.collection.objects.link(o);o.rotation_euler=q.to_euler();o.location=Vector((0,0,1))+q@Vector((0,0,15))
    if name=='Detail':s.camera=o
s.frame_set(1)
game=s.copy();game.name='E2_Run_ABC_GameplayScale';game.use_fake_user=True;game.camera=next(o for o in game.objects if o.name=='E2_GameplayScale')
readme=bpy.data.texts.new('E2_README');readme.write('PASS 1: LongGunReady_Run_V1 upper only, keys 1..17, 24 FPS base.\nShared phase with Run V7 required.\nE2_Run_ABC_Detail and E2_Run_ABC_GameplayScale scenes: A Hold V2, B Idle Ready Loop V1, C Run Ready V1.\nSpace plays 24 FPS; samples already advance Run and C at 1.60x.\nPREVIEW_ONLY actions are composed playback examples and must never be exported.\nProduction action remains upper only; previous actions unchanged. No Godot integration.\n')
sample(new,1)
bpy.context.window.scene=s
for a in bpy.context.screen.areas:
    if a.type=='VIEW_3D':
        a.spaces.active.overlay.show_overlays=False;a.spaces.active.shading.type='MATERIAL'
        a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.region_3d.view_camera_zoom=20
    if a.type=='DOPESHEET_EDITOR':a.spaces.active.mode='TIMELINE'
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
print('E2_VALIDATED '+json.dumps({'measurements':measurements,'lower_keys':lower_keys,'grip_error':grip_error,'transition':transition}))
