"""Exercise real library routing, asset/camera switches and model preservation."""
import bpy,runpy,json,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'SOLDIER_Asset_Library.blend'),load_ui=True)
loader=runpy.run_path(str(ROOT/'scripts/load_showcase_ui.py'))
assert 'SOLDIER_Asset_Library.blend' in loader['SHOWCASES'],'Soldier sidebar is missing from the public viewer loader'
loader['main']()
assert hasattr(bpy.types,'SOLDIER_PT_library')
library=bpy.data.scenes['SOLDIER_ASSET_LIBRARY']
entries=json.loads(library['soldier_registry'])['entries']
assert {'SOLDIER_Skin_v001','SOLDIER_Backpack_v001','SOLDIER_Facial_System_v001'} <= {e['id'] for e in entries}
def digest():
    return hashlib.sha256(json.dumps({o.name:{'matrix':[list(r) for r in o.matrix_local],'vertices':[list(v.co) for v in o.data.vertices]} for o in bpy.data.objects if o.type=='MESH'},sort_keys=True).encode()).hexdigest()
before=digest()
for asset_id,scene_name,prefix in [('SOLDIER_Skin_v001','SOLDIER_ASSET_LIBRARY',''),('SOLDIER_Backpack_v001','SOLDIER_BACKPACK_REVIEW','BPK_')]*2:
    assert bpy.ops.soldier_library.select_asset(asset_id=asset_id)=={'FINISHED'}
    assert bpy.context.scene.name==scene_name
    for direction in ['Front','Front_3Q','Left_Side','Back']:
        assert bpy.ops.soldier_library.view(direction=direction)=={'FINISHED'}
        assert bpy.context.scene.camera.name==prefix+direction
assert digest()==before,'Asset selection/view controls changed mesh data or object transforms'
assert bpy.data.objects['BPK_Backpack_v001'].parent is None and all(a.get('soldier_facial',False) for a in bpy.data.actions)
assert bpy.ops.soldier_library.view(direction='Front_3Q')=={'FINISHED'}
loader['main']()  # Re-loading the public bootstrap must be harmless.
print('SOLDIER_UI_TEST_PASS assets=2 switches=4 camera_switches=16 geometry_preserved=True')
