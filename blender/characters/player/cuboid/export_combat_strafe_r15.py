"""Sample the saved authored Actions on copies; never save or alter the source."""
import bpy, sys, json, hashlib
from pathlib import Path
from mathutils import Matrix
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,bone_signature
SOURCE=BASE/'player_combat_strafe_r14_pass2_study.blend'
OUT=BASE.parents[3]/'game_mobile_3d/assets/characters/r15'
assert Path(bpy.data.filepath)==SOURCE
OUT.mkdir(parents=True,exist_ok=True)
protected={a.name:digest(a) for a in bpy.data.actions}
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
source=bpy.data.objects['R14_P2_Right_Rig']
production=bpy.data.objects['Player_Cuboid_Rig']
BONES=['Hips','Leg.L','Leg.R','Spine']
for name in BONES:
    a,b=source.data.bones[name],production.data.bones[name]
    assert a.parent.name==b.parent.name
    assert max(abs(a.matrix_local[i][j]-b.matrix_local[i][j]) for i in range(4) for j in range(4))<1e-6
record={'source':str(SOURCE),'source_sha256':source_hash,'source_rig':source.name,
    'production_rig':production.name,'sample_rate_hz':192,'rest_compatible_bones':BONES,
    'rest':{n:bone_signature(source)[n] for n in BONES},'clips':{}}
old_scene=bpy.context.window.scene
scene=bpy.data.scenes.new('R15_EXPORT_ONLY');scene.render.fps=48
rig=source.copy();rig.data=source.data.copy();rig.animation_data_clear();rig.parent=None
rig.matrix_world=Matrix.Identity(4);scene.collection.objects.link(rig)
bpy.context.window.scene=scene
try:
    for name in ['Combat_StrafeLeft_V2','Combat_StrafeRight_V2']+[f'Combat_Strafe{d}_V1' for d in ['ForwardLeft','ForwardRight','BackwardLeft','BackwardRight']]:
        action=bpy.data.actions[name]
        assert tuple(action.frame_range)==(1.0,17.0)
        paths=sorted(set(c.data_path for c in curves(action)))
        assert all(any('"'+n+'"' in p for n in BONES) for p in paths)
        assert not any(p.endswith('scale') for p in paths)
        rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        samples=[]
        for index in range(65):
            for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4);p.rotation_mode='QUATERNION'
            frame=1+index/4
            scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
            row={}
            for n in BONES:
                p=rig.pose.bones[n];local=p.parent.matrix.inverted()@p.matrix
                q=local.to_quaternion().normalized()
                row[n]={'q':[q.x,q.y,q.z,q.w]}
                if n!='Spine':row[n]['p']=list(local.translation)
            samples.append(row)
        record['clips'][name]={'action':name,'action_sha256':protected[name],
            'frames':[1,17],'fps':48,'length':16/48,'loop':True,'tracks':paths,'samples':samples}
    assert all(digest(bpy.data.actions[n])==h for n,h in protected.items())
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
    record['protection']={'source_file_unchanged':True,'all_original_actions_unchanged':True,'rest_compatible':True}
    (OUT/'source.json').write_text(json.dumps(record,separators=(',',':')))
finally:
    bpy.context.window.scene=old_scene
    bpy.data.objects.remove(rig,do_unlink=True);bpy.data.scenes.remove(scene)
print('R15_SAMPLED',json.dumps({n:{'duration':c['length'],'samples':len(c['samples']),'tracks':c['tracks']} for n,c in record['clips'].items()}),flush=True)
