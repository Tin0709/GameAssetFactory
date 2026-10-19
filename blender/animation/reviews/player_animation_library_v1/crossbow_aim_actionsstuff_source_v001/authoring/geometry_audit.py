import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector
import argparse
p=argparse.ArgumentParser();p.add_argument('--cache',required=True);opt=p.parse_args(sys.argv[sys.argv.index('--')+1:])
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());S=Path(opt.cache).resolve();sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
r=bpy.data.objects[ui.RIG];mesh=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;N='Crossbow_Aim_ActionsStuff_Source_Test_v001';a=bpy.data.actions[N];base=bpy.data.actions['Rifle_Ready_Idle_ActionsStyle_v004']
r.animation_data.action=base;r.animation_data.action_slot=base.slots[0];s['gaf_library_last_action']=base.name;s.frame_set(1);bpy.context.view_layer.update();B={b.name:b.matrix.copy() for b in r.pose.bones};palmL=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));support=B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palmL);grip=B['UpperArm.R'].inverted()@B['WeaponCarrier'].translation
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N
feet={n:[v.co.copy() for v in mesh.data.vertices if any(g.group==mesh.vertex_groups[n].index and g.weight>.99 for g in v.groups)] for n in ['Leg.L','Leg.R']};rest={b.name:b.matrix_local.copy() for b in r.data.bones};worst=0.;minfoot=999.;mxgrip=0.;gaps=[]
for i in range(109):
 s.frame_set(i+1);bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in r.pose.bones};gap=(M['ForeArm.L']@palmL-M['WeaponCarrier']@support).length;gaps.append(gap);mxgrip=max(mxgrip,(M['UpperArm.R']@grip-M['WeaponCarrier'].translation).length)
 for n in feet:minfoot=min(minfoot,min((M[n]@rest[n].inverted()@v).z for v in feet[n]))
report={'passed':mxgrip<1e-5,'samples':109,'right_hand_attachment_position_error_m':mxgrip,'left_palm_to_approved_rifle_support_anchor_distance_m':[min(gaps),max(gaps)],'minimum_native_boot_corner_height_m':minfoot,'left_support_was_not_solved_or_reposed':True,'foot_floor_correction_applied':False,'description':'Source crossbow has a shorter item and different support spacing. Preserve literal arm pose; rifle left support is NOT claimed to match the approved rifle handguard. Native boot geometry keeps raw source transforms even if sole corners enter ground. Research fidelity study, not gameplay-ready fitting.'}
(S/'geometry_audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
