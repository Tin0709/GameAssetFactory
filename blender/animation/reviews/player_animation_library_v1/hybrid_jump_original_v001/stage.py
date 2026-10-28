"""Scene-local presentation; does not save a file or touch existing objects."""
import bpy,json,math
from mathutils import Matrix,Vector
def material(name,color,emit=False):
 mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
 if emit:
  mat.node_tree.nodes.clear();out=mat.node_tree.nodes.new('ShaderNodeOutputMaterial');em=mat.node_tree.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=(*color,1);em.inputs[1].default_value=.8;mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
 else:mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
 return mat
def build(native,native_mesh,action,m):
 scene=bpy.data.scenes.new('Hybrid_Jump_Context_v001_PENDING')
 def link(o):scene.collection.objects.link(o);return o
 carrier=link(bpy.data.objects.new('Hybrid_Jump_Presentation_Root',None))
 rig=link(native.copy());rig.data=native.data.copy();rig.name='Hybrid_Jump_Review_Rig';rig.animation_data_clear();rig.parent=carrier;rig.matrix_parent_inverse=Matrix.Identity(4);rig.matrix_basis=Matrix.Identity(4);rig.hide_render=True;rig.hide_viewport=False
 for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
 rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 mesh=link(native_mesh.copy());mesh.name='Hybrid_Jump_Review_Mesh';mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4);mesh.matrix_basis=Matrix.Identity(4);mesh.hide_render=False;mesh.hide_viewport=False
 for mod in mesh.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 floor=material('Hybrid_Jump_Floor',(.085,.115,.15));grid=material('Hybrid_Jump_Grid',(.2,.31,.38));ink=material('Hybrid_Jump_Ink',(.82,.9,1),True)
 def quad(name,verts,mat):
  me=bpy.data.meshes.new(name);me.from_pydata(verts,[],[(0,1,2,3)]);me.materials.append(mat);return link(bpy.data.objects.new(name,me))
 quad('Hybrid_Jump_Stage',[(-6,-6,0),(6,-6,0),(6,6,0),(-6,6,0)],floor)
 for i in range(-6,7):
  quad('Hybrid_Jump_Grid_X_'+str(i),[(i-.008,-6,.00005),(i+.008,-6,.00005),(i+.008,6,.00005),(i-.008,6,.00005)],grid)
  quad('Hybrid_Jump_Grid_Y_'+str(i),[(-6,i-.008,.00005),(6,i-.008,.00005),(6,i+.008,.00005),(-6,i+.008,.00005)],grid)
 cameras={}
 for d,pos in [('FRONT',(0,-13,3.2)),('THREE_QUARTER',(7,-11,6)),('SIDE',(13,0,3.2))]:
  cam=link(bpy.data.objects.new('Hybrid_Jump_'+d,bpy.data.cameras.new('Hybrid_Jump_'+d)));cam.location=pos;cam.rotation_euler=(Vector((0,0,1.45))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.7;cameras[d]=cam.name
 scene.camera=bpy.data.objects[cameras['THREE_QUARTER']]
 world=bpy.data.worlds.new('Hybrid_Jump_World');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.15,.2,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
 for name,pos,energy in [('Key',(1,-5,8),1400),('Fill',(-5,1,5),900)]:
  data=bpy.data.lights.new('Hybrid_Jump_'+name,'AREA');data.energy=energy;data.size=6;o=link(bpy.data.objects.new(data.name,data));o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
 hud=link(bpy.data.objects.new('Hybrid_Jump_HUD',None));hud.parent=scene.camera
 for i,(body,y,size)in enumerate([('ORIGINAL JUMP  |  MD2 + A&S',2.05,.13),('SNAPPY LIFT  /  SOFT RECEIVE  /  RIGID LIMBS',1.83,.09),('PENDING  |  ORIGINAL KEYS  |  PREVIEW ARC',-2.06,.09)]):
  data=bpy.data.curves.new('Hybrid_Jump_Label_'+str(i),'FONT');data.body=body;data.align_x='CENTER';data.size=size;data.materials.append(ink);obj=link(bpy.data.objects.new(data.name,data));obj.parent=hud;obj.location=(0,y,-4);obj.visible_shadow=False
 a=bpy.data.actions.new('PREVIEW_ONLY_Hybrid_Jump_Elevation');a.use_fake_user=True;slot=a.slots.new(id_type='OBJECT',name=carrier.name);bag=a.layers.new('Presentation elevation only').strips.new(type='KEYFRAME').channelbags.new(slot)
 times=sorted(set([i/(m.FPS*8)for i in range(round(m.DURATION*m.FPS*8)+1)]+m.landmarks('context')))
 for axis in range(3):
  c=bag.fcurves.new('location',index=axis);c.keyframe_points.add(len(times));c.keyframe_points.foreach_set('co',[v for t in times for v in (1+t*60,m.elevation(t)if axis==2 else 0)])
  for k in c.keyframe_points:k.interpolation='LINEAR'
  c.update()
 carrier.animation_data_create();carrier.animation_data.action=a;carrier.animation_data.action_slot=slot
 scene.frame_start=1;scene.frame_end=120;scene.render.fps=60;scene.render.fps_base=1;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard'
 for name,t in [('TAKEOFF',m.START),('APEX - PREVIEW ARC',m.START+m.APEX_TIME),('CONTACT',m.START+m.FLIGHT),('COMPRESSION',m.START+m.FLIGHT+.055),('SETTLED',m.START+m.FLIGHT+m.LANDING)]:scene.timeline_markers.new(name,frame=round(1+t*60))
 scene.frame_set(1)
 return scene,carrier,rig,mesh,a,cameras,hud
