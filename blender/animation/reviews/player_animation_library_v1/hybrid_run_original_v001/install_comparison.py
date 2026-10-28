import bpy,sys,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4];LIB=ROOT/'blender/animation/showcase'
sys.path.insert(0,str(HERE));sys.path.insert(0,str(LIB));import motion as m;import gaf_animation_library as ui
BASE=ROOT/'.validation/animation_showcase/hybrid_run_original_v001'
baseline=json.loads((BASE/'baseline.json').read_text());meta=json.loads((HERE/'source_metadata.json').read_text())
CENTRAL=LIB/'Animation_Showcase.blend';MANIFEST=LIB/'animation_manifest.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(CENTRAL)==baseline[str(CENTRAL)] and sha(MANIFEST)==baseline[str(MANIFEST)],'Concurrent central/registry change; stop'
data=json.loads(MANIFEST.read_text());assert not any(x['action']in meta['actions']for x in data['animations'])
native=bpy.data.objects[ui.RIG];native_mesh=bpy.data.objects['Showcase_Player_Mesh']
old_probe=json.loads((HERE/'rig_probe.json').read_text());old_actions=set(bpy.data.actions.keys())
assert set(old_probe['old_actions'])==old_actions
with bpy.data.libraries.load(str(HERE/'hybrid_run_authoring.blend'),link=False) as (src,dst):dst.actions=meta['actions']
entries=[]
for action,variant in zip(dst.actions,m.VARIANTS):
    entry={'action':action.name,'source':(HERE/'hybrid_run_authoring.blend').relative_to(ROOT).as_posix(),'source_sha256':meta['source_sha256'],'source_rig':meta['rig'],'source_mesh':meta['mesh'],'source_armature':meta['armature'],'slot_identifier':action.slots[0].identifier,'action_sha256':ui.action_signature(action),'action_frame_range':list(action.frame_range),'start':1,'end':128,'fps':m.FPS,'fps_base':m.FPS_BASE,'status':'pending','approval_note':'Original authored hybrid Run; awaiting human visual selection. No Godot integration.','rotation_modes':{b.name:b.rotation_mode for b in native.pose.bones},'seamless_loop':True,'original_custom_animation':True,'source_keyframes_copied':False,'production_eligible':False,'provenance':'Independent authored motion; only technical/artistic principles studied from references.','gait_hz':m.HZ,'nominal_speed_m_s':7,'original_stance_fraction':m.DUTY,'phase_origin':m.ORIGIN}
    action.use_fake_user=True;ui.validate_action(action,entry,native);entries.append(entry)
scene=bpy.data.scenes.new('Hybrid_Run_Comparison_v001_PENDING');scene[ui.REVIEW_TAG]='hybrid_run_comparison_v001'
world=bpy.data.worlds.new('Hybrid_Run_Comparison_World');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.15,.20,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
def link(obj):scene.collection.objects.link(obj);return obj
actors=[]
for index,(entry,variant) in enumerate(zip(entries,m.VARIANTS)):
    carrier=link(bpy.data.objects.new('Hybrid_Run_Comparison_Carrier_'+str(index+1),None));carrier.location=((index-1)*1.8,(index-1)*1.6,0)
    rig=link(native.copy());rig.data=native.data.copy();rig.name='Hybrid_Run_Comparison_Rig_'+str(index+1);rig.animation_data_clear();rig.parent=carrier;rig.matrix_parent_inverse=Matrix.Identity(4);rig.matrix_basis=Matrix.Identity(4);rig.hide_viewport=False;rig.hide_render=True
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    rig.animation_data_create();rig.animation_data.action=bpy.data.actions[entry['action']];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
    mesh=link(native_mesh.copy());mesh.name='Hybrid_Run_Comparison_Mesh_'+str(index+1);mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4);mesh.matrix_basis=Matrix.Identity(4);mesh.hide_render=False;mesh.hide_viewport=False
    for mod in mesh.modifiers:
        if mod.type=='ARMATURE':mod.object=rig
    actors.append((carrier,rig,mesh))
def mat(name,color):
    v=bpy.data.materials.new(name);v.diffuse_color=(*color,1);return v
floor_mat=mat('Hybrid_Run_Stage',(.11,.14,.18))
# One scene-local ground mesh, no replacement of the old fixed floor.
ground=bpy.data.meshes.new('Hybrid_Run_Floor_Mesh');ground.from_pydata([(-7,-7,0),(7,-7,0),(7,7,0),(-7,7,0)],[],[(0,1,2,3)]);ground.materials.append(floor_mat);link(bpy.data.objects.new('Hybrid_Run_Floor',ground))
def text(name,body,location,size=.2):
    curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.size=size;curve.align_x='CENTER';obj=link(bpy.data.objects.new(name,curve));obj.location=location;return obj
for i,(carrier,rig,mesh) in enumerate(actors):
    t=text('Hybrid_Run_Label_'+str(i+1),'V%d  %s\nPENDING'%(i+1,['SUBTLE','BALANCED','EXPRESSIVE'][i]),(carrier.location.x,carrier.location.y-.8,.006),.18)
    t.data.materials.append(mat('Hybrid_Run_Label_Ink_'+str(i),(.7,.8,.95)))
cameras={}
for direction,pos in [('FRONT',(0,-15,2.5)),('THREE_QUARTER',(8,-12,7)),('SIDE',(15,0,2.5))]:
    cam=link(bpy.data.objects.new('Hybrid_Run_'+direction,bpy.data.cameras.new('Hybrid_Run_'+direction)));cam.location=pos;cam.rotation_euler=(Vector((0,0,.8))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=10.7;cameras[direction]=cam.name
scene.camera=bpy.data.objects[cameras['THREE_QUARTER']]
for name,pos,power,size in [('Key',(1,-5,8),1800,7),('Fill',(-5,1,5),1100,6)]:
    light=bpy.data.lights.new('Hybrid_Run_'+name,'AREA');light.energy=power;light.shape='DISK';light.size=size;obj=link(bpy.data.objects.new(light.name,light));obj.location=pos;obj.rotation_euler=(Vector((0,0,.7))-obj.location).to_track_quat('-Z','Y').to_euler()
hud=link(bpy.data.objects.new('Hybrid_Run_HUD',None));hud.parent=scene.camera
for body,loc,size in [('ORIGINAL HYBRID RUN  |  1.888 Hz  |  SAME PHASE',(-.1,2.6,-4),.18),('V1 SUBTLE                  V2 BALANCED                  V3 EXPRESSIVE',(-.1,2.25,-4),.16),('PENDING REVIEW  /  RIGID LIMBS  /  NO GODOT CHANGES',(-.1,-2.5,-4),.14)]:
    t=text('Hybrid_Run_HUD_Text',body,loc,size);t.parent=hud;t.data.materials.append(mat('Hybrid_Run_HUD_Ink',(.85,.9,1)))
carrier,rig,mesh=actors[1]
pa=bpy.data.actions.new('PREVIEW_ONLY_Hybrid_Run_Comparison_Static');carrier.animation_data_create();carrier.animation_data.action=pa
carrier.keyframe_insert('location',frame=1);carrier.keyframe_insert('location',frame=129)
for c in ui.curves(pa):
    for k in c.keyframe_points:k.interpolation='LINEAR'
pa.use_fake_user=True
review={'id':'hybrid_run_comparison_v001','label':'Original Hybrid Run — V1 / V2 / V3 synchronized','status':'pending','scene':scene.name,'rig':rig.name,'mesh':mesh.name,'world_root':carrier.name,'pose_action':entries[1]['action'],'pose_slot_identifier':bpy.data.actions[entries[1]['action']].slots[0].identifier,'pose_action_sha256':entries[1]['action_sha256'],'presentation_action':pa.name,'presentation_slot_identifier':pa.slots[0].identifier,'presentation_action_sha256':ui.action_signature(pa),'start':1,'end':128,'fps':m.FPS,'fps_base':m.FPS_BASE,'seamless_loop':False,'research_only':True,'production_eligible':False,'original_authored_comparison':True,'rig_sha256':data['rig_sha256'],'rotation_modes':entries[1]['rotation_modes'],'cameras':cameras,'return_scene':'ANIMATION_SHOWCASE','hud_root':hud.name,'comparison_actors':[{'rig':r.name,'mesh':me.name,'action':e['action']}for (_,r,me),e in zip(actors,entries)]}
scene[ui.REVIEW_ENTRY]=json.dumps(review)
scene.frame_start=1;scene.frame_end=128;scene.render.fps=m.FPS;scene.render.fps_base=m.FPS_BASE;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.frame_set(1)
ui.validate_review_sequence(review)
data['animations'].extend(entries);data.setdefault('review_sequences',[]).append(review)
focus=data.get('library_focus',{});prior=focus.get('entries',[])
focus['entries']=[{'kind':'review_sequence','id':review['id']}]+[{'kind':'action','id':e['action']}for e in entries]+prior;data['library_focus']=focus
assert sha(CENTRAL)==baseline[str(CENTRAL)] and sha(MANIFEST)==baseline[str(MANIFEST)]
MANIFEST.write_text(json.dumps(data,indent=2))
ui.register();home=bpy.data.scenes['ANIMATION_SHOWCASE'];ui.refresh(home,import_missing=False)
for name,signature in old_probe['old_actions'].items():assert ui.action_signature(bpy.data.actions[name])==signature,name
assert ui.rest_signature(native.data)==data['rig_sha256']
ui.open_review_sequence(bpy.context,review['id']);scene.gaf_loop=True
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.show_region_ui=True;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(CENTRAL))
(HERE/'installation.json').write_text(json.dumps({'old_actions_preserved':len(old_actions),'total_actions':len(bpy.data.actions),'old_registry_entries_preserved':66,'new_entries':entries,'review':review},indent=2))
scene.render.filepath=str(HERE/'comparison_frame.png');scene.frame_set(9);bpy.ops.render.render(write_still=True,scene=scene.name)
print('HYBRID_INSTALLED',len(bpy.data.actions),flush=True)
