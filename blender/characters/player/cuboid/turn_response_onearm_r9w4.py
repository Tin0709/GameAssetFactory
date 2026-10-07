"""One-arm turn response driven by the existing facing-rate test metadata."""
from onearm_r9w4_common import *
import ast
design=json.loads((OUT/'design.json').read_text());meta=json.loads((BASE/'turning_study_r3_review/preview_metadata.json').read_text());rows=meta['gaits']['Walk']['rows']
tree=ast.parse((BASE/'create_onearm_r9w4.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['body','key_upper']],type_ignores=[]),'<W4 reusable FK authoring>','exec'))
for category,data in design['categories'].items():
    name='PREVIEW_ONLY_R9W4_'+category+'_ONEARM_TURN_RESPONSE'
    s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];ws=[bpy.data.objects[n] for n in data['weapons']];socket=Matrix(data['socket'])
    sample(r,s,bpy.data.actions[data['actions']['Hold']],1);basepose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
    a=bpy.data.actions.get(name)
    if a is not None:assert a.get('scope','').startswith('PREVIEW ONLY: response to original turn rates')
    else:a=bpy.data.actions[data['actions']['Move']].copy();a.name=name
    a.use_fake_user=True;a['scope']='PREVIEW ONLY: response to original turn rates, upper-only; lower gait/path unchanged'
    for c in curves(a):
        c.keyframe_points.clear()
        for mod in list(c.modifiers):c.modifiers.remove(mod)
    previous={}
    for i,row in enumerate(rows):
        # Bound upper gesture amplitude on fast source turn-rate ramps. The
        # right wrist's gun-axis projection becomes sensitive near the maximum
        # sideways reach; 65% response avoids that rapid roll without changing
        # actual facing, path, lower pose or native gait phase.
        drive=.65*row['signed_weight'];follow=.65*rows[max(0,i-3)]['signed_weight'];phase=2*math.pi*row['time']/4;breath=math.sin(phase)
        body(r,basepose,phase,drive,follow,breath);configure_pose(r,ws,socket,category,drive,follow,breath);key_upper(r,a,i+1,previous)
    for c in curves(a):
        ks=c.keyframe_points;ys=[k.co.y for k in ks]
        for i,k in enumerate(ks):
            slope=(ys[min(i+1,len(ks)-1)]-ys[max(0,i-1)])/(1 if i in [0,len(ks)-1] else 2)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE';k.handle_left=(k.co.x-1/3,k.co.y-slope/3);k.handle_right=(k.co.x+1/3,k.co.y+slope/3)
        c.update()
    review=design['reviews'][category+'_Turn'];rr=bpy.data.objects[review['actors']['B']['rig']];assign(rr,a);review['actors']['B']['upper']=a.name;review['response']='Current facing rate leads gun/body; off gesture follows the same rate 125 ms later'
    data['turn_response_action']=a.name;review['upper_response_scale']=.65
(OUT/'design.json').write_text(json.dumps(design,indent=2));bpy.context.window.scene=bpy.data.scenes['R9W4_REVIEW_RIFLE_HOLD'];save_checkpoint();result={'turn_response_actions':[v['turn_response_action'] for v in design['categories'].values()]}
