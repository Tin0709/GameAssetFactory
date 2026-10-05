import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/animation')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'player_cuboid_v5_movement.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];player=bpy.data.objects['Player_Cuboid_Base'];m=player.data
source=json.loads((OUT/'source_signature.json').read_text());static=source['static']
assert static['vertices']==[list(v.co) for v in m.vertices]
assert static['uv']==[list(d.uv) for d in m.uv_layers.active.data]
assert static['weights']==json.loads(json.dumps([[(g.group,g.weight) for g in v.groups] for v in m.vertices]))
assert static['bones']==json.loads(json.dumps([(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local],b.use_deform) for b in rig.data.bones]))
assert static['pixels']==list(bpy.data.images['Player_Cuboid_V5_Face_Atlas_64'].pixels)
assert source['sha256']==hashlib.sha256((OUT.parent/'player_cuboid_v5.blend').read_bytes()).hexdigest()
assert not any(pb.constraints for pb in rig.pose.bones)
reset_channels={}
baseline=[(m.vertices[e.vertices[0]].co-m.vertices[e.vertices[1]].co).length for e in m.edges]
parts=json.loads(player['rigid_parts'])
report={}
def reset():
    for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_euler=(0,0,0);pb.scale=(1,1,1)
def meshpositions(f):
    scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    obj=player.evaluated_get(bpy.context.evaluated_depsgraph_get());dm=obj.to_mesh();p=[v.co.copy() for v in dm.vertices];obj.to_mesh_clear();return p
for name,N in [('Player_Idle',48),('Player_Walk',32),('Player_Run',24)]:
    reset();a=bpy.data.actions[name];rig.animation_data.action=a
    first=meshpositions(1);last=meshpositions(N+1)
    closure=max((a-b).length for a,b in zip(first,last));edgeerr=0;rooterr=0;minfloor=1e6;maxfloor=-1e6;minscale=1;maxscale=1
    feet={s:[] for s in ['L','R']};allfeet={s:[] for s in ['L','R']};planted={s:[] for s in ['L','R']};headtilts=[];positions=[]
    for i in range(N*4+1):
        f=1+i/4;ps=meshpositions(f);positions.append(ps)
        for e,b in zip(m.edges,baseline):edgeerr=max(edgeerr,abs((ps[e.vertices[0]]-ps[e.vertices[1]]).length-b))
        rooterr=max(rooterr,max(abs(rig.pose.bones['Root'].matrix[r][c]-rig.data.bones['Root'].matrix_local[r][c]) for r in range(4) for c in range(4)))
        for pb in rig.pose.bones:
            minscale=min(minscale,*pb.scale);maxscale=max(maxscale,*pb.scale)
        for s in ['L','R']:
            part=next(p for p in parts if p['bone']=='Shin.'+s)
            floor=min(ps[j].z for j in range(part['first_vertex'],part['first_vertex']+8));minfloor=min(minfloor,floor)
            phase=((f-1)/N+(0 if s=='L' else .5))%1
            ankle=rig.pose.bones['Foot.'+s].matrix.translation.copy();allfeet[s].append(ankle)
            if name=='Player_Idle':feet[s].append(ankle);planted[s].append(floor)
            elif (.06<=phase<=.38 if name=='Player_Walk' else .045<=phase<=.17):
                speed=.6 if name=='Player_Walk' else 1.68
                feet[s].append(Vector((ankle.x,ankle.y-speed*phase*N/24,ankle.z)));planted[s].append(floor)
        rot=rig.pose.bones['Head'].matrix.to_quaternion() @ rig.data.bones['Head'].matrix_local.to_quaternion().inverted()
        headtilts.append(math.degrees(rot.angle))
    # Finite velocity continuity around the loop closure (at 1/100 frame).
    eps=.01
    p0=meshpositions(1);pa=meshpositions(1+eps);pb=meshpositions(N+1-eps)
    velerr=max(((x-z)/eps-(z-y)/eps).length for x,y,z in zip(pa,pb,p0))
    drift={s:{'lateral_span_m':max(v.x for v in feet[s])-min(v.x for v in feet[s]),'treadmill_corrected_foreaft_span_m':max(v.y for v in feet[s])-min(v.y for v in feet[s]),'stance_min_z_m':min(planted[s]),'stance_max_z_m':max(planted[s])} for s in ['L','R']}
    # maximum consecutive quarter-frame vertex travel indicates gross pops.
    step=max((v-w).length for a,b in zip(positions,positions[1:]) for v,w in zip(a,b))
    report[name]={'playback':[1,N],'closing_key':N+1,'fps':24,'loop_vertex_error_m':closure,'loop_velocity_error_m_per_frame':velerr,'rigid_edge_error_m':edgeerr,'root_matrix_error':rooterr,'minimum_floor_z_m':minfloor,'scale_range':[minscale,maxscale],'max_quarter_frame_vertex_travel_m':step,'head_max_world_rotation_deg':max(headtilts),'foot_contact':drift}
    assert closure<1e-6 and edgeerr<1e-6 and rooterr<1e-7 and minscale==maxscale==1
reset();rig.animation_data.action=bpy.data.actions['Player_Idle'];expected=meshpositions(13)
rig.animation_data.action=bpy.data.actions['Player_Run'];meshpositions(7)
rig.animation_data.action=bpy.data.actions['Player_Idle'];switched=meshpositions(13)
assert max((a-b).length for a,b in zip(expected,switched))<1e-6
for info in report.values():info['switching_actions_resets_unused_channels']=True
reset();rig.animation_data.action=bpy.data.actions['Player_Idle'];scene.frame_start=1;scene.frame_end=48;scene.frame_set(1)
(OUT/'movement_validation.json').write_text(json.dumps(report,indent=2))
result=report
