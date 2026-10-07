"""Study-only Walk sway. Arms and weapon inherit the same torso motion."""
from hold_r11_common import *

design=json.loads((OUT/'design.json').read_text())
assert 'walk_sway' not in design, 'Sway pass already authored; inspect before repeating.'
(OUT/'walk_sway_before.json').write_text(json.dumps(design,indent=2))
before={name:digest(bpy.data.actions[name]) for c in design['categories'].values() for name in c['actions'].values()}
sway={'roll_amplitude_deg':1.8,'lateral_amplitude_m':.006,'gait_period_frames':16,'gait':'Walk','baseline_move_actions':{},'actions':{}}
for cat,c in design['categories'].items():
    sc=bpy.data.scenes[c['scene']];bpy.context.window.scene=sc
    rig=bpy.data.objects[c['rig']];old=bpy.data.actions[c['actions']['Move']]
    new=old.copy();new.name=PREFIX[cat]+'Move_WalkSwayR11';new.use_fake_user=True
    new['scope']='Study only. Original Walk; torso roll inherited by straight arms and weapon.'
    spine_curves=[fc for fc in curves(new) if '"Spine"' in fc.data_path]
    for fc in spine_curves:
        fc.keyframe_points.clear()
        for mod in list(fc.modifiers):fc.modifiers.remove(mod)
    previous=None
    for frame in range(1,66):
        sample(rig,sc,old,frame)
        spine=rig.pose.bones['Spine'];phase=2*math.pi*(frame-1)/16
        q=spine.rotation_quaternion.copy()@Quaternion((0,0,1),math.radians(1.8)*math.sin(phase))
        if previous is not None and q.dot(previous)<0:q.negate()
        previous=q.copy();loc=spine.location.copy();loc.x+=.006*math.sin(phase)
        assign(rig,new);spine.rotation_quaternion=q;spine.location=loc
        spine.keyframe_insert('rotation_quaternion',frame=frame,group='Spine')
        spine.keyframe_insert('location',frame=frame,group='Spine')
    for fc in curves(new):
        if '"Spine"' in fc.data_path:
            for k in fc.keyframe_points:k.interpolation='LINEAR'
            fc.modifiers.new('CYCLES')
    sway['baseline_move_actions'][cat]=old.name;sway['actions'][cat]=new.name
    c['actions']['Move']=new.name
    for item in [design['walking'][cat],design['showcases']['Move'],design['showcases']['Turn']]:
        actor=item['actors'][cat];r=bpy.data.objects[actor['rig']]
        assign(r,new);actor['upper']=new.name
    assign(rig,bpy.data.actions[c['actions']['Hold']])
assert all(digest(bpy.data.actions[name])==value for name,value in before.items())
design['walk_sway']=sway
(OUT/'design.json').write_text(json.dumps(design,indent=2))
(OUT/'walk_sway_source_action_hashes.json').write_text(json.dumps(before,indent=2))
result=sway
