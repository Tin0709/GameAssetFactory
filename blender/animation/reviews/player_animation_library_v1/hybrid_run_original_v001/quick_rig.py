import bpy,json
from pathlib import Path
rig=bpy.data.objects["Showcase_Player_Rig"];mesh=bpy.data.objects["Showcase_Player_Mesh"]
print("RIG",[(b.name,list(b.bone.head_local),list(b.bone.tail_local),b.rotation_mode)for b in rig.pose.bones]);print("MESH",len(mesh.data.vertices),mesh.matrix_world)
Path(__file__).with_name("rest.json").write_text(json.dumps({b.name:{"rest":[list(x)for x in b.bone.matrix_local],"parent":b.parent.name if b.parent else None,"mode":b.rotation_mode}for b in rig.pose.bones},indent=2))
