import bpy,json,sys,math
from pathlib import Path
from mathutils import Matrix
HERE=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/actions_stuff_walk_v001')
sys.path.insert(0,str(HERE.parents[4]/'blender/animation/showcase'))
import gaf_animation_library as lib
info=json.loads((HERE/'manifest.json').read_text());s=bpy.data.scenes[info['scene']];bpy.context.window.scene=s
r=bpy.data.objects[info['source_rig']];m=bpy.data.objects[info['source_mesh']]
assert lib.rest_signature(r.data)==info['rig_sha256'];assert lib.action_signature(bpy.data.actions[info['action']])==info['action_sha256']
maximum=0;worst=None
for sample in json.loads((HERE/'expected_matrices.json').read_text()):
 f=sample['frame'];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
 for n,expected in sample['matrices'].items():
  err=max(abs(r.pose.bones[n].matrix[i][j]-expected[i][j]) for i in range(4) for j in range(4))
  if err>maximum:maximum=err;worst={'bone':n,'frame':f,'basis':[list(v)for v in r.pose.bones[n].matrix_basis]}
sole_indices={side:[v.index for v in m.data.vertices if any(g.group==m.vertex_groups['Leg.'+side].index and g.weight>.99 for g in v.groups)] for side in ['L','R']}
heights={side:[] for side in ['L','R']};minscale=1;maxscale=1
for i in range(241):
 f=1+i/10;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();evaluated=m.evaluated_get(bpy.context.evaluated_depsgraph_get())
 for side,ids in sole_indices.items():heights[side].append(min((evaluated.matrix_world@evaluated.data.vertices[k].co).z for k in ids))
 for p in r.pose.bones:
  minscale=min(minscale,*p.scale);maxscale=max(maxscale,*p.scale)
s.frame_set(1);first={p.name:p.matrix.copy() for p in r.pose.bones};s.frame_set(25)
seam=max(abs(p.matrix[i][j]-first[p.name][i][j]) for p in r.pose.bones for i in range(4) for j in range(4))
report={'source_reopened':True,'matrix_sample_count':242,'maximum_bone_matrix_error':maximum,'loop_pose_seam_error':seam,'floor_z':bpy.data.objects['ASW_FixedFloor'].location.z,'lowest_leg_vertex_z_range':{k:[min(v),max(v)] for k,v in heights.items()},'scale_range':[minscale,maxscale],'geometry_samples':241,'note':'Faithful source movement; floor and support observations are reported without changing source keyframes.'}
print('DIAGNOSTIC',json.dumps(report),worst,flush=True)
assert maximum<1e-4 and seam<2e-6 and minscale>0.99999 and maxscale<1.00001
(HERE/'source_verification.json').write_text(json.dumps(report,indent=2));print('SOURCE_VERIFIED',json.dumps(report),flush=True)
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=8;s.cycles.use_denoising=True;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
for view,cam in [('three_quarter','Showcase_THREE_QUARTER'),('front','Showcase_FRONT'),('side','Showcase_SIDE')]:
 s.camera=bpy.data.objects[cam];s.frame_set(6,subframe=.3328);s.render.filepath=str(HERE/(view+'_preview.png'));bpy.ops.render.render(write_still=True,scene=s.name)
print('PREVIEW_IMAGES_READY',flush=True)
