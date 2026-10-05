"""Pistol-only V4 grip refinement, executed through Blender MCP.
Original reference used only for chunky, compact silhouette principles.
"""
from pathlib import Path
import hashlib
base=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
current=base/'pistol/blocky_pistol_v3.blend';prior_hash=hashlib.sha256(current.read_bytes()).hexdigest()
assert not (base/'pistol/blocky_pistol_v4.blend').exists(),'V4 already exists; inspect before revising.'
source=(base/'cleanup_weapon_geometry.py').read_text(encoding='utf-8-sig')
start=source.index('inputs=');end=source.index('\nhashes=',start)
source=source[:start]+"inputs={'Pistol':('pistol/blocky_pistol_v1.blend','blocky_pistol_v4')}"+source[end:]
source=source.replace("[(-.023,.094),(.047,.067),(.038,.039),(.009,-.055),(.012,-.064),(.012,-.072),(-.038,-.072),(-.038,-.059),(-.026,-.034)]","[(-.018,.084),(.039,.067),(.027,-.072),(-.025,-.072)]")
source=source.replace("assert all(abs(a-b)<1e-5 for aa,bb in zip(oldbounds,newbounds) for a,b in zip(aa,bb)),(key,oldbounds,newbounds)","assert all(abs(a-b)<1e-5 for i in [0,2] for a,b in zip(oldbounds[i],newbounds[i])),(key,oldbounds,newbounds)\n assert abs(newbounds[1][1]-oldbounds[1][1])<1e-5 and abs(newbounds[1][0]+.025)<1e-5")
source=source.replace("item={'before_triangles':before","before=340\n item={'before_triangles':before")
source=source.replace("BASE/'weapon_cleanup_report.json'","BASE/'pistol/pistol_grip_v4_report.json'")
exec(compile(source,'pistol_v4_generated.py','exec'))
assert hashlib.sha256(current.read_bytes()).hexdigest()==prior_hash
scene=bpy.context.scene;scene.camera=bpy.data.objects['Weapon_Side'];scene.render.filepath=str(base/'pistol/blocky_pistol_v4_side.png');bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['Weapon_Isometric'];scene['grip_refinement']='Controlled four-corner handle, slight rake, flat heel, no shoulder beyond slide rear. Original shape design.'
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(base/'pistol/blocky_pistol_v4.blend'))
result=report
