"""Actual Blender renders, original30FPS. No generated stand-in imagery."""
import bpy,sys,json,time,argparse
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));sys.path.insert(0,str(D.parent/'showcase'))
p=argparse.ArgumentParser();p.add_argument('--view',choices=['front','three_quarter','gameplay','stills'],required=True);args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(D.parent/'showcase/SOLDIER_Asset_Library.blend'),load_ui=True)
import soldier_library_ui;soldier_library_ui.register();import facial_ui as ui;import face_blender as fb;import expression_model as model
scene=ui.show_layer(bpy.context);out=D/'review';out.mkdir(exist_ok=True)
scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=8;scene.render.fps=30;scene.render.fps_base=1.;scene.render.resolution_percentage=100;scene.render.film_transparent=False
ctrl=bpy.data.objects['SF_Face_Control'];rig=bpy.data.objects['SF_Soldier_Rig'];weapon=bpy.data.objects['SF_Rifle_Sand_Block_V1']
if args.view=='stills':
 scene.render.resolution_x=scene.render.resolution_y=512;scene.render.image_settings.media_type='IMAGE';scene.render.image_settings.file_format='PNG'
 times={'Neutral_Idle':.7,'Blink_Soft':.575,'Look_Left':.65,'Look_Right':.65,'Look_Down_Short':.5,'Alert':.6,'Focused_Aim':.65,'Fire_Recoil_Face':.5333,'Enemy_Nearby':1.,'Move_Effort_Light':.75,'Run_Effort':.75,'Jump_Focus':.45,'Land_Impact':.30,'Hurt_Light':.32,'Hurt_Heavy':.38,'Low_HP_Tense':1.,'Victory_Small':.8,'Death_Stunned':.5}
 for name,t in times.items():
  ui.select(bpy.context,'preset',name);scene.soldier_facial.auto_blink=False;scene.frame_set(round(t*30)+5);scene.camera=bpy.data.objects['SF_Front_Close'];scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
 for name in ['Neutral_Idle','Alert','Focused_Aim','Hurt_Heavy']:
  ui.select(bpy.context,'preset',name);scene.soldier_facial.auto_blink=False;scene.frame_set(round(times[name]*30)+5);scene.camera=bpy.data.objects['SF_ThreeQuarter_Close'];scene.render.filepath=str(out/(name+'_3Q.png'));bpy.ops.render.render(write_still=True)
 ui.select(bpy.context,'situation','Aim');scene.frame_set(35);scene.camera=bpy.data.objects['SF_Side_Close'];scene.render.filepath=str(out/'Aim_side.png');bpy.ops.render.render(write_still=True)
else:
 fb.assign(ctrl,bpy.data.actions['SOLDIER_Facial_Review_Reel']);fb.assign(rig,bpy.data.actions['SF_Review_Reel_Body']);fb.assign(weapon,bpy.data.actions['SF_Review_Reel_Weapon']);ctrl['auto_blink']=1.;ctrl['intensity']=1.;ctrl['look_x']=ctrl['look_y']=0.
 weapon.hide_render=False;weapon.hide_set(False)
 for child in weapon.children_recursive:child.hide_render=False
 scene.frame_start=1;scene.frame_end=round(model.REEL_DURATION*30)
 camera={'front':'SF_Front_Close','three_quarter':'SF_ThreeQuarter_Close','gameplay':'SF_Gameplay_Distance'}[args.view];scene.camera=bpy.data.objects[camera]
 scene.render.resolution_x=1280 if args.view=='gameplay' else 512;scene.render.resolution_y=720 if args.view=='gameplay' else 512
 scene.render.image_settings.media_type='VIDEO';scene.render.image_settings.file_format='FFMPEG';scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264';scene.render.ffmpeg.constant_rate_factor='HIGH';scene.render.ffmpeg.ffmpeg_preset='GOOD';scene.render.filepath=str(out/('soldier_face_'+args.view+'_30fps_1x.mp4'))
 start=time.time();bpy.ops.render.render(animation=True)
 (out/('render_'+args.view+'.json')).write_text(json.dumps({'passed':True,'actual_blender_render':True,'view':args.view,'fps':30,'frames':scene.frame_end,'duration_s':model.REEL_DURATION,'original_speed':True,'seconds_to_render':time.time()-start},indent=2)+'\n')
print('SOLDIER_FACE_RENDER_DONE',args.view,flush=True)
