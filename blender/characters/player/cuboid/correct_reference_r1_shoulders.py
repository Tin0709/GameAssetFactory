"""Small clearance correction inside the first-pass R1 Actions; no new versions."""
import bpy,math
from pathlib import Path
BASE=Path(__file__).resolve().parent
assert Path(bpy.data.filepath)==BASE/'player_locomotion_reference_study.blend'
def curves(a):return [c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
rig=bpy.data.objects['R1_Study_Rig']
for gait,period in [('Walk',16),('Sprint',13)]:
    action=bpy.data.actions[gait+'_ReferenceStudy_V1'];rig.animation_data.action=action
    for i in range(65):
        f=1+i*period/64
        for side,sign in [('L',1),('R',-1)]:
            path='pose.bones["Arm.'+side+'"].rotation_euler'
            arm=math.degrees(next(c for c in curves(action) if c.data_path==path and c.array_index==0).evaluate(f))
            forward=max(0,(arm-12)/(52 if gait=='Sprint' else 29))
            p=rig.pose.bones['Arm.'+side];p.location=(-sign*.022*forward**2,0,.012*forward**2)
            p.keyframe_insert('location',frame=f,group=p.name)
    step=period/64
    for c in curves(action):
        if 'Arm.' not in c.data_path or not c.data_path.endswith('location'):continue
        ks=c.keyframe_points;ys=[k.co.y for k in ks]
        for i,k in enumerate(ks):
            j=i%64;slope=(ys[(j+1)%64]-ys[(j-1)%64])/(2*step)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-step/3,k.co.y-slope*step/3);k.handle_right=(k.co.x+step/3,k.co.y+slope*step/3)
        if not c.modifiers:c.modifiers.new('CYCLES')
        c.update()
    action['shoulder_clearance']='Up to 22 mm outward and 12 mm forward local translation during forward swing, preserving rest rig and rigid limbs.'
bpy.context.window.scene=bpy.data.scenes['R1_Walk_Sprint_Comparison'];bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,check_existing=False)
