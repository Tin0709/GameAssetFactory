"""Non-production A/B reel; all world travel is on PREVIEW path parents."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
assert Path(bpy.data.filepath)==DEV
assert 'R2_Review_AB' not in bpy.data.scenes
protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected)
CASES=[('Left bend',3.),('Right bend',3.),('S curve',4.),('CCW circle',4.5),('CW circle',4.5)]
MAX_RATE=2*math.pi/3
def pulse(t,a,b,c,d):
    return smooth((t-a)/(b-a))*(1-smooth((t-c)/(d-c)))
def rate(label,t):
    if label in ['Left bend','Right bend']:return (1 if label=='Left bend' else -1)*(math.pi/3)*pulse(t,.5,1,2,2.5)
    if label=='S curve':return 1.2*(pulse(t,.4,.8,1.4,1.8)-pulse(t,2,2.4,3,3.4))
    return (1 if label=='CCW circle' else -1)*MAX_RATE*pulse(t,.5,1,3.5,4)
def path_frames(speed):
    rows=[];start=0.
    for label,duration in CASES:
        h=1/240;pos=Vector((0,0,0));yaw=0.;fine=[(pos.copy(),yaw)]
        for i in range(round(duration/h)):
            w=rate(label,(i+.5)*h);mid=yaw+w*h/2
            pos+=Vector((math.sin(mid),-math.cos(mid),0))*speed*h;yaw+=w*h;fine.append((pos.copy(),yaw))
        lo=Vector((min(p.x for p,y in fine),min(p.y for p,y in fine),0));hi=Vector((max(p.x for p,y in fine),max(p.y for p,y in fine),0));center=(lo+hi)/2
        for i in range(round(duration*24)):
            t=i/24;pos,yaw=fine[i*10]
            rows.append({'time':start+t,'case':label,'case_time':t,'position':list(pos-center),'yaw':yaw,'signed_weight':rate(label,t)/MAX_RATE,'phase':None})
        start+=duration
    return rows
def evaluate(a,f):
    ps={n:(Vector((0,0,0)),Euler((0,0,0),'XYZ')) for n in BODY}
    for c in curves(a):
        n=c.data_path.split('"')[1]
        if n not in ps:continue
        prop=c.data_path.rsplit('.',1)[1]
        if prop in ['location','rotation_euler']:ps[n][0 if prop=='location' else 1][c.array_index]=c.evaluate(f)
    return ps
def fullpose(gait,t,weight,phase_offset=0):
    period=PERIOD[gait];f=1+((t*24+phase_offset*period)%period)
    a=evaluate(bpy.data.actions[gait+'_ReferenceStudy_V1'],f)
    if abs(weight)<1e-12:return a
    b=evaluate(bpy.data.actions[gait+'_Turn'+('Left' if weight>0 else 'Right')+'_Reference_V1'],f)
    return mix(a,b,min(1,abs(weight)))
metadata={'fps':24,'seconds':19,'cases':[],'gaits':{},'camera':'Fixed world rear-oblique camera; no camera orbit. Hard cuts between test paths, global gait time continues.'}
start=0
for label,dur in CASES:metadata['cases'].append({'name':label,'start_seconds':start,'end_seconds':start+dur});start+=dur

# Reuse R1's neutral lighting; new grid belongs only to this study.
world=bpy.data.worlds['R1_World']
floor_data=bpy.data.meshes.new('R2_Grid_Ground');floor_data.from_pydata([(-100,-100,-.005),(100,-100,-.005),(100,100,-.005),(-100,100,-.005)],[],[(0,1,2,3)])
mat=bpy.data.materials.new('R2_Grid');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.95
coord=nodes.new('ShaderNodeTexCoord');check=nodes.new('ShaderNodeTexChecker');check.inputs['Scale'].default_value=2
check.inputs['Color1'].default_value=(.16,.19,.22,1);check.inputs['Color2'].default_value=(.22,.25,.28,1)
links.new(coord.outputs['Object'],check.inputs['Vector']);links.new(check.outputs['Color'],bs.inputs['Base Color']);floor_data.materials.append(mat)
lights=[o for o in bpy.data.scenes['R1_Walk_Sprint_Comparison'].objects if o.type=='LIGHT']
def scene_setup(name):
    s=bpy.data.scenes.new(name);s.use_fake_user=True;s.world=world;s.render.engine='BLENDER_EEVEE'
    s.render.resolution_x=480;s.render.resolution_y=480;s.render.resolution_percentage=100
    s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=456;s.sync_mode='FRAME_DROP'
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGB'
    for o in lights:s.collection.objects.link(o)
    floor=bpy.data.objects.new(name+'_Ground',floor_data);s.collection.objects.link(floor)
    s.camera=camera(s,name+'_FixedWorldCamera',(0,10,5.5),(0,0,.6),6.2)
    for case in metadata['cases']:s.timeline_markers.new(case['name'],frame=1+round(case['start_seconds']*24))
    return s

paths={};preview_actions={}
author=bpy.data.objects['R2_Author_Rig']
for gait,speed in [('Walk',1.4),('Sprint',2.1)]:
    rows=path_frames(speed);paths[gait]=rows
    for row in rows:row['phase']=(row['time']*24/PERIOD[gait])%1
    s=bpy.data.scenes['R2_Turn_Authoring'];bpy.context.window.scene=s
    a=bpy.data.actions.new('PREVIEW_ONLY_R2_'+gait+'_BlendedReel');a.use_fake_user=True
    for i,row in enumerate(rows):key_pose(author,a,i+1,fullpose(gait,row['time'],row['signed_weight']))
    for c in curves(a):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    a['preview_only']='Baked same-phase absolute-pose blend. Do not export. World travel is in a separate path-parent Action.'
    preview_actions[gait]=a
    for variant in ['A','B']:
        ss=scene_setup('R2_'+gait+'_'+variant);rr,mm=copy_character(ss,gait+'_'+variant)
        parent=bpy.data.objects.new('PREVIEW_R2_'+gait+'_'+variant+'_Path',None);ss.collection.objects.link(parent);rr.parent=parent
        if variant=='A':
            for i,row in enumerate(rows):
                parent.location=row['position'];parent.rotation_euler=(0,0,row['yaw'])
                parent.keyframe_insert('location',frame=i+1);parent.keyframe_insert('rotation_euler',frame=i+1)
            pathaction=parent.animation_data.action;pathaction.name='PREVIEW_ONLY_R2_'+gait+'_Path';pathaction.use_fake_user=True
            for c in curves(pathaction):
                for i,k in enumerate(c.keyframe_points):
                    k.interpolation='CONSTANT' if i+1<len(rows) and rows[i]['case']!=rows[i+1]['case'] else 'LINEAR'
        else:parent.animation_data_create();parent.animation_data.action=pathaction;parent.animation_data.action_slot=pathaction.slots[0]
        assign(rr,bpy.data.actions[gait+'_ReferenceStudy_V1'] if variant=='A' else a)
        ss.frame_set(1)
    metadata['gaits'][gait]={'speed_m_s':speed,'period_frames':PERIOD[gait],'rows':rows}

# One live four-up scene, using offset stage parents so A/B tracks are identical.
review=scene_setup('R2_Review_AB');review.camera.data.ortho_scale=16
review.camera.location=(0,18,17);review.camera.rotation_euler=(Vector((0,0,.6))-review.camera.location).to_track_quat('-Z','Y').to_euler()
review.render.resolution_x=1280;review.render.resolution_y=1000
for gait,y in [('Walk',-4.6),('Sprint',4.6)]:
    for variant,x in [('A',3.6),('B',-3.6)]:
        rr,mm=copy_character(review,'Review_'+gait+'_'+variant)
        stage=bpy.data.objects.new('PREVIEW_R2_Stage_'+gait+'_'+variant,None);review.collection.objects.link(stage);stage.location=(x,y,0)
        parent=bpy.data.objects.new('PREVIEW_R2_Review_'+gait+'_'+variant+'_Path',None);review.collection.objects.link(parent);parent.parent=stage
        parent.animation_data_create();pa=bpy.data.actions['PREVIEW_ONLY_R2_'+gait+'_Path'];parent.animation_data.action=pa;parent.animation_data.action_slot=pa.slots[0];rr.parent=parent
        assign(rr,bpy.data.actions[gait+'_ReferenceStudy_V1'] if variant=='A' else preview_actions[gait])
        d=bpy.data.curves.new('R2_Label','FONT');d.body=gait+' '+variant;d.size=.28;d.align_x='CENTER'
        ob=bpy.data.objects.new('R2_Label_'+gait+'_'+variant,d);review.collection.objects.link(ob);ob.location=(x,y+2.6,.03);ob.rotation_euler=(0,0,math.pi)
game=review.copy();game.name='R2_Review_Gameplay';game.use_fake_user=True
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)));q=(D@Matrix.Rotation(math.radians(36.86989764584402),3,'Y')@Matrix.Rotation(math.radians(-36.31588642394517),3,'X')).to_quaternion()
gc=camera(game,'R2_GameplayCamera',(0,0,15),(0,0,.6),14.5*1280/720);gc.rotation_euler=q.to_euler();gc.location=Vector((0,0,.6))+q@Vector((0,0,20));game.camera=gc;game.render.resolution_x=1280;game.render.resolution_y=720

# Same-phase entry probes at four offsets; the envelope never resets the gait clock.
phase_tests=[]
bpy.context.window.scene=bpy.data.scenes['R2_Turn_Authoring'];r=author;pts=mesh_points(bpy.data.objects['R2_Author_Mesh'])
for gait,period in PERIOD.items():
    for direction,sign in [('Left',1),('Right',-1)]:
        for phase in [0,.25,.5,.75]:
            minimum=1.;maxerr=0.;enderr=0
            # Entry starts at t=0 in this diagnostic, at the requested normalized phase.
            for i in range(193):
                t=i/240;w=sign*smooth(t/.4)*(1-smooth((t-.4)/.4))
                ps=fullpose(gait,t,w,phase);apply(r,ps);minimum=min(minimum,floor_min(r,pts))
                expected=(phase+t*24/period)%1;computed=((t*24+phase*period)%period)/period;maxerr=max(maxerr,abs(expected-computed))
            p0=fullpose(gait,.8,0,phase);p1=fullpose(gait,.8,sign*smooth(2)*(1-smooth(1)),phase)
            enderr=max((p0[n][0]-p1[n][0]).length for n in BODY)
            phase_tests.append({'gait':gait,'direction':direction,'entry_phase':phase,'phase_error':maxerr,'floor_min_m':minimum,'return_pose_location_error':enderr})
            assert minimum>-.001 and maxerr<1e-10 and enderr<1e-6
(OUT/'preview_metadata.json').write_text(json.dumps(metadata,indent=2));(OUT/'phase_entry_tests.json').write_text(json.dumps(phase_tests,indent=2))
readme=bpy.data.texts.new('R2_README');readme.write('R2 TURNING STUDY — first pass only.\nFour new full-pose cyclic variants, absolute crossfade at shared R1 phase.\nLeft = anatomical +X at rest, positive world-Z yaw; right = opposite.\nRoot stays still; PREVIEW path parents carry world motion.\nA = straight R1 + path; B = same phase/path + turning blend.\nR2_Review_AB: Walk upper row, Sprint lower row; A left, B right. Space = 24 FPS, 1.0x.\n19-second reel: left bend, right bend, S, CCW circle, CW circle. Hard cuts between paths; no gait reset on turn entry/exit.\nR2_Review_Gameplay = elevated project camera scale. Individual R2_Walk_A/B and R2_Sprint_A/B scenes share fixed world framing.\nNo Godot, weapons or R1 asset changes. Preview-only Actions must not be exported.\n')
check_preserved(protected);bpy.context.window.scene=review;review.frame_set(1)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.region_3d.view_camera_zoom=10
    if area.type=='DOPESHEET_EDITOR':area.spaces.active.mode='TIMELINE'
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'preview_seconds':19,'frames':456,'phase_entry_cases':len(phase_tests),'active_scene':review.name}
