"""Matched W2/V3 review scenes in the connected Blender study only."""
from living_r9w2_common import *
OUT=BASE/'living_r9w3_review'
assert Path(bpy.data.filepath).name=='player_longgun_living_r9w3_study.blend'
assert not bpy.data.scenes.get('R9W3_REVIEW_SWEEP')
old=bpy.data.actions['LongGunAimAround_LeftRight_V2'];new=bpy.data.actions['LongGunAimAround_LeftRight_V3']

def compose(r,a,lower):
    r.animation_data_clear()
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    r.animation_data_create()
    if lower:
        tr=r.animation_data.nla_tracks.new();tr.name='UNCHANGED W1 GAIT AND PATH'
        st=tr.strips.new(lower.name,1,lower);st.action_slot=lower.slots[0]
        st.blend_type='REPLACE';st.extrapolation='HOLD';st.use_auto_blend=False
    assign(r,a);r.animation_data.action_blend_type='REPLACE';r.animation_data.action_influence=1

review={}
for mode,lower_name in [('SWEEP',None),('WALK_LOCAL','PREVIEW_ONLY_R9W1_Steering_Local'),('FIGURE8','LongGunAimAround_LeftRight_V1'),('CONTACT',None)]:
    s=scene('R9W3_REVIEW_'+mode);bpy.context.window.scene=s
    # Copy the W2 uniform review lighting rather than introducing position-dependent A/B light.
    for ob in list(s.objects):
        if ob.type=='LIGHT':s.collection.objects.unlink(ob)
    source=bpy.data.scenes['R9W2_REVIEW_'+('SWEEP' if mode=='CONTACT' else mode)]
    for ob in source.objects:
        if ob.type=='LIGHT':s.collection.objects.link(ob)
    template=bpy.data.objects['R9W3_Side'] if mode=='CONTACT' else source.camera
    cam=template.copy();cam.data=template.data.copy();cam.name='R9W3_Camera_'+mode;s.collection.objects.link(cam);s.camera=cam
    right=cam.matrix_world.to_quaternion()@Vector((1,0,0))
    if mode=='CONTACT':
        cam.data.ortho_scale=3.2
        cam.location+=cam.matrix_world.to_quaternion()@Vector((0,.38,0))
        separation=.8;s.render.resolution_x=1920
        s.frame_start=176;s.frame_end=211
    else:
        separation=7 if mode=='FIGURE8' else 2.1
        s.render.resolution_x=1440;s.frame_start=1;s.frame_end=288
    s.render.resolution_y=640;s.eevee.taa_render_samples=16
    rows={}
    for label,a,sign in [('A',old,-1),('B',new,1)]:
        rr,mp=clone2('W3_'+mode+'_'+label,s)
        for ob in mp.values():ob.name=ob.name.replace('R9W2_W3_','R9W3_')
        rr.name='R9W3_'+mode+'_'+label+'_Rig'
        compose(rr,a,bpy.data.actions[lower_name] if lower_name else None)
        offset=right*(sign*separation)
        for ob in mp.values():
            if ob.parent is None and not ob.constraints:ob.location+=offset
        rows[label]={'rig':rr.name,'offset':list(offset),'action':a.name}
        if mode!='CONTACT':
            font=bpy.data.curves.new('R9W3_Label','FONT');font.body=label+('  R9-W2' if label=='A' else '  CANDIDATE V3');font.align_x='CENTER';font.size=.25 if mode=='FIGURE8' else .115
            ob=bpy.data.objects.new(font.name,font);s.collection.objects.link(ob);ob.location=offset+Vector((0,0,3.8 if mode=='FIGURE8' else 2.08));ob.rotation_euler=cam.rotation_euler
    s['review']='A = original R9-W2; B = targeted right-arm V3. Same path, gait, timing, camera projection.'
    s.frame_set(191,subframe=.5)
    review[mode]={'scene':s.name,'actors':rows,'lower_action':lower_name,'fps':24,'frames':[s.frame_start,s.frame_end]}
(OUT/'review.json').write_text(json.dumps(review,indent=2))
bpy.context.window.scene=bpy.data.scenes['R9W3_REVIEW_SWEEP']
result={'review':review}
