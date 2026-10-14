"""Use a fresh process with normal user preferences; no manual module registration."""
import bpy,json
from pathlib import Path
target=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/Mobs_Animation_Library.blend')
assert 'gaf_mobs_animation_library' in bpy.context.preferences.addons
assert hasattr(bpy.types.Scene,'mobs_clips'),'Add-on did not register at startup'
bpy.ops.wm.open_mainfile(filepath=str(target))
s=bpy.context.scene;r=bpy.data.objects['Zombie_Cuboid_Rig']
assert s.mobs_mob=='Zombie' and len(s.mobs_clips)==2 and not s.mobs_error
for i,name,N in [(0,'Zombie_Idle_Original_V1',120),(1,'Zombie_Walk_Original_V1',42)]:
    s.mobs_active_index=i
    assert r.animation_data.action.name==name
    assert r.animation_data.action_slot==r.animation_data.action.slots[0]
    assert s.frame_start==1 and s.frame_end==N and s.render.fps==30
    assert s.mobs_clips[i].status=='Pending'
    s.frame_set(1);a=r.pose.bones['Head'].matrix.copy();s.frame_set(N//3)
    assert max(abs(a[x][y]-r.pose.bones['Head'].matrix[x][y]) for x in range(4) for y in range(4))>.001
bpy.ops.wm.open_mainfile(filepath=str(target))
assert bpy.context.scene.mobs_active_index==0 and not bpy.context.scene.mobs_error
result={'startup_addon_enabled':True,'fresh_reopening':True,'action_switching_and_motion':True,'initial_statuses':['Pending','Pending']}
(Path(__file__).resolve().parent/'validation_reopen.json').write_text(json.dumps(result,indent=2))
print('FRESH_REOPEN_PASS',json.dumps(result))
