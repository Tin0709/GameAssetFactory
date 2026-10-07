"""Minimal response-amplitude probe; no actions or source data are edited."""
from onearm_r9w4_common import *
import ast
design=json.loads((OUT/'design.json').read_text());meta=json.loads((BASE/'turning_study_r3_review/preview_metadata.json').read_text());rows=meta['gaits']['Walk']['rows'];tree=ast.parse((BASE/'create_onearm_r9w4.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='body'],type_ignores=[]),'<body>','exec'))
category='Shotgun';data=design['categories'][category];s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];ws=[bpy.data.objects[n] for n in data['weapons']];socket=Matrix(data['socket']);sample(r,s,bpy.data.actions[data['actions']['Hold']],1);basepose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
scale=.65;previous=None;maximum=0;where=None
for i,row in enumerate(rows):
    drive=scale*row['signed_weight'];follow=scale*rows[max(0,i-3)]['signed_weight'];phase=2*math.pi*row['time']/4;breath=math.sin(phase);body(r,basepose,phase,drive,follow,breath);configure_pose(r,ws,socket,category,drive,follow,breath)
    q=r.pose.bones['ForeArm.R'].matrix_basis.to_quaternion()
    if previous:
        ang=math.degrees(previous.rotation_difference(q).angle);ang=min(ang,360-ang)
        if ang>maximum:maximum=ang;where=i+1
    previous=q
result={'scale':scale,'shotgun_right_forearm_max_integer_frame_deg':maximum,'frame':where,'rough_half_frame_deg':maximum/2,'no_actions_edited':True}
(OUT/'turn_amplitude_probe.json').write_text(json.dumps(result,indent=2))
