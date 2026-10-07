from hold_r10wh1_common import *
from bpy_extras.object_utils import world_to_camera_view
design=json.loads((OUT/'design.json').read_text());stats={};failures=[]
for cat in ['Rifle','Shotgun','Pistol']:
    s=bpy.data.scenes[design['reviews'][cat+'_Turn']['scene']];bpy.context.window.scene=s;lo=[99,99];hi=[-99,-99]
    for f in range(1,457):
        s.frame_set(f);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
        for ob in [o for o in s.objects if o.type=='MESH']:
            ev=ob.evaluated_get(dg);mesh=ev.to_mesh()
            for v in mesh.vertices:
                c=world_to_camera_view(s,s.camera,ev.matrix_world@v.co)
                for j in range(2):lo[j]=min(lo[j],c[j]);hi[j]=max(hi[j],c[j])
            ev.to_mesh_clear()
    stats[cat]={'min':lo,'max':hi,'frames':456}
    if min(lo)<.025 or max(hi)>.975:failures.append(cat+' camera bounds')
result={'passed':not failures,'failures':failures,'bounds':stats};(OUT/'camera_validation.json').write_text(json.dumps(result,indent=2))
