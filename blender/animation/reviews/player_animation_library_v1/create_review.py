"""Assemble existing authored animations into an isolated Blender review copy."""
import bpy, json, hashlib, math
from pathlib import Path
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
SRC = ROOT/'blender/characters/player/cuboid/player_combat_strafe_r14_pass2_study.blend'
JUMP = ROOT/'blender/animation/studies/block_jump_v2/block_jump_v2_review.blend'
RUNTIME = ROOT/'game_mobile_3d/assets/characters/r15/player_r15_combat_strafe_v1.glb'
DEST = OUT/'player_animation_library_v1.blend'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def curves(a):
    return [c for l in a.layers for s in l.strips for cb in s.channelbags for c in cb.fcurves]
def sig(a):
    return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
def assign(o,a):
    o.animation_data_create();o.animation_data.action=a
    if a and a.slots:o.animation_data.action_slot=a.slots[0]

protected = {str(p.relative_to(ROOT)):sha(p) for p in (SRC,JUMP,RUNTIME)}
bpy.ops.wm.open_mainfile(filepath=str(SRC),load_ui=False)
original_actions = {a.name:sig(a) for a in bpy.data.actions}
with bpy.data.libraries.load(str(JUMP),link=False) as (a,b):
    b.scenes=['BLOCK_JUMP_V2_REVIEW']
with bpy.data.libraries.load(str(JUMP),link=False) as (a,b):
    b.actions=[n for n in a.actions if n not in bpy.data.actions]
all_actions = {a.name:sig(a) for a in bpy.data.actions}
for a in bpy.data.actions:a.use_fake_user=True
sc=bpy.data.scenes.new('PLAYER_ANIMATION_LIBRARY_V1')
bpy.context.window.scene=sc
sc.render.engine='CYCLES';sc.cycles.samples=24
sc.render.resolution_x=1280;sc.render.resolution_y=900;sc.render.resolution_percentage=100
sc.render.fps=24;sc.sync_mode='FRAME_DROP'
sc.world=bpy.data.worlds.new('PlayerReview_SoftWorld')
sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.32,.36,.40,1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.32
sc.view_settings.view_transform='AgX';sc.view_settings.exposure=-.35
sc.view_settings.look='AgX - Medium Low Contrast'

catalog=[];actors={}
def clone_actor(source_name,key,action=None):
    source=bpy.data.objects[source_name]
    col=bpy.data.collections.new('REVIEW_'+key);sc.collection.children.link(col)
    objects=[source]+list(source.children_recursive)
    # Weapon mounts are separate scene roots with bone Copy Transforms, not rig children.
    mounts=[o for o in bpy.data.objects if any(getattr(c,'target',None)==source for c in o.constraints)]
    for mount in mounts:
        objects += [mount]+list(mount.children_recursive)
    # Preserve authored heading-only turn parent, while discarding its static layout offset.
    if source.parent and key.endswith('_Turn'):
        objects.append(source.parent)
    objects=list(dict.fromkeys(objects))
    mapping={}
    for old in objects:
        new=old.copy()
        if old.type=='ARMATURE':new.data=old.data.copy()
        new.name='LIB_'+key+'_'+old.name
        col.objects.link(new);mapping[old]=new
    for old,new in mapping.items():
        new.parent=mapping.get(old.parent)
        if old==source.parent and key.endswith('_Turn'):
            new.location=(0,0,0);new.matrix_parent_inverse=Matrix.Identity(4)
        if old==source:
            new.matrix_parent_inverse=Matrix.Identity(4)
            new.location=(0,0,0);new.rotation_euler=(0,0,0);new.scale=(1,1,1)
        for md in new.modifiers:
            if md.type=='ARMATURE' and md.object in mapping:md.object=mapping[md.object]
        for con in new.constraints:
            if hasattr(con,'target') and con.target in mapping:con.target=mapping[con.target]
        new.hide_viewport=False;new.hide_render=False;new.hide_set(False)
        if new.type=='MESH':new.display_type='TEXTURED'
    rig=mapping[source]
    if action:assign(rig,bpy.data.actions[action])
    actors[key]={'collection':col.name,'rig':rig.name,'source':source_name,'objects':[o.name for o in mapping.values()]}
    return rig,col

def entry(label,group,key,start,end,fps=24,action=None,status='Existing authored source; Blender review'):
    catalog.append({'id':str(len(catalog)),'label':label,'group':group,'actor':key,
                    'start':start,'end':end,'fps':fps,'action':action,
                    'duration_seconds':(end-start)/fps,'status':status})

for gait,period in [('Hold',96),('Walk',16),('Sprint',13)]:
    for kind in ['Unarmed','Pistol','Rifle','Shotgun']:
        key=gait+'_'+kind
        rig,col=clone_actor('R12_'+key+'_Rig',key)
        # The unarmed authoring template retains hidden pistol geometry.
        if kind=='Unarmed':
            for o in col.objects:
                if o.type=='MESH' and not any(md.type=='ARMATURE' for md in o.modifiers):
                    o.hide_render=True;o.hide_viewport=True
        entry(('Idle' if gait=='Hold' else gait)+' / '+kind,'Locomotion',key,1,1+period)
for gait in ['Walk','Sprint']:
    for kind in ['Unarmed','Pistol','Rifle','Shotgun']:
        key=gait+'_'+kind+'_Turn'
        rig,col=clone_actor('R12_'+key+'_Rig',key)
        if kind=='Unarmed':
            for o in col.objects:
                if o.type=='MESH' and not any(md.type=='ARMATURE' for md in o.modifiers):
                    o.hide_render=True;o.hide_viewport=True
        entry(gait+' turning / '+kind,'Turning',key,1,456)
for kind in ['Pistol','Rifle','Shotgun']:
    key='Stow_'+kind;clone_actor('R13_'+kind+'_Rig',key)
    entry('Holster / '+kind,'Holster & Draw',key,12,58,126,status='Native source slice; 5.25x game transition rate')
    entry('Draw / '+kind,'Holster & Draw',key,66,112,126,status='Native source slice; 5.25x game transition rate')
import sys
sys.path.insert(0, str(OUT))
from additional_reviews import add_armed_strafes, add_jump_slices
add_armed_strafes(sc,catalog,actors,clone_actor,entry,assign)
clone_actor('BlockJump_Study_Rig','Jump')
for a in ['BlockJump_Up_V2','BlockJump_Up_V2_OppositeLead','BlockHop_Down_V2','BlockHop_Down_V2_OppositeLead']:
    lo,hi=bpy.data.actions[a].frame_range
    entry(a,'Jump (study only)','Jump',int(lo),int(hi),24,action=a,
          status='Blender study only; jump remains deferred in game; pose only')

# Full jump journey retains its separate authored travel and block/camera context.
catalog.append({'id':str(len(catalog)),'label':'Jump journey / both leads','group':'Jump (study only)',
                'scene':'BLOCK_JUMP_V2_REVIEW','start':1,'end':208,'fps':24,
                'duration_seconds':207/24,'status':'Original Blender journey; preview-only travel, not in-game'})
add_jump_slices(catalog)

def mat(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.85;p.inputs['Specular IOR Level'].default_value=.12
    return m
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.065))
floor=bpy.context.object;floor.name='Review_Only_Stage';floor.dimensions=(7,7,.12)
floor.data.materials.append(mat('Review_Only_NeutralFloor',(.12,.15,.17)))
for name,loc,power,size,color in [('SoftKey',(-3,-4,6),600,5,(1,.96,.90)),('SoftFill',(4,-1,4),350,5,(.86,.93,1)),('SoftRim',(0,4,5),400,4,(1,1,1))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    ob=bpy.data.objects.new(name,data);sc.collection.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('PlayerReview_Camera');camdata.type='ORTHO';camdata.ortho_scale=3.7
cam=bpy.data.objects.new('PlayerReview_Camera',camdata);sc.collection.objects.link(cam);cam.location=(3,-6,3)
cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler();sc.camera=cam
sc['review_catalog']=json.dumps(catalog)
sc['review_actors']=json.dumps(actors)
sc['review_sources']=json.dumps(protected)
sc['review_scope']='All source actions retained; current family selected by catalog; original older scenes retained as archive'

control=bpy.data.texts.new('START_HERE_review_controls.py')
control.write((OUT/'review_controls.py').read_text(encoding='utf-8'))
note=bpy.data.texts.new('README_PLAYER_ANIMATIONS')
note.write('Player animation review only. Use N sidebar > Player Review. Space plays. Sources are preserved.\n'
           'Jump is a deferred Blender study. Old scenes/Actions are archive references, not artistic approvals.\n'
           'If controls are missing after reopening, run START_HERE_review_controls.py or use Open_Review.cmd.\n')
exec(compile(control.as_string(),control.name,'exec'),{'__name__':'player_review_controls'})
bpy.ops.player_review.select(clip_id=next(e['id'] for e in catalog if e['label']=='Walk / Rifle'))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.show_region_ui=True;sp.overlay.show_overlays=False
            sp.shading.type='MATERIAL';sp.shading.studiolight_rotate_z=.3
            sp.shading.studiolight_intensity=.65
            sp.region_3d.view_perspective='CAMERA'
        elif area.type=='DOPESHEET_EDITOR':area.ui_type='TIMELINE'
for o in bpy.context.selected_objects:o.select_set(False)
active=bpy.data.objects[actors['Walk_Rifle']['rig']]
bpy.context.view_layer.objects.active=active;active.select_set(True)
for n,h in all_actions.items():assert sig(bpy.data.actions[n])==h,n
for rel,h in protected.items():assert sha(ROOT/rel)==h,rel
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(DEST))
manifest={'file':str(DEST),'scene':sc.name,'sources':protected,'source_action_count':len(original_actions),
          'retained_source_actions':len(all_actions),'catalog_entries':len(catalog),
          'catalog':catalog,'source_action_hashes':all_actions,'actors':actors,
          'gameplay_unchanged':True,'runtime_transition_rate':5.25,
          'scope':'Blender review only; no new animation keys or game integration'}
(OUT/'review_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps({'file':str(DEST),'catalog':len(catalog),'source_actions':len(all_actions),'source_preserved':True}))
