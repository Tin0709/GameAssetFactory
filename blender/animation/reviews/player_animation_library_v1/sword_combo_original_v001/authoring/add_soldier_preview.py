"""Add one Pending review to the existing Soldier library, preserving its assets.

Appearance adapter only: copy current rigid skin, rebind its rest pivots to the
unchanged 13-bone Showcase rig. Reuse the SAME original Action, never retarget
or edit an approved Action or the original 10-bone Soldier armature.
"""
import bpy,json,hashlib,sys
from pathlib import Path
from mathutils import Matrix,Vector
OUT=Path(__file__).resolve().parent.parent
ROOT=OUT.parents[4]
SOURCE=OUT/'sword_combo_original_v001.blend'
KEY='SOLDIER_Sword_Combo_v001'
SCENE='SOLDIER_SWORD_COMBO_REVIEW'
BODY='Survivor_Reference_v001 — ORIGINAL BODY / NEW SKIN'
CLOTH='Survivor_Clothing_3D — requested outer relief'
MAP={'Arm.L':'UpperArm.L','Arm.R':'UpperArm.R'}


def add_preview(write_registry=False):
    assert SCENE not in bpy.data.scenes,'Preview exists; never replace review state silently'
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
        dst.scenes=['SWORD_COMBO_ORIGINAL_REVIEW']
    scene=dst.scenes[0];scene.name=SCENE
    rig=next(o for o in scene.objects if o.type=='ARMATURE');rig.name='SW_Soldier_Review_Rig'
    original_mesh=next(o for o in scene.objects if o.name.startswith('SC_Player_Mesh'))
    original_mesh.hide_render=True;original_mesh.hide_viewport=True
    col=bpy.data.collections.new(KEY+'_PENDING');scene.collection.children.link(col)
    copies=[]
    for name in [BODY,CLOTH,'SOLDIER_HairCards_v001','SOLDIER_Bandana_2D_v001']:
        old=bpy.data.objects[name];oldrig=old.parent
        new=old.copy();new.data=old.data.copy();new.animation_data_clear()
        new.name='SW_'+({'SOLDIER_HairCards_v001':'Hair','SOLDIER_Bandana_2D_v001':'Bandana',BODY:'Body',CLOTH:'Clothing'}[name])
        col.objects.link(new);new.parent=rig;new.parent_type='OBJECT';new.matrix_parent_inverse=Matrix.Identity(4);new.matrix_basis=Matrix.Identity(4)
        new.hide_render=False;new.hide_viewport=False;new.hide_set(False)
        for mod in new.modifiers:
            if mod.type=='ARMATURE':mod.object=rig
        # Every source vertex is already rigidly weighted to one original part.
        # Preserve skin width, UVs, face, materials and card silhouettes.
        groups={g.index:g.name for g in new.vertex_groups}
        for v in new.data.vertices:
            weights=[w for w in v.groups if w.weight>1e-5]
            assert len(weights)==1 and abs(weights[0].weight-1)<1e-5,(name,v.index)
            oldname=groups[weights[0].group];target=MAP.get(oldname,oldname)
            v.co=rig.data.bones[target].matrix_local@oldrig.data.bones[oldname].matrix_local.inverted()@(old.matrix_world@v.co)
        for group in new.vertex_groups:group.name=MAP.get(group.name,group.name)
        new['review_source_object']=name;new['adapter']='Rigid rest-pivot rebind only; same source Action and unchanged source skin'
        copies.append(new)
    # Camera data is new: shared Soldier and Showcase cameras remain unchanged.
    cameras={}
    positions={'Front':(0,-7,2.1),'Front_3Q':(3,-6,3),'Left_Side':(7,0,2.1),'Back':(0,7,2.1),'Right_Side':(-7,0,2.1),'Back_3Q':(-3,6,3)}
    for suffix,position in positions.items():
        data=bpy.data.cameras.new('SW_'+suffix);data.type='ORTHO';data.ortho_scale=3.5
        ob=bpy.data.objects.new('SW_'+suffix,data);scene.collection.objects.link(ob);ob.location=position
        ob.rotation_euler=(Vector((0,-.12,1.13))-ob.location).to_track_quat('-Z','Y').to_euler();cameras[suffix]=ob
    scene.camera=cameras['Front_3Q'];scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.frame_start=1;scene.frame_end=61;scene.render.fps=30;scene.render.fps_base=1
    scene.sync_mode='FRAME_DROP'
    scene['soldier_animation_preview']=KEY
    scene['same_canonical_action']='Sword_Combo_Original_v001'
    scene['source_sha256']=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    scene.frame_set(10)
    entry={'id':KEY,'label':'Sword Combo v001','type':'animation','status':'Pending',
       'review_scene':SCENE,'view_layer':scene.view_layers[0].name,'object':rig.name,'camera_prefix':'SW_',
       'action':'Sword_Combo_Original_v001','source':str(SOURCE.relative_to(ROOT)),
       'source_sha256':scene['source_sha256'],'frames':[1,61],'fps':30,'contacts':[10,25,43],
       'appearance_adapter':'Copied current skin / original rigid part weights; arm rest pivots rebound to existing Showcase rig',
       'godot_integrated':False,'original_motion':True}
    base=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];registry=json.loads(base['soldier_registry'])
    assert not any(e['id']==KEY for e in registry['entries'])
    registry['entries'].append(entry);base['soldier_registry']=json.dumps(registry)
    if write_registry:(ROOT/'blender/characters/soldier/showcase/registry.json').write_text(json.dumps(registry,indent=2)+'\n')
    text=bpy.data.texts.new('SW_Sword_Combo_Review.txt');text.write('PENDING / ORIGINAL Sword Combo v001\nSame Action as Animation Showcase. 1–61 @30FPS. Planned contacts 10/25/43.\nAll choreography and timing original proposals, not extracted MD2 tracks.\nUse SOLDIER Library > ANIMATIONS > Sword Combo v001. Play / Restart and impact frame buttons.\nAppearance is a copy bound to the existing Showcase rest rig; original Soldier assets stay intact.\nBlender review only. No Godot integration.\n')
    bpy.context.window.scene=scene
    print('SOLDIER_COMBO_ADDED',json.dumps(entry),flush=True)
    return scene,entry


if __name__=='__main__':
    live=not bpy.app.background
    scene,entry=add_preview(write_registry=live)
    if live:
        # Reload only our local selector; preserve facial/hair panels and handlers.
        import importlib,soldier_library_ui
        soldier_library_ui.unregister();importlib.reload(soldier_library_ui);soldier_library_ui.register()
        bpy.ops.soldier_library.select_asset(asset_id=KEY)
        # Save only after returning the invoking console area to its 3D review.
        for area in bpy.context.window.screen.areas:
            if area.type=='CONSOLE':area.type='VIEW_3D';area.spaces.active.show_region_ui=True;area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/characters/soldier/showcase/SOLDIER_Asset_Library.blend'))
    else:
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'.validation/sword_combo_original_v001_20261025/SOLDIER_staged.blend'))
