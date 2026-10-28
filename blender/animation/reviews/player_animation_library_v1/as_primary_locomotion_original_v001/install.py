"""Append only new original Actions and review takes to the existing library."""
import bpy,sys,json,hashlib,math,runpy
from pathlib import Path
from mathutils import Matrix,Vector
H=Path(__file__).resolve().parent;R=H.parents[4];LIB=R/'blender/animation/showcase'
sys.path.insert(0,str(H));import motion as m
runpy.run_path(str(R/'scripts/load_showcase_ui.py'),run_name='__main__');import gaf_animation_library as ui
B=R/'.validation/animation_showcase/as_primary_locomotion_original_v001'
base=json.loads((B/'baseline.json').read_text(encoding='utf8'));meta=json.loads((H/'source_metadata.json').read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
CENTRAL=LIB/'Animation_Showcase.blend';MANIFEST=LIB/'animation_manifest.json'
for path,digest in base['files'].items():assert sha(Path(path))==digest,'Concurrent central change'
data=json.loads(MANIFEST.read_text(encoding='utf8'));old_actions=set(bpy.data.actions.keys())
assert set(base['actions'])==old_actions
for name,digest in base['actions'].items():assert ui.action_signature(bpy.data.actions[name])==digest,name
native=bpy.data.objects[ui.RIG];native_mesh=bpy.data.objects['Showcase_Player_Mesh'];modes={b.name:b.rotation_mode for b in native.pose.bones}
with bpy.data.libraries.load(str(H/'as_primary_locomotion_authoring.blend'),link=False)as(src,dst):dst.actions=meta['actions']
entries=[]
for a,spec in zip(dst.actions,meta['specs']):
 style=spec.get('style',{})
 e={'action':a.name,'source':meta['source'],'source_sha256':meta['source_sha256'],'source_rig':meta['rig'],'source_mesh':meta['mesh'],'source_armature':meta['armature'],'slot_identifier':a.slots[0].identifier,'action_sha256':ui.action_signature(a),'action_frame_range':list(a.frame_range),'start':spec['start'],'end':spec['end'],'fps':60,'fps_base':1.,'rotation_modes':modes,'status':'pending','approval_note':'Original A&S-inspired motion, awaiting human artistic review. Godot untouched.','seamless_loop':spec['loop'],'original_custom_animation':True,'source_keyframes_copied':False,'production_eligible':False,'preview_only':spec.get('preview_only',False),'provenance':'Independently authored phase/support/spacing curves; reference principles only. No source keys or rig imported into new authoring.','gait_hz':style.get('hz'),'nominal_speed_m_s':style.get('speed'),'cycle_stride_m':style['speed']/style['hz']if style else None,'original_stance_fraction':style.get('duty'),'phase_origin':m.ORIGIN,'playback_sync':'FRAME_DROP'}
 ui.validate_action(a,e,native);a.use_fake_user=True;entries.append(e)
print('NEW_ACTIONS_VALIDATED',len(entries),flush=True)
def material(name,color,emission=False):
 mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
 if emission:
  mat.node_tree.nodes.clear();out=mat.node_tree.nodes.new('ShaderNodeOutputMaterial');em=mat.node_tree.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=(*color,1);em.inputs[1].default_value=.8;mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
 else:
  node=mat.node_tree.nodes.get('Principled BSDF');node.inputs['Base Color'].default_value=(*color,1);node.inputs['Roughness'].default_value=.9
 return mat
floor_mat=material('ASPrimary_Stage',(.085,.115,.15));ink=material('ASPrimary_HUD_Ink',(.78,.9,1),True);gridmat=material('ASPrimary_Grid_Ink',(.20,.31,.38))
def link(scene,obj):scene.collection.objects.link(obj);return obj
def plane(scene,name,vertices,mat):
 me=bpy.data.meshes.new(name);me.from_pydata(vertices,[],[(0,1,2,3)]);me.materials.append(mat);return link(scene,bpy.data.objects.new(name,me))
def actor(scene,entry,number,location=(0,0,0)):
 prefix='ASPrimary_'+scene.name+'_'+str(number)
 carrier=link(scene,bpy.data.objects.new(prefix+'_Carrier',None));carrier.location=location
 rig=link(scene,native.copy());rig.data=native.data.copy();rig.name=prefix+'_Rig';rig.animation_data_clear();rig.parent=carrier;rig.matrix_parent_inverse=Matrix.Identity(4);rig.matrix_basis=Matrix.Identity(4);rig.hide_viewport=False;rig.hide_render=True
 for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
 rig.animation_data_create();rig.animation_data.action=bpy.data.actions[entry['action']];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
 mesh=link(scene,native_mesh.copy());mesh.name=prefix+'_Mesh';mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4);mesh.matrix_basis=Matrix.Identity(4);mesh.hide_render=False;mesh.hide_viewport=False
 for mod in mesh.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 return carrier,rig,mesh
def text(scene,name,body,parent,location,size):
 curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.size=size;curve.align_x='CENTER';curve.materials.append(ink)
 obj=link(scene,bpy.data.objects.new(name,curve));obj.parent=parent;obj.location=location;return obj
def stage(name,title,subtitle,end,travel=False):
 scene=bpy.data.scenes.new(name);scene.frame_start=1;scene.frame_end=end;scene.render.fps=60;scene.render.fps_base=1
 world=bpy.data.worlds.new(name+'_World');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.15,.20,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
 scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=1120;scene.render.resolution_y=700;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard'
 plane(scene,name+'_Floor',[(-6,-23,0),(6,-23,0),(6,5,0),(-6,5,0)],floor_mat)
 for y in range(-22,6):plane(scene,name+'_MetreLine_'+str(y),[(-6,y-.009,.0001),(6,y-.009,.0001),(6,y+.009,.0001),(-6,y+.009,.0001)],gridmat)
 for x in range(-6,7):plane(scene,name+'_LaneLine_'+str(x),[(x-.009,-23,.0001),(x+.009,-23,.0001),(x+.009,5,.0001),(x-.009,5,.0001)],gridmat)
 cameras={}
 for direction,pos in [('FRONT',(0,-15,2.5)),('THREE_QUARTER',(8,-12,7)),('SIDE',(15,0,2.5))]:
  cam=link(scene,bpy.data.objects.new(name+'_'+direction,bpy.data.cameras.new(name+'_'+direction)));cam.location=pos;cam.rotation_euler=(Vector((0,0,.8))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=6.7 if travel else 8.0;cameras[direction]=cam.name
 scene.camera=bpy.data.objects[cameras['THREE_QUARTER']]
 lights=[]
 for suffix,pos,power in [('Key',(1,-5,8),1400),('Fill',(-5,1,5),900)]:
  l=bpy.data.lights.new(name+'_'+suffix,'AREA');l.energy=power;l.size=6;obj=link(scene,bpy.data.objects.new(l.name,l));obj.location=pos;obj.rotation_euler=(Vector((0,0,.7))-obj.location).to_track_quat('-Z','Y').to_euler();lights.append(obj)
 hud=link(scene,bpy.data.objects.new(name+'_HUD',None));hud.parent=scene.camera
 text(scene,name+'_Title',title,hud,(0,2.0 if not travel else 1.6,-4),.17 if not travel else .14)
 text(scene,name+'_Subtitle',subtitle,hud,(0,-2.05 if not travel else -1.65,-4),.12)
 return scene,cameras,hud,lights
def presentation(carrier,name,rows):
 a=bpy.data.actions.new(name);a.use_fake_user=True;slot=a.slots.new(id_type='OBJECT',name=carrier.name);bag=a.layers.new('Preview travel only').strips.new(type='KEYFRAME').channelbags.new(slot)
 for axis in range(3):
  c=bag.fcurves.new('location',index=axis);c.keyframe_points.add(len(rows));c.keyframe_points.foreach_set('co',[v for f,xyz in rows for v in (f,xyz[axis])])
  for k in c.keyframe_points:k.interpolation='LINEAR'
  c.update()
 carrier.animation_data_create();carrier.animation_data.action=a;carrier.animation_data.action_slot=slot
 return a
reviews=[]
for transition in [False,True]:
 if not transition:
  scene,cameras,hud,lights=stage('ASPrimary_WalkRun_Comparison_PENDING','ORIGINAL WALK / RUN  |  A&S-INSPIRED','PENDING  |  ORIGINAL KEYS  |  IN-PLACE COMPARISON  |  NO GODOT CHANGE',150)
  actors=[actor(scene,e,i,((i-.5)*2.7*12/math.sqrt(208),(i-.5)*2.7*8/math.sqrt(208),0))for i,e in enumerate(entries[:2])]
  for i,label in enumerate(['WALK  1.20 Hz / 1.50 m stride','RUN  1.60 Hz / 2.69 m stride']):text(scene,'ASPrimary_Column_'+str(i),label,hud,((i-.5)*2.7,1.65,-4),.13)
  carrier,rig,mesh=actors[1];entry=entries[1];pa=presentation(carrier,'PREVIEW_ONLY_ASPrimary_Comparison_Static',[(1,list(carrier.location)),(151,list(carrier.location))]);rid='as_primary_walkrun_comparison_v001';label='Original Walk / Run — A&S-inspired, Pending'
 else:
  scene,cameras,hud,lights=stage('ASPrimary_WalkRun_Transition_PENDING','WALK > RUN > WALK  |  CONTINUOUS PHASE','PENDING  |  ORIGINAL CONTACT CONSTRUCTION  |  GRID = 1 METRE',270,True)
  carrier,rig,mesh=actor(scene,entries[2],0);actors=[(carrier,rig,mesh)];entry=entries[2]
  trace=json.loads((H/'transition_trace.json').read_text(encoding='utf8'));pa=presentation(carrier,'PREVIEW_ONLY_ASPrimary_Transition_Travel',[(v['frame'],[0,-v['travel_m'],0])for v in trace])
  for obj in [bpy.data.objects[n]for n in cameras.values()]+lights:obj.parent=carrier
  rid='as_primary_walkrun_transition_v001';label='Original Walk→Run→Walk — traveled contact review'
 review={'id':rid,'label':label,'status':'pending','scene':scene.name,'rig':rig.name,'mesh':mesh.name,'world_root':carrier.name,'pose_action':entry['action'],'pose_slot_identifier':bpy.data.actions[entry['action']].slots[0].identifier,'pose_action_sha256':entry['action_sha256'],'presentation_action':pa.name,'presentation_slot_identifier':pa.slots[0].identifier,'presentation_action_sha256':ui.action_signature(pa),'start':1,'end':scene.frame_end,'fps':60,'fps_base':1.,'seamless_loop':False,'research_only':True,'production_eligible':False,'original_authored_comparison':True,'rig_sha256':data['rig_sha256'],'rotation_modes':modes,'cameras':cameras,'return_scene':'ANIMATION_SHOWCASE','hud_root':hud.name,'playback_sync':'FRAME_DROP','comparison_actors':[{'rig':r.name,'mesh':me.name,'action':r.animation_data.action.name}for c,r,me in actors]}
 scene[ui.REVIEW_TAG]=rid;scene[ui.REVIEW_ENTRY]=json.dumps(review);scene.frame_set(1);ui.validate_review_sequence(review);reviews.append(review)
data['animations'].extend(entries);data.setdefault('review_sequences',[]).extend(reviews)
focus=data.get('library_focus',{});focus['entries']=[{'kind':'review_sequence','id':e['id']}for e in reviews]+[{'kind':'action','id':e['action']}for e in entries]+focus.get('entries',[]);data['library_focus']=focus
for path,digest in base['files'].items():assert sha(Path(path))==digest,'Concurrent change before write'
MANIFEST.write_text(json.dumps(data,indent=2),encoding='utf8')
home=bpy.data.scenes['ANIMATION_SHOWCASE'];ui.refresh(home,import_missing=False)
for name,digest in base['actions'].items():assert ui.action_signature(bpy.data.actions[name])==digest,name
assert ui.rest_signature(native.data)==data['rig_sha256']
ui.open_review_sequence(bpy.context,reviews[0]['id']);scene=bpy.context.scene;scene.gaf_loop=True;scene.frame_set(1)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.show_region_ui=True;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(CENTRAL))
(H/'installation.json').write_text(json.dumps({'old_actions_preserved':len(old_actions),'total_actions':len(bpy.data.actions),'new_entries':entries,'reviews':reviews},indent=2),encoding='utf8')
for rev in reviews:
 s=bpy.data.scenes[rev['scene']];s.frame_set(18 if 'comparison'in rev['id']else 121);s.render.filepath=str(H/('comparison.png'if 'comparison'in rev['id']else'transition.png'));bpy.ops.render.render(write_still=True,scene=s.name)
print('INSTALLED',len(entries),'original pose Actions and',len(reviews),'review entries',flush=True)
