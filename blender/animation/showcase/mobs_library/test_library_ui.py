"""Real Blender integration tests, including future mobs with another skeleton."""
import bpy,sys,json,importlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT))
assert (OUT/'gaf_mobs_animation_library.py').exists(),'Dedicated mob library add-on is missing'
if 'gaf_mobs_animation_library' in sys.modules:sys.modules.pop('gaf_mobs_animation_library').unregister()
import gaf_mobs_animation_library as lib
lib.register()
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Mobs_Animation_Library.blend'))
s=bpy.context.scene;r=bpy.data.objects['Zombie_Cuboid_Rig']
assert len(s.mobs_clips)==2 and s.mobs_mob=='Zombie'
assert lib.mob_items(s,None) is lib.mob_items(s,None),'Enum callback must retain stable item/string references'
for i,name in enumerate(['Zombie_Idle_Original_V1','Zombie_Walk_Original_V1']):
    r.pose.bones['Head'].scale=(2,2,2)
    s.mobs_active_index=i
    lib.activate(s)
    assert r.animation_data.action.name==name
    assert r.animation_data.action_slot==r.animation_data.action.slots[0]
    assert tuple(r.pose.bones['Head'].scale)==(1,1,1)
    assert s.render.fps==30 and s.frame_start==1
    assert s.frame_end==(120 if i==0 else 42)
    assert r.animation_data.action['review_status']=='Pending'

# Status must survive metadata serialization, and revisions must not replace it.
s.mobs_active_index=0
original=r.animation_data.action
assert bpy.ops.mobs.set_status(status='Approved')=={'FINISHED'}
assert original['review_status']=='Approved'
sig=lib.action_signature(original)
assert bpy.ops.mobs.new_revision(name='Zombie_Idle_Original_V2')=={'FINISHED'}
assert bpy.data.actions['Zombie_Idle_Original_V1'] is original
assert lib.action_signature(original)==sig
assert bpy.data.actions['Zombie_Idle_Original_V2']['review_status']=='Pending'
assert bpy.ops.mobs.new_revision(name='Zombie_Idle_Original_V1')=={'CANCELLED'}
assert original['review_status']=='Approved'

# Save and actually reopen the changed status and revision in a scratch file.
scratch=OUT/'validation_review_state.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(scratch))
bpy.ops.wm.open_mainfile(filepath=str(scratch))
saved=lib.registry(bpy.context.scene)
assert next(c for c in saved['clips'] if c['action']=='Zombie_Idle_Original_V1')['status']=='Approved'
assert next(c for c in saved['clips'] if c['action']=='Zombie_Idle_Original_V2')['status']=='Pending'
assert lib.action_signature(bpy.data.actions['Zombie_Idle_Original_V1'])==sig
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Mobs_Animation_Library.blend'))
s=bpy.context.scene;r=bpy.data.objects['Zombie_Cuboid_Rig']

# No common skeleton or shared bone-name assumption: one unrelated bone.
col=bpy.data.collections.new('MOB_TestDifferentRig');s.collection.children.link(col)
data=bpy.data.armatures.new('OtherSkeleton');other=bpy.data.objects.new('OtherRig',data);col.objects.link(other)
bpy.context.view_layer.objects.active=other;other.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');b=data.edit_bones.new('DifferentOnly');b.tail=(0,0,1);bpy.ops.object.mode_set(mode='OBJECT')
lib.register_mob(s,'Fixture','Fixture',col,other)
s.mobs_mob='Fixture';assert len(s.mobs_clips)==0
assert bpy.data.collections['MOB_Zombie'].hide_viewport and not col.hide_viewport
act=bpy.data.actions.new('OtherIdle');other.animation_data_create();other.animation_data.action=act
other.pose.bones['DifferentOnly'].keyframe_insert('rotation_euler',frame=1)
other.pose.bones['DifferentOnly'].keyframe_insert('rotation_euler',frame=31)
lib.register_clip(s,'Fixture',act,1,30,30,act.slots[0])
lib.rebuild(s);lib.activate(s)
assert other.animation_data.action is act
assert other.animation_data.action_slot==act.slots[0]
s.mobs_mob='Zombie';assert col.hide_viewport and not bpy.data.collections['MOB_Zombie'].hide_viewport
assert other.animation_data.action is None

# Unsupported Object travel must be rejected rather than leaking into a later clip.
bad=bpy.data.actions.new('BadObjectTravel');other.animation_data.action=bad
other.keyframe_insert('location',frame=1)
before=lib.registry(s)
try:lib.register_clip(s,'Fixture',bad,1,30,30,bad.slots[0])
except ValueError:pass
else:raise AssertionError('Object-transform Action was silently accepted')
assert lib.registry(s)==before

# Restore original fresh file; status/revision fixture changes must never leak.
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Mobs_Animation_Library.blend'))
s=bpy.context.scene
assert len(s.mobs_clips)==2
assert all(c.status=='Pending' for c in s.mobs_clips)
assert set(bpy.data.actions)=={bpy.data.actions['Zombie_Idle_Original_V1'],bpy.data.actions['Zombie_Walk_Original_V1']}
print('UI_INTEGRATION_PASS: switch/reset/slots/status/revision/collision/different-skeleton/visibility/fresh-reopen')
(OUT/'validation_ui.json').write_text(json.dumps({'passed':True,'checks':['switch','reset','slots','status','revision','name_collision','different_skeleton','empty_mob','visibility','fresh_reopen'],'final_statuses':[c.status for c in s.mobs_clips]},indent=2))
