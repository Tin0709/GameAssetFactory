"""Draw the real existing library in full-body review and leave3/4 selected."""
import bpy,json
from pathlib import Path
D=Path(__file__).resolve().parent
steps=['Front','ThreeQuarter','Side','Back','ThreeQuarter'];results=[]
def inspect():
    bpy.ops.soldier_hair.compare(variant='BANDANA')
    s=bpy.context.scene;s.soldier_hair.closeup=False
    if steps:
        view=steps.pop(0);bpy.ops.soldier_hair.view(direction=view)
        bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP',iterations=1)
        e=next(e for e in json.loads(s['soldier_registry'])['entries'] if e['id']=='SOLDIER_Skin_v001')
        visible=all(bpy.data.objects[n].visible_get(view_layer=bpy.context.view_layer) for n in [e['body'],e['clothing'],'SOLDIER_HairCards_v001','SOLDIER_Bandana_2D_v001'])
        assert visible
        results.append({'view':view,'camera':s.camera.name,'character_visible':visible})
        return .6
    report={'passed':True,'native_viewport_draws':results,'final_scene':s.name,'final_layer':bpy.context.view_layer.name,'final_camera':s.camera.name,'full_body':True,'status':'Pending','saved':False}
    (D/'native_viewport_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('WORN_NATIVE_VIEWPORT_READY',json.dumps(report),flush=True)
    return None
bpy.app.timers.register(inspect,first_interval=2.)
