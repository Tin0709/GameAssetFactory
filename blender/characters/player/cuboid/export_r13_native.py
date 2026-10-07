"""Run in the approved open Blender file; export copies, never save it."""
import bpy, json, sys, hashlib
from pathlib import Path
from mathutils import Matrix

BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE))
from turning_r2_common import digest
ROOT = BASE.parents[3]
OUT = ROOT / 'game_mobile_3d/assets/characters/r13'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = BASE / 'player_weapon_stow_r13_upper_back_review.blend'
assert Path(bpy.data.filepath) == SOURCE
d = json.loads((BASE / 'weapon_stow_r13_review/design.json').read_text())
r12 = json.loads((BASE / 'locomotion_sway_r12_review/design.json').read_text())
protected = {a.name: digest(a) for a in bpy.data.actions}
file_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
original_scene = bpy.context.window.scene
frames = {s.name: (s.frame_current, s.frame_subframe) for s in bpy.data.scenes}
C = Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
mapping = {'Arm.L':'UpperArm.L', 'Arm.R':'UpperArm.R'}
bones = ['Spine','Chest','Neck','Head','Arm.L','Arm.R','WeaponCarrier']
records = {'source': str(SOURCE), 'file_sha256': file_hash, 'clips':{}, 'weapons':{}, 'source_actions':{}}

def rows(m): return [list(row) for row in m]
def scene_for(obj): return next(s for s in bpy.data.scenes if obj.name in s.objects)
def sample(rig, scene, f):
    scene.frame_set(int(f), subframe=f-int(f))
    bpy.context.view_layer.update()
    output = {}
    for name in bones:
        p = rig.pose.bones[mapping.get(name,name)]
        local = p.parent.matrix.inverted() @ p.matrix
        q = local.to_quaternion().normalized()
        output[name] = {'p': list(local.translation), 'q': [q.x,q.y,q.z,q.w]}
    for side in ['L','R']:
        p = rig.pose.bones['ForeArm.'+side]
        assert p.matrix_basis.to_quaternion().angle < 0.0001, 'Bent source arm cannot collapse'
    return output

def clip(name, rig, scene, start, end, loop):
    bpy.context.window.scene = scene
    action = rig.animation_data.action
    records['source_actions'][action.name] = protected[action.name]
    n = int(round((end-start)*2))
    records['clips'][name] = {'action':action.name, 'frames':[start,end], 'length':(end-start)/24,
        'loop':loop, 'samples':[sample(rig,scene,start+i/2) for i in range(n+1)]}

def export_scene(scene, path):
    bpy.context.window.scene = scene
    for o in scene.objects:
        o.hide_viewport=False; o.hide_render=False; o.hide_set(False); o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_active_scene=True,
        use_selection=True, export_animations=False, export_def_bones=False,
        export_cameras=False, export_lights=False)

def remove_temp(scene):
    for o in list(scene.objects): bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene=original_scene
    bpy.data.scenes.remove(scene)

try:
    for kind,a in d['actors'].items():
        rig=bpy.data.objects[a['rig']]; scene=bpy.data.scenes[d['scene']]
        clip('R13_'+kind+'_Holster',rig,scene,12,58,False)
        clip('R13_'+kind+'_Draw',rig,scene,66,112,False)
        scene.frame_set(12); bpy.context.view_layer.update()
        main=bpy.data.objects[next(n for n in a['weapons'] if '_Base' in n)]
        main_world=main.matrix_world.copy()
        mount=rig.pose.bones['WeaponCarrier'].matrix.inverted()@rig.matrix_world.inverted()@main_world@C.inverted()
        target=Matrix(a['hip_target_chest_matrix'] if kind=='Pistol' else a['back_target_chest_matrix'])@C.inverted()
        records['weapons'][kind]={'action':a['action'],'carrier_mount':rows(mount),'stow_mount':rows(target),
            'stow_space':'Chest','attachment':'hip' if kind=='Pistol' else 'back', 'asset':kind.lower()+'.glb'}
        tmp=bpy.data.scenes.new('R13_EXPORT_WEAPON')
        for source in main.parent.children:
            if source.type not in ['MESH','EMPTY']: continue
            o=source.copy()
            if source.data: o.data=source.data.copy()
            o.animation_data_clear(); o.parent=None
            for con in list(o.constraints): o.constraints.remove(con)
            tmp.collection.objects.link(o)
            o.matrix_world=main_world.inverted()@source.matrix_world
            for marker in ['Muzzle_Point','Grip_Point','Support_Hand_Point']:
                if marker in source.name: o.name=marker
        export_scene(tmp,OUT/(kind.lower()+'.glb')); remove_temp(tmp)
    for gait,period in [('Walk',16),('Sprint',13)]:
        for kind,a in r12['scenes'][gait]['actors'].items():
            clip('R12_'+kind+'_'+gait,bpy.data.objects[a['rig']],bpy.data.scenes[r12['scenes'][gait]['scene']],1,1+period,True)
    for kind in ['Unarmed','Pistol','Rifle','Shotgun']:
        clip('R12_'+kind+'_Idle',bpy.data.objects['R12_Hold_'+kind+'_Rig'],bpy.data.scenes['R12_HOLD_ALL'],1,97,True)
    # A copy of the existing production rest rig, with approved rigid straight arms.
    tmp=bpy.data.scenes.new('R13_EXPORT_BODY')
    proto=bpy.data.objects['Player_Cuboid_Rig']
    rig=proto.copy(); rig.data=proto.data.copy(); rig.animation_data_clear(); rig.name='R13_Export_Rig'
    tmp.collection.objects.link(rig);rig.matrix_world=Matrix.Identity(4)
    for p in rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
    original=bpy.data.objects[d['actors']['Rifle']['mesh']]
    original_rig=bpy.data.objects[d['actors']['Rifle']['rig']]
    mesh=original.copy();mesh.data=original.data.copy();mesh.animation_data_clear();mesh.name='R13_Export_Base'
    tmp.collection.objects.link(mesh);mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
    mesh.matrix_basis=original_rig.matrix_world.inverted()@original.matrix_world
    for mod in mesh.modifiers:
        if mod.type=='ARMATURE':mod.object=rig
    for side in ['L','R']:
        dest=mesh.vertex_groups.new(name='Arm.'+side)
        src=[mesh.vertex_groups[n].index for n in ['UpperArm.'+side,'ForeArm.'+side]]
        for v in mesh.data.vertices:
            weight=sum(g.weight for g in v.groups if g.group in src)
            if weight:dest.add([v.index],weight,'REPLACE')
        for name in ['UpperArm.'+side,'ForeArm.'+side]:mesh.vertex_groups.remove(mesh.vertex_groups[name])
    export_scene(tmp,OUT/'body_raw.glb');remove_temp(tmp)
    assert all(digest(bpy.data.actions[n])==h for n,h in protected.items())
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==file_hash
    records['protection']={'source_file_unchanged':True,'all_original_actions_unchanged':True,'sample_rate_hz':48,
        'arm_mapping':'Straight UpperArm/ForeArm -> original Arm, identical rest basis',
        'draw_mapping':'Native approved return slice 66..112, including arm preparation; no new posing'}
    (OUT/'source.json').write_text(json.dumps(records,separators=(',',':')))
finally:
    bpy.context.window.scene=original_scene
    for name,(f,sf) in frames.items():bpy.data.scenes[name].frame_set(f,subframe=sf)
    bpy.context.view_layer.update()
result={'exported':str(OUT),'clips':len(records['clips']),'protected':records.get('protection')}
