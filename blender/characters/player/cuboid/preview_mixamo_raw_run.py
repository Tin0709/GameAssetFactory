"""Live-session preview setup only. No saving, key edits, rig edits or playback start."""
import bpy, json, hashlib
from pathlib import Path
assert Path(bpy.data.filepath).name=='blocky_character_mixamo_test.blend',bpy.data.filepath
rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
action=bpy.data.actions.get('Player_Run_Mixamo_RAW')
assert action is not None,'Player_Run_Mixamo_RAW is missing in the live session. Reload the saved test file first.'
def digest(a):
    curves=[c for l in a.layers for s in l.strips for bag in getattr(s,'channelbags',[]) for c in bag.fcurves]
    data=[(c.data_path,c.array_index,[(list(k.co),list(k.handle_left),list(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points],[(m.type,getattr(m,'mode_before',None),getattr(m,'mode_after',None)) for m in c.modifiers]) for c in curves]
    return hashlib.sha256(json.dumps(data).encode()).hexdigest()
protected={n:digest(bpy.data.actions[n]) for n in ['Player_Run_Mixamo_RAW','Player_Idle','Running_Mixamo_RAW','Running_Mixamo_InPlace']}
area=bpy.context.area
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for obj in bpy.context.selected_objects:obj.select_set(False)
rig.hide_set(False);mesh.hide_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
rig.animation_data_create();rig.animation_data.action=action
if action.slots:rig.animation_data.action_slot=action.slots[0]
scene=bpy.context.scene
scene.frame_preview_start=1;scene.frame_preview_end=17;scene.use_preview_range=True
for name in ['Armature','Mixamo_Working']:
    obj=bpy.data.objects.get(name)
    if obj:obj.hide_set(True)
scene.frame_set(1);bpy.context.view_layer.update()
# Restore this editor to a viewport and frame the visible character in both views.
area.type='VIEW_3D'
mesh.select_set(True)
for view in bpy.context.screen.areas:
    region=next((r for r in view.regions if r.type=='WINDOW'),None)
    if not region:continue
    if view.type=='VIEW_3D':
        view.spaces.active.shading.type='MATERIAL'
        view.spaces.active.overlay.show_overlays=False
        with bpy.context.temp_override(area=view,region=region):bpy.ops.view3d.view_selected(use_all_regions=False)
    elif view.type=='DOPESHEET_EDITOR':
        with bpy.context.temp_override(area=view,region=region):bpy.ops.action.view_all()
mesh.select_set(False)
assert protected=={n:digest(bpy.data.actions[n]) for n in protected},'Animation data changed unexpectedly'
assert bpy.context.view_layer.objects.active==rig and rig.select_get()
assert rig.mode=='OBJECT'
assert scene.frame_preview_start==1 and scene.frame_preview_end==17 and scene.use_preview_range
print('PREVIEW READY:',rig.name,rig.animation_data.action.name,'range 1-17, Object Mode; source armatures hidden; action data unchanged. NOT SAVED.')
