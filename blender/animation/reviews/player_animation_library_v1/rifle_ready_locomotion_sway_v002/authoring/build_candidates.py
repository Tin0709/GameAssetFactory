"""Copy the approved Actions; author only upper-body twist / rifle overlap."""
import bpy, sys, json, math, hashlib, time
from pathlib import Path
from mathutils import Vector
R = next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists())
O = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R/'blender/animation/showcase'))
sys.path.insert(0, str(O/'authoring'))
import gaf_animation_library as ui
from holding_sway import apply, SETTINGS

mf = json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text())
r = bpy.data.objects[ui.RIG]; s = bpy.context.scene
rest = {b.name:b.matrix_local.copy() for b in r.data.bones}
palm = Vector((0, r.data.bones['ForeArm.L'].length*.78, 0))
before = {a.name:ui.action_signature(a) for a in bpy.data.actions}
changed = {'Chest': ['rotation_quaternion'], 'Head': ['rotation_quaternion']}
names = {'Walk':'Rifle_Ready_Walk_ActionsStyle_v0012', 'Run':'Rifle_Ready_Run_ActionsStyle_v002'}
entries=[]; reports=[]; out=O/'rifle_ready_locomotion_sway_v002.blend'
for kind,name in names.items():
    start=time.time(); old='Rifle_Ready_'+kind+'_ActionsStyle_v001'
    e=next(e for e in mf['animations'] if e['action']==old)
    assert e['status']=='approved' and before[old]==e['action_sha256']
    assert hashlib.sha256((R/e['source']).read_bytes()).hexdigest()==e['source_sha256']
    assert name not in bpy.data.actions
    base=bpy.data.actions[old]; frames=sorted({float(k.co.x) for c in ui.curves(base) for k in c.keyframe_points})
    r.animation_data.action=base;r.animation_data.action_slot=base.slots[0];s['gaf_library_last_action']=old
    values={n:{p:[] for p in ps} for n,ps in changed.items()};previous={}
    metrics={'head_world_matrix_error':0.,'chest_bounce_position_error_m':0.,'right_shoulder_chest_local_error_m':0.,'left_shoulder_chest_local_shift_m':0.}
    for j,f in enumerate(frames):
        s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        B={b.name:b.matrix.copy() for b in r.pose.bones}
        M=apply(kind,(f-1)/30.,e,B,rest,palm)
        metrics['head_world_matrix_error']=max(metrics['head_world_matrix_error'],max(abs(M['Head'][a][b]-B['Head'][a][b]) for a in range(4) for b in range(4)))
        metrics['chest_bounce_position_error_m']=max(metrics['chest_bounce_position_error_m'],(M['Chest'].translation-B['Chest'].translation).length)
        for side in ['L','R']:
            err=(M['Chest'].inverted()@M['UpperArm.'+side].translation-B['Chest'].inverted()@B['UpperArm.'+side].translation).length
            key='right_shoulder_chest_local_error_m' if side=='R' else 'left_shoulder_chest_local_shift_m'
            metrics[key]=max(metrics[key],err)
        for n,props in changed.items():
            bone=r.data.bones[n]
            local=bone.convert_local_to_pose(M[n],rest[n],invert=True,parent_matrix=M[bone.parent.name],parent_matrix_local=rest[bone.parent.name])
            pos,q,scale=local.decompose()
            if n in previous and q.dot(previous[n])<0:q.negate()
            previous[n]=q.copy()
            for prop in props:values[n][prop].append(list(pos if prop=='location' else q))
        if j%6000==0:print(kind,'sample',j,'/',len(frames),flush=True)
    act=base.copy();act.name=name;act.use_fake_user=True
    for c in ui.curves(act):
        match=next(((n,p) for n,ps in changed.items() for p in ps if c.data_path==r.pose.bones[n].path_from_id(p)),None)
        if match is None:continue
        n,p=match;ys=[row[c.array_index] for row in values[n][p]]
        c.keyframe_points.clear();c.keyframe_points.add(len(frames));c.keyframe_points.foreach_set('co',[x for f,y in zip(frames,ys) for x in (f,y)])
        for k in c.keyframe_points:k.interpolation='LINEAR'
        c.update()
    # Verify isolation by comparing every untouched curve, including all leg,
    # root, hip, spine, scale, forearm and timing data, byte-for-byte in RNA.
    def curve_data(c):return [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]
    base_curves={(c.data_path,c.array_index):c for c in ui.curves(base)};count=0
    for c in ui.curves(act):
        if any(c.data_path==r.pose.bones[n].path_from_id(p) for n,ps in changed.items() for p in ps):continue
        assert curve_data(c)==curve_data(base_curves[c.data_path,c.array_index]);count+=1
    act['research_only']=True;act['production_eligible']=False;act['visual_base']=old
    entry=dict(e);entry.update(action=name,source=out.relative_to(R).as_posix(),action_sha256=ui.action_signature(act),status='pending',
        approval_note='Pending Blender review, requested2026-10-18. Existing approved gameplay landing carry informs this upper-body sway refinement; no gameplay integration.',
        refinement_base=old,holding_sway=SETTINGS[kind],
        adaptation_note='Chest-led gait yaw with unchanged world-space head observation. Original arm, rifle-relative grip, support overlap and waist-roll curves are untouched. New authored adaptation over the approved research bake, not an additional source crossbow clip.')
    entry.pop('source_sha256',None);ui.validate_action(act,entry,r);entries.append(entry)
    reports.append({'action':name,'base':old,'samples':len(frames),'untouched_curves_exact':count,'metrics':metrics,'seconds':time.time()-start})
    print('BUILT',json.dumps(reports[-1]),flush=True)
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
r.animation_data.action=bpy.data.actions[names['Run']];r.animation_data.action_slot=r.animation_data.action.slots[0];s['gaf_library_last_action']=r.animation_data.action.name
s.frame_start=1;s.frame_end=2700;s.render.fps=30;s.render.fps_base=1.;s.frame_set(1);s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
sha=hashlib.sha256(out.read_bytes()).hexdigest()
for e in entries:e['source_sha256']=sha
(O/'entries.json').write_text(json.dumps(entries,indent=2)+'\n')
(O/'build_validation.json').write_text(json.dumps({'passed':True,'original_actions_unchanged':len(before),'modified_bone_properties':changed,'reports':reports},indent=2)+'\n')
