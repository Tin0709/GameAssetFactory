import bpy,json,sys,os
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D.parent));import grass_library_ui as ui
steps=['All','T:Soft Meadow','T:Open Fan','T:Low Sweep','T:Uneven Crown','T:Meadow Cluster','T:Upright Cluster','T:Grouped','T:Side','S:Overview','S:Low Cushion','All'];pending=None;records=[]
def draw():
 global pending
 try:
  if pending:
   assert hasattr(bpy.types,'MD2_PT_grass_library') and not hasattr(bpy.types,'MD2_PT_short_grass') and not hasattr(bpy.types,'MD2_PT_tall_grass')
   a=next(a for a in bpy.context.screen.areas if a.type=='VIEW_3D');cats=[getattr(r,'active_panel_category','') for r in a.regions if r.type=='UI'];assert 'Grass MD2' in cats
   if pending=='All':
    layer=bpy.context.view_layer;assert all(bpy.data.objects[n].visible_get(view_layer=layer) for n in json.loads(bpy.context.scene['md2_review'])['masters'])
    assert sum(o.visible_get(view_layer=layer) for o in bpy.data.collections[ui.record()['combined_collection']].objects if o.name.startswith('MD2_Combined_Tall_'))==6
   if pending in ['All','T:Soft Meadow','T:Grouped']:bpy.ops.screen.screenshot(filepath=str(D/'review'/('Native_'+pending.replace(':','_').replace(' ','_')+'.png')))
   records.append({'view':pending,'window_pointer':bpy.context.window.as_pointer(),'layer':bpy.context.view_layer.name,'camera':a.spaces.active.camera.name,'shared_panel':True})
   pending=None
  if steps:
   pending=steps.pop(0);ui.select(bpy.context,pending);ui.short.focus_sidebar();bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP',iterations=1);return 1.6
  assert len({r['window_pointer'] for r in records})==1
  report={'passed':True,'pid':os.getpid(),'file':bpy.data.filepath,'routes':records,'one_native_window_for_all_reviews':True,'final':'All','saved':False};(D/'native_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('GRASS_LIBRARY_NATIVE_READY',json.dumps(report),flush=True)
 except Exception as e:
  (D/'native_validation.json').write_text(json.dumps({'passed':False,'error':repr(e),'routes':records},indent=2));raise
 return None
bpy.app.timers.register(draw,first_interval=8.)
