"""Background-only reusable review import, backup, Pending registration and refresh.
Blender -b Animation_Showcase.blend --python-exit-code 1 --python import_to_review.py -- CLIP.samples.json [Unique_Action_Name]
"""
import bpy,sys,json,hashlib,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;SHOWCASE=HERE.parent/'showcase';ROOT=HERE.parents[2]
sys.path[:0]=[str(HERE),str(SHOWCASE)]
import import_blockbench as bridge
import register_animation
ui=bridge.library

def run(sample_path,name=None):
    if not bpy.app.background:raise ValueError('Use a background process to protect unsaved editor work')
    viewer=(SHOWCASE/'Animation_Showcase.blend').resolve();manifest=SHOWCASE/'animation_manifest.json'
    if Path(bpy.data.filepath).resolve()!=viewer:raise ValueError('Start from the existing Animation_Showcase.blend')
    baseline={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in [viewer,manifest]}
    clip=json.loads(Path(sample_path).read_text());contract=json.loads((HERE/'bridge_contract.json').read_text());rig=bpy.data.objects['Showcase_Player_Rig']
    action=bridge.import_clip(rig,clip,contract,name)
    # A unique source is required for each revision; never overwrite existing studies.
    folder=HERE/'imports'/action.name
    if folder.exists():raise ValueError('Review source already exists; use a new versioned name')
    folder.mkdir(parents=True);source=folder/'source.blend'
    shutil.copy2(sample_path,folder/'source.samples.json')
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    scene=bpy.context.scene;scene.name='BLOCKBENCH_IMPORT_SOURCE'
    if 'gaf_animation_showcase' in scene:del scene['gaf_animation_showcase']
    scene.frame_start=1;scene.frame_end=int(round(1+clip['duration']*clip['fps']));scene.render.fps=clip['fps'];scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    for p,d in baseline.items():
        if hashlib.sha256(p.read_bytes()).hexdigest()!=d:raise RuntimeError('Concurrent library change; source retained, nothing registered')
    register_animation.register_entry(action.name,rig.name,'Showcase_Player_Mesh',1,scene.frame_end,clip['fps'])
    # Re-open the original existing rig; refresh appends the named Action only.
    bpy.ops.wm.open_mainfile(filepath=str(viewer));ui.register() if not hasattr(bpy.types.Scene,'gaf_clips') else None
    ui.refresh(bpy.context.scene)
    if hashlib.sha256(viewer.read_bytes()).hexdigest()!=baseline[viewer]:raise RuntimeError('Concurrent viewer change; Pending source registered, viewer not overwritten')
    bpy.ops.wm.save_as_mainfile(filepath=str(viewer))
    print('IMPORTED AND REGISTERED PENDING:',clip['name'],'->',source)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    if not 1<=len(args)<=2:raise ValueError('Expected CLIP.samples.json [Unique_Action_Name]')
    run(*args)
