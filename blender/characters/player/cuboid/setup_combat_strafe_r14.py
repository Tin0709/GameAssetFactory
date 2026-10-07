"""Native review layout; A/B/C overview plus individual scene playback."""
import ast,bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'combat_strafe_r14_review'
p=BASE/'create_combat_strafe_r14.py';txt=p.read_text();ns={'__file__':str(p)}
exec(compile(txt.split('FLOOR=')[0],str(p),'exec'),ns)
for key in ['FLOOR','GRID','TARGETMAT']:ns[key]=bpy.data.materials[{'FLOOR':'R14_Floor','GRID':'R14_Grid','TARGETMAT':'R14_Target'}[key]]
exec(compile(ast.Module(body=[n for n in ast.parse(txt).body if isinstance(n,ast.FunctionDef) and n.name in ['box','new_scene']],type_ignores=[]),str(p),'exec'),ns)
d=json.loads((OUT/'design.json').read_text())
s,cs=ns['new_scene']('R14_00_ABC_COMPARISON');s.render.resolution_x=1800;s.render.resolution_y=720
for i,key in enumerate(['A','B','C']):
    data=d['reviews'][key];a=bpy.data.actions[data['action']];r,m,st=ns['clone'](s,'Overview_'+key,a)
    src=bpy.data.objects[data['stage']];ns['assign'](st,src.animation_data.action.copy());st.animation_data.action.name='PREVIEW_ONLY_R14_Overview_'+key
    for c in ns['curves'](st.animation_data.action):
        if c.array_index==0:
            for k in c.keyframe_points:
                k.co.y+=(i-1)*2.9;k.handle_left.y+=(i-1)*2.9;k.handle_right.y+=(i-1)*2.9
    text=bpy.data.curves.new('R14_Label_'+key,'FONT');text.body={'A':'A  EXISTING WALK','B':'B  STRAFE RIGHT','C':'C  STRAFE LEFT'}[key];text.size=.17;text.align_x='CENTER'
    ob=bpy.data.objects.new(text.name,text);s.collection.objects.link(ob);ob.location=((i-1)*2.9,0,2.12)
    ob.rotation_euler=(1.5707963,0,0)
for name in cs.values():
    cam=bpy.data.objects[name];cam.data.ortho_scale=9.6
cam=bpy.data.objects[cs['ThreeQuarter']];cam.location=(1,-9,4);cam.rotation_euler=(ns['Vector']((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
for o in s.objects:
    if 'Enemy' in o.name:o.hide_render=True;o.hide_set(True)
for f,label in [(1,'24 FPS / 0.833 SEC SHUFFLE'),(8,'LEAD PLANTS'),(11,'TRAILING FOOT FOLLOWS'),(18,'TRAILER PLANTS')]:s.timeline_markers.new(label,frame=f)
d['overview_scene']=s.name;(OUT/'design.json').write_text(json.dumps(d,indent=2))
notes=bpy.data.texts.new('R14_READ_ME')
notes.write('R14 COMBAT STRAFE V1 — ARTISTIC STATUS: AWAITING HUMAN REVIEW\n\nStart in R14_00_ABC_COMPARISON. Space plays at 24 FPS.\nSelect R14_D_RIGHT_STOP_LEFT_RIGHT for the continuous 268-frame sequence.\nIndividual R14_A/B/C scenes provide Gameplay, ThreeQuarter, Front and Side cameras.\nActions: Combat_StrafeRight_V1 / Combat_StrafeLeft_V1. Frame 21 is the closure key; play frames 1–20.\nApproved rifle ready is an unchanged NLA layer. The new Action supplies Hips, legs and small Spine counterbalance only.\nTorso/Hips relative yaw measured <=1.300 degrees including reversals (limit 20).\nFull rendered review: combat_strafe_r14_review/index.html\nNo production export or Godot integration.\n')
bpy.context.window.scene=s;s.frame_set(1)
for ob in bpy.context.view_layer.objects:ob.select_set(False)
r=bpy.data.objects['R14_Overview_B_Rig'];r.select_set(True);bpy.context.view_layer.objects.active=r
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.region_3d.view_camera_zoom=0;area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL';area.spaces.active.show_region_ui=False
    if area.type=='DOPESHEET_EDITOR':
        area.spaces.active.mode='TIMELINE'
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'ABC_overview.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'player_combat_strafe_r14_v1_study.blend'))
result={'saved':bpy.data.filepath,'overview':s.name}
