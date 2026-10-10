"""Read-only evaluated audit of the three new jumps on a saved Blender library."""
import bpy, json, hashlib
from pathlib import Path
from itertools import combinations
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent
M=json.loads((OUT/'manifest.json').read_text())
def curves(a):return [c for l in a.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]
def sig(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
def evaluate(mesh):
    bpy.context.view_layer.update();e=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [e.matrix_world@v.co for v in e.data.vertices]
def run():
    for n,h in M['preserved_action_hashes'].items():assert sig(bpy.data.actions[n])==h,n
    for n,t in M['old_scene_timing'].items():
        s=bpy.data.scenes[n];assert [s.render.fps,s.render.fps_base,s.frame_start,s.frame_end]==t,n
    sr=bpy.data.objects[M['source_rig']];sm=bpy.data.objects[M['source_mesh']]
    groups={g.name:[v.index for v in sm.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in sm.vertex_groups}
    soles={n:[i for i in groups[n] if abs(sm.data.vertices[i].co.z)<1e-5] for n in ['Leg.L','Leg.R']}
    adjacent={frozenset(p) for p in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
    pairs=[p for p in combinations(groups,2) if frozenset(p) not in adjacent]
    def separation(rig,a,b,coords):
        ca=[coords[i] for i in groups[a]];cb=[coords[i] for i in groups[b]]
        aa=rig.pose.bones[a].matrix.to_3x3();bb=rig.pose.bones[b].matrix.to_3x3()
        axes=[aa.col[i].normalized() for i in range(3)]+[bb.col[i].normalized() for i in range(3)]
        axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-5]
        return max(max(min(v.dot(ax) for v in ca)-max(v.dot(ax) for v in cb),min(v.dot(ax) for v in cb)-max(v.dot(ax) for v in ca)) for ax in axes)
    # Use original neutral, never a moving new clip, as the overlap baseline.
    old=bpy.data.scenes['JUMP_DEFAULT_V001_REVIEW'];bpy.context.window.scene=old;old.frame_set(1)
    idle=evaluate(sm)
    baseline={a+' / '+b:min(0,separation(sr,a,b,idle)) for a,b in pairs}
    report={'preserved_actions':len(M['preserved_action_hashes']),'old_scene_timing_unchanged':True,'idle_overlap_baseline_m':baseline,'cases':{}}
    failures=[]
    for kind,c in M['cases'].items():
        sc=bpy.data.scenes[c['scene']];bpy.context.window.scene=sc
        rig=bpy.data.objects[c['rig']];mesh=bpy.data.objects[c['mesh']];carrier=bpy.data.objects[c['carrier']]
        assert mesh.data==sm.data and mesh.parent==rig and rig.parent==carrier
        assert rig.animation_data.action.name==c['action'] and rig.animation_data.action_slot.identifier==c['slot']
        assert len(rig.animation_data.action.slots)==1 and len(carrier.animation_data.action.slots)==1
        assert not rig.animation_data.nla_tracks and not rig.animation_data.drivers
        assert not any(x.modifiers for x in curves(rig.animation_data.action)+curves(carrier.animation_data.action))
        assert not any(any(n in x.data_path for n in ['Root','Hips','scale']) for x in curves(rig.animation_data.action))
        assert all(b.matrix_local==sr.data.bones[b.name].matrix_local for b in rig.data.bones)
        result={'samples':0,'min_floor_z_m':100,'max_ground_gap_m':0,'min_air_z_m':100,'support_y_drift_m':0,'camera_bounds':{},'new_overlaps':[],'max_arc_error_m':0}
        support={};first=None;basis=rig.matrix_basis.copy()
        for q in range((c['end']-1)*128+1):
            f=1+q/128;sc.frame_set(int(f),subframe=f%1);coords=evaluate(mesh)
            low=min(v.z for v in coords);result['samples']+=1
            result['min_floor_z_m']=min(result['min_floor_z_m'],low)
            if f<=c['take'] or f>=c['land']:
                result['max_ground_gap_m']=max(result['max_ground_gap_m'],abs(low-.0001))
                n='Leg.L' if f<=c['take'] else 'Leg.R';phase='pre' if f<=c['take'] else 'post'
                sy=sum(coords[i].y for i in soles[n])/4;support.setdefault(phase,sy)
                result['support_y_drift_m']=max(result['support_y_drift_m'],abs(sy-support[phase]))
            else:
                result['min_air_z_m']=min(result['min_air_z_m'],low)
                u=(f-c['take'])/(c['land']-c['take'])
                expected=(1-u)*c['launch_carrier_z']+u*c['contact_carrier_z']+4*c['height']*u*(1-u)
                result['max_arc_error_m']=max(result['max_arc_error_m'],abs(carrier.location.z-expected))
            assert rig.matrix_basis==basis
            assert all(abs(p.scale.x-1)+abs(p.scale.y-1)+abs(p.scale.z-1)<1e-7 for p in rig.pose.bones)
            if f==1:first=[v.copy() for v in coords]
            if kind=='stationary' and f in [1,c['end']]:
                assert max((v-carrier.location-w).length for v,w in zip(coords,idle))<1e-6,'Neutral differs'
            if q%32==0:
                for a,b in pairs:
                    sep=separation(rig,a,b,coords)
                    if sep<baseline[a+' / '+b]-1e-5:result['new_overlaps'].append([f,a,b,sep])
                for name in c['cameras'].values():
                    pts=[world_to_camera_view(sc,bpy.data.objects[name],v) for v in coords]
                    bounds=result['camera_bounds'].setdefault(name,[1,1,0,0])
                    bounds[:]=[min(bounds[0],min(v.x for v in pts)),min(bounds[1],min(v.y for v in pts)),max(bounds[2],max(v.x for v in pts)),max(bounds[3],max(v.y for v in pts))]
        # Rigid toe/heel corner changes introduce a sub-millimetre interpolation
        # gap. Report the measured error; allow at most 0.3 mm beyond the margin.
        checks={'no_floor_penetration':result['min_floor_z_m']>=-1e-5,'ground_clearance':result['max_ground_gap_m']<.0003,
                'support_center_stable':result['support_y_drift_m']<.00005,'airborne':result['min_air_z_m']>0,
                'carrier_curve':result['max_arc_error_m']<.00005,'no_new_overlap':not result['new_overlaps'],
                'framing':all(min(v[:2])>.025 and max(v[2:])<.975 for v in result['camera_bounds'].values())}
        result['checks']=checks;report['cases'][kind]=result
        failures.extend((kind,n) for n,passed in checks.items() if not passed)
    report['failures']=failures
    (OUT/'validation.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:{n:v for n,v in r.items() if n not in ['camera_bounds','new_overlaps']} for k,r in report['cases'].items()},indent=2))
    assert not failures,failures
if __name__=='__main__':run()
