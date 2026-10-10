"""Foreground-only append of V004, retaining every V003 GLB/imported clip.

Samples an isolated clone, never reloads/saves the user's library. Carrier and arc
are excluded. Sole support is derived from the actual rigid pose instead.
"""
import bpy, json, struct, hashlib, math
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
SOURCE=HERE.parent/'player_animation_library_v1.blend'
BASE=ROOT/'game_mobile_3d/assets/characters/jump_loop_v003/player_r15_jump_loop_v003.glb'
OUT=ROOT/'game_mobile_3d/assets/characters/jump_gif_v004'
HZ=120
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def run():
    assert not bpy.app.background
    assert Path(bpy.data.filepath).resolve()==SOURCE.resolve()
    protected={str(p.relative_to(ROOT)):sha(p) for p in [SOURCE,BASE]}
    raw=BASE.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);original_binary=raw[28+size:]
    binary=bytearray(original_binary)
    old_animations=json.dumps(doc['animations'],sort_keys=True)
    names={n['name']:i for i,n in enumerate(doc['nodes'])}
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}

    def append(values,kind):
        while len(binary)%4:binary.append(0)
        offset=len(binary);flat=[x for row in values for x in row]
        binary.extend(struct.pack('<'+'f'*len(flat),*flat))
        view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':4*len(flat)})
        a={'bufferView':view,'componentType':5126,'count':len(values),'type':kind}
        if kind=='SCALAR':a.update(min=[min(flat)],max=[max(flat)])
        index=len(doc['accessors']);doc['accessors'].append(a);return index

    def node_matrix(node):
        q=node.get('rotation',[0,0,0,1])
        return Matrix.LocRotScale(Vector(node.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(node.get('scale',[1,1,1])))

    def global_rest(i):
        local=node_matrix(doc['nodes'][i]);return global_rest(parents[i])@local if i in parents else local

    def error(a,b):return max(abs(a[r][c]-b[r][c]) for r in range(4) for c in range(4))

    manifest=json.loads((HERE/'manifest.json').read_text())
    rig=bpy.data.objects[manifest['rig']];mesh=bpy.data.objects[manifest['mesh']]
    action=bpy.data.actions[manifest['pose_action']]
    aliases={'Arm.L':'UpperArm.L','Arm.R':'UpperArm.R'}
    bones=['Hips','Spine','Chest','Neck','Head','Leg.L','Leg.R','Arm.L','Arm.R','ForeArm.L','ForeArm.R']
    for name in bones:
        b=rig.data.bones[aliases.get(name,name)]
        assert error(b.parent.matrix_local.inverted()@b.matrix_local,node_matrix(doc['nodes'][names[name]]))<1e-6,name
    prior_scene=bpy.context.window.scene
    scene=bpy.data.scenes.new('JGIF4_TEMP_RUNTIME_EXPORT')
    clone=rig.copy();rest=rig.data.copy();clone.data=rest;clone.parent=None;clone.matrix_world=Matrix.Identity(4)
    clone.animation_data_clear();scene.collection.objects.link(clone);clone.animation_data_create()
    clone.animation_data.action=action;clone.animation_data.action_slot=action.slots[0]
    bpy.context.window.scene=scene
    C=Matrix.Rotation(-math.pi/2,4,'X')
    corners=[]
    for v in mesh.data.vertices:
        group=next(mesh.vertex_groups[w.group].name for w in v.groups if w.weight>.999)
        corners.append((C@v.co,{'UpperArm.L':'Arm.L','UpperArm.R':'Arm.R'}.get(group,group)))
    samples=[];previous={};max_error=0.0;max_seam=0.0
    end=(manifest['end']-1)/30;take=(manifest['take']-1)/30;contact=(manifest['contact']-1)/30
    try:
        for index in range(round(end*HZ)+1):
            time=index/HZ;frame=1+time*30
            scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
            evaluated=clone.evaluated_get(bpy.context.evaluated_depsgraph_get())
            expected=[]
            for v,group in corners:
                name=aliases.get(group,group)
                expected.append(C@evaluated.pose.bones[name].matrix@rig.data.bones[name].matrix_local.inverted()@C.inverted()@v)
            support=-min(p.y for p,(_,group) in zip(expected,corners) if group.startswith('Leg.'))+.0003
            row={};runtime_globals={'Root':global_rest(names['Root'])}
            for name in bones:
                b=evaluated.pose.bones[aliases.get(name,name)];local=b.parent.matrix.inverted()@b.matrix
                q=local.to_quaternion().normalized()
                if name in previous and q.dot(previous[name])<0:q.negate()
                previous[name]=q.copy();p=local.translation.copy()
                if name=='Hips':p+=Vector((0,support,0))
                row[name]={'p':list(p),'q':[q.x,q.y,q.z,q.w]}
                parent=doc['nodes'][parents[names[name]]]['name']
                runtime_globals[name]=runtime_globals[parent]@Matrix.LocRotScale(p,q,Vector((1,1,1)))
            for point,(v,group) in zip(expected,corners):
                actual=runtime_globals[group]@global_rest(names[group]).inverted()@v
                max_error=max(max_error,(actual-point-Vector((0,support,0))).length)
            for side in ['L','R']:
                q=row['ForeArm.'+side]['q']
                assert abs(q[3])>.999999 and max(abs(x) for x in q[:3])<1e-6
            samples.append(row)
    finally:
        bpy.context.window.scene=prior_scene
        bpy.data.objects.remove(clone,do_unlink=True)
        bpy.data.armatures.remove(rest)
        bpy.data.scenes.remove(scene)
    assert max_error<3e-6,max_error
    animation={'name':manifest['pose_action'],'channels':[],'samplers':[],
               'extras':{'loop':False,'source_action':action.name,'straight_arms':True}}
    times=append([[i/HZ] for i in range(len(samples))],'SCALAR')
    for name in bones:
        for key,path,typ in [('p','translation','VEC3'),('q','rotation','VEC4')]:
            output=append([s[name][key] for s in samples],typ);sampler=len(animation['samplers'])
            animation['samplers'].append({'input':times,'output':output,'interpolation':'LINEAR'})
            animation['channels'].append({'sampler':sampler,'target':{'node':names[name],'path':path}})
    doc['animations'].append(animation)
    assert json.dumps(doc['animations'][:-1],sort_keys=True)==old_animations
    assert bytes(binary[:len(original_binary)])==original_binary
    doc['buffers']=[{'byteLength':len(binary)}]
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);binary+=b'\0'*((-len(binary))%4)
    OUT.mkdir(parents=True,exist_ok=True);output=OUT/'player_r15_jump_gif_v004.glb'
    output.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
    (OUT/'source.json').write_text(json.dumps({'action':action.name,'length':end,'sample_rate_hz':HZ,'samples':samples,
        'events':{'takeoff':take,'apex':(take+contact)/2,'contact':contact,'end':end}},separators=(',',':')))
    assert all(sha(ROOT/p)==h for p,h in protected.items())
    report={'protected_sha256':protected,'output_sha256':sha(output),'preserved_old_clips':len(doc['animations'])-1,
        'new_clip':action.name,'samples':len(samples),'tracks':22,'vertex_reconstruction_error_m':max_error,
        'geometry_skin_uv_material_binary_unchanged':True,'preview_carrier_exported':False,'root_motion':False,
        'straight_arms':True,'artistic_status':'AWAITING HUMAN REVIEW'}
    (OUT/'export_validation.json').write_text(json.dumps(report,indent=2))
    return report
