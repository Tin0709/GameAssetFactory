"""Read-only motion audit; no runtime/game claims."""
import bpy,sys,json,itertools
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from flower_preservation import compare
from blender_strong_wind_v1 import apply_preview_pose

def audit_wind():
    copies=[o for o in bpy.data.objects if o.get('blender_only_strong_wind')]
    assert len(copies)==4,'Missing four isolated stronger Blender wind previews (initial RED)'
    assert bpy.data.scenes['REVIEW_DungeonsGround_Style_V2'].render.fps==24
    assert bpy.data.scenes['REVIEW_DungeonsGround_Style_V2'].render.fps_base==1
    assert all(not o.modifiers and not o.data.shape_keys for o in copies)
    root_error=rigidity=planarity=travel=0
    first={}
    for frame in (1,13,25,37,49,61,73,85,97):
        apply_preview_pose(frame)
        for o in copies:
            m=o.data;rest=m.attributes['wind_rest'];mask=m.attributes['wind_mask']
            if frame==1:first[o.name]=[v.co.copy()for v in m.vertices]
            for v in m.vertices:
                delta=(v.co-rest.data[v.index].vector).length
                if mask.data[v.index].value==0:root_error=max(root_error,delta)
                travel=max(travel,delta)
            for p in m.polygons:
                points=[m.vertices[vi].co for vi in p.vertices]
                planarity=max(planarity,max(abs((v-points[0]).dot(p.normal))for v in points))
                if all(m.attributes['wind_rigid'].data[vi].value for vi in p.vertices):
                    # Preserve all pair distances within each head/petal/leaf.
                    for a,b in itertools.combinations(p.vertices,2):
                        rigidity=max(rigidity,abs((m.vertices[a].co-m.vertices[b].co).length-(rest.data[a].vector-rest.data[b].vector).length))
    loop=max((v.co-first[o.name][v.index]).length for o in copies for v in o.data.vertices)
    assert root_error==0 and rigidity<2e-6 and planarity<2e-6 and loop<2e-6 and travel>.15
    baseline=json.loads((HERE.parents[3]/'.validation/flower_patch_v1/before_strong_wind_fingerprints.json').read_text())
    assert not compare(baseline['data']), 'Wind copies must preserve all existing authored source'
    return {'status':'PASS','scope':'Blender-only isolated live previews; no game integration','copies':len(copies),'loop_seconds':4,'fps':24,'root_max_error_m':root_error,'rigid_head_leaf_pair_distance_error_m':rigidity,'plane_max_error_m':planarity,'loop_1_97_max_error_m':loop,'peak_vertex_travel_m':travel,'preserved_existing_data':True}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
    report=audit_wind();(HERE.parents[3]/'.validation/flower_patch_v1/validation_blender_strong_wind.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
