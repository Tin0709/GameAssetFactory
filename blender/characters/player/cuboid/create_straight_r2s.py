"""R2-S: two first-pass V2 straight gaits; protected V1 and turning data untouched."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'straight_study_r2s_review';OUT.mkdir(exist_ok=True)
DEV=BASE/'player_locomotion_straight_v2_study.blend';assert Path(bpy.data.filepath)==DEV
revise=globals().get('REVISE_R2S',False)
if not revise:
    assert all(g+'_ReferenceStudy_V2' not in bpy.data.actions for g in PERIOD)
    protected=preserve();protected['files']['player_locomotion_turning_study.blend']=hashlib.sha256((BASE/'player_locomotion_turning_study.blend').read_bytes()).hexdigest()
    (OUT/'preservation_before.json').write_text(json.dumps(protected,indent=2))
    s=bpy.data.scenes.new('R2S_Authoring');s.use_fake_user=True;bpy.context.window.scene=s;r,mesh=copy_character(s,'StraightV2_Author')
else:
    protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected)
    s=bpy.data.scenes['R2S_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_StraightV2_Author_Rig'];mesh=bpy.data.objects['R2_StraightV2_Author_Mesh']
pts=mesh_points(mesh)
def cyc(values,t):
    x=(t%1)*len(values);i=int(x);u=x-i;n=len(values)
    p0,p1,p2,p3=[values[j%n] for j in [i-1,i,i+1,i+2]]
    return .5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)
def authored_pose(t,fast):
    assign(r,None)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    def rot(n,x=0,y=0,z=0):r.pose.bones[n].rotation_euler=tuple(map(math.radians,(x,y,z)))
    yaw=cyc([1,.85,.1,-.65,-1,-.85,-.1,.65],t)
    roll=cyc([-.1,-.7,-1,-.55,.1,.7,1,.55],t)
    weight=cyc([0,-.5,-1,-.7,0,.5,1,.7],t)
    down=cyc([.2,1,.55,-.45,-.8,-.35,.05,.2],2*t)
    rot('Hips', (2.2 if fast else 1.2)+.5*down,(4.2 if fast else 2.9)*yaw,(3.4 if fast else 2.4)*roll)
    r.pose.bones['Hips'].location.x=(.018 if fast else .014)*weight
    rot('Spine',(6.4 if fast else 2.7)+(1.3 if fast else .8)*down,-(3.2 if fast else 2.4)*cyc([1,.85,.1,-.65,-1,-.85,-.1,.65],t-.022),-(1.2 if fast else .8)*cyc([-.1,-.7,-1,-.55,.1,.7,1,.55],t-.035))
    rot('Chest',(2 if fast else 1)+(1 if fast else .5)*cyc([.2,1,.55,-.45,-.8,-.35,.05,.2],2*t-.12),-(3.8 if fast else 2.7)*cyc([1,.85,.1,-.65,-1,-.85,-.1,.65],t-.055),-.65*cyc([-.1,-.7,-1,-.55,.1,.7,1,.55],t+.015))
    for side,shift,sign in [('R',0,-1),('L',.5,1)]:
        p=(t+shift)%1
        leg=cyc([35,12,-14,-48,-77,-57,-4,33] if fast else [24,10,-8,-29,-59,-42,-6,22],p)
        rot('Leg.'+side,leg,0,sign*.8)
        lift=cyc([0,.018,.028,.012,.004,.012,.025,.034,.030,.027,.018,.008,.008,.016,.023,.008],p)*(1.15 if fast else 1)
        gather=max(0,cyc([0,0,0,.35,1,.7,.2,0],p))
        # The rigid thigh's upper rear corner rises during recovery. Route its root
        # down/back at the deepest fold, retaining the lift around passing.
        r.pose.bones['Leg.'+side].location=(0,-max(0,lift)*(1-min(1,gather))+(.055 if fast else .020)*gather,-.010*gather)
        arm=cyc([-39,-33,10,68,79,42,-22,-42] if fast else [-28,-23,5,47,56,26,-15,-32],p)
        forward=max(0,min(1,(arm-12)/(67 if fast else 44)))
        arm+=(1.0 if side=='R' else -1.4)*forward
        twist=(19 if side=='R' else 18) if fast else (18 if side=='R' else 16)
        rot('Arm.'+side,arm,sign*twist*forward**1.3,sign*(1.7-(5.7 if fast else 8)*forward**2))
        r.pose.bones['Arm.'+side].location=(-sign*(.040 if fast else .024)*forward**2,0,.024*forward**2)
    bpy.context.view_layer.update()
    delta=r.pose.bones['Chest'].matrix.to_quaternion()@r.data.bones['Chest'].matrix_local.to_quaternion().inverted()
    for n,retained in [('Neck',.48),('Head',.24)]:
        p=r.pose.bones[n];m=(Quaternion().slerp(delta,retained)@r.data.bones[n].matrix_local.to_quaternion()).to_matrix().to_4x4();m.translation=p.matrix.translation;p.matrix=m;bpy.context.view_layer.update()
    clearance=cyc([.006,.004,.010,.020,.030,.065,.095,.030] if fast else [.006,.004,.008,.010,.016,.038,.058,.020],2*t)
    r.pose.bones['Hips'].location.y+=max(.004,clearance)-floor_min(r,pts)
    bpy.context.view_layer.update()
    return {n:(r.pose.bones[n].location.copy(),r.pose.bones[n].rotation_euler.copy()) for n in BODY}
for gait,period in PERIOD.items():
    poses=[authored_pose(i/128,gait=='Sprint') for i in range(128)];poses.append(poses[0])
    name=gait+'_ReferenceStudy_V2';a=bpy.data.actions[name] if revise else bpy.data.actions.new(name);a.use_fake_user=True
    for i,ps in enumerate(poses):key_pose(r,a,1+period*i/128,ps)
    periodic(a,period)
    a['fps']=24;a['cycle_frames']=period;a['cycle_seconds']=period/24
    a['phase_convention']='R1-compatible phi0 right reach/left arm forward; opposite at .5. Contact 0/.5, Down .10/.60, Passing .25/.75, Up .375/.875 are authoring labels, not source foot contacts.'
    a['design']='V2: deeper rigid recovery arc and small root path; 3D arm pitch/twist/inward path with restrained authored side differences; shaped weight acceptance/rise and selective torso follow-through; inherited head bob.'
    a['scope']='Original full-pose unarmed study; no scale, weapon tracks or accumulated Root. Turning V1 remains unchanged and requires later rebase.'
    if not revise:
        for label,phi in [('Contact R',0),('Down R',.1),('Passing R',.25),('Up R',.375),('Contact L',.5),('Down L',.6),('Passing L',.75),('Up L',.875)]:a.pose_markers.new(label).frame=round(1+phi*period)
check_preserved(protected);s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=13
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'file':str(DEV),'created':['Walk_ReferenceStudy_V2','Sprint_ReferenceStudy_V2'],'preserved_actions':len(protected['actions'])}
