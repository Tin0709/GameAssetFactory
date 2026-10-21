"""Scope, protected design, planar tabs, binary holes and rigid bone attachment."""
from pathlib import Path
import bpy, json, math, array, hashlib
from mathutils import Matrix, Vector
D=Path(__file__).resolve().parent
LIB=D.parents[1]/'showcase/SOLDIER_Asset_Library.blend'
bpy.ops.wm.open_mainfile(filepath=str(LIB),load_ui=True)
s=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];entry=next(e for e in json.loads(s['soldier_registry'])['entries'] if e['id']=='SOLDIER_Skin_v001')
body=bpy.data.objects[entry['body']];clothes=bpy.data.objects[entry['clothing']];rig=bpy.data.objects[entry['rig']]
original_body=bpy.data.meshes[body['wc_source_mesh']];original_clothes=bpy.data.meshes[clothes['wc_source_mesh']]
assert len(bpy.data.scenes)==2 and len(bpy.data.actions)==34 and len(rig.data.bones)==10
assert [tuple(v.co) for v in body.data.vertices]==[tuple(v.co) for v in original_body.vertices]
assert [tuple(l.uv) for l in body.data.uv_layers.active.data]==[tuple(l.uv) for l in original_body.uv_layers.active.data]
assert [[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]==[[(g.group,g.weight) for g in v.groups] for v in original_body.vertices]
for poly in body.data.polygons:
    bone=body.vertex_groups[body.data.vertices[poly.vertices[0]].groups[0].group].name
    if bone=='Head':assert body.data.materials[poly.material_index]==original_body.materials[0]
assert original_body.users>=2 and original_clothes.users>=2,'Archived originals and Facial review must remain'
layout=json.loads((D/'cloth_cards.json').read_text());assert len(layout['cards'])==35
assert len(clothes.data.polygons)==191 and len(clothes.data.vertices)==332
assert clothes['wc_garment_faces']==6
for v in clothes.data.vertices:assert len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7
def key(points):return tuple(sorted(tuple(round(float(a),6) for a in p) for p in points))
faces={key([clothes.data.vertices[i].co for i in p.vertices]):p for p in clothes.data.polygons}
for card in layout['cards']:
    poly=faces[key(card['vertices'])]
    assert len(poly.vertices)==4
    points=[clothes.data.vertices[i].co for i in poly.vertices]
    n=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
    assert abs((points[3]-points[0]).dot(n))<1e-7,card['name']
    assert all(clothes.vertex_groups[clothes.data.vertices[i].groups[0].group].name==card['bone'] for i in poly.vertices)
    for p,expected in zip(points,card['vertices']):assert (p-Vector(expected)).length<1e-7
mat=clothes.data.materials[0];assert not mat.use_backface_culling
cut=next(n for n in mat.node_tree.nodes if n.type=='MATH');assert cut.operation=='GREATER_THAN' and cut.inputs[1].default_value==.5
tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');assert tex.interpolation=='Closest'
assert set(round(a,5) for a in tex.image.pixels[3::4])=={0.,1.}
assert len(clothes.modifiers)==1 and clothes.modifiers[0].type=='ARMATURE' and clothes.modifiers[0].object==rig
saved={b.name:b.matrix_basis.copy() for b in rig.pose.bones};max_error=0.
for angles in [(0,0,0,0,0),(8,-90,90,35,-35),(-10,40,-35,-30,30),(12,-65,-65,50,-50)]:
    for name,angle in zip(['Chest','Arm.L','Arm.R','Leg.L','Leg.R'],angles):rig.pose.bones[name].matrix_basis=Matrix.Rotation(math.radians(angle),4,'X')
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    for obj in [body,clothes]:
        evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh()
        for a,b in zip(obj.data.vertices,mesh.vertices):
            bone=rig.pose.bones[obj.vertex_groups[a.groups[0].group].name]
            expected=bone.matrix@bone.bone.matrix_local.inverted()@a.co
            max_error=max(max_error,(expected-b.co).length)
        evaluated.to_mesh_clear()
for name,matrix in saved.items():rig.pose.bones[name].matrix_basis=matrix
bpy.context.view_layer.update();assert max_error<1e-5,max_error
report={'passed':True,'original_body_vertices_uv_weights_exact':True,'original_head_material_retained':True,'original_shared_meshes_archived_and_facial_review_preserved':True,'flat_cloth_cards':35,'thin_trouser_garment_faces':6,'binary_cutout':True,'rigid_pose_samples':4,'maximum_attachment_error_m':max_error,'actions':34,'bones':10,'new_scenes':0,'no_save_performed':True}
(D/'native_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('WORN_CLOTHING_VERIFY_PASS',json.dumps(report),flush=True)
