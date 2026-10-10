"""Check evaluated geometry between keys and preserve all pre-existing data."""
import bpy,json,runpy,hashlib,math,struct
from pathlib import Path
from itertools import combinations
from bpy_extras.object_utils import world_to_camera_view

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
TMP=ROOT/'.validation/expressive_arm_motion_test'

def run():
    h=runpy.run_path(str(OUT/'build_test.py'))['HELPER']
    s=bpy.data.scenes['EXPRESSIVE_ARM_MOTION_REVIEW'];bpy.context.window.scene=s
    r=bpy.data.objects['EAM_Player_Rig'];m=bpy.data.objects['EAM_Player_Mesh']
    groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups}
    groups={k:v for k,v in groups.items() if v}
    adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
    pairs=[x for x in combinations(groups,2) if frozenset(x) not in adjacent]
    def coords(f):
        s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
        e=m.evaluated_get(bpy.context.evaluated_depsgraph_get())
        return [e.matrix_world@v.co for v in e.data.vertices]
    def sep(a,b,pts):
        axes=[(r.matrix_world@r.pose.bones[n].matrix).to_3x3().col[i].normalized() for n in [a,b] for i in range(3)]
        axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
        va,vb=[[pts[i] for i in groups[n]] for n in [a,b]]
        return max(max(min(p.dot(ax) for p in va)-max(p.dot(ax) for p in vb),min(p.dot(ax) for p in vb)-max(p.dot(ax) for p in va)) for ax in axes)
    base=coords(1)
    distances=[(a,b,(base[a]-base[b]).length) for ids in groups.values() for a,b in combinations(ids,2)]
    overlaps={a+'/'+b:min(0,sep(a,b,base)) for a,b in pairs}
    seams=[(a,b) for side in ['L','R'] for a in groups['UpperArm.'+side] for b in groups['ForeArm.'+side] if (m.data.vertices[a].co-m.data.vertices[b].co).length<1e-7]
    report={'samples':185,'max_segment_distance_error_m':0,'max_elbow_seam_gap_m':0,'max_foot_drift_m':0,'new_nonadjacent_overlaps':[],'baseline_overlaps_m':overlaps,'camera_bounds':{},'hand_trajectories':[]}
    for i in range(185):
        f=1+i/8;pts=coords(f)
        report['max_segment_distance_error_m']=max(report['max_segment_distance_error_m'],max(abs((pts[a]-pts[b]).length-d) for a,b,d in distances))
        report['max_elbow_seam_gap_m']=max(report['max_elbow_seam_gap_m'],max((pts[a]-pts[b]).length for a,b in seams))
        report['max_foot_drift_m']=max(report['max_foot_drift_m'],max((pts[j]-base[j]).length for n in ['Leg.L','Leg.R'] for j in groups[n]))
        for a,b in pairs:
            v=sep(a,b,pts)
            if v<overlaps[a+'/'+b]-1e-5:report['new_nonadjacent_overlaps'].append([f,a,b,v])
        for view in ['FRONT','THREE_QUARTER']:
            q=[world_to_camera_view(s,bpy.data.objects['EAM_'+view],p) for p in pts]
            bounds=report['camera_bounds'].setdefault(view,[1,1,0,0])
            bounds[:]=[min(bounds[0],min(p.x for p in q)),min(bounds[1],min(p.y for p in q)),max(bounds[2],max(p.x for p in q)),max(bounds[3],max(p.y for p in q))]
        if i%8==0:
            report['hand_trajectories'].append({'frame':f,**{side:list(r.matrix_world@r.pose.bones['ForeArm.'+side].tail) for side in ['L','R']}})
    end=coords(24);report['neutral_return_error_m']=max((a-b).length for a,b in zip(base,end))
    before=json.loads((TMP/'original_data.json').read_text())
    report['changed_originals']=h['compare_originals'](before)
    manifest=json.loads((OUT/'manifest.json').read_text())
    preservation=runpy.run_path(str(ROOT/'blender/environment/studies/dungeons_ground_style_v2/flower_preservation.py'))
    rebased=[]
    for group,name in report['changed_originals']:
        if group!='images' or name not in bpy.data.images:continue
        im=bpy.data.images[name]
        original_path=bpy.path.relpath(bpy.path.abspath(im.filepath),start=str(Path(manifest['source_library']).parent))
        pixels=list(im.pixels)
        value=preservation['digest']({'size':list(im.size),'filepath':original_path,'source':im.source,'colorspace':im.colorspace_settings.name,'pixels':hashlib.sha256(struct.pack('<'+'f'*len(pixels),*pixels)).hexdigest(),'packed':hashlib.sha256(im.packed_file.data).hexdigest() if im.packed_file else None})
        if value==before['images'][name]:rebased.append(name)
    report['verified_image_path_rebases_only']=rebased
    report['unexpected_original_changes']=[x for x in report['changed_originals'] if x[0]!='images' or x[1] not in rebased]
    report['original_library_hash_unchanged']=hashlib.sha256(Path(manifest['source_library']).read_bytes()).hexdigest()==manifest['source_sha256']
    report['old_action_count']=len(before['actions']);report['total_actions']=len(bpy.data.actions)
    report['same_mesh_datablock']=m.data==bpy.data.objects['JD1_Player_Mesh'].data
    report['same_rest_matrices']=all(b.matrix_local==bpy.data.objects['JD1_Player_Rig'].data.bones[b.name].matrix_local for b in r.data.bones)
    report['no_nla_or_drivers']=not r.animation_data.nla_tracks and not r.animation_data.drivers
    report['action_range']=list(r.animation_data.action.frame_range)
    (OUT/'validation.json').write_text(json.dumps(report,indent=2))
    s.frame_set(14);s.camera=bpy.data.objects['EAM_THREE_QUARTER']
    return {k:v for k,v in report.items() if k not in ['hand_trajectories','baseline_overlaps_m','new_nonadjacent_overlaps']}
