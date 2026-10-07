import importlib
import hold_r11_common
importlib.reload(hold_r11_common)
from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text())
for cat,d in design['categories'].items():
    if globals().get('CATEGORY') and cat!=CATEGORY:continue
    s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;r=bpy.data.objects[d['rig']];socket=Matrix(d['socket'])
    for mode,name in d['actions'].items():
        a=bpy.data.actions[name]
        for c in curves(a):
            c.keyframe_points.clear()
            for mod in list(c.modifiers):c.modifiers.remove(mod)
        N=PERIOD[mode];previous={}
        for i in range(N+1):
            phase=2*math.pi*i/N;simple_pose(r,socket,cat,12*math.sin(phase) if mode=='AimAround' else 0,math.sin(phase));assign(r,a)
            for n in UPPER:
                p=r.pose.bones[n];q=p.rotation_quaternion.copy()
                if n in previous and q.dot(previous[n])<0:q.negate()
                p.rotation_quaternion=q;previous[n]=q.copy();p.keyframe_insert('rotation_quaternion',frame=i+1,group=n);p.keyframe_insert('location',frame=i+1,group=n)
        for c in curves(a):
            for k in c.keyframe_points:k.interpolation='LINEAR'
            c.modifiers.new('CYCLES')
    if 'ReferenceAngle' not in d['cameras']:
        cam=camera(s,'R11_'+cat+'_ReferenceAngle',(3,-5,25),(0,-.35,1.2),1.95);d['cameras']['ReferenceAngle']=cam.name
    d['trigger']=list(TRIGGER[cat]);d['anchor_role']='trigger centre' if cat!='Pistol' else 'grip offset within block hand'
    d['gun_offset_forward_up_m']=list(GUN_OFFSET[cat])
    d['gun_offset_character_right_m']=GUN_RIGHT[cat]
    assign(r,bpy.data.actions[d['actions']['Hold']]);s.frame_set(25)
(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'reference':'inward straight-arm convergence, lower hand height; no elbow changes'}
