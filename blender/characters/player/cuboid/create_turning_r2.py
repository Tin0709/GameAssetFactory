import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
assert Path(bpy.data.filepath)==DEV
OUT.mkdir(exist_ok=True)
names=[g+'_Turn'+d+'_Reference_V1' for g in PERIOD for d in ['Left','Right']]
revise=globals().get('REVISE_R2_V1',False)
if revise:
    protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected)
    s=bpy.data.scenes['R2_Turn_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_Author_Rig'];mesh=bpy.data.objects['R2_Author_Mesh']
else:
    assert all(n not in bpy.data.actions for n in names)
    protected=preserve();(OUT/'preservation_before.json').write_text(json.dumps(protected,indent=2))
    s=bpy.data.scenes.new('R2_Turn_Authoring');s.use_fake_user=True;s.render.fps=24;s.render.fps_base=1
    bpy.context.window.scene=s;r,mesh=copy_character(s,'Author')
points=mesh_points(mesh)
descriptions=[]
for gait,period in PERIOD.items():
    base=bpy.data.actions[gait+'_ReferenceStudy_V1'];assert abs(base.frame_range[1]-base.frame_range[0]-period)<1e-6
    for direction,sign in [('Left',1),('Right',-1)]:
        pslist=[];floors=[]
        for i in range(64):
            ps=sample(r,s,base,1+period*i/64);clearance=floor_min(r,points);apply(r,ps)
            fast=gait=='Sprint'
            def delta(n,y=0,z=0):
                p=r.pose.bones[n];p.rotation_euler.y+=math.radians(sign*y);p.rotation_euler.z+=math.radians(sign*z)
            # Model forward -Y, anatomical left +X. Positive world yaw turns left.
            # Axial local Z points forward: negative axial Z roll banks toward left.
            delta('Hips',1 if fast else .5,-9 if fast else -4.8)
            r.pose.bones['Hips'].location.x+=sign*(.012 if fast else .008)
            delta('Spine',.75 if fast else .5,-.3)
            delta('Chest',1 if fast else .75,-.2)
            delta('Neck',1.5 if fast else 1,.4)
            delta('Head',1.5 if fast else 1,.6)
            for side in ['L','R']:
                # Modest arm balance, retaining the R1 shoulder translations exactly.
                delta('Arm.'+side,0,.8 if fast else .5)
            bpy.context.view_layer.update()
            r.pose.bones['Hips'].location.y+=clearance-floor_min(r,points)+.0015
            bpy.context.view_layer.update();floors.append(floor_min(r,points))
            pslist.append({n:(r.pose.bones[n].location.copy(),r.pose.bones[n].rotation_euler.copy()) for n in BODY})
        pslist.append(pslist[0]);name=gait+'_Turn'+direction+'_Reference_V1'
        a=bpy.data.actions[name] if revise else bpy.data.actions.new(name);a.use_fake_user=True
        for i,ps in enumerate(pslist):key_pose(r,a,1+period*i/64,ps)
        periodic(a,period)
        a['fps']=24;a['cycle_frames']=period;a['composition']='Absolute full pose; crossfade with matching R1 gait at same normalized phase. World heading/travel belongs to PREVIEW parent.'
        a['direction']='Anatomical '+direction.lower()+'; forward -Y, left +X; left world yaw positive about +Z.'
        a['phase']='phi=((f-1)/period)%1; phi0 right leg reach + left arm forward, phi.5 opposite. Reach anchors, not verified planted contacts.'
        a['scope']='Sustained turning cycle, not a one-shot heading change. No scale or weapon tracks.'
        descriptions.append({'action':a.name,'period':period,'seconds':period/24,'turn_sign':sign,'additional_axial_bank_degrees':9.5 if fast else 5.3,'hips_yaw_degrees':sign*(1 if fast else .5),'spine_chest_yaw_degrees':sign*(1.75 if fast else 1.25),'relative_neck_head_yaw_degrees':sign*(3 if fast else 2),'ground_min':min(floors)})
(OUT/'design_values.json').write_text(json.dumps(descriptions,indent=2))
assign(r,bpy.data.actions['Walk_TurnLeft_Reference_V1']);s.frame_start=1;s.frame_end=16
check_preserved(protected)
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'actions':names,'preserved_actions':len(protected['actions'])}
