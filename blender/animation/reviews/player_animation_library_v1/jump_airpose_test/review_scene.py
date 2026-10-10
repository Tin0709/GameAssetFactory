"""Temporary presentation of two independent Actions, with separate preview travel."""
import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
def configure(s,r):
    data=json.loads((OUT/'manifest.json').read_text())
    return data
def bind(s,r,name,f):
    r.animation_data.action=None
    neutral=json.loads(bpy.data.texts['GAF_Neutral_Pose.json'].as_string())
    for b in r.pose.bones:
        for k,v in neutral[b.name].items():setattr(b,k,v)
    a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
    s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
def preview_offset(f,data):
    t=max(0,f-1);duration=data['preview_settle_frames'];u=min(t,duration)
    # Entry tangent carries into a fixed-height display; this is not a jump arc.
    distance=u-u*u/duration+u*u*u/(3*duration*duration)
    return Vector(data['preview_offset_m'])+Vector(data['preview_entry_velocity_m_per_frame'])*distance
def sequence(s,r,g,data):
    bpy.data.objects['Showcase_FixedFloor'].location.z=0
    if g<=24:
        r.location=(0,0,0);bind(s,r,'Jump_Takeoff_Test',g)
    else:
        f=g-23;r.location=preview_offset(f,data);bind(s,r,'Jump_AirPose_Test',f)
    bpy.context.view_layer.update()
