"""Run in a source .blend to register one compatible Action as PENDING.
blender -b source.blend --python-exit-code 1 --python register_animation.py -- Action Rig Mesh Start End FPS
"""
import bpy,json,sys,hashlib,shutil
from pathlib import Path
from datetime import datetime,timezone
import gaf_animation_library as ui
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]

def register_entry(action_name,rig_name,mesh_name,start,end,fps):
    path=OUT/'animation_manifest.json';manifest=json.loads(path.read_text())
    if any(e['action']==action_name for e in manifest['animations']):raise ValueError('Already registered; never overwrite an existing Action. Use a new versioned name.')
    source=Path(bpy.data.filepath).resolve()
    if not source.is_file() or source==(OUT/'Animation_Showcase.blend').resolve():raise ValueError('Open a saved, separate source study')
    relative=source.relative_to(ROOT)
    rig=bpy.data.objects[rig_name];mesh=bpy.data.objects[mesh_name];a=bpy.data.actions[action_name]
    if rig.type!='ARMATURE' or ui.rest_signature(rig.data)!=manifest['rig_sha256']:raise ValueError('Incompatible rest rig; no registration made')
    modes={b.name:b.rotation_mode for b in rig.pose.bones}
    if modes!=manifest['rotation_modes']:raise ValueError('Incompatible pose rotation modes; no registration made')
    if mesh.parent!=rig or not any(m.type=='ARMATURE' and m.object==rig for m in mesh.modifiers):raise ValueError('Source mesh is not bound to the named rig')
    if any(b.constraints for b in rig.pose.bones) or rig.animation_data.nla_tracks or rig.animation_data.drivers:raise ValueError('Bake to an isolated rig-only Action first; constraints/NLA/drivers are unsupported')
    from mathutils import Matrix
    if any(abs(rig.matrix_world[i][j]-Matrix.Identity(4)[i][j])>1e-6 for i in range(4) for j in range(4)):raise ValueError('Source rig uses unsupported world travel/scale')
    entry={'action':action_name,'source':relative.as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_rig':rig_name,'source_mesh':mesh_name,'source_armature':rig.data.name,'slot_identifier':a.slots[0].identifier,'action_sha256':ui.action_signature(a),'action_frame_range':list(a.frame_range),'start':int(start),'end':int(end),'fps':int(fps),'fps_base':1.0,'status':'pending','approval_note':'Awaiting explicit human review; registering/importing does not approve animation.','seamless_loop':False}
    entry['rotation_modes']=modes
    ui.validate_timing(entry)
    ui.validate_action(a,entry,rig)
    # Back up both registration state and the viewer before any manifest change.
    backup=ROOT/'.validation/animation_showcase/registrations'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');backup.mkdir(parents=True)
    shutil.copy2(path,backup/path.name);shutil.copy2(OUT/'Animation_Showcase.blend',backup/'Animation_Showcase.blend')
    manifest['animations'].append(entry)
    temp=path.with_suffix('.json.tmp');temp.write_text(json.dumps(manifest,indent=2));temp.replace(path)
    return entry

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    if len(args)!=6:raise ValueError('Expected Action Rig Mesh Start End FPS')
    print('REGISTERED PENDING',json.dumps(register_entry(*args)),flush=True)
