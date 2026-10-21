"""Essential native contracts: flat/cutout assets, exact head follow, real controls."""
from pathlib import Path
import bpy,sys,json,math
from mathutils import Matrix,Vector
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));sys.path.insert(0,str(D.parents[1]/'showcase'))
bpy.ops.wm.open_mainfile(filepath=str(D.parents[1]/'showcase/SOLDIER_Asset_Library.blend'),load_ui=True)
import soldier_library_ui;soldier_library_ui.register();import haircards_ui as ui
s=ui.show(bpy.context);p=s.soldier_hair;hair=bpy.data.objects['SOLDIER_HairCards_v001'];band=bpy.data.objects['SOLDIER_Bandana_2D_v001'];rig=hair.parent
p.closeup=False;bpy.ops.soldier_hair.view(direction='ThreeQuarter');assert s.camera.name=='Front_3Q'
p.closeup=True
assert len(bpy.data.scenes)==2 and len(bpy.data.actions)==34 and len(rig.data.bones)==10
for obj in [hair,band]:
 assert obj.get('review_status')=='Pending' and obj.asset_data
 assert len(obj.modifiers)==1 and obj.modifiers[0].type=='ARMATURE' and obj.modifiers[0].object==rig
 assert len(obj.vertex_groups)==1 and obj.vertex_groups[0].name=='Head'
 for v in obj.data.vertices:assert len(v.groups)==1 and abs(v.groups[0].weight-1.)<1e-8
 for poly in obj.data.polygons:
  assert len(poly.vertices)==4
  points=[obj.data.vertices[i].co for i in poly.vertices];n=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
  assert abs((points[3]-points[0]).dot(n))<1e-7,(obj.name,'nonplanar card')
 assert not any(m.type=='SOLIDIFY' for m in obj.modifiers)
 for uv in obj.data.uv_layers.active.data:assert 0<=uv.uv.x<=1 and 0<=uv.uv.y<=1
mat=hair.data.materials[0];assert mat==band.data.materials[0] and not mat.use_backface_culling
texture=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');assert texture.interpolation=='Closest';image=texture.image
assert set(round(a,5) for a in image.pixels[3::4])=={0.,1.}
cut=next(n for n in mat.node_tree.nodes if n.type=='MATH');assert cut.operation=='GREATER_THAN' and cut.inputs[1].default_value==.5
layer=s.view_layers[ui.LAYER]
for mode in ['ORIGINAL','HAIR','BANDANA']:
 assert bpy.ops.soldier_hair.compare(variant=mode)=={'FINISHED'}
 assert ui.find(layer.layer_collection,ui.COLS['old']).exclude==(mode!='ORIGINAL')
 assert ui.find(layer.layer_collection,ui.COLS['hair']).exclude==(mode=='ORIGINAL')
 assert ui.find(layer.layer_collection,ui.COLS['band']).exclude==(mode!='BANDANA')
 assert not ui.find(layer.layer_collection,ui.COLS['body']).exclude
 for direction in ['Front','ThreeQuarter','Side','Back']:
  assert bpy.ops.soldier_hair.view(direction=direction)=={'FINISHED'};assert s.camera.name=='HC_'+direction
p.preview='HAIR_ONLY';assert ui.find(layer.layer_collection,ui.COLS['band']).exclude,'Dropdown Hair only must hide bandana'
p.bandana=False;p.preview='HAIR_BANDANA';assert not ui.find(layer.layer_collection,ui.COLS['band']).exclude,'Dropdown Hair + Bandana must show bandana'
p.bandana=False;assert p.preview=='HAIR_ONLY','Independent hide must keep preview label coherent'
bpy.ops.soldier_hair.isolate(bandana=False);assert ui.find(layer.layer_collection,ui.COLS['body']).exclude and ui.find(layer.layer_collection,ui.COLS['band']).exclude
bpy.ops.soldier_hair.isolate(bandana=True);assert not ui.find(layer.layer_collection,ui.COLS['band']).exclude
p.bandana=False;assert ui.find(layer.layer_collection,ui.COLS['band']).exclude
bpy.ops.soldier_hair.compare(variant='BANDANA');old=rig.pose.bones['Head'].matrix_basis.copy();old_mode=rig.pose.bones['Head'].rotation_mode
max_error=0.
for yaw,pitch,roll in [(0,0,0),(45,0,0),(-45,0,0),(0,20,0),(0,-20,0),(20,10,7),(-20,-10,7)]:
 bone=rig.pose.bones['Head'];bone.rotation_mode='XYZ';bone.matrix_basis=Matrix.Rotation(math.radians(yaw),4,'Y')@Matrix.Rotation(math.radians(pitch),4,'X')@Matrix.Rotation(math.radians(roll),4,'Z');bpy.context.view_layer.update()
 transform=bone.matrix@bone.bone.matrix_local.inverted();deps=bpy.context.evaluated_depsgraph_get()
 for obj in [hair,band]:
  evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh()
  for a,b in zip(obj.data.vertices,mesh.vertices):max_error=max(max_error,(transform@a.co-b.co).length)
  evaluated.to_mesh_clear()
rig.pose.bones['Head'].rotation_mode=old_mode;rig.pose.bones['Head'].matrix_basis=old;bpy.context.view_layer.update();assert max_error<1e-5,max_error
for asset in ['SOLDIER_Skin_v001','SOLDIER_Backpack_v001','SOLDIER_Facial_System_v001','SOLDIER_HairCards_v001','SOLDIER_Bandana_2D_v001']:
 assert bpy.ops.soldier_library.select_asset(asset_id=asset)=={'FINISHED'}
ui.register();assert bpy.app.handlers.load_post.count(ui.loaded)==1
report={'passed':True,'flat_hair_cards':len(hair.data.polygons),'flat_bandana_cards':len(band.data.polygons),'binary_alpha':True,'double_sided':True,'head_pose_checks':7,'maximum_head_attachment_error_m':max_error,'existing_actions':len(bpy.data.actions),'new_bones':0,'original_and_new_hair_controls':True,'bandana_hide_and_isolated_views':True,'all_5_asset_routes':True,'no_save_performed':True}
(D/'native_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('HAIRCARDS_VERIFY_PASS',json.dumps(report),flush=True)
