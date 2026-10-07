import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'straight_study_r2s_review';DEV=BASE/'player_locomotion_straight_v2_study.blend'
p=json.loads((OUT/'preservation_before.json').read_text());check_preserved(p)
def setting(s):
 s.use_fake_user=True;s.world=bpy.data.worlds['R1_World'];s.render.engine='BLENDER_EEVEE';s.render.fps=24;s.render.fps_base=1;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGB';s.view_settings.view_transform='AgX';s.frame_start=1;s.frame_end=208
 for n in ['R1_Key','R1_Fill','R1_Review_Ground']:
  if n not in s.objects:s.collection.objects.link(bpy.data.objects[n])
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)));q=(D@Matrix.Rotation(math.radians(36.86989764584402),3,'Y')@Matrix.Rotation(math.radians(-36.31588642394517),3,'X')).to_quaternion()
s=bpy.data.scenes['R2S_Authoring'];setting(s)
for view,pos,target,scale in [('Front',(0,-8,1.15),(0,0,.9),3),('Rear',(0,7,4.2),(0,0,.9),3.1),('Side',(8,0,1.3),(0,0,.9),3)]:camera(s,'R2S_'+view,pos,target,scale)
c=camera(s,'R2S_GameClose',(0,0,8),(0,0,.9),3.1);c.rotation_euler=q.to_euler();c.location=Vector((0,0,.9))+q@Vector((0,0,10))
for view in ['Front','Gameplay']:
 s=bpy.data.scenes.new('R2S_'+view+'_V1_V2');setting(s);bpy.context.window.scene=s;s.render.resolution_x=1280;s.render.resolution_y=720
 c=camera(s,'R2S_'+view+'_ComparisonCamera',(0,-12,2),(0,0,.95),8.2)
 if view=='Gameplay':c.rotation_euler=q.to_euler();c.location=Vector((0,0,.9))+q@Vector((0,0,15));c.data.ortho_scale=14.5*1280/720
 right=c.rotation_euler.to_quaternion()@Vector((1,0,0))
 for i,(gait,ver) in enumerate([('Walk','V1'),('Walk','V2'),('Sprint','V1'),('Sprint','V2')]):
  r,m=copy_character(s,'R2S_'+view+'_'+gait+ver);r.location=right*((i-1.5)*1.8);assign(r,bpy.data.actions[gait+'_ReferenceStudy_'+ver])
 s.camera=c;s.frame_set(1)
s=bpy.data.scenes['R2S_Front_V1_V2'];bpy.context.window.scene=s
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.overlay.show_overlays=False
check_preserved(p);bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'scene':s.name,'order':'Walk V1, Walk V2, Sprint V1, Sprint V2','fps':24,'range':[1,208]}
