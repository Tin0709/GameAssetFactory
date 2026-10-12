"""Real saved-file selection/reopen contract; run with Blender, no mocks."""
import bpy,sys,json
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import gaf_weapon_library as lib
from library_safety import protected_category,UpdateLock
assert protected_category('blender\\weapons\\approved.blend')=='weapons'
assert protected_category('blender\\animation\\showcase\\Animation_Showcase.blend')=='animations'
assert protected_category('game_mobile_3d\\assets\\characters\\r13\\rifle.glb')=='production_characters'
guard=UpdateLock(HERE).acquire()
try:
 try:UpdateLock(HERE).acquire();raise AssertionError('Concurrent writer accepted')
 except RuntimeError:pass
finally:guard.release()
lib.register()
bpy.ops.wm.open_mainfile(filepath=str(HERE/'Weapon_Showcase.blend'))
s=bpy.context.scene
assert len(s.gaf_weapons)>=16
manifest=json.loads((HERE/'weapon_manifest.json').read_text())
if manifest.get('default_selection'):
 assert lib.entries(s)[s.gaf_weapon_index]['id']==manifest['default_selection'],'Saved library must open with the latest registered weapon selected'
ui=lib.GAF_UL_weapons(bpy.context);flags,order=ui.filter_items(bpy.context,s,'gaf_weapons')
assert sorted(order)==list(range(len(s.gaf_weapons)))
for identifier,position in [('pistol_stylized_v2',0),('rifle_stylized_v2',1)]:
 assert order[next(i for i,e in enumerate(lib.entries(s)) if e['id']==identifier)]==position
for kind in ['Rifle','Pistol','Shotgun']:
 ready=s['fit_'+kind+'_READY'];holster=s['fit_'+kind+'_HOLSTER']
 assert max(abs(ready[i][3]-holster[i][3]) for i in range(3))>.15,('Holster snapshot is still ready',kind)
checks=0
for i,item in enumerate(s.gaf_weapons):
 s.gaf_weapon_index=i
 for mode in ['STANDALONE','READY','HOLSTER']:
  s.gaf_fit_mode=mode
  lib.activate(s)
  visible=[c.name for c in bpy.data.collections if c.get('weapon_entry') and not c.hide_render]
  assert visible==[item.collection],(item.name,mode,visible)
  roots=[o for o in bpy.data.collections[item.collection].objects if o.get('weapon_root')]
  assert len(roots)==1
  assert all(abs(v-1)<1e-6 for v in roots[0].scale) if mode=='STANDALONE' else True
  for direction in ['LEFT','RIGHT','FRONT','BACK','THREE_QUARTER']:
   lib.view(s,direction)
   assert s.camera is not None
   obs=list(bpy.data.collections[item.collection].objects)
   if mode!='STANDALONE':obs+=list(bpy.data.collections['FIT_'+item.kind+'_'+mode].objects)
   bpy.context.view_layer.update()
   for o in obs:
    if o.type=='MESH':
     for corner in o.bound_box:
      uv=world_to_camera_view(s,s.camera,o.matrix_world@Vector(corner))
      assert .015<uv.x<.985 and .015<uv.y<.985,('Camera crops model',item.name,mode,direction,list(uv))
   checks+=1
assert not bpy.data.actions,'Static fit must not create/import character Actions'
print('LIBRARY_TEST_PASSED',checks)
(HERE/'library_verification.json').write_text(json.dumps({'passed':True,'view_mode_selections':checks,'entries':len(s.gaf_weapons),'actions':len(bpy.data.actions)},indent=2))
