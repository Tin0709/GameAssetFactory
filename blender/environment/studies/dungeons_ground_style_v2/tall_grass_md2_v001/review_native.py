"""Exercise the real existing viewer, capture native pixels and leave comparison open."""
import bpy,sys,json
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));import tall_review_ui as ui
steps=list(ui.record()['cameras'])+['Short','Original','Compare'];pending=None;results=[]
def draw():
 global pending
 try:
  if pending is not None:
   info=ui.record();layer=bpy.context.view_layer;expected=info['short_layer'] if pending=='Short' else info['original_layer'] if pending=='Original' else info['layer'];assert layer.name==expected
   area=next(a for a in bpy.context.screen.areas if a.type=='VIEW_3D');space=area.spaces.active;assert bpy.context.scene.camera.name==info['original_camera'];assert hasattr(bpy.types,'MD2_PT_tall_grass') and hasattr(bpy.types,'MD2_PT_short_grass')
   active=[getattr(r,'active_panel_category','') for r in area.regions if r.type=='UI'];assert 'Grass MD2' in active,active
   if pending not in ['Short','Original']:
    allowed=ui.visible_names(pending);assert all(o.hide_get(view_layer=layer)==(o.name not in allowed) for o in bpy.data.collections['MD2_Tall_Grass_v001_PENDING'].all_objects)
   if pending in ['Overview','Soft Meadow','Grouped','Compare','Short']:
    bpy.ops.screen.screenshot(filepath=str(D/'review'/('Native_'+pending.replace(' ','_')+'.png')))
   results.append({'view':pending,'layer':layer.name,'local_camera':space.camera.name,'sidebar':active,'shading':space.shading.type})
   pending=None
  if steps:
   pending=steps.pop(0);ui.select(bpy.context,pending);ui.short_ui.focus_sidebar();bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP',iterations=1);return 1.5
  report={'passed':True,'routes':results,'file':bpy.data.filepath,'final_view':'Compare','new_scenes':0,'saved':False}
  (D/'native_viewport_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('TALL_MD2_NATIVE_VIEWPORT_READY',json.dumps(report),flush=True)
 except Exception as e:
  (D/'native_viewport_validation.json').write_text(json.dumps({'passed':False,'error':repr(e),'completed':results},indent=2)+'\n');raise
 return None
bpy.app.timers.register(draw,first_interval=8.)
