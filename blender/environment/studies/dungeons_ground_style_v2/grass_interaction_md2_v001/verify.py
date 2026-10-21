"""Essential native contracts, source preservation, field recovery and UI round trips."""
import bpy
import hashlib
import json
import math
import sys
import time
from pathlib import Path
import numpy as np
from mathutils import Vector

D=Path(__file__).resolve().parent;P=D.parent;R=D.parents[4];E=R/'.validation/md2_grass_interaction_v001'
sys.path[:0]=[str(D),str(P),str(P/'tall_grass_md2_v001'),str(P/'grass_wind_md2_v001')]
from flower_preservation import snapshot, digest, rna_values, node_content, scalar_copy
from check_field import check
from field import CONTROLS
import runtime
import grass_library_ui as static_ui
import interaction_review_ui as ui
import wind_review_ui

def stable_snapshot():
    s=bpy.context.scene;old=bpy.context.view_layer.name;tmp=s.view_layers.new('__Interaction_Preservation_Eval')
    def include(lc):
        lc.exclude=False;lc.hide_viewport=False
        for c in lc.children:include(c)
    include(tmp.layer_collection);bpy.context.window.view_layer=tmp
    for o in list(tmp.objects):o.hide_set(False,view_layer=tmp)
    s.update_tag();s.frame_set(78);tmp.update()
    bpy.context.evaluated_depsgraph_get().update()
    # First establish the new graph, THEN propagate all original matrix caches.
    # Tagging before graph creation does not normalize newly excluded Wind roots.
    for o in list(tmp.objects):o.update_tag(refresh={'OBJECT'})
    s.frame_set(78);tmp.update();result=snapshot()
    bpy.context.window.view_layer=s.view_layers[old];s.view_layers.remove(tmp);return result

def wind_fingerprint():
    info=json.loads(bpy.context.scene['md2_wind_review']);tree=bpy.data.node_groups['MD2_Grass_Wind_v001']
    objects={}
    for name in info['wind_objects']:
        o=bpy.data.objects[name];mod=o.modifiers['MD2_Grass_Wind_v001']
        drivers=[]
        for fc in o.animation_data.drivers:
            drivers.append((fc.data_path,fc.array_index,fc.driver.expression,[(v.name,v.type,[(t.id.name if t.id else None,t.data_path,t.transform_type,t.transform_space) for t in v.targets]) for v in fc.driver.variables]))
        attrs={}
        for attr in o.data.attributes:
            if attr.name.startswith('md2_wind_'):
                attrs[attr.name]=[list(d.vector) if hasattr(d,'vector') else d.value for d in attr.data]
        values={s.identifier:scalar_copy(mod.properties.inputs[s.identifier]['value']) for s in tree.interface.items_tree if s.item_type=='SOCKET' and s.in_out=='INPUT' and s.name!='Geometry'}
        objects[name]={'modifier_values':values,'drivers':drivers,'attributes':attrs}
    return digest({'tree':node_content(tree),'interface':[rna_values(s) for s in tree.interface.items_tree],
                   'props':dict(tree.items()),'objects':objects,'controller':dict(bpy.data.objects[info['controller']].items())})

target=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else E/'dungeons_ground_style_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(E/'before.blend'))
baseline=stable_snapshot();wind_before=wind_fingerprint()
baseline_rna={o.name:rna_values(o) for o in bpy.data.objects}
bpy.ops.wm.open_mainfile(filepath=str(target));scene=bpy.context.scene
actual=stable_snapshot();errors=[(g,n) for g,values in baseline.items() for n,val in values.items() if actual[g].get(n)!=val]
if errors:
    print('PRESERVATION_RNA_DIFFS',[(n,{k:[v,rna_values(bpy.data.objects[n]).get(k)] for k,v in baseline_rna[n].items() if v!=rna_values(bpy.data.objects[n]).get(k)}) for g,n in errors[:3] if g=='objects'],flush=True)
assert not errors,errors
assert wind_fingerprint()==wind_before,'Original Wind tree, controls, attributes, modifier values or drivers changed'
assert len(bpy.data.scenes)==1 and not len(bpy.data.actions)
static_ui.register();ui.select(bpy.context)
info=runtime.record();controller=bpy.data.objects[info['controller']]
grasses=[bpy.data.objects[n] for n in info['grass_objects']]
assert {o.name for o in bpy.context.view_layer.objects}=={o.name for o in bpy.data.collections[info['root']].all_objects}
assert all(len(o.modifiers)==2 and o.modifiers[0].node_group.name=='MD2_Grass_Wind_v001' and o.modifiers[1].node_group.name==info['group'] for o in grasses)
assert all(o.data==bpy.data.objects[n].data for o in grasses for n in json.loads(scene['md2_wind_review'])['masters'] if bpy.data.objects[n]['wind_source']==o['wind_source'])
numeric=check()
def pose(obj):
    dg=bpy.context.evaluated_depsgraph_get();dg.update();e=obj.evaluated_get(dg);mesh=e.to_mesh()
    result=np.array([list(v.co) for v in mesh.vertices]);e.to_mesh_clear();return result
def at(t):
    f=t*scene.render.fps/scene.render.fps_base;scene.frame_set(int(f),subframe=f%1.)
    runtime.update(scene,force=True);bpy.context.view_layer.update()
def control(key,value):
    controller[key]=value;controller.update_tag();bpy.context.view_layer.update();runtime.update(scene,force=True);bpy.context.view_layer.update()
def reset():
    for key,value in CONTROLS.items():controller[key]=value[0]
    controller.update_tag();runtime.update(scene,force=True);bpy.context.view_layer.update()
def err(a,b):return float(np.max(np.linalg.norm(a-b,axis=-1)))
root_error=width_error=maximum=0.;largest_contact=0.;contact_obj=None
for t in [2.,3.5,6.5,7.2,9.5,11.5,15.,19.]:
    at(t)
    for o in grasses:
        base=np.array([list(v.co) for v in o.data.vertices]);posed=pose(o)
        mask=np.array([d.value for d in o.data.attributes['md2_wind_t'].data])
        assert np.isfinite(posed).all()
        root_error=max(root_error,err(base[mask==0],posed[mask==0]))
        width_error=max(width_error,float(np.max(np.linalg.norm((posed[1::2]-posed[::2])-(base[1::2]-base[::2]),axis=-1))))
        maximum=max(maximum,err(base,posed))
    active={o.name:pose(o) for o in grasses};control('Player Interaction On/Off',False)
    for o in grasses:
        delta=err(active[o.name],pose(o))
        if delta>largest_contact:largest_contact=delta;contact_obj=o
    control('Player Interaction On/Off',True)
assert root_error<1e-7 and width_error<2e-6,(root_error,width_error)
assert .1<largest_contact<.8,(largest_contact,contact_obj)
o=contact_obj;at(7.2)
# Disabled output matches the ACTUAL original first modifier exactly.
control('Player Interaction On/Off',False);off=pose(o)
o.modifiers[1].show_viewport=False;bpy.context.view_layer.update();wind_only=pose(o)
o.modifiers[1].show_viewport=True;bpy.context.view_layer.update()
off_error=err(off,wind_only);assert off_error<1e-7,off_error
control('Player Interaction On/Off',True);control('Interaction Strength',0.)
zero_error=err(pose(o),wind_only);assert zero_error<1e-7,zero_error
reset();at(7.25);a=pose(o);at(18.);at(.5);at(7.25);scrub=err(a,pose(o));assert scrub<1e-7
# Stopped character has zero gait but retained proximity contact; Wind still moves.
at(11.5);stopped_a={q.name:pose(q) for q in grasses};proxy_a=bpy.data.objects[info['proxy']['root']].location.copy()
at(12.5);proxy_b=bpy.data.objects[info['proxy']['root']].location.copy()
assert (proxy_a-proxy_b).length<1e-7
assert max(err(stopped_a[q.name],pose(q)) for q in grasses)>.005,'Wind stopped while standing'
assert max(np.max(np.abs(runtime.ensure_cache().sample(t))) for t in [11.,12.,13.])>.1
at(20.);end_poses={q.name:pose(q) for q in grasses};control('Player Interaction On/Off',False)
end_error=max(err(end_poses[q.name],pose(q)) for q in grasses);assert end_error<1e-7,end_error
reset()
# Native equal-time parity plus bounded adjacent frames through run/contact exit.
fps_results={};samples={}
for fps in [30,60]:
    scene.render.fps=fps;scene.update_tag();bpy.context.view_layer.update();previous=None;maximum_step=0.;equal={};start=time.perf_counter()
    for f in range(6*fps,8*fps+1):
        at(f/fps);p=pose(o)
        if previous is not None:maximum_step=max(maximum_step,err(p,previous))
        if f%(fps//5)==0:equal[round(f/fps,4)]=p
        previous=p
    assert maximum_step<.15,(fps,maximum_step)
    samples[fps]=equal;fps_results[str(fps)]={'max_adjacent_vertex_step_m':maximum_step,'elapsed_s':time.perf_counter()-start}
fps_error=max(err(samples[30][t],samples[60][t]) for t in samples[30]);assert fps_error<2e-6,fps_error
scene.render.fps=24;scene.update_tag();bpy.context.view_layer.update()
# Actual operators and live timeline restoration; static -> interaction -> Wind -> static.
for key in ['Gameplay','Close']:
    assert bpy.ops.md2_interaction.view(key=key)=={'FINISHED'}
    assert bpy.context.view_layer.name==info['layer']
    assert all(not o.hide_get(view_layer=bpy.context.view_layer) for o in list(bpy.data.collections[info['root']].all_objects))
    assert all(a.spaces.active.camera.name==info['cameras'][key] for a in bpy.context.screen.areas if a.type=='VIEW_3D')
static_ui.select(bpy.context,'All')
scene.use_preview_range=False;scene.frame_start=17;scene.frame_end=400;scene.frame_set(123)
keys=['frame_current','frame_start','frame_end','frame_preview_start','frame_preview_end','use_preview_range','sync_mode']
timeline={k:getattr(scene,k) for k in keys}
ui.select(bpy.context);wind_review_ui.select(bpy.context,'Field');static_ui.select(bpy.context,'All')
assert {k:getattr(scene,k) for k in keys}==timeline
ui.select(bpy.context);control('Walk/Run Preview Speed',.5);assert scene.frame_preview_end==960
control('Walk/Run Preview Speed',1.);assert scene.frame_preview_end==480
reset()
# Compare immutable assets again after every control/route check. Scene render FPS restored.
actual=stable_snapshot();errors=[(g,n) for g,values in baseline.items() for n,val in values.items() if actual[g].get(n)!=val]
assert not errors,errors
assert wind_fingerprint()==wind_before
report={'passed':True,'native_original_data_exact':True,'wind_graph_controls_modifiers_drivers_attrs_exact':True,
        'native_preservation_errors':errors,'same_scene':True,'new_actions':0,'numeric_field':numeric,
        'root_error_m':root_error,'ring_width_error_m':width_error,'max_total_displacement_sampled_m':maximum,
        'largest_interaction_vs_wind_m':largest_contact,'disabled_vs_first_wind_error_m':off_error,'zero_strength_error_m':zero_error,
        'end_recovery_vs_wind_error_m':end_error,'reverse_scrub_error_m':scrub,'fps_30_60_error_m':fps_error,
        'fps_checks':fps_results,'controls_and_ui_roundtrips':True,'paused_controls_refresh':True}
(E/('verification_published.json' if target.parent==P else 'verification.json')).write_text(json.dumps(report,indent=2)+'\n')
print('MD2_INTERACTION_VERIFIED',json.dumps(report),flush=True)
