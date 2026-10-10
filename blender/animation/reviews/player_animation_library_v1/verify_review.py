"""Fresh-open source/key preservation and selectable catalog audit."""
import bpy, json, math, hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
m=json.loads((OUT/'review_manifest.json').read_text(encoding='utf-8'))
def curves(a):return [c for l in a.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]
def sig(a):
    return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
for rel,h in m['sources'].items():assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==h,rel
for n,h in m['source_action_hashes'].items():assert sig(bpy.data.actions[n])==h,n
exec(compile((OUT/'review_controls.py').read_text(encoding='utf-8'),'review_controls.py','exec'))
results=[]
for e in m['catalog']:
    bpy.ops.player_review.select(clip_id=e['id'])
    sc=bpy.context.scene
    assert (sc.frame_start,sc.frame_end,sc.render.fps)==(e['start'],e['end'],e['fps']),e['label']
    if 'actor' in e:
        actor=m['actors'][e['actor']]
        visible=[k for k,a in m['actors'].items() if not bpy.data.collections[a['collection']].hide_viewport]
        assert visible==[e['actor']],(e['label'],visible)
        rig=bpy.data.objects[actor['rig']]
        body=[bpy.data.objects[n] for n in actor['objects'] if bpy.data.objects[n].type=='MESH']
        if any(kind in e['label'] for kind in ['Pistol','Rifle','Shotgun']) or e['actor']=='Combat':
            weapons=[o for o in body if not any(md.type=='ARMATURE' for md in o.modifiers)]
            assert weapons,(e['label'],'Missing weapon geometry')
        poses=[]
        for f in [e['start'],(e['start']+e['end'])//2,e['end']]:
            sc.frame_set(f);bpy.context.view_layer.update()
            poses.append(tuple(v for n in ['Leg.L','Leg.R'] for row in rig.pose.bones[n].matrix for v in row))
            for p in rig.pose.bones:
                assert all(math.isfinite(v) for row in p.matrix for v in row),(e['label'],p.name)
        if e['group'] in ['Locomotion','Combat Strafe'] and not e['label'].startswith('Idle'):
            assert any(abs(a-b)>1e-4 for a,b in zip(poses[0],poses[1])),(e['label'],'No evaluated leg motion')
        if e.get('action'):assert rig.animation_data.action.name==e['action']
    results.append({'label':e['label'],'selection_valid':True})
missing=[im.filepath for im in bpy.data.images if im.source=='FILE' and not im.packed_file and im.filepath and not Path(bpy.path.abspath(im.filepath)).exists()]
assert not missing,missing
assert bpy.data.texts.get('START_HERE_review_controls.py')
default=next(e for e in m['catalog'] if e['label']=='Walk / Rifle')
bpy.ops.player_review.select(clip_id=default['id'])
bpy.context.scene.frame_set(5)
bpy.context.scene.render.resolution_percentage=65
bpy.context.scene.render.filepath=str(OUT/'review_preview.png')
bpy.ops.render.render(write_still=True)
report={'source_files_unchanged':True,'source_actions_unchanged':len(m['source_action_hashes']),
        'catalog_selections_passed':len(results),'missing_images':missing,'results':results,
        'render':str(OUT/'review_preview.png'),'gameplay_modified':False}
(OUT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='results'}))
