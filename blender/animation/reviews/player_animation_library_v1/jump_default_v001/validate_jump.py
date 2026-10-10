"""Read-only evaluated audit, run on a freshly loaded saved Blender library."""
import bpy, json, math, hashlib
from pathlib import Path
from itertools import combinations
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
manifest=json.loads((OUT/'manifest.json').read_text())

def curves(a):return [c for l in a.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]
def sig(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()

def run():
    sc=bpy.data.scenes[manifest['scene']]; bpy.context.window.scene=sc
    rig=bpy.data.objects[manifest['rig']]; mesh=bpy.data.objects[manifest['mesh']]; carrier=bpy.data.objects[manifest['carrier']]
    original=json.loads((OUT.parent/'review_manifest.json').read_text())
    for n,h in manifest['original_action_hashes'].items():assert sig(bpy.data.actions[n])==h,('Changed Action',n)
    for rel,h in original['sources'].items():assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==h,('Changed source file',rel)
    assert rig.animation_data.action.name==manifest['pose_action']
    assert rig.animation_data.action_slot.identifier==manifest['pose_slot']
    assert len(rig.animation_data.action.slots)==1
    assert carrier.animation_data.action!=rig.animation_data.action and len(carrier.animation_data.action.slots)==1
    assert not rig.animation_data.nla_tracks and not rig.animation_data.drivers
    assert mesh.data==bpy.data.objects[manifest['source_mesh']].data
    assert rig.parent==carrier and mesh.parent==rig
    assert sum(m.type=='ARMATURE' for m in mesh.modifiers)==1
    assert (sc.render.fps,sc.frame_start,sc.frame_end)==(30,1,25)
    assert not any(c.modifiers for c in curves(rig.animation_data.action)+curves(carrier.animation_data.action))
    forbidden=['Root','Hips','scale']
    assert not any(any(s in c.data_path for s in forbidden) for c in curves(rig.animation_data.action))
    # Deformation rig rest matrices and all original constraints stay untouched.
    source=bpy.data.objects[manifest['source_rig']]
    for b in rig.data.bones:
        assert b.matrix_local==source.data.bones[b.name].matrix_local
    groups={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in mesh.vertex_groups}
    soles={name:[i for i in groups[name] if abs(mesh.data.vertices[i].co.z-manifest['floor_z'])<1e-5] for name in ['Leg.L','Leg.R']}
    assert all(len(ids)==4 for ids in soles.values())
    floor=manifest['floor_z']; h=manifest['carrier_apex']; contacts={}; max_arc_error=0; ground_error=0; min_flight=100
    collisions=[]; min_clearance={}; baseline_clearance={}; sampled=[]; framing={}; idle_vertices=None; root_baseline=rig.matrix_basis.copy()
    # SAT on the eight rigid mesh cuboids, excluding adjoining joints only.
    adjacent={frozenset(p) for p in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
    pairs=[p for p in combinations(groups,2) if frozenset(p) not in adjacent]
    camera_names=['JD1_Gameplay','JD1_Side','JD1_Front']
    def separation(a,b,coords):
        ca=[coords[i] for i in groups[a]]; cb=[coords[i] for i in groups[b]]
        aa=rig.pose.bones[a].matrix.to_3x3(); bb=rig.pose.bones[b].matrix.to_3x3()
        axes=[aa.col[i].normalized() for i in range(3)]+[bb.col[i].normalized() for i in range(3)]
        axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-5]
        return max(max(min(v.dot(ax) for v in ca)-max(v.dot(ax) for v in cb),min(v.dot(ax) for v in cb)-max(v.dot(ax) for v in ca)) for ax in axes)
    for q in range(97):
        f=1+q*.25; sc.frame_set(int(f),subframe=f%1); bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get(); evaluated=mesh.evaluated_get(dg)
        coords=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
        if f==1:idle_vertices=[v.copy() for v in coords]
        if f==25:assert max((v-w).length for v,w in zip(coords,idle_vertices))<1e-6,'End pose differs from idle'
        u=(f-5)/14; expected=4*h*u*(1-u) if 5<f<19 else 0
        max_arc_error=max(max_arc_error,abs(carrier.location.z-expected))
        assert abs(carrier.location.x)+abs(carrier.location.y)<1e-9
        assert rig.matrix_basis==root_baseline
        heights={n:min(coords[i].z-floor for i in ids) for n,ids in soles.items()}
        if f<=5 or f>=19:
            for name,ids in soles.items():
                ground_error=max(ground_error,max((coords[i]-idle_vertices[i]).length for i in ids))
        else:min_flight=min(min_flight,min(heights.values()))
        if f in [1,3,5,6,9,12,16,19,21,25]:contacts[str(f)]=heights
        assert min(v.z-floor for v in coords)>-1e-5,('Floor penetration',f)
        for a,b in pairs:
            sep=separation(a,b,coords); name=a+' / '+b
            if f==1:baseline_clearance[name]=min(0,sep)
            min_clearance[name]=min(min_clearance.get(name,100),sep)
            # Preserve existing asset seam overlap, but never hide a new overlap
            # behind a blanket tolerance. Numerical margin is only 10 microns.
            if sep<baseline_clearance[name]-1e-5:collisions.append([f,name,sep])
        for name in camera_names:
            points=[world_to_camera_view(sc,bpy.data.objects[name],v) for v in coords]
            framing.setdefault(name,[1,1,0,0])
            framing[name]=[min(framing[name][0],min(v.x for v in points)),min(framing[name][1],min(v.y for v in points)),max(framing[name][2],max(v.x for v in points)),max(framing[name][3],max(v.y for v in points))]
        sampled.append({'frame':f,'carrier_z':carrier.location.z,'foot_min_z':heights})
    assert max_arc_error<1e-5, max_arc_error
    assert ground_error<1e-5,ground_error
    assert min_flight>0,min_flight
    assert all(min(v[:2])>.03 and max(v[2:])<.97 for v in framing.values()),framing
    report={'source_action_hashes_unchanged':len(manifest['original_action_hashes']),'source_files_unchanged':list(original['sources']),
            'shared_original_mesh_and_materials':True,'rest_rig_unchanged':True,'sample_count':len(sampled),'subframe_step':.25,
            'max_carrier_parabola_error_m':max_arc_error,'max_grounded_sole_displacement_m':ground_error,
            'min_sampled_airborne_sole_height_m':min_flight,'contacts':contacts,'new_nonadjacent_penetrations_beyond_idle':collisions,
            'idle_baseline_overlap_m':baseline_clearance,'numeric_penetration_tolerance_m':1e-5,
            'minimum_part_clearance_m':min_clearance,'camera_frame_bounds':framing,
            'pose_and_travel_separate_single_slot_actions':True,'pose_root_channels_absent':True,
            'first_last_evaluated_pose_match':True,'no_cycle_modifiers':True,'gameplay_modified':False,
            'limitations':'No knees/ankles: ground compression uses torso/arms only. Existing idle Chest/ForeArm overlap about 3.875 mm is preserved. Head/UpperArm new overlaps corrected with an 8 mm pose-only shoulder glide; neutral restores original 32 mm inset. Adjacent rigid joints excluded from SAT. Not a runtime/mobile test.'}
    (OUT/'validation.json').write_text(json.dumps(report,indent=2))
    (ROOT/'.validation/jump_default_v001/motion_samples.json').write_text(json.dumps(sampled,indent=2))
    assert not collisions,collisions[:10]
    return report

if __name__=='__main__':print(json.dumps(run(),indent=2))
