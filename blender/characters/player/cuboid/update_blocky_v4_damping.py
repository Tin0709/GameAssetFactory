from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid\create_blocky_run_v4_pass4.py')
s=p.read_text(encoding='utf-8-sig')
s=s.replace("for c in fcurves(v4):", """# A bounded +/-3 mm Head local-Y correction gently reduces inherited vertical bob.
# It does not alter Hips/Chest or remove the natural run bounce.
hip_low=min(m['Hips'].translation.z for m,_ in baseline.values());hip_high=max(m['Hips'].translation.z for m,_ in baseline.values())
head_y_first=None
for f,_ in key_values['Head']:
    mats,_=sample(f);u=(mats['Hips'].translation.z-hip_low)/(hip_high-hip_low)
    y=.003*(1-2*u)
    if f==1:head_y_first=y
    if f==17:y=head_y_first
    rig.pose.bones['Head'].location.y=y
    rig.pose.bones['Head'].keyframe_insert(data_path='location',index=1,frame=f,group='Head')
for c in fcurves(v4):""")
s=s.replace('assert len(fcurves(v4))==36','assert len(fcurves(v4))==37')
s=s.replace('explicit_translation_used=False','explicit_translation_used=True,head_local_y_translation_range_m=[min(c.evaluate(f) for f in frames) for c in fcurves(v4) if c.data_path==\'pose.bones["Head"].location\']+[max(c.evaluate(f) for f in frames) for c in fcurves(v4) if c.data_path==\'pose.bones["Head"].location\']')
s=s.replace("assert not any('.scale'", "assert max(heights['Head'])-min(heights['Head']) < max(heights['Chest'])-min(heights['Chest'])\nassert not any('.scale'")
p.write_text(s,encoding='utf-8')
