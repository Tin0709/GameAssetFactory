"""Inspect actual evaluated geometry and source preservation, including in-betweens."""
import bpy,runpy,json,math,hashlib
from pathlib import Path
from itertools import combinations
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;B=runpy.run_path(str(OUT/'build_test.py'))

def run():
    s=bpy.data.scenes['LOWERBODY_RECOVERY_REVIEW'];bpy.context.window.scene=s
    r=bpy.data.objects['LB_Test_Rig'];m=bpy.data.objects['LB_Test_Mesh']
    groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups}
    groups={k:v for k,v in groups.items() if v}
    soles={side:[i for i in groups['Leg.'+side] if abs(m.data.vertices[i].co.z)<1e-6] for side in ['L','R']}
    adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
    pairs=[p for p in combinations(groups,2) if frozenset(p) not in adjacent]
    base=[v.co.copy() for v in m.data.vertices]
    distances=[(a,b,(base[a]-base[b]).length) for ids in groups.values() for a,b in combinations(ids,2)]
    def pts(f):
        s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
        e=m.evaluated_get(bpy.context.evaluated_depsgraph_get())
        return [e.matrix_world@v.co for v in e.data.vertices]
    def separation(a,b,v):
        axes=[r.pose.bones[n].matrix.to_3x3().col[i].normalized() for n in [a,b] for i in range(3)]
        axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
        aa,bb=[[v[j] for j in groups[n]] for n in [a,b]]
        return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
    result={'samples':(B['END']-1)*16+1,'rig_changes':[],'max_rigid_distance_error_m':0,'min_sole_z_m':1,'max_support_height_error_m':0,'max_contact_corner_xy_error_m':0,'max_leg_local_translation_m':0,'overlaps':{},'camera_bounds':{},'frames':[],'unsupported_samples':0}
    heights=[];locations=[];vertices=[]
    for j in range(result['samples']):
        f=1+j/16;v=pts(f);d=B['design'](f)
        result['max_rigid_distance_error_m']=max(result['max_rigid_distance_error_m'],max(abs((v[a]-v[b]).length-dist) for a,b,dist in distances))
        result['min_sole_z_m']=min(result['min_sole_z_m'],min(v[i].z for ids in soles.values() for i in ids))
        supported=0
        for side,ids in soles.items():
            result['max_leg_local_translation_m']=max(result['max_leg_local_translation_m'],r.pose.bones['Leg.'+side].location.length)
            floor=min(v[i].z for i in ids);base,lift=d['feet'][side]
            if lift<1e-8:
                supported+=1;result['max_support_height_error_m']=max(result['max_support_height_error_m'],abs(floor))
                # Only the actual lowest corner/edge is claimed fixed during rigid roll.
                for i in ids:
                    if v[i].z<floor+1e-6:
                        rest=Vector((base.x+(m.data.vertices[i].co.x-(-.1125 if side=='R' else .1125)),base.y+m.data.vertices[i].co.y,0))
                        result['max_contact_corner_xy_error_m']=max(result['max_contact_corner_xy_error_m'],(v[i].xy-rest.xy).length)
        if not supported:result['unsupported_samples']+=1
        heights.append(r.pose.bones['Hips'].head.z);locations.append(tuple(r.pose.bones['Hips'].head))
        vertices.append(v)
        if j%2==0:
            for a,b in pairs:
                dist=separation(a,b,v)
                if dist<-.00001 and dist<result['overlaps'].get(a+'/'+b,{}).get('depth_m',0):result['overlaps'][a+'/'+b]={'frame':f,'depth_m':dist}
            for view in ['FRONT','THREE_QUARTER','SIDE']:
                q=[world_to_camera_view(s,bpy.data.objects['LB_'+view],x) for x in v]
                bounds=result['camera_bounds'].setdefault(view,[1,1,0,0]);bounds[:]=[min(bounds[0],min(x.x for x in q)),min(bounds[1],min(x.y for x in q)),max(bounds[2],max(x.x for x in q)),max(bounds[3],max(x.y for x in q))]
        if j%16==0:result['frames'].append({'frame':f,'hip':list(r.pose.bones['Hips'].head),'soles':{side:min(v[i].z for i in ids) for side,ids in soles.items()}})
    result['hip_height_range_m']=[min(heights),max(heights)]
    result['hip_compression_from_ready_m']=heights[0]-min(heights)
    result['hip_lateral_range_m']=[min(p[0] for p in locations),max(p[0] for p in locations)]
    result['maximum_adjacent_sample_displacement_m']=max((a-b).length for prev,nxt in zip(vertices,vertices[1:]) for a,b in zip(prev,nxt))
    result['old_actions']=len(json.loads((B['TMP']/'original_data.json').read_text())['actions']);result['actions_now']=len(bpy.data.actions)
    result['changed_originals']=B['H']['compare_originals'](json.loads((B['TMP']/'original_data.json').read_text()))
    result['source_files_unchanged']=all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in json.loads((B['TMP']/'backup_manifest.json').read_text())['files'].items())
    result['same_mesh']=m.data==bpy.data.objects['RUN_Test_Mesh'].data
    result['same_rest']=all(b.matrix_local==bpy.data.objects['RUN_Test_Rig'].data.bones[b.name].matrix_local for b in r.data.bones)
    result['no_scale_tracks']=not any(c.data_path.endswith('scale') for c in B['H']['curves'](bpy.data.actions['LowerBody_Recovery_Test']))
    result['root_static']=all(abs(c.evaluate(1)-c.evaluate(B['END']))<1e-7 and max(k.co.y for k in c.keyframe_points)-min(k.co.y for k in c.keyframe_points)<1e-7 for c in B['H']['curves'](bpy.data.actions['LowerBody_Recovery_Test']) if '"Root"' in c.data_path)
    s.frame_set(18);s.camera=bpy.data.objects['LB_THREE_QUARTER']
    (OUT/'validation.json').write_text(json.dumps(result,indent=2))
    return {k:v for k,v in result.items() if k!='frames'}

if __name__=='__main__':
    result=run();print(json.dumps(result,indent=2))
