"""Exercise the real native viewer and leave the existing library open for review."""
import bpy,json,sys
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));import review_ui as ui
steps=['Overview','Low Cushion','Broad Fan','Soft Rosette','Uneven Tuft','Cluster','Grouped','Compare','Opposite','Original','Overview'];pending=None;results=[]
def draw():
 global pending
 try:
  if pending is not None:
   info=ui.record();layer=bpy.context.view_layer
   expected=info['old_layer'] if pending=='Original' else info['layer'];assert layer.name==expected
   area=next(a for a in bpy.context.screen.areas if a.type=='VIEW_3D');space=area.spaces.active
   cam=info['original_camera'] if pending=='Original' else info['cameras'][pending]
   assert space.camera.name==cam and bpy.context.scene.camera.name==info['original_camera']
   assert hasattr(bpy.types,'MD2_PT_short_grass')
   active=[getattr(r,'active_panel_category','') for r in area.regions if r.type=='UI']
   assert 'Grass MD2' in active,active
   assert any(o.visible_get(view_layer=layer) for o in layer.objects if o.type=='MESH')
   if pending in ['Overview','Grouped','Low Cushion','Compare']:
    bpy.ops.screen.screenshot(filepath=str(D/'review'/('Native_'+pending.replace(' ','_')+'.png')))
   results.append({'view':pending,'view_layer':layer.name,'local_camera':cam,'sidebar':active,'viewport_shading':space.shading.type})
   pending=None
  if steps:
   pending=steps.pop(0);ui.select(bpy.context,pending);ui.focus_sidebar()
   bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP',iterations=1)
   return 1.8
  report={'passed':True,'native_routes':results,'file':bpy.data.filepath,'final_view':'Overview','new_scene_count':0,'saved':False}
  (D/'native_viewport_validation.json').write_text(json.dumps(report,indent=2)+'\n')
  print('MD2_NATIVE_VIEWPORT_READY',json.dumps(report),flush=True)
 except Exception as e:
  (D/'native_viewport_validation.json').write_text(json.dumps({'passed':False,'error':repr(e),'completed':results},indent=2)+'\n')
  raise
 return None
bpy.app.timers.register(draw,first_interval=8.)
