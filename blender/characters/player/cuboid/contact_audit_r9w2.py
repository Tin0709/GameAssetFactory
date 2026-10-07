from living_r9w2_common import *
s=bpy.data.scenes['R9W2_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W2_Probe_Rig'];w=gun(s);m=next(o for o in s.objects if o.type=='MESH' and 'Author_Mesh' in o.name);boxes=boxes_for(r,m,0)
pts=np.array([(x,-.312,z) for x in np.linspace(-.0515,.0515,13) for z in np.linspace(.0415,.2185,27)])
results={}
for label,an in [('A','PREVIEW_ONLY_R9W2_A_Steering'),('B','PREVIEW_ONLY_R9W2_B_Steering'),('C','LongGunAimAround_LeftRight_V2')]:
 sample(r,s,bpy.data.actions[an],1);worstgap=0;maxhandpenetration=0;stock=[]
 for step in range(577):
  f=1+step/2;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
  ds=[]
  for bone in ['UpperArm.R','Chest']:
   lo,hi=boxes[bone];t=np.array(r.pose.bones[bone].matrix.inverted()@gm);p=pts@t[:3,:3].T+t[:3,3];ds.append(float(np.linalg.norm(np.maximum(np.maximum(lo-p,p-hi),0),axis=1).min()))
  gap=min(ds)
  if gap>worstgap:worstgap=gap;worstframe=f
  stock.append(gap)
  # OBB terminal hand-block overlap, with complete separating axes.
  mats=[r.pose.bones['ForeArm.'+side].matrix for side in ['R','L']];centers=[mat@Vector((0,.2625,0)) for mat in mats];axes=[np.array(mat.to_3x3()) for mat in mats];extent=np.array([.1125,.075,.1125]);delta=np.array(centers[1]-centers[0]);tests=[axes[0][:,i] for i in range(3)]+[axes[1][:,i] for i in range(3)]+[np.cross(axes[0][:,i],axes[1][:,j]) for i in range(3) for j in range(3)];overlap=[]
  for axis in tests:
   norm=np.linalg.norm(axis)
   if norm<1e-7:continue
   axis=axis/norm;overlap.append(float(np.abs(axis@axes[0])@extent+np.abs(axis@axes[1])@extent-abs(delta@axis)))
  maxhandpenetration=max(maxhandpenetration,min(overlap))
 results[label]={'stock_butt_patch_nearest_body_gap_max_m':worstgap,'stock_gap_worst_frame':worstframe if worstgap else None,'terminal_hand_boxes_overlap_depth_max_m':maxhandpenetration,'stock_note':'Nearest sampled butt-pad point to right upper arm or chest surface. Zero can also mean embedding; read with triangle overlap report.'}
(OUT/'contact_audit.json').write_text(json.dumps(results,indent=2))
