"""Blender-only 4-second wind study. Acts exclusively on isolated review mesh copies."""
import bpy,math
from mathutils import Vector,Quaternion
PREFIX='REVIEW_WIND_'

def apply_preview_pose(frame):
    phase=2*math.pi*(frame-1)/96
    for obj in bpy.data.objects:
        if not obj.get('blender_only_strong_wind'):continue
        m=obj.data;rest=m.attributes['wind_rest'];mask=m.attributes['wind_mask'];root=m.attributes['wind_root'];centers=m.attributes['wind_ring_center'];kind=m.attributes['wind_rigid']
        for vi,v in enumerate(m.vertices):
            r=root.data[vi].vector;t=mask.data[vi].value;p=rest.data[vi].vector
            local_phase=phase+r.x*.7+r.y*.5
            if obj['wind_kind']=='grass':
                # Twice the original copied v4 local amplitudes (.018/.008 m).
                h=obj['wind_reference_height'];dx=.036*math.sin(local_phase);dy=.016*math.sin(local_phase+1.1)
                axis=Vector((-dy,dx,0));angle=math.atan(axis.length/h)
            else:
                dx=.16*math.sin(local_phase);dy=.09*math.sin(local_phase+1.1)
                axis=Vector((-dy,dx,0));angle=axis.length
            if t==0:v.co=p;continue
            q=Quaternion(axis.normalized(),angle*t*t)
            if kind.data[vi].value:
                v.co=r+q@(p-r)
            else:
                center=centers.data[vi].vector
                v.co=r+q@(center-r)+(p-center)
        m.update()

def _wind_frame(scene,depsgraph=None):
    if scene.name=='REVIEW_DungeonsGround_Style_V2':apply_preview_pose(scene.frame_current)
_wind_frame._flower_study_wind=True

def register():
    for handler in list(bpy.app.handlers.frame_change_pre):
        if getattr(handler,'_flower_study_wind',False):bpy.app.handlers.frame_change_pre.remove(handler)
    bpy.app.handlers.frame_change_pre.append(_wind_frame)
    apply_preview_pose(bpy.context.scene.frame_current)
