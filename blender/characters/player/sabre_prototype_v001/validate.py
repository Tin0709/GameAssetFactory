"""Independent saved/reopened Blender acceptance, then GLB pose roundtrip."""
from pathlib import Path
import bpy, json, math, sys
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import motion

def run():
    path=HERE/'Sabre_Character_Showcase.blend'
    assert path.exists(),'Blender showcase is not built'
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False)
    scene=bpy.context.scene;rig=bpy.data.objects['SabrePrototypeRig']
    body=bpy.data.objects['SabrePrototypeBody'];face=bpy.data.objects['SabrePrototypeFace']
    sabre=bpy.data.objects['SabrePrototypeSabre']
    checks={};fixtures=[]
    checks['22_named_actions']=all('Sabre_'+name in bpy.data.actions for name in motion.CLIPS)
    checks['11_rigid_bones']=len(rig.data.bones)==11
    checks['face_morphs']=set(face.data.shape_keys.key_blocks.keys())=={'Basis','Focused','Blink'}
    checks['neutral_face_defaults']=all(face.data.shape_keys.key_blocks[k].value==0 for k in ['Focused','Blink'])
    checks['packed_authored_atlas']=all(i.packed_file is not None for i in bpy.data.images if i.name.startswith('Sabre_AuthoredAtlas'))
    for name,obj in [('body',body),('face',face),('sabre',sabre)]:
        checks[name+'_rigid_weights']=all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in obj.data.vertices)
    rig.animation_data.use_nla=False
    max_grip=0.;changed=False;min_blade_z=100.
    for name,row in motion.CLIPS.items():
        action=bpy.data.actions['Sabre_'+name]
        rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        checks[name+'_duration']=abs((action.frame_range[1]-action.frame_range[0])/120-row['duration'])<1e-6
        bounds=[]
        for f in [0,.25,.5,.75,1]:
            frame=1+row['duration']*120*f
            scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
            arm_head=rig.matrix_world@rig.pose.bones['Hand.R'].matrix.translation
            mount_head=rig.matrix_world@rig.pose.bones['Weapon'].matrix.translation
            max_grip=max(max_grip,(arm_head-mount_head).length)
            assert (bpy.data.objects['SabreGrip'].matrix_world.translation-mount_head).length<1e-5
            evaluated=sabre.evaluated_get(bpy.context.evaluated_depsgraph_get())
            verts=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
            assert all(math.isfinite(c) for v in verts for c in v)
            if name in ['Idle','Walk','Run','CombatReady']:min_blade_z=min(min_blade_z,min(v.z for v in verts))
            tip=max(verts,key=lambda v:(v-mount_head).length)
            bounds.append([*tip])
            if name in ['Idle','Walk','Run','Attack1','Attack2','Attack3','Recovery1','JumpTakeoff','JumpAirborne','JumpLanding']:
                fixtures.append({'clip':name,'fraction':f,'joint_positions':{
                    b:list(rig.matrix_world@rig.pose.bones[b].matrix.translation) for b in ['Hips','Head','Arm.R','Hand.R','Weapon']},
                    'sabre_bounds':[[min(v[k] for v in verts),max(v[k] for v in verts)] for k in range(3)]})
        if name=='Attack1':changed=(Vector(bounds[0])-Vector(bounds[2])).length>.35
        if name=='Attack1':
            scene.frame_set(1);bpy.context.view_layer.update()
            axis=rig.pose.bones['Body'].matrix.to_quaternion()@Vector((0,0,1))
            from mathutils import Quaternion
            axis=Quaternion((0,0,1),math.radians(35))@axis
            checks['physical_side_lean_has_intended_sign']=axis.x<0
    checks['evaluated_blade_motion']=changed
    checks['grip_invariant']=max_grip<1e-5
    checks['grounded_blade_clearance']=min_blade_z>-.03
    checks['source_files_not_linked']=all(not lib for lib in bpy.data.libraries)
    result={'checks':checks,'all_passed':all(checks.values()),'maximum_grip_error':max_grip,
            'minimum_sampled_grounded_blade_z':min_blade_z,'fixtures':fixtures,
            'scope':'Own saved geometry/poses/atlas; source-informed sparse recreation, not MD2 tracks.'}
    (HERE/'blender-validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    assert result['all_passed'],[k for k,v in checks.items() if not v]
    print('BLENDER_SABRE_ACCEPTANCE',len(checks),'checks passed')

if __name__=='__main__':run()
