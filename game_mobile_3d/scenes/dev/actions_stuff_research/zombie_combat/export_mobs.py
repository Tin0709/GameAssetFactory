"""Read-only evaluated export of the exact existing three Mobs research Actions.
Raw tables/fixtures stay in --stage outside Git; never saves a Blender file.
"""
import bpy, sys, json, math, hashlib, struct, argparse
from pathlib import Path
from mathutils import Matrix
parser=argparse.ArgumentParser();parser.add_argument('--stage',required=True);parser.add_argument('--repo',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);R=Path(args.repo);S=Path(args.stage);S.mkdir(parents=True,exist_ok=True)
sys.dont_write_bytecode=True
sys.path.insert(0,str(R/'blender/animation/showcase/mobs_library'))
import gaf_mobs_animation_library as ui
source=R/'blender/animation/showcase/Mobs_Animation_Library.blend';before=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
scene=bpy.context.scene;registry=ui.registry(scene)
names=['Root','Hips','Spine','Chest','Neck','Head','Arm.L','Arm.R','Leg.L','Leg.R']
actions={'Idle':'Zombie_Idle_ActionsStuff_Source_Test_v001','Walk':'Zombie_Walk_ActionsStuff_Source_Test_v001','Attack':'Zombie_Attack_Player_A&S_Reference_v001'}
profile={'research_only':True,'production_eligible':False,'source':str(source.relative_to(R)),'source_sha256':before,'bones':names,'clips':{}}
fixtures=[];A=Matrix.Rotation(-math.pi/2,4,'X')
for kind,name in actions.items():
    entry=next(e for e in registry['clips'] if e.get('action')==name)
    rig=bpy.data.objects[entry['preview_rig']];action=bpy.data.actions[name]
    duration=entry.get('duration_s',(entry['end']-entry['start']+1)/entry['fps'])
    # Unhide the original research rig in this background session only.
    col=bpy.data.collections[entry['preview_collection']];col.hide_viewport=False;col.hide_render=False
    def include(layer):
        if layer.collection.name==col.name:layer.exclude=False
        for child in layer.children:include(child)
    for view in scene.view_layers:include(view.layer_collection)
    rig.hide_set(False);rig.animation_data_create();rig.animation_data.action=action
    rig.animation_data.action_slot=next(s for s in action.slots if s.identifier==entry['slot'])
    for track in rig.animation_data.nla_tracks:track.mute=True
    times=sorted({0.,duration}|{round((k.co.x-entry['start'])/entry['fps'],9) for l in action.layers for st in l.strips for bag in st.channelbags for c in bag.fcurves for k in c.keyframe_points if 0<=(k.co.x-entry['start'])/entry['fps']<=duration})
    previous={};rows=[]
    for index,t in enumerate(times):
        f=entry['start']+t*entry['fps'];scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        world={n:rig.pose.bones[n].matrix.copy() for n in names};row=[t];poses={}
        for n in names:
            bone=rig.data.bones[n]
            local=world[bone.parent.name].inverted()@world[n] if bone.parent else A@world[n]
            p,q,s=local.decompose()
            if n in previous and q.dot(previous[n])<0:q.negate()
            previous[n]=q.copy();values=[*p,q.x,q.y,q.z,q.w,*s];row+=values;poses[n]=values
        rows.append(row)
        if index in {0,len(times)-1}|{int((len(times)-1)*x) for x in [.031,.129,.277,.499,.731,.917]}:
            fixtures.append({'kind':kind,'time':t,'poses':poses})
    raw=S/(kind.lower()+'.bin')
    with raw.open('wb') as out:
        for row in rows:out.write(struct.pack('<'+'f'*len(row),*row))
    profile['clips'][kind]={'action':name,'action_sha256':ui.action_signature(action),'registered_status':entry['status'],'duration':duration,'samples':len(rows),'row_floats':len(rows[0]),'raw_file':raw.name,'loop':kind!='Attack','preview_floor_y':entry['preview_floor_z_m']}
    print('EXPORTED',kind,duration,len(rows),flush=True)
assert hashlib.sha256(source.read_bytes()).hexdigest()==before
(S/'profile.json').write_text(json.dumps(profile,indent=2));(S/'fixtures.json').write_text(json.dumps(fixtures,indent=2))
