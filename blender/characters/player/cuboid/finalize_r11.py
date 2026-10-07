from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text());s=bpy.data.scenes[design['showcases']['Hold']['scene']];bpy.context.window.scene=s;s.frame_set(25)
for image in bpy.data.images:
    if image.source=='FILE' and image.has_data and not image.packed_file:image.pack()
for key in ['overhead','front','under','top_reverse']:
    ref=bpy.data.images.load(str(OUT/('reference_'+key+'.png')),check_existing=True);ref.name='R11_CANONICAL_'+key.upper();ref.pack()
text=bpy.data.texts.get('R11_REVIEW_README') or bpy.data.texts.new('R11_REVIEW_README');text.clear();text.write((OUT/'R11_REPORT.txt').read_text(encoding='utf-8'))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'player_weapon_hold_r11_study.blend'),check_existing=False)
result={'study':bpy.data.filepath,'default_scene':s.name,'frame':s.frame_current,'human_review':'pending','production_migration':False}
