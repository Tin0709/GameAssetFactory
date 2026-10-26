"""Validate authored GLB metadata and independently reimported world poses."""
from pathlib import Path
import bpy,sys,json,struct,math
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import motion

def run():
    raw=(HERE/'Sabre_Character_Authored.glb').read_bytes()
    length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length])
    names={a['name'] for a in doc.get('animations',[])}
    assert names=={'Sabre_'+n for n in motion.CLIPS},names
    errors={}
    for a in doc['animations']:
        assert min(doc['accessors'][s['input']]['min'][0] for s in a['samplers'])<1e-7
        duration=max(doc['accessors'][s['input']]['max'][0] for s in a['samplers'])
        errors[a['name']]=abs(duration-motion.CLIPS[a['name'][6:]]['duration'])
    assert max(errors.values())<1e-6,errors
    morph=next(m for m in doc['meshes'] if m.get('extras',{}).get('targetNames'))
    assert morph['extras']['targetNames']==['Focused','Blink']
    assert all(w==0 for w in morph.get('weights',[])),'Neutral GLB must not start focused or blinking'
    data=json.loads((HERE/'blender-validation.json').read_text(encoding='utf-8'))
    assert data['all_passed']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.render.fps=120;scene.render.fps_base=1
    bpy.ops.import_scene.gltf(filepath=str(HERE/'Sabre_Character_Authored.glb'))
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    mesh=next(o for o in scene.objects if o.type=='MESH' and o.name.startswith('SabrePrototypeSabre'))
    rig.animation_data.use_nla=False
    maximum_joint=maximum_bounds=0.;count=0
    for f in data['fixtures']:
        key='Sabre_'+f['clip']
        actions=[a for a in bpy.data.actions if a.name==key or a.name.endswith('|'+key)]
        assert len(actions)==1,(key,[a.name for a in bpy.data.actions])
        action=actions[0];rig.animation_data.action=action
        for slot in action.slots:
            if slot.target_id_type=='OBJECT':rig.animation_data.action_slot=slot;break
        frame=action.frame_range[0]+motion.CLIPS[f['clip']]['duration']*120*f['fraction']
        scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
        for name,position in f['joint_positions'].items():
            actual=rig.matrix_world@rig.pose.bones[name].matrix.translation
            maximum_joint=max(maximum_joint,(actual-Vector(position)).length);count+=1
        evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        verts=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
        for k in range(3):
            for a,b in zip([min(v[k] for v in verts),max(v[k] for v in verts)],f['sabre_bounds'][k]):
                maximum_bounds=max(maximum_bounds,abs(a-b))
    result={'passed':maximum_joint<.002 and maximum_bounds<.002,'pose_joint_comparisons':count,
       'maximum_world_joint_position_error':maximum_joint,'maximum_sabre_world_bounds_error':maximum_bounds,
       'maximum_clip_duration_error':max(errors.values()),'animations':len(names),
       'scope':'Authored Blender -> GLB -> independent Blender reimport. No MD2 fidelity implied.'}
    (HERE/'glb-roundtrip-validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    assert result['passed'],result
    print('SABRE_GLB_ROUNDTRIP',json.dumps(result))
if __name__=='__main__':run()
