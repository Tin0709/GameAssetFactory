"""Audit approved appearance/rest data and actual saved review travel."""
import bpy,json,sys,hashlib,runpy
from pathlib import Path
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
B=runpy.run_path(str(OUT/'build_test.py'))
def digest(value):return hashlib.sha256(repr(value).encode()).hexdigest()
def assets(r,m):
    mesh=([tuple(v.co) for v in m.data.vertices],[tuple(p.vertices) for p in m.data.polygons],[p.material_index for p in m.data.polygons],[(uv.name,[tuple(x.uv) for x in uv.data]) for uv in m.data.uv_layers],[(g.name,g.index) for g in m.vertex_groups],[[(w.group,w.weight) for w in v.groups] for v in m.data.vertices],[(a.name,a.domain,a.data_type) for a in m.data.attributes])
    materials=[]
    for mat in m.data.materials:
        nodes=[]
        for n in mat.node_tree.nodes:
            defaults=[]
            for sock in n.inputs:
                if hasattr(sock,'default_value'):
                    v=sock.default_value
                    defaults.append((sock.name,list(v) if hasattr(v,'__len__') and not isinstance(v,str) else v))
            nodes.append((n.name,n.bl_idname,defaults,n.image.name if n.type=='TEX_IMAGE' and n.image else None))
        materials.append((mat.name,list(mat.diffuse_color),nodes,[(l.from_node.name,l.from_socket.identifier,l.to_node.name,l.to_socket.identifier) for l in mat.node_tree.links]))
    images=[(i.name,i.colorspace_settings.name,i.alpha_mode,[(p.filepath,hashlib.sha256(p.packed_file.data).hexdigest()) for p in i.packed_files]) for i in bpy.data.images if i.packed_files]
    lights=[(o.name,list(o.location),list(o.rotation_euler),o.data.type,o.data.energy,list(o.data.color),getattr(o.data,'size',None)) for o in bpy.data.objects if o.type=='LIGHT']
    return {'mesh_weights_uvs':digest(mesh),'materials':digest(materials),'packed_images':digest(images),'rest_rig':ui.rest_signature(r.data),'lights':digest(lights),'binding':[(x.type,x.object==r,x.use_vertex_groups,x.use_deform_preserve_volume) for x in m.modifiers if x.type=='ARMATURE']}
original=ROOT/'.validation/full_jump_expressive_test/source_before_test.blend'
bpy.ops.wm.open_mainfile(filepath=str(original));before=assets(bpy.data.objects['JI_Test_Rig'],bpy.data.objects['JI_Test_Mesh']);old={a.name:ui.action_signature(a) for a in bpy.data.actions}
results={};full_sig=None
for filename in ['full_jump_expressive_review.blend','full_jump_preview.blend']:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/filename));r=bpy.data.objects['FJ_Test_Rig'];m=bpy.data.objects['FJ_Test_Mesh'];s=bpy.context.scene
    audit=assets(r,m);assert audit==before,(filename,audit,before)
    assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in old.items())
    sig=ui.action_signature(bpy.data.actions['Full_Jump_Expressive_Test'])
    if full_sig is None:full_sig=sig
    assert sig==full_sig
    if filename=='full_jump_expressive_review.blend':
        assert len(bpy.data.actions)==8 and r.parent is None and r.matrix_world==Matrix.Identity(4)
    else:
        travel=bpy.data.objects['Review_Only_Jump_Travel'];assert len(bpy.data.actions)==9 and r.parent==travel and travel.animation_data.action.name=='PREVIEW_ONLY_FullJump_Height'
        assert all(c.data_path=='location' for c in ui.curves(travel.animation_data.action))
        heights=[];ground=1;error=0
        for j in range(92*16+1):
            f=1+j/16;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();h=travel.location.z;heights.append(h);error=max(error,abs(h-B['height'](f)))
            obj=m.evaluated_get(bpy.context.evaluated_depsgraph_get());ground=min(ground,min((obj.matrix_world@v.co).z for v in obj.data.vertices))
            if f<=19 or f>=46:assert abs(h)<1e-8
        apex=heights.index(max(heights));assert all(b>=a-1e-8 for a,b in zip(heights[:apex],heights[1:apex+1])) and all(b<=a+1e-8 for a,b in zip(heights[apex:],heights[apex+1:]))
        assert ground>-.00001
        results['actual_preview']={'separate_parent_and_action':True,'single_rise_and_descent':True,'minimum_floor_clearance_m':ground,'maximum_bake_error_m':error,'height_m':max(heights),'zero_travel_during_support':True}
    results[filename]={'appearance_and_binding_identical':True,'approved_actions_identical':True,'full_action_signature':sig,'asset_fingerprints':audit}
results['passed']=True;(OUT/'asset_verification.json').write_text(json.dumps(results,indent=2),encoding='utf8');print('APPEARANCE / SOURCE / ACTUAL PREVIEW VERIFIED',json.dumps(results),flush=True)
