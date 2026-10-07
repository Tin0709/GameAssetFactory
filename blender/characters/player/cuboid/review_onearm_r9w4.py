"""Matched A/B scenes on native Walk/Sprint and current V3 turning poses."""
from onearm_r9w4_common import *
assert not bpy.data.scenes.get('R9W4_REVIEW_RIFLE_HOLD')
design=json.loads((OUT/'design.json').read_text());asset_scene=bpy.data.scenes['R9W4_ASSETS']
assets={k:[o for o in asset_scene.objects if o.name.startswith('R9W4_Asset_'+k+'_')] for k in ['Pistol','Shotgun']}
canonical=['Walk_ReferenceStudy_V2','Sprint_ReferenceStudy_V2']+[g+'_Turn'+side+'_Reference_V3' for g in ['Walk','Sprint'] for side in ['Left','Right']]
path_names=['PREVIEW_ONLY_R3_'+g+'_Path' for g in ['Walk','Sprint']]
with bpy.data.libraries.load(str(BASE/'player_locomotion_turning_v3_study.blend'),link=False) as (src,dst):
    dst.actions=canonical+path_names;dst.objects=['Player_Cuboid_Rig']
source_actions=dict(zip(canonical+path_names,dst.actions))
for name,a in source_actions.items():a.name='R9W4_SOURCE_'+name;a.use_fake_user=True
source_rig=dst.objects[0];source_rig.name='R9W4_Locomotion_Source_Rig';asset_scene.collection.objects.link(source_rig);source_rig.hide_render=True;source_rig.hide_viewport=True
probe=bpy.data.objects[design['categories']['Rifle']['rig']]
rest_error=max(abs(source_rig.data.bones[n].matrix_local[i][j]-probe.data.bones[n].matrix_local[i][j]) for n in LOWER for i in range(4) for j in range(4));assert rest_error<1e-6,rest_error
source_hashes={n:digest(a) for n,a in source_actions.items()}

def lower_copy(a,name):
    a=a.copy();a.name=name;a.use_fake_user=True
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for c in list(bag.fcurves):
                    if not any(c.data_path.startswith('pose.bones["'+n+'"]') for n in LOWER):bag.fcurves.remove(c)
    a['scope']='PREVIEW ONLY: copied native locomotion channels; no cadence/speed changes'
    return a
lower={g:lower_copy(source_actions[g+'_ReferenceStudy_V2'],'PREVIEW_ONLY_R9W4_'+g+'_LOWER') for g in ['Walk','Sprint']}
metadata=json.loads((BASE/'turning_study_r3_review/preview_metadata.json').read_text())
def evaluate(a,f):
    values={n:[Vector((0,0,0)),Euler((0,0,0),'XYZ')] for n in LOWER}
    for c in curves(a):
        n=c.data_path.split('"')[1]
        if n in values and c.data_path.rsplit('.',1)[-1] in ['location','rotation_euler']:
            values[n][0 if c.data_path.endswith('location') else 1][c.array_index]=c.evaluate(f)
    return values
def mix_lower(g,f,weight):
    a=evaluate(source_actions[g+'_ReferenceStudy_V2'],f)
    if abs(weight)<1e-12:return a
    b=evaluate(source_actions[g+'_Turn'+('Left' if weight>0 else 'Right')+'_Reference_V3'],f);w=min(1,abs(weight))
    return {n:[a[n][0].lerp(b[n][0],w),a[n][1].to_quaternion().slerp(b[n][1].to_quaternion(),w).to_euler('XYZ',a[n][1])] for n in LOWER}
# Reuse the existing turn cases, trajectories, weights and global clocks. Only
# the canonical V3 turn pose source replaces the older V2 preview source.
turn_lower={}
bpy.context.window.scene=bpy.data.scenes[design['categories']['Rifle']['scene']];author=probe
for g,period in [('Walk',16),('Sprint',13)]:
    rows=metadata['gaits'][g]['rows'];a=bpy.data.actions.new('PREVIEW_ONLY_R9W4_'+g+'_V3_TURN_LOWER');a.use_fake_user=True
    for k in range((len(rows)-1)*4+1):
        f=1+k/4;idx=k//4;u=k/4-idx;weight=rows[idx]['signed_weight']
        if u and idx+1<len(rows) and rows[idx+1]['case']==rows[idx]['case']:weight=weight*(1-u)+rows[idx+1]['signed_weight']*u
        values=mix_lower(g,1+((f-1)%period),weight);assign(author,a)
        for n,(loc,rot) in values.items():
            p=author.pose.bones[n];p.rotation_mode='XYZ';p.location=loc;p.rotation_euler=rot
            p.keyframe_insert('location',frame=f,group=n);p.keyframe_insert('rotation_euler',frame=f,group=n)
    for c in curves(a):
        for key in c.keyframe_points:key.interpolation='LINEAR'
    a['scope']='PREVIEW ONLY: native 16/13 frame phase, absolute straight/V3 turn blend; source path unchanged'
    turn_lower[g]=a
for n in LOWER:author.pose.bones[n].rotation_mode='QUATERNION';author.pose.bones[n].matrix_basis=Matrix.Identity(4)

def compose(r,upper,lo,repeat):
    r.animation_data_clear()
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    for n in LOWER:r.pose.bones[n].rotation_mode='XYZ'
    r.animation_data_create()
    if lo:
        tr=r.animation_data.nla_tracks.new();tr.name='UNCHANGED GAIT CLOCK / SOURCE POSES';st=tr.strips.new(lo.name,1,lo);st.action_slot=lo.slots[0];st.blend_type='REPLACE';st.extrapolation='HOLD';st.repeat=repeat;st.scale=1
    assign(r,upper);r.animation_data.action_blend_type='REPLACE'
def review_scene(name,template,width):
    s=scene(name);bpy.context.window.scene=s;s.render.resolution_x=1920;s.render.resolution_y=640;s.eevee.taa_render_samples=16;s.sync_mode='FRAME_DROP'
    for ob in list(s.objects):
        if ob.type=='LIGHT':s.collection.objects.unlink(ob)
    for ob in bpy.data.scenes['R9W2_REVIEW_SWEEP'].objects:
        if ob.type=='LIGHT':s.collection.objects.link(ob)
    cam=template.copy();cam.data=template.data.copy();cam.name=name+'_Camera';s.collection.objects.link(cam);cam.data.ortho_scale=width;s.camera=cam
    return s
reviews={}
for category,data in design['categories'].items():
    for mode in ['Hold','Move','AimAround','Turn']:
        turning=mode=='Turn';N=456 if turning else PERIOD[mode]
        template=bpy.data.objects[data['cameras']['Rear' if turning else 'Front']]
        s=review_scene('R9W4_REVIEW_'+category.upper()+'_'+mode.upper(),template,12.4 if turning else 6.8);s.frame_end=N
        if turning:s.camera.location=(0,10,5.5);s.camera.rotation_euler=(Vector((0,0,.6))-s.camera.location).to_track_quat('-Z','Y').to_euler()
        q=s.camera.matrix_world.to_quaternion();right=q@Vector((1,0,0));actors={}
        for label,sign in [('A',-1),('B',1)]:
            r,m,ws=clone_actor(category+'_'+mode+'_'+label,s,category,assets)
            upper=bpy.data.actions[data['baseline_actions' if label=='A' else 'actions']['Move' if turning else mode]]
            compose(r,upper,turn_lower['Walk'] if turning else lower['Walk'] if mode=='Move' else None,1 if turning else 4)
            offset=right*(sign*(3.1 if turning else 1.7))
            if turning:
                stage=bpy.data.objects.new('R9W4_'+category+'_'+label+'_Stage',None);s.collection.objects.link(stage);stage.location=offset
                path=bpy.data.objects.new('R9W4_'+category+'_'+label+'_Path',None);s.collection.objects.link(path);path.parent=stage;assign(path,source_actions['PREVIEW_ONLY_R3_Walk_Path']);r.parent=path;r.matrix_parent_inverse=Matrix.Identity(4);r.location=(0,0,0)
            else:r.location+=offset
            label_data=bpy.data.curves.new('R9W4_Label','FONT');label_data.body=label+('  PREVIOUS W3' if label=='A' and category=='Rifle' else '  COMPACT ADAPTER' if label=='A' else '  ONE-ARM CANDIDATE');label_data.align_x='CENTER';label_data.size=.17 if turning else .09
            ob=bpy.data.objects.new(label_data.name,label_data);s.collection.objects.link(ob);ob.location=offset+Vector((0,0,3.1 if turning else 2.08));ob.rotation_euler=s.camera.rotation_euler
            actors[label]={'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'upper':upper.name}
        if not turning:
            cameras={'Front':s.camera.name}
            for view in ['Side','Rear']:
                source=bpy.data.objects[data['cameras'][view]];cam=source.copy();cam.data=source.data.copy();cam.data.ortho_scale=6.8;cam.name=s.name+'_'+view;s.collection.objects.link(cam);cameras[view]=cam.name
            # Pair offsets match the front camera axis. Side/rear stills are
            # rendered individually from the probes so projection stays exact.
        else:cameras={'Rear':s.camera.name}
        for marker in metadata['cases'] if turning else []:s.timeline_markers.new(marker['name'],frame=1+round(marker['start_seconds']*24))
        s.frame_set(1);reviews[category+'_'+mode]={'scene':s.name,'actors':actors,'frames':[1,N],'fps':24,'lower':(turn_lower['Walk'] if turning else lower['Walk'] if mode=='Move' else None).name if mode in ['Turn','Move'] else None,'path':source_actions['PREVIEW_ONLY_R3_Walk_Path'].name if turning else None,'cameras':cameras}

# Sprint composition is a full 832-frame joint loop (LCM 64/13); a short movie
# excerpt may be rendered separately without claiming that excerpt is a loop.
s=review_scene('R9W4_REVIEW_SPRINT_ALL',bpy.data.objects[design['categories']['Rifle']['cameras']['Front']],12.8);s.render.resolution_x=1920;s.render.resolution_y=1440;s.frame_end=832;s.camera.location=(0,-7,6);s.camera.rotation_euler=(Vector((0,0,0))-s.camera.location).to_track_quat('-Z','Y').to_euler();q=s.camera.matrix_world.to_quaternion();right=q@Vector((1,0,0));up=q@Vector((0,1,0));actors={}
for j,(category,data) in enumerate(design['categories'].items()):
    for label,sign in [('A',-1),('B',1)]:
        r,m,ws=clone_actor('Sprint_'+category+'_'+label,s,category,assets);upper=bpy.data.actions[data['baseline_actions' if label=='A' else 'actions']['Move']];compose(r,upper,lower['Sprint'],64)
        r.location+=right*(sign*2.4)+up*((1-j)*2.65)
        actors[category+'_'+label]={'rig':r.name,'upper':upper.name}
s.frame_set(1);reviews['Sprint_All']={'scene':s.name,'actors':actors,'frames':[1,832],'movie_excerpt_frames':208,'fps':24,'lower':lower['Sprint'].name}
design['reviews']=reviews;design['locomotion']={'source_file':'player_locomotion_turning_v3_study.blend','source_action_digests':source_hashes,'imported_actions':{n:a.name for n,a in source_actions.items()},'lower_rest_matrix_error':rest_error,'walk_period':16,'sprint_period':13,'turn_weights_and_paths':'Original R3 review metadata / path Actions; V3 turn poses at same continuing phase; no foot edits','lower_copies':{g:a.name for g,a in lower.items()},'turn_lower':{g:a.name for g,a in turn_lower.items()}}
(OUT/'design.json').write_text(json.dumps(design,indent=2));bpy.context.window.scene=bpy.data.scenes['R9W4_REVIEW_RIFLE_HOLD'];save_checkpoint()
result={'review_scenes':[v['scene'] for v in reviews.values()],'locomotion_rest_error':rest_error,'native_walk_sprint_periods':[16,13]}
