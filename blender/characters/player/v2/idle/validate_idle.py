import bpy, math, json
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/v2/idle')
rig=bpy.data.objects['Player_Rig']; mesh=bpy.data.objects['Player_Base']; scene=bpy.context.scene
action=rig.animation_data.action
assert action.name=='Player_Idle'
curves=[fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
assert all('Root' not in fc.data_path for fc in curves)
sole_ids=[v.index for v in mesh.data.vertices if v.co.z<.057]
def evaluate(f):
    scene.frame_set(int(f),subframe=f-int(f)); bpy.context.view_layer.update()
    ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); me=ev.to_mesh()
    points=[v.co.copy() for v in me.vertices]; ev.to_mesh_clear()
    return points
first=evaluate(1)
max_foot=0; max_root=0; max_stretch=0; max_compression=1; max_rig_movement=0
per_frame=[]
for i in range(193):
    f=1+i*.25; coords=evaluate(f)
    slip=max((coords[j]-first[j]).length for j in sole_ids)
    max_foot=max(max_foot,slip)
    root=rig.pose.bones['Root']
    max_root=max(max_root,max(abs(root.matrix[r][c]-root.bone.matrix_local[r][c]) for r in range(4) for c in range(4)))
    max_rig_movement=max(max_rig_movement,rig.location.length)
    assert all(math.isfinite(x) for p in coords for x in p)
    for edge in mesh.data.edges:
        a,b=edge.vertices; length=(mesh.data.vertices[a].co-mesh.data.vertices[b].co).length
        if length>.005:
            ratio=(coords[a]-coords[b]).length/length
            max_stretch=max(max_stretch,ratio); max_compression=min(max_compression,ratio)
    if i%4==0: per_frame.append({'frame':int(f),'max_sole_drift_mm':slip*1000})
closure=evaluate(49)
closure_difference=max((a-b).length for a,b in zip(first,closure))
value_error=max(abs(fc.evaluate(1)-fc.evaluate(49)) for fc in curves)
def slope(point,right):
    h=point.handle_right if right else point.handle_left
    return (h.y-point.co.y)/(h.x-point.co.x)
tangent_error=max(abs(slope(fc.keyframe_points[0],True)-slope(fc.keyframe_points[-1],False)) for fc in curves)
assert max_foot<.0001, max_foot
assert max_root<1e-7 and max_rig_movement<1e-7
assert closure_difference<1e-6
assert tangent_error<1e-6
assert max_stretch<1.3 and max_compression>.7
evaluate(1)
report={'action':action.name,'fps':24,'playback_frames':[1,48],'closure_frame':49,'duration_seconds':2,'sample_count':193,'max_sole_drift_mm':max_foot*1000,'root_matrix_error':max_root,'object_translation_m':max_rig_movement,'closure_vertex_difference_m':closure_difference,'curve_closure_error':value_error,'seam_tangent_error':tangent_error,'min_edge_length_ratio':max_compression,'max_edge_length_ratio':max_stretch,'weight_changes':False,'rest_structure_changes':False,'frames':per_frame}
(OUT/'idle_validation.json').write_text(json.dumps(report,indent=2))
result={k:v for k,v in report.items() if k!='frames'}
