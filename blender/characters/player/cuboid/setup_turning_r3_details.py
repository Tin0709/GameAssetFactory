import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'turning_study_r3_review';DEV=BASE/'player_locomotion_turning_v2_study.blend'
src=(BASE/'build_turning_r2_preview.py').read_text();exec(src[src.index('def evaluate('):src.index("metadata={'fps'")].replace('ReferenceStudy_V1','ReferenceStudy_V2').replace('_Reference_V1','_Reference_V2'))
def settings(s,w=1280,h=720):
 s.use_fake_user=True;s.world=bpy.data.worlds['R1_World'];s.render.engine='BLENDER_EEVEE';s.render.fps=24;s.render.fps_base=1;s.sync_mode='FRAME_DROP';s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGB';s.frame_start=1;s.frame_end=208
 for n in ['R1_Key','R1_Fill','R1_Review_Ground']:s.collection.objects.link(bpy.data.objects[n])
for direction in ['Left','Right']:
 s=bpy.data.scenes.new('R3_V1_V2_'+direction);settings(s);bpy.context.window.scene=s;s.camera=camera(s,'R3_'+direction+'_CompareCam',(0,-10,2),(0,0,.9),8.2)
 for i,(g,v) in enumerate([('Walk','V1'),('Walk','V2'),('Sprint','V1'),('Sprint','V2')]):
  r,m=copy_character(s,'R3_Compare_'+direction+'_'+g+v);r.location.x=(i-1.5)*1.8;assign(r,bpy.data.actions[g+'_Turn'+direction+'_Reference_'+v])
 s.frame_set(1)
s=bpy.data.scenes.new('R3_Entry_Phases');settings(s,1280,900);s.frame_end=48;s.camera=camera(s,'R3_Entry_Camera',(0,14,12),(0,0,.6),11)
bpy.context.window.scene=s
for gait,y in [('Walk',-2.5),('Sprint',2.5)]:
 for i,phase in enumerate([0,.25,.5,.75]):
  r,m=copy_character(s,'R3_Entry_'+gait+'_'+str(i));r.location=((1.5-i)*2.2,y,0);a=bpy.data.actions.new('PREVIEW_ONLY_R3_Entry_'+gait+'_'+str(i));a.use_fake_user=True
  for k in range(189):
   t=k/96;w=smooth((t-.25)/.4)*(1-smooth((t-1.1)/.4));ps=fullpose(gait,t,w,phase-.25*24/PERIOD[gait]);key_pose(r,a,1+k/4,ps)
  for c in curves(a):
   for k in c.keyframe_points:k.interpolation='LINEAR'
  a['preview_only']='Left turn entry starts at t=.25 at named phase; continues gait clock through rise, hold, recovery. No export.'
s.frame_set(1)
author=bpy.data.scenes['R3_Turn_Authoring'];author.world=bpy.data.worlds['R1_World'];author.render.engine='BLENDER_EEVEE';author.render.resolution_x=320;author.render.resolution_y=440;author.render.resolution_percentage=100;author.render.image_settings.file_format='PNG';author.render.image_settings.color_mode='RGB'
for n in ['R1_Key','R1_Fill','R1_Review_Ground']:author.collection.objects.link(bpy.data.objects[n])
for view,pos in [('Front',(0,-8,1.2)),('Rear',(0,7,4.2)),('Side',(8,0,1.2))]:camera(author,'R3_Detail_'+view,pos,(0,0,.9),2.8)
check_preserved(json.loads((OUT/'preservation_before.json').read_text()));bpy.context.window.scene=bpy.data.scenes['R3_Review_AB'];bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False);result={'detail_scenes':['R3_V1_V2_Left','R3_V1_V2_Right','R3_Entry_Phases'],'entry_phase_start_seconds':.25}
