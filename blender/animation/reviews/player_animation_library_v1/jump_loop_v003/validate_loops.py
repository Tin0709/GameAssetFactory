"""Fresh-load loop continuity, moving-footwork, preservation and geometry checks."""
import bpy,json,math,hashlib
from pathlib import Path
from itertools import combinations
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;M=json.loads((OUT/'manifest.json').read_text())
def curves(a):return [c for l in a.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]
def sig(a):return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
def evaluate(mesh):
    bpy.context.view_layer.update();e=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [e.matrix_world@v.co for v in e.data.vertices]
def run():
    for n,h in M['previous_action_hashes'].items():assert sig(bpy.data.actions[n])==h,n
    for n,t in M['previous_scene_timing'].items():
        sc=bpy.data.scenes[n];assert [sc.render.fps,sc.render.fps_base,sc.frame_start,sc.frame_end]==t,n
    sr=bpy.data.objects['JD1_Player_Rig'];sm=bpy.data.objects['JD1_Player_Mesh']
    groups={g.name:[v.index for v in sm.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in sm.vertex_groups}
    adjacent={frozenset(p) for p in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
    pairs=[p for p in combinations(groups,2) if frozenset(p) not in adjacent]
    def separation(rig,a,b,coords):
        ca=[coords[i] for i in groups[a]];cb=[coords[i] for i in groups[b]]
        aa=rig.pose.bones[a].matrix.to_3x3();bb=rig.pose.bones[b].matrix.to_3x3()
        axes=[aa.col[i].normalized() for i in range(3)]+[bb.col[i].normalized() for i in range(3)]
        axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-5]
        return max(max(min(v.dot(ax) for v in ca)-max(v.dot(ax) for v in cb),min(v.dot(ax) for v in cb)-max(v.dot(ax) for v in ca)) for ax in axes)
    old=bpy.data.scenes['JUMP_DEFAULT_V001_REVIEW'];bpy.context.window.scene=old;old.frame_set(1);idle=evaluate(sm)
    baseline={a+' / '+b:min(0,separation(sr,a,b,idle)) for a,b in pairs}
    report={'preserved_actions':len(M['previous_action_hashes']),'original_scene_timing_unchanged':True,'baseline_overlap_m':baseline,'cases':{}}
    failures=[]
    for kind,c in M['cases'].items():
        sc=bpy.data.scenes[c['scene']];bpy.context.window.scene=sc
        rig=bpy.data.objects[c['rig']];mesh=bpy.data.objects[c['mesh']];carrier=bpy.data.objects[c['carrier']];action=rig.animation_data.action
        assert mesh.data==sm.data and mesh.parent==rig and rig.parent==carrier
        assert all(b.matrix_local==sr.data.bones[b.name].matrix_local for b in rig.data.bones)
        assert len(action.slots)==1 and action.name==c['action']
        assert not rig.animation_data.nla_tracks and not rig.animation_data.drivers
        assert not any('Root' in x.data_path or 'scale' in x.data_path for x in curves(action))
        prefix='JL3_'+kind.upper()
        # Lighting must remain identical as the review travels and wraps.
        light_offsets={}
        for t in [0,period if False else c['period'],2*c['period']]:
            sc.frame_set(1+t);bpy.context.view_layer.update()
            for suffix in ['Key','Fill','Rim']:
                ob=bpy.data.objects[prefix+'_'+suffix]
                offset=ob.matrix_world.translation-carrier.matrix_world.translation
                if suffix not in light_offsets:light_offsets[suffix]=offset.copy()
                else:assert (offset-light_offsets[suffix]).length<2e-6,('Lighting changes across repeat',suffix)
        error=0;velerror=0;period=c['period']
        for x in curves(action):
            assert len(x.modifiers)==1 and x.modifiers[0].type=='CYCLES'
            error=max(error,abs(x.evaluate(1)-x.evaluate(1+period)))
            a=x.keyframe_points[0];b=x.keyframe_points[-1]
            velocity_a=(a.handle_right.y-a.co.y)/(a.handle_right.x-a.co.x)
            velocity_b=(b.co.y-b.handle_left.y)/(b.co.x-b.handle_left.x)
            velerror=max(velerror,abs(velocity_a-velocity_b))
        r={'channel_endpoint_error':error,'channel_tangent_error_per_frame':velerror,'min_floor_z_m':100,
           'max_ground_gap_m':0,'new_overlaps':[],'camera_bounds':{},'repeat_pose_error_m':0,'samples':0}
        reference={};air_angles=[];bodybasis=rig.matrix_basis.copy()
        for q in range(3*period*8+1):
            t=q/8;f=1+t;sc.frame_set(int(f),subframe=f%1);coords=evaluate(mesh);local=[v-carrier.matrix_world.translation for v in coords]
            low=min(v.z for v in coords);r['min_floor_z_m']=min(r['min_floor_z_m'],low);r['samples']+=1
            phase=t%period
            if phase<=c['take'] or phase>=c['land']:r['max_ground_gap_m']=max(r['max_ground_gap_m'],low)
            elif t<period:air_angles.append(math.degrees(rig.pose.bones['Leg.R'].rotation_euler.x))
            k=q%(period*8)
            if q<period*8:reference[k]=local
            else:r['repeat_pose_error_m']=max(r['repeat_pose_error_m'],max((v-w).length for v,w in zip(local,reference[k])))
            assert rig.matrix_basis==bodybasis and all(tuple(p.scale)==(1.,1.,1.) for p in rig.pose.bones)
            if q%2==0:
                for a,b in pairs:
                    sep=separation(rig,a,b,coords)
                    if sep<baseline[a+' / '+b]-1e-5:r['new_overlaps'].append([f,a,b,sep])
                for name in c['cameras'].values():
                    pts=[world_to_camera_view(sc,bpy.data.objects[name],v) for v in coords]
                    bounds=r['camera_bounds'].setdefault(name,[1,1,0,0])
                    bounds[:]=[min(bounds[0],min(v.x for v in pts)),min(bounds[1],min(v.y for v in pts)),max(bounds[2],max(v.x for v in pts)),max(bounds[3],max(v.y for v in pts))]
        r['airborne_leg_sweep_deg']=max(air_angles)-min(air_angles)
        checks={'loop_position':error<1e-6,'loop_tangent':velerror<1e-5,'three_repeats_identical':r['repeat_pose_error_m']<3e-6,
                'no_floor_penetration':r['min_floor_z_m']>=-1e-5,'ground_clearance':r['max_ground_gap_m']<.004,
                'air_footwork_continues':r['airborne_leg_sweep_deg']>40,'no_new_overlap':not r['new_overlaps'],
                'framing':all(min(v[:2])>.025 and max(v[2:])<.975 for v in r['camera_bounds'].values())}
        r['checks']=checks;report['cases'][kind]=r;failures.extend((kind,n) for n,ok in checks.items() if not ok)
    report['failures']=failures;(OUT/'validation.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:{n:v for n,v in c.items() if n not in ['new_overlaps','camera_bounds']} for k,c in report['cases'].items()},indent=2))
    assert not failures,failures
if __name__=='__main__':run()
