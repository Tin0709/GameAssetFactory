"""Render actual native hair comparisons; does not save or edit source assets."""
import bpy,sys,json
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D.parents[1]/'showcase'));sys.path.insert(0,str(D))
bpy.ops.wm.open_mainfile(filepath=str(D.parents[1]/'showcase/SOLDIER_Asset_Library.blend'),load_ui=True)
import soldier_library_ui;soldier_library_ui.register();import haircards_ui as ui
s=ui.show(bpy.context);p=s.soldier_hair;out=D/'review';out.mkdir(exist_ok=True)
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=48;s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.resolution_percentage=100;s.render.film_transparent=False
for mode in ['ORIGINAL','HAIR','BANDANA']:
 bpy.ops.soldier_hair.compare(variant=mode);p.closeup=True
 for direction in ['Front','ThreeQuarter','Side','Back']:
  bpy.ops.soldier_hair.view(direction=direction);s.render.resolution_x=s.render.resolution_y=640;s.render.filepath=str(out/(mode+'_'+direction+'.png'));bpy.ops.render.render(write_still=True)
 p.closeup=False;bpy.ops.soldier_hair.view(direction='ThreeQuarter');s.render.resolution_x=480;s.render.resolution_y=720;s.render.filepath=str(out/(mode+'_Full.png'));bpy.ops.render.render(write_still=True)
for band in [False,True]:
 bpy.ops.soldier_hair.isolate(bandana=band);p.closeup=True;bpy.ops.soldier_hair.view(direction='BackThreeQuarter');s.render.resolution_x=s.render.resolution_y=640;s.render.filepath=str(out/('Isolated_HairBandana.png' if band else 'Isolated_Hair.png'));bpy.ops.render.render(write_still=True)
bpy.ops.soldier_hair.compare(variant='BANDANA');p.closeup=True;bpy.ops.soldier_hair.view(direction='BackThreeQuarter');s.render.resolution_x=s.render.resolution_y=640;s.render.filepath=str(out/'BANDANA_BackThreeQuarter.png');bpy.ops.render.render(write_still=True)
print('HAIRCARDS_RENDERED actual Blender comparison views',flush=True)
