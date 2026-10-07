"""Upper-body-only V2 Actions, composed over untouched V1 preview tracks."""
import importlib,living_r9w2_common as h
importlib.reload(h)
from living_r9w2_common import *
assert Path(bpy.data.filepath).name=='player_longgun_living_r9w2_study.blend'
s=bpy.data.scenes['R9W2_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W2_Probe_Rig'];w=gun(s)
design1=json.loads((BASE/'living_r9w1_review/design.json').read_text());design={'actions':{},'composition':'Original V1 Actions in NLA; new active Actions contain upper-body channels only.','chest_head_weapon':'unchanged V1 curves','contact_markers':'Internal center targets are not surface contacts. Patch distances inspect terminal block surfaces against actual grip/handguard regions.'}
def upper_copy(src,name):
 assert name not in bpy.data.actions,name
 a=src.copy();a.name=name;a.use_fake_user=True
 for l in a.layers:
  for st in l.strips:
   for bag in st.channelbags:
    for c in list(bag.fcurves):
     if any(c.data_path.startswith('pose.bones["'+n+'"]') for n in LOWER):bag.fcurves.remove(c)
 a['scope']='R9-W2 upper-body/helper only; no Root/Hips/leg tracks'
 return a
def key_arms(a,f,pose,last):
 apply_pose(r,pose);assign(r,a)
 for side in ['L','R']:
  for bone in ['UpperArm.','ForeArm.']:
   pb=r.pose.bones[bone+side];q=pb.rotation_quaternion.copy()
   if pb.name in last and q.dot(last[pb.name])<0:q.negate()
   pb.rotation_quaternion=q;last[pb.name]=q.copy();pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
for v1,d in design1['actions'].items():
 mode=d['mode'];N=d['period'];src=bpy.data.actions[v1];variants={'A':upper_copy(src,'PREVIEW_ONLY_R9W2_A_'+mode),'B':upper_copy(src,'PREVIEW_ONLY_R9W2_B_'+mode),'C':upper_copy(src,v1.replace('_V1','_V2'))};previous={'B':{},'C':{}};records={'B':[],'C':[]};first={}
 for i in range(N+1):
  f=i+1;sample(r,s,src,f,True,True);pose={p.name:p.matrix_basis.copy() for p in r.pose.bones};gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy();poles={side:r.pose.bones['ForeArm.'+side].head.copy() for side in ['R','L']}
  for label in ['B','C']:
   apply_pose(r,pose);angle=(30+30*d['records'][i]['support_drive']) if label=='C' else 0
   targets=corrected(r,gm,poles,angle);newpose={p.name:p.matrix_basis.copy() for p in r.pose.bones}
   if i==0:first[label]=newpose
   if i==N:newpose=first[label]
   key_arms(variants[label],f,newpose,previous[label]);records[label].append({'frame':f,'angle':angle,'targets':targets})
 # Smooth periodic quaternion components only for new arm curves; keep other V1 curves exact.
 for label in ['B','C']:
  a=variants[label]
  for c in curves(a):
   if 'Arm.' not in c.data_path:continue
   ks=c.keyframe_points;ys=[k.co.y for k in ks]
   for i,k in enumerate(ks):
    j=i%N;slope=(ys[(j+1)%N]-ys[(j-1)%N])/2;k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE';k.handle_left=(k.co.x-1/3,k.co.y-slope/3);k.handle_right=(k.co.x+1/3,k.co.y+slope/3)
   c.update()
 design['actions'][mode]={'period':N,'source':v1,'variants':{k:a.name for k,a in variants.items()},'records':records}
(OUT/'design.json').write_text(json.dumps(design,indent=2))
# Separate upper Actions and unchanged locomotion/path, never new lower-body tracks.
def compose(r,upper,lower=None):
 r.animation_data_clear()
 for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
 r.animation_data_create()
 if lower:
  tr=r.animation_data.nla_tracks.new();tr.name='UNCHANGED V1 GAIT AND PATH';st=tr.strips.new(lower.name,1,lower);st.action_slot=lower.slots[0];st.blend_type='REPLACE';st.extrapolation='HOLD';st.use_auto_blend=False
 assign(r,upper);r.animation_data.action_blend_type='REPLACE';r.animation_data.action_influence=1
q=Vector((-3,-5,3.4)).to_track_quat('Z','Y');right=q@Vector((1,0,0));review={}
for mode,key,lower in [('READY','Ready',None),('SWEEP','Steering',None),('WALK_LOCAL','Steering','PREVIEW_ONLY_R9W1_Steering_Local'),('FIGURE8','Steering','LongGunAimAround_LeftRight_V1'),('MOVE','Move','LongGunReady_Move_V1')]:
 cs=scene('R9W2_REVIEW_'+mode);bpy.context.window.scene=cs;cs.frame_end=design['actions'][key]['period'];cs.render.resolution_x=1440;cs.render.resolution_y=640;cs.eevee.taa_render_samples=16
 rows={}
 for i,label in enumerate(['A','B','C']):
  rr,mp=clone2(mode+'_'+label,cs);compose(rr,bpy.data.actions[design['actions'][key]['variants'][label]],bpy.data.actions[lower] if lower else None)
  offset=right*((i-1)*(7.0 if mode=='FIGURE8' else 2.1))
  for old,o in mp.items():
   if old.parent is None and not o.constraints:o.location+=offset
  font=bpy.data.curves.new('R9W2_Label','FONT');font.body={'A':'A  ORIGINAL W1','B':'B  CONTACT ONLY','C':'C  CONTACT + SUPPORT'}[label];font.align_x='CENTER';font.size=.115 if mode!='FIGURE8' else .25;ob=bpy.data.objects.new(font.name,font);cs.collection.objects.link(ob);ob.location=offset+Vector((0,0,2.08 if mode!='FIGURE8' else 3.8));ob.rotation_euler=q.to_euler();rows[label]=rr.name
  if mode=='FIGURE8':
   old=next(o for o in bpy.data.scenes['R9W1_REVIEW_STEERING'].objects if o.type=='CURVE' and 'PathGuide' in o.name);ob=old.copy();ob.data=old.data.copy();ob.name='R9W2_PathGuide';cs.collection.objects.link(ob)
   # Recenter the W1 guide geometry, then translate to this matched panel.
   pts=ob.data.splines[0].points;center=(Vector(pts[0].co[:3])+Vector(pts[len(pts)//2].co[:3]))/2;center.z=0
   for p in pts:p.co=(*(Vector(p.co[:3])-center+offset),1)
 cs.camera=camera(cs,'R9W2_Camera_'+mode,Vector((0,-.2,1))+q@Vector((0,0,15)),(0,-.2,1),21 if mode=='FIGURE8' else 7.4);cs.frame_set(49 if cs.frame_end>=49 else 1);review[mode]={'scene':cs.name,'rigs':rows}
design['review']=review;(OUT/'design.json').write_text(json.dumps(design,indent=2))
bpy.context.window.scene=bpy.data.scenes['R9W2_REVIEW_SWEEP'];save()
