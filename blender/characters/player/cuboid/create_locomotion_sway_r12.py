from locomotion_sway_r12_common import *
assert not bpy.data.scenes.get('R12_WALK_ALL')
baseline={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'}}
(R12OUT/'baseline.json').write_text(json.dumps(baseline,indent=2))
baseposes={kind:base_hold(kind) for kind in ['Unarmed','Pistol','Rifle','Shotgun']}
design={'scope':'Isolated universal torso-sway study; human review before production migration','gaits':GAITS,'source_file':bpy.data.filepath,'scenes':{},'source_locomotion':CURRENT['locomotion'],'turn_preview':'Native S-curve case only, original phase and yaw; in-place direction review'}
for gait in ['Walk','Sprint']:
    for turning in [False,True]:
        key=gait+('_Turn' if turning else '');name='R12_'+gait.upper()+('_TURN' if turning else '')+'_ALL'
        sc=studio(name);sc.render.resolution_x=1800;sc.render.resolution_y=700;sc.render.fps=24
        cam=camera(sc,name+'_Camera',(3,-5,3),(0,-.25,1.1),11.5);sc.camera=cam
        right=cam.rotation_euler.to_quaternion()@Vector((1,0,0));actors={}
        lower_name=CURRENT['locomotion']['turn_lower' if turning else 'lower_copies'][gait]
        if turning:
            source=bpy.data.actions[CURRENT['locomotion']['imported_actions']['PREVIEW_ONLY_R3_'+gait+'_Path']]
            path_action=source.copy();path_action.name='R12_'+gait+'_NativeYaw_InPlace';path_action.use_fake_user=True
            for layer in path_action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for fc in list(bag.fcurves):
                            if fc.data_path=='location':bag.fcurves.remove(fc)
            path_action['scope']='Preview orientation only. Original heading clock retained; source path unchanged.'
        for i,kind in enumerate(['Unarmed','Pistol','Rifle','Shotgun']):
            rig,mesh,weapons=new_actor(sc,gait,kind,turning)
            upper,metadata=author_upper(sc,rig,gait,kind,turning,baseposes[kind])
            compose(rig,upper,bpy.data.actions[lower_name],1 if turning else 4)
            offset=right*((i-1.5)*2.65)
            if turning:
                stage=bpy.data.objects.new(name+'_'+kind+'_Stage',None);sc.collection.objects.link(stage);stage.location=offset
                path=bpy.data.objects.new(name+'_'+kind+'_Yaw',None);sc.collection.objects.link(path);path.parent=stage;assign(path,path_action)
                rig.parent=path;rig.matrix_parent_inverse=Matrix.Identity(4);rig.location=(0,0,0)
            else:rig.location=offset
            actors[kind]={'rig':rig.name,'mesh':mesh.name,'weapons':[w.name for w in weapons],'upper':upper.name,'motion':metadata}
            label(sc,cam,kind.upper(),(i-1.5)*2.65)
        sc.frame_start=145 if turning else 1;sc.frame_end=240 if turning else GAITS[gait]['period']*4
        sc.frame_set(sc.frame_start);sc.sync_mode='FRAME_DROP'
        design['scenes'][key]={'scene':sc.name,'actors':actors,'lower':lower_name,'frame_start':sc.frame_start,'frame_end':sc.frame_end,'path_yaw':path_action.name if turning else None,'loop':not turning}
(R12OUT/'design.json').write_text(json.dumps(design,indent=2))
bpy.context.window.scene=bpy.data.scenes[design['scenes']['Walk']['scene']]
result={'scenes':{k:v['scene'] for k,v in design['scenes'].items()},'new_upper_actions':16,'original_gait_periods':[16,13]}
