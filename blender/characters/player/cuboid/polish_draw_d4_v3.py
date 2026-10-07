import bpy,json,math,hashlib,shutil,datetime
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene
def curves(a):return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
def digest(a):return hashlib.sha256(repr(([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)],[(m.name,m.frame) for m in a.pose_markers],dict(a.items()))).encode()).hexdigest()
def geometry():return {o.name:hashlib.sha256(repr(([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest() for o in bpy.data.objects if o.type=='MESH'}
def bones():return {b.name:([list(row) for row in b.matrix_local],list(b.head_local),list(b.tail_local),b.parent.name if b.parent else None,b.use_deform) for b in rig.data.bones}
assert 'Draw_LongGun_V3_Final' not in bpy.data.actions
backup=DEV.with_name('player_cuboid_weapon_animation_dev_before_draw_v3_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend');shutil.copy2(DEV,backup)
protected={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'bones':bones(),'backup':str(backup)}
(BASE/'draw_d4_v3_protection.json').write_text(json.dumps(protected,indent=2))
source=bpy.data.actions['Draw_LongGun_V2'];a=source.copy();a.name='Draw_LongGun_V3_Final';a.use_fake_user=True;rig.animation_data.action=a
changes=[]
def retime(n,old,new):
 for c in curves(a):
  if c.data_path.startswith('pose.bones["'+n+'"]'):
   for k in c.keyframe_points:
    if abs(k.co.x-old)<.001:
     d=new-old;k.co.x+=d;k.handle_left.x+=d;k.handle_right.x+=d
   c.update()
 changes.append({'bone':n,'retime':[old,new]})
def value(n,prop,i,f,v):
 c=next(c for c in curves(a) if c.data_path=='pose.bones["'+n+'"].'+prop and c.array_index==i)
 k=next(k for k in c.keyframe_points if abs(k.co.x-f)<.001);old=k.co.y;k.co.y=v;c.update();changes.append({'bone':n,'property':prop,'axis':i,'frame':f,'before':old,'after':v})
def frame(f):
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
 scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
# Preserve short alert and separate acquire/release; sharpen the reach by 0.1f.
retime('Arm.R',3.85,3.75)
value('Chest','rotation_euler',0,1.8,math.radians(.95))
# Chest reaction trails the clear-body impulse by .25f; spine trails chest.
retime('Chest',7.35,7.4);retime('Spine',8.35,7.7)
value('Spine','rotation_euler',0,7.7,math.radians(.35))
# Reduce authored residual motion; endpoint values are never touched.
frame(14);ready={n:rig.pose.bones[n].matrix_basis.copy() for n in rig.pose.bones.keys()}
for n,f,axis,amount in [('Arm.R',12.9,0,.35),('Arm.L',13.1,0,.25)]:
 c=next(c for c in curves(a) if c.data_path=='pose.bones["'+n+'"].rotation_euler' and c.array_index==axis)
 old=c.evaluate(f);value(n,'rotation_euler',axis,f,old-math.radians(.65-.35 if n=='Arm.R' else .5-.25))
value('Chest','rotation_euler',0,11.75,math.radians(2.53))
# Blend carrier overshoot toward Ready in its own local space, preserving continuity.
for prop in ['location','rotation_quaternion']:
 for c in curves(a):
  if c.data_path=='pose.bones["WeaponCarrier"].'+prop:
   for f,factor in [(12.15,.60),(13.15,.60)]:
    old=c.evaluate(f);end=c.evaluate(14);value('WeaponCarrier',prop,c.array_index,f,end+(old-end)*factor)
# Optimize only small rigid-arm orientation corrections against actual gun triangles.
data=json.loads((BASE/'draw_d4_v2_samples.json').read_text());refs=[o for o in bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].all_objects if o.type=='MESH']
tris=[np.array(g['vertices'])[np.array(g['triangles'])] for g in data['geometry']]
def score(n):
 inv=np.array((rig.matrix_world@rig.pose.bones[n].matrix).inverted());b=data['boxes'][n];lo=np.array(b['min'])+.025;hi=np.array(b['max'])-.025;hi[1]-=.12
 center=(lo+hi)/2;extent=(hi-lo)/2;hits=0
 dep=bpy.context.evaluated_depsgraph_get()
 for ts,o in zip(tris,refs):
  t=inv@np.array(o.evaluated_get(dep).matrix_world);v=ts@t[:3,:3].T+t[:3,3]-center;e=np.roll(v,-1,axis=1)-v
  axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1)
  p=np.einsum('ntd,nad->nta',v,axes);r=np.abs(axes)@extent
  hits+=int((~((p.min(1)>r+1e-8)|(p.max(1)<-r-1e-8)).any(1)).sum())
 return hits
contact=[]
for n,f in [('Arm.R',3.75),('Arm.R',5),('Arm.R',6.9),('Arm.R',9.05),('Arm.L',9.4),('Arm.L',10.9),('Arm.L',11.8)]:
 frame(f);p=rig.pose.bones[n];original=p.rotation_euler.copy();before=score(n);best=(before,0,original.copy(),(0,0,0))
 for axis in range(3):
  for deg in [-2,-1,-.5,.5,1,2]:
   q=original.copy();q[axis]+=math.radians(deg);p.rotation_euler=q;bpy.context.view_layer.update();s=score(n)
   if (s,abs(deg))<best[:2]:best=(s,abs(deg),q.copy(),tuple(deg if i==axis else 0 for i in range(3)))
 p.rotation_euler=best[2]
 for i in range(3):
  if abs(best[2][i]-original[i])>1e-7:
   value(n,'rotation_euler',i,f,best[2][i])
   if n=='Arm.R' and f==5:value(n,'rotation_euler',i,5.25,best[2][i])
 contact.append({'bone':n,'frame':f,'triangles_before':before,'triangles_after':best[0],'delta_degrees':best[3]})
# Clamp meaningful curves, zero tiny translation residue; keep all authored beats.
for c in curves(a):
 for k in c.keyframe_points:
  if c.data_path.endswith('location') and abs(k.co.y)<1e-6:k.co.y=0
  k.interpolation='BEZIER'
  if k.handle_left_type!='FREE':k.handle_left_type='AUTO_CLAMPED'
  if k.handle_right_type!='FREE':k.handle_right_type='AUTO_CLAMPED'
 c.update()
a['pass']='D4 Pass 3 final character acting / production polish';a['comparison_source']=source.name
a['weapon_settle_rotation_degrees']=.6;a['arm_settle_degrees']=json.dumps({'Arm.R':.35,'Arm.L':.25})
a['event_subframes_json']=json.dumps({'DRAW_BEGIN':1.0,'WEAPON_GRAB':5.0,'WEAPON_BACK_RELEASE':5.25,'SUPPORT_HAND_CATCH':10.9,'DRAW_READY':14.0});a['event_frames_json']=a['event_subframes_json']
a['production_changes_json']=json.dumps(changes);a['contact_cleanup_json']=json.dumps(contact)
frame(1)
(BASE/'draw_d4_v3_changes.json').write_text(json.dumps({'changes':changes,'contact_cleanup':contact},indent=2))
result={'action':a.name,'contact_cleanup':contact,'change_count':len(changes),'backup':str(backup)}
