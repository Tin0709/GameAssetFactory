"""Refine the same Pending Soldier in its existing library; preserve source data."""
from pathlib import Path
import bpy, bmesh, json

D=Path(__file__).resolve().parent
LIB=D.parents[1]/'showcase/SOLDIER_Asset_Library.blend'
bpy.ops.wm.open_mainfile(filepath=str(LIB),load_ui=True)
bpy.context.preferences.filepaths.save_version=0
s=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];bpy.context.window.scene=s
registry=json.loads(s['soldier_registry']);entry=next(e for e in registry['entries'] if e['id']=='SOLDIER_Skin_v001')
body=bpy.data.objects[entry['body']];clothes=bpy.data.objects[entry['clothing']];rig=bpy.data.objects[entry['rig']]

# The Facial Expressions review shares the original mesh datablocks. Copy-on-write
# keeps that review and the original material/images intact, including face/eyes.
for obj in [body,clothes]:
    if 'wc_source_mesh' not in obj:
        obj['wc_source_mesh']=obj.data.name
        obj.data.use_fake_user=True
    obj.data=bpy.data.meshes[obj['wc_source_mesh']]
for group in [bpy.data.meshes,bpy.data.materials,bpy.data.images]:
    for block in list(group):
        if block.get('wc_owned',False) and block.users==0:group.remove(block)

source_body=body.data;source_clothes=clothes.data;source_mat=source_body.materials[0]
def image(name,path):
    im=bpy.data.images.load(str(path),check_existing=False);im.name=name;im['wc_owned']=True;im.pack();return im
body_atlas=image('WC_Worn_Body — protected original face',D/'worn_body_atlas.png')
cloth_atlas=image('WC_Ragged_Cloth — binary rips and flat tabs',D/'worn_cloth_atlas.png')
def material(name,atlas,cutout=False):
    mat=source_mat.copy();mat.name=name;mat['wc_owned']=True
    tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');tex.image=atlas;tex.interpolation='Closest'
    if cutout:
        mat.surface_render_method='DITHERED';mat.use_backface_culling=False
        if hasattr(mat,'use_transparency_overlap'):mat.use_transparency_overlap=False
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        threshold=mat.node_tree.nodes.new('ShaderNodeMath');threshold.operation='GREATER_THAN';threshold.inputs[1].default_value=.5
        mat.node_tree.links.new(tex.outputs['Alpha'],threshold.inputs[0]);mat.node_tree.links.new(threshold.outputs[0],bsdf.inputs['Alpha'])
        mat['alpha_mode']='MASK';mat['alpha_cutoff']=.5
    return mat
body_mat=material('WC_Dusty_Base — opaque / nearest',body_atlas)
cloth_mat=material('WC_Ragged_Clothing — cutout / two-sided',cloth_atlas,True)

body.data=source_body.copy();body.data.name='WC_Original_Body_Geometry — worn garment skin';body.data['wc_owned']=True;body.data.use_fake_user=False
body.data.materials.clear();body.data.materials.append(source_mat);body.data.materials.append(body_mat)
for face in body.data.polygons:
    bone=body.vertex_groups[body.data.vertices[face.vertices[0]].groups[0].group].name
    face.material_index=0 if bone=='Head' else 1

mesh=source_clothes.copy();mesh.name='WC_Ragged_Clothing — existing relief plus flat cloth';mesh['wc_owned']=True;mesh.use_fake_user=False
bm=bmesh.new();bm.from_mesh(mesh)
deform=bm.verts.layers.deform.verify();uv=bm.loops.layers.uv.active
seen=set();remove=[];removed_components=[]
for first in bm.verts:
    if first in seen:continue
    component=[];stack=[first];seen.add(first)
    while stack:
        v=stack.pop();component.append(v)
        for edge in v.link_edges:
            other=edge.other_vert(v)
            if other not in seen:seen.add(other);stack.append(other)
    lo=min(v.co.z for v in component);hi=max(v.co.z for v in component);cz=(lo+hi)*.5
    groups=list(component[0][deform].keys());bone=clothes.vertex_groups[groups[0]].name
    hem=(bone=='Chest' and abs(cz-.686)<.001 and hi-lo<.025) or (bone.startswith('Arm.') and abs(cz-1.134)<.001 and hi-lo<.021)
    if hem:
        faces=set(f for v in component for f in v.link_faces)
        removed_components.append({'bone':bone,'centre_z':cz,'faces':len(faces)})
        remove.extend(component)
assert sum(c['faces'] for c in removed_components)==48,removed_components
bmesh.ops.delete(bm,geom=remove,context='VERTS')
layout=json.loads((D/'cloth_cards.json').read_text());parts=[]
# Continuous thin garment faces hide the inner skin patch outside each rip,
# including where the original trousers had no raised outer panel.
underlay_parts=[]
body_uv=source_body.uv_layers.active.data
for poly in source_body.polygons:
    v0=source_body.vertices[poly.vertices[0]]
    bone=body.vertex_groups[v0.groups[0].group].name
    if not bone.startswith('Leg.'):continue
    sign=1 if bone.endswith('.L') else -1
    if not (abs(poly.normal.y)>.5 or poly.normal.x*sign>.5):continue
    coords=[source_body.vertices[i].co.copy() for i in poly.vertices]
    source_uv=[body_uv[i].uv.copy() for i in poly.loop_indices]
    low=min(co.y for co in source_uv);high=max(co.y for co in source_uv)
    vertices=[];coords_uv=[]
    for co,tuv in zip(coords,source_uv):
        if co.z<.165:
            co.z=.165;tuv.y=low+(.165/.675)*(high-low)
        vertices.append(bm.verts.new(co+poly.normal*.003));coords_uv.append(tuv)
    for vertex in vertices:vertex[deform][clothes.vertex_groups[bone].index]=1.
    face=bm.faces.new(vertices);face.material_index=0;face.smooth=False
    for loop,tuv in zip(face.loops,coords_uv):loop[uv].uv=tuv
    underlay_parts.append(bone)
assert len(underlay_parts)==6
for card in layout['cards']:
    vertices=[bm.verts.new(co) for co in card['vertices']]
    group=clothes.vertex_groups[card['bone']].index
    for v in vertices:v[deform][group]=1.
    face=bm.faces.new(vertices);face.material_index=0;face.smooth=False
    x,y,w,h=card['region']
    coords=[((x+.5)/512,1-(y+h-.5)/512),((x+w-.5)/512,1-(y+h-.5)/512),((x+w-.5)/512,1-(y+.5)/512),((x+.5)/512,1-(y+.5)/512)]
    for loop,co in zip(face.loops,coords):loop[uv].uv=co
    parts.append({'name':card['name'],'bone':card['bone']})
bm.normal_update();bm.to_mesh(mesh);bm.free();mesh.materials.clear();mesh.materials.append(cloth_mat);mesh.update()
clothes.data=mesh
clothes['wc_flat_cards']=len(parts);clothes['wc_parts']=json.dumps(parts)
clothes['wc_garment_faces']=len(underlay_parts)
clothes['scope']='Pending worn shirt/trousers: source cuboid relief, real cutout rips, flat rigid cloth tabs. Wrist bands retained.'
body['wc_scope']='Original body vertices/UV/rest weights. Original Head material retained; worn clothing and skin behind cloth rips only.'
entry['clothing_refinement']={'status':'Pending','type':'worn_clothing','flat_cards':len(parts),'same_existing_clothing_object':True,'source_meshes_archived':True,'guide':'assets/worn_clothing_v001'}
s['soldier_registry']=json.dumps(registry)
(D.parents[1]/'showcase/registry.json').write_text(json.dumps(registry,indent=2)+'\n')
text=bpy.data.texts.get('SOLDIER — Worn Cloth construction') or bpy.data.texts.new('SOLDIER — Worn Cloth construction');text.clear();text.write((D/'cloth_cards.json').read_text())
bpy.context.window.view_layer=s.view_layers['Hair & Bandana']
s['hc_style']='CARDS';s['hc_bandana']=True;s['hc_preview']='CHARACTER';s['hc_closeup']=False;s['hc_camera']='ThreeQuarter';s.camera=bpy.data.objects['Front_3Q']
mesh.calc_loop_triangles()
report={'passed':True,'same_pending_skin':True,'body_vertices':len(body.data.vertices),'clothing_vertices':len(mesh.vertices),'clothing_faces':len(mesh.polygons),'clothing_triangles':len(mesh.loop_triangles),'flat_cloth_tabs':len(parts),'thin_trouser_garment_faces':len(underlay_parts),'removed_finished_hem_faces':48,'retained_wrist_rings':True,'source_meshes_archived':[source_body.name,source_clothes.name],'existing_actions':len(bpy.data.actions),'existing_bones':len(rig.data.bones),'new_scenes':0}
(D/'build_validation.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(LIB),compress=True)
print('WORN_CLOTHING_BUILT',json.dumps(report),flush=True)
