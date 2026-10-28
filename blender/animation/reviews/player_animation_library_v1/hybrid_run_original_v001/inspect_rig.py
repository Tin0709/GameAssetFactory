import bpy,json,sys
from pathlib import Path
r=Path(r"C:\Users\ADMIN\Desktop\Dev\GameAssetFactory");sys.path.insert(0,str(r/"blender/animation/showcase"));import gaf_animation_library as ui
rig=bpy.data.objects["Showcase_Player_Rig"];mesh=bpy.data.objects["Showcase_Player_Mesh"]
out={"bones":{b.name:{"rest":[list(row)for row in b.bone.matrix_local],"parent":b.parent.name if b.parent else None,"mode":b.rotation_mode}for b in rig.pose.bones},"rig_world":[list(x) for x in rig.matrix_world],"mesh_world":[list(x) for x in mesh.matrix_world],"scene":bpy.context.scene.name,"scenes":list(bpy.data.scenes.keys()),"signature":ui.rest_signature(rig.data),"old_actions":{a.name:ui.action_signature(a)for a in bpy.data.actions},"neutral":bpy.data.texts[ui.BASELINE].as_string()}
Path(__file__).with_name("rig_probe.json").write_text(json.dumps(out,indent=2));print("RIG",[(b.name,list(b.bone.head_local),list(b.bone.tail_local))for b in rig.pose.bones]);print("MESH",len(mesh.data.vertices),[g.name for g in mesh.vertex_groups]);print("SEQUENCES",json.loads((r/"blender/animation/showcase/animation_manifest.json").read_text()).get("review_sequences",[])[:1])
