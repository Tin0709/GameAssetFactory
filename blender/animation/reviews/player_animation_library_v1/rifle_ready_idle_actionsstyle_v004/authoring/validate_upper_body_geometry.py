"""Read-only independent Blender geometry guard.
Run Blender --background --python this.py -- --candidate ABS.blend --output ABS.json.
Default source and Action hashes are pinned to approved shoulder_support_v006.
Current user-authorized neck/right-shoulder seating has explicit absolute bounds;
all other rigidity/nonadjacent/foot/loop guards remain unchanged.
All mesh collision tests operate on the original rigid cuboids and actual rifle meshes.
BVH triangle counts are reported only with baseline/adjacency/solid-contact context.
"""
import bpy,sys,json,math,hashlib,itertools,argparse
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file())
SOURCE=ROOT/'blender/animation/reviews/player_animation_library_v1/rifle_ready_v16_test/shoulder_support_v006/rifle_ready_v16_review.blend'
SOURCE_SHA='22017e77d5a722d087c46bd839e38fbec5a30ac5a56bb4b326e86cbbbbee3fde'
ACTION_SHA='e12357dab1a854a4642f293e8049747f7e17b426ff69f1a4c331327b47e91743'
BASE_ACTION='Rifle_Ready_V2_v16_Test';NEW_ACTION='Rifle_Ready_Idle_ActionsStyle_v004'
WEAPONS=['Rifle_V2_Body','Rifle_V2_Magazine']
ARMS=['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R']
# These are existing anatomical joint or approved solid block-hand contacts.
ADJACENT={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('Chest','Leg.L'),('Chest','Leg.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R')]}
CONTACT={frozenset(x) for x in [('UpperArm.R','Rifle_V2_Body'),('ForeArm.R','Rifle_V2_Body'),('Rifle_V2_Body','Rifle_V2_Magazine')]}
def sig(a):
 def props(o):return [(p.identifier,getattr(o,p.identifier)) for p in o.bl_rna.properties if p.type in {'BOOLEAN','INT','FLOAT','ENUM'} and not p.is_readonly and p.identifier not in {'show_expanded','active'}]
 curves=[c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
 d=[(c.data_path,c.array_index,c.mute,c.group.mute if c.group else False,c.extrapolation,c.auto_smoothing,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type,k.easing,k.back,k.amplitude,k.period) for k in c.keyframe_points],[(m.type,props(m)) for m in c.modifiers]) for c in curves]
 st=[(props(l),[(s.type,props(s),[b.slot_handle for b in s.channelbags]) for s in l.strips]) for l in a.layers]
 return hashlib.sha256(repr(([(s.identifier,s.target_id_type) for s in a.slots],st,d)).encode()).hexdigest()
def md(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
def rounded(xs):return [float(x) for x in xs]
def open_scene(p,action):
 bpy.ops.wm.open_mainfile(filepath=str(p));r=bpy.data.objects['Showcase_Player_Rig'];m=bpy.data.objects['Showcase_Player_Mesh'];a=bpy.data.actions[action]
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 # Prevent the Showcase selection handler from switching away from explicitly chosen Action.
 bpy.context.scene['gaf_library_last_action']=action
 return r,m,a

def frame(t):bpy.context.scene.frame_set(int(t),subframe=t-int(t));bpy.context.view_layer.update()
def topology(r,m):
 return {'rest':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in r.data.bones], 'vertices':[list(v.co) for v in m.data.vertices], 'polygons':[list(p.vertices) for p in m.data.polygons], 'weights':[[(m.vertex_groups[g.group].name,g.weight) for g in v.groups] for v in m.data.vertices], 'weapon':{n:{'vertices':[list(v.co) for v in bpy.data.objects[n].data.vertices],'polygons':[list(p.vertices) for p in bpy.data.objects[n].data.polygons]} for n in WEAPONS}}
def setup(r,m):
 groups={g.index:g.name for g in m.vertex_groups};ids={g.name:[] for g in m.vertex_groups};bad=[]
 for v in m.data.vertices:
  w=[(groups[g.group],g.weight) for g in v.groups if g.weight>1e-8]
  if len(w)!=1 or abs(w[0][1]-1)>1e-8:bad.append(v.index)
  else:ids[w[0][0]].append(v.index)
 m.data.calc_loop_triangles();tri={g:[] for g in ids}
 for t in m.data.loop_triangles:
  ns={groups[m.data.vertices[i].groups[0].group] for i in t.vertices}
  if len(ns)!=1:raise RuntimeError('Triangle bridges rigid groups')
  tri[next(iter(ns))].append(tuple(t.vertices))
 return ids,tri,bad

def geometry(r,m,ids,tri):
 dg=bpy.context.evaluated_depsgraph_get();em=m.evaluated_get(dg).to_mesh();vs=[m.matrix_world@v.co for v in em.vertices];m.evaluated_get(dg).to_mesh_clear()
 pts={g:[vs[i] for i in ix] for g,ix in ids.items()};trees={g:BVHTree.FromPolygons(vs,ts,all_triangles=True,epsilon=0) for g,ts in tri.items()}
 for n in WEAPONS:
  o=bpy.data.objects[n];eo=o.evaluated_get(dg);me=eo.to_mesh();me.calc_loop_triangles();wv=[eo.matrix_world@v.co for v in me.vertices];pts[n]=wv;trees[n]=BVHTree.FromPolygons(wv,[tuple(t.vertices) for t in me.loop_triangles],all_triangles=True,epsilon=0);eo.to_mesh_clear()
 return pts,trees

def cuboid_signed_margin(A,B,axesA,axesB):
 """Positive=penetration, negative=separation; SAT on actual rigid cube face axes."""
 axes=[v.normalized() for v in axesA+axesB]
 axes += [u.cross(v).normalized() for u in axesA for v in axesB if u.cross(v).length>1e-7]
 return min(min(max(p.dot(a) for p in A),max(p.dot(a) for p in B))-max(min(p.dot(a) for p in A),min(p.dot(a) for p in B)) for a in axes)

def collision(r,pts,trees):
 pairs={};sat={}
 for a,b in itertools.combinations(pts,2):
  k=a+'|'+b;n=len(trees[a].overlap(trees[b]));pairs[k]=n
  if a in r.pose.bones and b in r.pose.bones:
   ma=r.matrix_world@r.pose.bones[a].matrix;mb=r.matrix_world@r.pose.bones[b].matrix
   sat[k]=cuboid_signed_margin(pts[a],pts[b],[ma.to_3x3().col[i] for i in range(3)],[mb.to_3x3().col[i] for i in range(3)])
 return pairs,sat

def bidirectional_gap(pts,trees,a,b):
 return min([trees[b].find_nearest(v)[3] for v in pts[a]]+[trees[a].find_nearest(v)[3] for v in pts[b]])
def pose_snapshot(r):return {b.name:(r.matrix_world@b.matrix).copy() for b in r.pose.bones}
def transform_vel(m0,m1,dt):
 v=(m1.translation-m0.translation)/dt;q0=m0.to_quaternion();q1=m1.to_quaternion();dq=q0.rotation_difference(q1)
 # atan2 on quaternion vector remains precise for tiny increments; acos(w)
 # quantizes near identity in single-precision Blender Quaternion.angle.
 if dq.w<0:dq.negate()
 xyz=Vector((dq.x,dq.y,dq.z));sn=xyz.length
 return v,xyz*(2*math.atan2(sn,dq.w)/(sn*dt)) if sn>1e-12 else Vector((0,0,0))
def main():
 av=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
 p=argparse.ArgumentParser();p.add_argument('--candidate');p.add_argument('--output',required=True);p.add_argument('--action',default=NEW_ACTION);opt=p.parse_args(av)
 out={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'candidate':opt.candidate,'sampling':('every integer and half-frame F1..325 (649 poses)' if opt.candidate else 'approved source every integer and half-frame F1..121 (241 poses)'),'limitations':['Blender geometry validation only; no Godot transitions or device certification.','Bidirectional vertex-to-surface gap is sampled, not the exact edge-to-edge minimum.','Raw triangle counts at approved adjacent joints, rigid block grip and stock contact are diagnostic; relative transform stability preserves their reviewed geometry.']}
 assert out['source_sha256']==SOURCE_SHA,'Approved source hash changed'
 r,m,a=open_scene(SOURCE,BASE_ACTION);assert sig(a)==ACTION_SHA,'Source Action mismatch'
 source_actions={a.name:sig(a) for a in bpy.data.actions};source_topology=topology(r,m);ids,tri,bad=setup(r,m);assert not bad
 frame(1);base_pose=pose_snapshot(r);base_attach=bpy.data.objects['GAF_Rifle_V2_Attachment'].matrix_world.copy();base_rels={n:base_attach.inverted()@base_pose[n] for n in ARMS}
 bp,bt=geometry(r,m,ids,tri);base_feet={g:[v.copy() for v in bp[g]] for g in ['Leg.L','Leg.R']};rest_dist={g:[(x-y).length for x,y in itertools.combinations(vs,2)] for g,vs in bp.items() if g not in WEAPONS};base_gap=bidirectional_gap(bp,bt,'ForeArm.L','Rifle_V2_Body')
 base_pairs={};base_sat={};base_gap_min=1e9;base_gap_max=0
 for j in range(241):
  frame(1+j/2);pts,trees=geometry(r,m,ids,tri);pairs,sats=collision(r,pts,trees)
  for k,v in pairs.items():base_pairs[k]=max(v,base_pairs.get(k,0))
  for k,v in sats.items():base_sat[k]=max(v,base_sat.get(k,-1e9))
  gap=bidirectional_gap(pts,trees,'ForeArm.L','Rifle_V2_Body');base_gap_min=min(base_gap_min,gap);base_gap_max=max(base_gap_max,gap)
 out['baseline']={'rigid_vertices':len(m.data.vertices),'vertex_groups':{g:len(v) for g,v in ids.items()},'rigid_weights_exact':not bad,'source_action_sha256':ACTION_SHA,'left_support_sampled_gap_range_m':[base_gap_min,base_gap_max],'raw_triangle_pairs_max':{k:v for k,v in base_pairs.items() if v},'cuboid_signed_margin_max_m':base_sat,'foot_lowest_z_m':{g:min(v.z for v in x) for g,x in base_feet.items()},'adjacent_contact_pair_names':[sorted(x) for x in ADJACENT],'approved_solid_contact_pair_names':[sorted(x) for x in CONTACT]}
 if not opt.candidate:
  out['passed']=True;Path(opt.output).write_text(json.dumps(out,indent=2));print(json.dumps({'baseline_report':opt.output,'baseline_gap_m':base_gap,'passed':True}));return
 out['candidate_sha256']=hashlib.sha256(Path(opt.candidate).read_bytes()).hexdigest()
 r,m,a=open_scene(opt.candidate,opt.action);ids,tri,bad=setup(r,m)
 failures=[];topology_exact=topology(r,m)==source_topology;preserved={n:(n in bpy.data.actions and sig(bpy.data.actions[n])==h) for n,h in source_actions.items()}
 if not topology_exact:failures.append('Original topology/weights/rest rig/weapon geometry changed')
 if not all(preserved.values()):failures.append('Pre-existing Action(s) missing/changed')
 if bad:failures.append('Nonrigid mesh weights')
 metrics={k:0.0 for k in ['arm_relative_rifle_matrix_error','connected_elbow_gap_m','straight_arm_cross_error','forearm_local_articulation_rad','bone_world_scale_error','rigid_pair_distance_error_m','foot_full_vertex_drift_m','foot_floor_penetration_m','attachment_to_carrier_matrix_error','left_support_gap_deviation_m','approved_entry_pose_matrix_error']}
 gap_min=1e9;gap_max=0;max_pairs={};max_sats={};unwanted=[];worse_adjacent={};floor=min(v.z for x in base_feet.values() for v in x)
 frame(1);candidate_entry=pose_snapshot(r);carrier_rel=candidate_entry['WeaponCarrier'].inverted()@bpy.data.objects['GAF_Rifle_V2_Attachment'].matrix_world
 for n in candidate_entry:metrics['approved_entry_pose_matrix_error']=max(metrics['approved_entry_pose_matrix_error'],md(candidate_entry[n],base_pose[n]))
 closing=int(round(a.frame_range[1]));poses={}
 handlocal=Vector((0,r.data.bones['ForeArm.L'].length*.78,0))
 anchor_ref=base_attach.inverted()@(base_pose['ForeArm.L']@handlocal);metrics['left_support_anchor_excursion_m']=0.
 for j in range(int((closing-1)*2)+1):
  t=1+j/2;frame(t);pm=pose_snapshot(r);at=bpy.data.objects['GAF_Rifle_V2_Attachment'].matrix_world.copy();pts,trees=geometry(r,m,ids,tri)
  if t in (1,1.5,2,closing-1,closing-.5,closing):poses[t]=pm
  metrics['left_support_anchor_excursion_m']=max(metrics['left_support_anchor_excursion_m'],(at.inverted()@(pm['ForeArm.L']@handlocal)-anchor_ref).length)
  for n in ['UpperArm.R','ForeArm.R']:metrics['arm_relative_rifle_matrix_error']=max(metrics['arm_relative_rifle_matrix_error'],md(at.inverted()@pm[n],base_rels[n]))
  for side in ['L','R']:
   u=r.pose.bones['UpperArm.'+side];f=r.pose.bones['ForeArm.'+side]
   metrics['connected_elbow_gap_m']=max(metrics['connected_elbow_gap_m'],(u.tail-f.head).length)
   metrics['straight_arm_cross_error']=max(metrics['straight_arm_cross_error'],(u.tail-u.head).normalized().cross((f.tail-f.head).normalized()).length)
   metrics['forearm_local_articulation_rad']=max(metrics['forearm_local_articulation_rad'],f.matrix_basis.to_quaternion().angle)
  for n,ma in pm.items():metrics['bone_world_scale_error']=max(metrics['bone_world_scale_error'],max(abs(x-1) for x in ma.to_scale()))
  metrics['attachment_to_carrier_matrix_error']=max(metrics['attachment_to_carrier_matrix_error'],md(pm['WeaponCarrier'].inverted()@at,carrier_rel))
  for g,ref in rest_dist.items():metrics['rigid_pair_distance_error_m']=max(metrics['rigid_pair_distance_error_m'],max(abs((x-y).length-d) for (x,y),d in zip(itertools.combinations(pts[g],2),ref)))
  for g,ref in base_feet.items():metrics['foot_full_vertex_drift_m']=max(metrics['foot_full_vertex_drift_m'],max((x-y).length for x,y in zip(pts[g],ref)));metrics['foot_floor_penetration_m']=max(metrics['foot_floor_penetration_m'],max(0,floor-min(v.z for v in pts[g])))
  gap=bidirectional_gap(pts,trees,'ForeArm.L','Rifle_V2_Body');gap_min=min(gap_min,gap);gap_max=max(gap_max,gap);metrics['left_support_gap_deviation_m']=max(metrics['left_support_gap_deviation_m'],abs(gap-base_gap))
  pairs,sats=collision(r,pts,trees)
  for k,v in pairs.items():
   max_pairs[k]=max(v,max_pairs.get(k,0));a0,b0=k.split('|');key=frozenset((a0,b0))
   if v and key not in ADJACENT|CONTACT:
    # Cuboid SAT suppresses shared-boundary numerical BVH contacts.
    if k not in sats or sats[k]>1e-5:unwanted.append({'frame':t,'pair':k,'triangle_pairs':v,'sat_margin_m':sats.get(k)})
  for k,v in sats.items():
   key=frozenset(k.split('|'))
   if key not in ADJACENT and v>1e-5 and not pairs[k]:unwanted.append({'frame':t,'pair':k,'triangle_pairs':0,'sat_margin_m':v,'note':'SAT detects complete containment without surface crossing'})
   max_sats[k]=max(v,max_sats.get(k,-1e9));key=frozenset(k.split('|'))
   # Anatomical neighboring cubes have approved seating, measured separately.
   allowance=(.030 if key==frozenset(('Head','Chest')) else (.020 if key==frozenset(('Chest','UpperArm.R')) else (.016 if key in [frozenset(('Chest','Leg.L')),frozenset(('Chest','Leg.R'))] else (.0001 if key==frozenset(('Head','Chest')) else .002))))
   limit=(.030 if key==frozenset(('Head','Chest')) else (.055 if key==frozenset(('Chest','UpperArm.R')) else max(0,base_sat[k])+allowance))
   if key in ADJACENT and v>limit:
    if k not in worse_adjacent or v>worse_adjacent[k]['margin_m']:worse_adjacent[k]={'frame':t,'margin_m':v,'baseline_max_m':base_sat[k],'allowance_m':allowance,'absolute_limit_m':limit}
 # Derivative at the actual240Hz bake interval, not a30Hz secant dominated
 # by source400degree/s acceleration. Preserve the same0.006m/s limit.
 for t in [1.125,closing-.125]:frame(t);poses[t]=pose_snapshot(r)
 seam=max(md(poses[1][n],poses[closing][n]) for n in poses[1]);vmax=0;wmax=0;dt=.125/(bpy.context.scene.render.fps/bpy.context.scene.render.fps_base)
 for n in poses[1]:
  v0,w0=transform_vel(poses[1][n],poses[1.125][n],dt);v1,w1=transform_vel(poses[closing-.125][n],poses[closing][n],dt);vmax=max(vmax,(v0-v1).length);wmax=max(wmax,(w0-w1).length)
 limits={'arm_relative_rifle_matrix_error':1e-4,'connected_elbow_gap_m':1e-5,'straight_arm_cross_error':1e-5,'forearm_local_articulation_rad':1e-4,'bone_world_scale_error':1e-5,'rigid_pair_distance_error_m':1e-5,'foot_floor_penetration_m':1e-5,'attachment_to_carrier_matrix_error':1e-5,'left_support_anchor_excursion_m':.003}
 for k,lim in limits.items():
  if metrics[k]>lim:failures.append(k+' exceeds '+str(lim))
 if seam>1e-5:failures.append('Loop pose seam')
 if vmax>0.006:failures.append('Loop one-sided translation velocity seam exceeds0.006m/s')
 if wmax>0.05:failures.append('Loop one-sided angular velocity seam exceeds0.05rad/s')
 if unwanted:failures.append('Unwanted nonadjacent/rifle intersections')
 if worse_adjacent:failures.append('Anatomical seating exceeds explicit attachment envelopes (Head/Chest30mm and right shoulder55mm; other existing limits retained)')
 out.update({'passed':not failures,'failures':failures,'evaluated_samples':int((closing-1)*2)+1,'topology_weights_rest_geometry_exact':topology_exact,'preserved_actions':preserved,'metrics':metrics,'limits':limits,'left_support_sampled_gap_range_m':[gap_min,gap_max],'loop_pose_matrix_error':seam,'loop_one_sided_translation_velocity_difference_m_s':vmax,'loop_one_sided_angular_velocity_difference_rad_s':wmax,'raw_triangle_pairs_max':{k:v for k,v in max_pairs.items() if v},'cuboid_signed_margin_max_m':max_sats,'unwanted_intersections':unwanted[:100],'unwanted_intersection_samples_count':len(unwanted),'worsened_adjacent_penetration':worse_adjacent})
 out['source_file_after_sha256']=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
 assert out['source_file_after_sha256']==SOURCE_SHA
 Path(opt.output).write_text(json.dumps(out,indent=2));print(json.dumps({'passed':out['passed'],'report':opt.output,'failures':failures,'metrics':metrics}))
main()
