"""Non-destructive evaluated-transform import onto the existing rig (Blender 5.2).
No file save, registration, rig edits or active-Action changes occur here.
"""
import json,math,sys,hashlib
from pathlib import Path
import bpy
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'showcase'))
import gaf_animation_library as library
TOL=2e-5

def matrix(value):
    if not isinstance(value,list) or len(value)!=4 or any(not isinstance(r,list) or len(r)!=4 for r in value):raise ValueError('Expected row-major 4x4 matrix')
    if any(type(x) not in (int,float) or not math.isfinite(x) for r in value for x in r):raise ValueError('Matrix values must be finite numbers')
    m=Matrix(value)
    if max(abs(m[3][i]-(1 if i==3 else 0)) for i in range(4))>TOL:raise ValueError('Non-affine matrix')
    rot=m.to_3x3();gram=rot.transposed()@rot
    if max(abs(gram[i][j]-(1 if i==j else 0)) for i in range(3) for j in range(3))>TOL or abs(rot.determinant()-1)>TOL:raise ValueError('Only rigid transforms are supported; scale/shear/reflection rejected')
    return m

def delta(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))

def preflight(rig,clip,contract):
    body={k:v for k,v in contract.items() if k!='sha256'}
    if hashlib.sha256(json.dumps(body,sort_keys=True,separators=(',',':')).encode()).hexdigest()!=contract['sha256']:raise ValueError('Corrupt contract')
    if clip.get('schema')!='gaf.blockbench.samples.v1' or clip.get('contract_sha256')!=contract['sha256']:raise ValueError('Incompatible contract/schema')
    if rig.type!='ARMATURE' or library.rest_signature(rig.data)!=contract['rig_sha256']:raise ValueError('Incompatible Blender rest rig')
    if delta(rig.matrix_world,Matrix.Identity(4))>TOL:raise ValueError('Rig object must retain its identity world transform')
    if any(p.constraints for p in rig.pose.bones) or (rig.animation_data and (rig.animation_data.nla_tracks or rig.animation_data.drivers)):raise ValueError('Constraints, NLA or drivers require separate review')
    names={b['name'] for b in contract['bones']}
    if names!=set(rig.pose.bones.keys()):raise ValueError('Bone hierarchy mismatch')
    for b in contract['bones']:
        p=rig.pose.bones[b['name']]
        if p.rotation_mode!=b['mode'] or (p.parent.name if p.parent else None)!=b['parent']:raise ValueError('Bone mode/parent mismatch: '+p.name)
    fps=clip.get('fps');rate=clip.get('sample_rate');duration=clip.get('duration')
    if type(fps) is not int or not 1<=fps<=240 or type(rate) not in (int,float) or not math.isfinite(rate) or not 1<=rate<=960:raise ValueError('Invalid FPS/sample rate')
    if type(duration) not in (int,float) or not math.isfinite(duration) or not 0<duration<=600:raise ValueError('Invalid duration (0–600 seconds supported)')
    if clip.get('loop') not in ('once','hold','loop'):raise ValueError('Unsupported loop mode')
    rest=clip.get('rest',{})
    if set(rest)!=names:raise ValueError('Missing rest bones')
    rest={n:matrix(v) for n,v in rest.items()}
    for b in contract['bones']:
        if delta(rest[b['name']],Matrix.Translation(b['origin']))>TOL:raise ValueError('Changed proxy rest transform/pivot: '+b['name'])
    samples=clip.get('samples',[])
    if not 2<=len(samples)<=600000:raise ValueError('Expected 2–600000 samples')
    C=Matrix(contract['blender_to_blockbench']);Ci=C.inverted();baked=[];previous=-1
    for sample in samples:
        t=sample.get('time')
        if type(t) not in (int,float) or not math.isfinite(t) or t<=previous or t<0 or t>duration+1e-6:raise ValueError('Sample times must be finite, sorted and unique')
        if previous>=0 and t-previous>1/rate+1e-5:raise ValueError('Missing samples for declared sample rate')
        previous=t
        if set(sample.get('matrices',{}))!=names:raise ValueError('Sample bone set differs')
        desired={n:Ci@matrix(v)@rest[n].inverted()@C@rig.data.bones[n].matrix_local for n,v in sample['matrices'].items()}
        row={}
        for b in contract['bones']:
            bone=rig.data.bones[b['name']];kwargs={}
            if bone.parent:kwargs=dict(parent_matrix=desired[bone.parent.name],parent_matrix_local=bone.parent.matrix_local)
            basis=bone.convert_local_to_pose(desired[bone.name],bone.matrix_local,invert=True,**kwargs)
            matrix(list(map(list,basis)))
            if b['locked']:
                if delta(basis,Matrix.Identity(4))>TOL:raise ValueError('ForeArm motion is forbidden: '+bone.name)
                basis=Matrix.Identity(4)
            row[bone.name]=basis
        baked.append((1+t*fps,row))
    if abs(samples[0]['time'])>1e-6 or abs(samples[-1]['time']-duration)>1e-6:raise ValueError('Samples must include both clip endpoints')
    return baked

def import_clip(rig,clip,contract,name=None):
    name=name or clip.get('name')
    if not isinstance(name,str) or not name or len(name)>60:raise ValueError('Action name must have 1–60 characters')
    if name in bpy.data.actions:raise ValueError('Action already exists; use a new versioned name')
    baked=preflight(rig,clip,contract)
    action=bpy.data.actions.new(name)
    try:
        slot=action.slots.new(id_type='OBJECT',name=rig.name)
        bag=action.layers.new('Blockbench Baked').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
        for bone in rig.pose.bones:
            previous=None;channels={'location':[],'scale':[]};rotation='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler';channels[rotation]=[]
            for frame,row in baked:
                loc,quat,scale=row[bone.name].decompose()
                if rotation=='rotation_quaternion':
                    if previous is not None and quat.dot(previous)<0:quat.negate()
                    value=quat;previous=quat.copy()
                else:
                    value=quat.to_euler(bone.rotation_mode,previous) if previous is not None else quat.to_euler(bone.rotation_mode);previous=value.copy()
                channels['location'].append(list(loc));channels['scale'].append([1,1,1]);channels[rotation].append(list(value))
            for prop,values in channels.items():
                for axis in range(len(values[0])):
                    curve=bag.fcurves.new(bone.path_from_id(prop),index=axis)
                    curve.keyframe_points.add(len(baked));curve.keyframe_points.foreach_set('co',[v for (frame,_),vals in zip(baked,values) for v in (frame,vals[axis])])
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
                    curve.update()
        action.use_fake_user=True
        action['review_status']='pending';action['blockbench_contract']=contract['sha256'];action['blockbench_version']=clip.get('blockbench_version','unknown');action['sample_rate_hz']=clip['sample_rate'];action['source_clip']=clip['name']
        return action
    except Exception:
        bpy.data.actions.remove(action);raise

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    if len(args)!=1:raise ValueError('Usage: blender -b INPUT.blend --python import_blockbench.py -- CLIP.samples.json (in memory only; save and register separately)')
    clip=json.loads(Path(args[0]).read_text());contract=json.loads((HERE/'bridge_contract.json').read_text())
    a=import_clip(bpy.data.objects['Showcase_Player_Rig'],clip,contract)
    print('IMPORTED PENDING, UNSAVED:',a.name)
