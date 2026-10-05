import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
report=json.loads((BASE/'weapon_family_report.json').read_text())
checks={}
anchor=BASE/'m4a1_blocky/m4a1_blocky_v1.blend'
bpy.ops.wm.open_mainfile(filepath=str(anchor))
a=bpy.data.objects['M4A1_Blocky_Base'];old_coords=[tuple(v.co) for v in a.data.vertices];old_uv=[tuple(x.uv) for x in a.data.uv_layers.active.data]
for key,item in report.items():
 bpy.ops.wm.open_mainfile(filepath=item['blend']);bpy.context.view_layer.update()
 mesh=[o for o in bpy.context.scene.objects if o.type=='MESH']
 verts=[o.matrix_world@v.co for o in mesh for v in o.data.vertices]
 ext=[max(v[i] for v in verts)-min(v[i] for v in verts) for i in range(3)]
 item['dimensions_m']=dict(zip(['width','length','height'],ext))
 for o in mesh:
  assert list(o.scale)==[1,1,1] and max(abs(a) for a in o.rotation_euler)<1e-7
  assert not o.modifiers
  assert all(0<=a<=1 for uv in o.data.uv_layers.active.data for a in uv.uv)
  assert len(o.data.materials)==1
  o.data.calc_loop_triangles();assert all(t.area>1e-12 for t in o.data.loop_triangles)
 mats={m.name for o in mesh for m in o.data.materials};assert len(mats)==1
 m=mesh[0].data.materials[0];bsdf=m.node_tree.nodes.get('Principled BSDF')
 assert abs(bsdf.inputs['Roughness'].default_value-.48)<1e-6 and bsdf.inputs['Metallic'].default_value==0
 tex=next(n for n in m.node_tree.nodes if n.type=='TEX_IMAGE');assert tex.interpolation=='Closest' and tex.image.packed_file and list(tex.image.size)==[64,64]
 grip=bpy.data.objects['Grip_Point'];assert grip.location.length<1e-7
 assert sum(len(o.data.loop_triangles) for o in mesh)==item['triangles']
 if key=='M4A1':
  new=[tuple(v.co) for v in mesh[0].data.vertices];assert len(old_coords)==len(new)
  assert all(a[1:]==b[1:] for a,b in zip(old_coords,new))
  assert old_uv==[tuple(x.uv) for x in mesh[0].data.uv_layers.active.data]
  assert abs(ext[0]-.103)<1e-6
 if key=='Shotgun':
  pump=bpy.data.objects['Shotgun_Pump'];assert (pump.location-bpy.data.objects['Support_Hand_Point'].location).length<1e-6
  item['pump_translation_blender_m']=list(pump.location)
 item['identity_transforms']='Root and main mesh identity; pump has intentional support-center local translation, unit scale and zero rotation.' if key=='Shotgun' else True
 checks[key]={'triangles':item['triangles'],'dimensions_m':item['dimensions_m'],'uvs_in_bounds':True,'no_degenerate_triangles':True,'unit_scales_zero_rotations':True,'packed_atlas_and_nearest':True,'markers':item['markers_blender_m']}
 path=Path(item['blend']);rp=path.with_name(path.stem+'_report.json');rp.write_text(json.dumps(item,indent=2))
 bpy.context.scene['asset_report']=json.dumps(item)
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path))
(BASE/'weapon_family_report.json').write_text(json.dumps(report,indent=2))
(BASE/'blender_validation.json').write_text(json.dumps(checks,indent=2))
result=checks
