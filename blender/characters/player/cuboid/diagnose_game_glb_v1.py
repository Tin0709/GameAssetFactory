import bpy,json,struct,math,bisect,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
OUT=BASE/'export'; manifest=json.loads((OUT/'player_cuboid_export_validation_input.json').read_text())
raw=Path(manifest['glb']).read_bytes();magic,version,length=struct.unpack_from('<4sII',raw)
assert magic==b'glTF' and version==2 and length==len(raw)
chunks={};off=12
while off<len(raw):
 size,kind=struct.unpack_from('<II',raw,off);off+=8;chunks[kind]=raw[off:off+size];off+=size
g=json.loads(chunks[0x4e4f534a]);binary=chunks[0x004e4942]
sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16};types={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
def acc(index):
 a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];fmt,width=types[a['componentType']];n=sizes[a['type']];stride=v.get('byteStride',n*width)
 start=v.get('byteOffset',0)+a.get('byteOffset',0)
 rows=[struct.unpack_from('<'+fmt*n,binary,start+i*stride) for i in range(a['count'])]
 if a.get('normalized'):
  denom={5121:255,5123:65535,5120:127,5122:32767}[a['componentType']];rows=[tuple(max(-1,x/denom) for x in row) for row in rows]
 return rows
def mat4(row):return Matrix([row[i::4] for i in range(4)])
nodes=g['nodes'];names=[n.get('name','') for n in nodes]
assert not any('mixamo' in n.lower() for n in names)
assert len(g['meshes'])==1 and len(g['skins'])==1
assert 'cameras' not in g and 'KHR_lights_punctual' not in g.get('extensions',{})
assert set(a['name'] for a in g['animations'])=={'Idle','Run'}
assert all('uri' not in i and 'bufferView' in i for i in g.get('images',[])), 'Images must be embedded'
parents={ch:i for i,n in enumerate(nodes) for ch in n.get('children',[])}
meshnode=next(i for i,n in enumerate(nodes) if 'mesh' in n);skin=g['skins'][nodes[meshnode]['skin']];joints=skin['joints'];ibm=[mat4(x) for x in acc(skin['inverseBindMatrices'])]
assert 'Player_Cuboid_Rig' in names and 'Root' in names
root=names.index('Root');hips=names.index('Hips')
C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));Ci=C.inverted()
rest=[Vector(v) for v in manifest['rest_vertices']]
primitives=[]
for p in g['meshes'][0]['primitives']:
 at=p['attributes'];pos=acc(at['POSITION']);js=acc(at['JOINTS_0']);ws=acc(at['WEIGHTS_0'])
 mapping=[]
 for v in pos:
  bv=Ci@Vector((*v,1));idx=min(range(len(rest)),key=lambda i:(rest[i]-bv.to_3d()).length_squared)
  assert (rest[idx]-bv.to_3d()).length<1e-6
  mapping.append(idx)
 assert all(abs(sum(w)-1)<1e-6 for w in ws)
 assert all(sum(x>1e-7 for x in w)==1 for w in ws), 'Expected rigid single-bone weights'
 primitives.append((pos,js,ws,mapping))
def evaluate(anim,t):
 properties={}
 for channel in anim['channels']:
  sam=anim['samplers'][channel['sampler']];times=[x[0] for x in acc(sam['input'])];values=acc(sam['output']);path=channel['target']['path'];ni=channel['target']['node']
  interpolation=sam.get('interpolation','LINEAR');assert interpolation in ['LINEAR','STEP']
  if t<=times[0]:value=values[0]
  elif t>=times[-1]:value=values[-1]
  else:
   j=bisect.bisect_right(times,t)-1;a=(t-times[j])/(times[j+1]-times[j]);v0=values[j];v1=values[j+1]
   if interpolation=='STEP':value=v0
   elif path=='rotation':
    q0=Quaternion((v0[3],*v0[:3]));q1=Quaternion((v1[3],*v1[:3]));q=q0.slerp(q1,a);value=(q.x,q.y,q.z,q.w)
   else:value=tuple(x+(y-x)*a for x,y in zip(v0,v1))
  properties.setdefault(ni,{})[path]=value
 matrices={}
 def world(i):
  if i in matrices:return matrices[i]
  n=nodes[i];p=properties.get(i,{})
  if 'matrix' in n and not p:local=mat4(n['matrix'])
  else:
   loc=Vector(p.get('translation',n.get('translation',(0,0,0))));q=p.get('rotation',n.get('rotation',(0,0,0,1)));scale=Vector(p.get('scale',n.get('scale',(1,1,1))))
   local=Matrix.LocRotScale(loc,Quaternion((q[3],*q[:3])),scale)
  matrices[i]=world(parents[i])@local if i in parents else local
  return matrices[i]
 for i in range(len(nodes)):world(i)
 points=[]
 for pos,js,ws,mapping in primitives:
  for p,j,w,idx in zip(pos,js,ws,mapping):
   vec=Vector((0,0,0,0))
   for ji,weight in zip(j,w):
    if weight:vec+=(matrices[joints[ji]]@ibm[ji]@Vector((*p,1)))*weight
   points.append((idx,(Ci@vec).to_3d()))
 return matrices,points
results={}
for animation in g['animations']:
 name=animation['name'];base=manifest['baseline'][name]
 assert not any(c['target']['path']=='scale' for c in animation['channels'])
 assert not any(c['target']['node']==names.index('Player_Cuboid_Rig') for c in animation['channels'])
 assert not any(c['target']['node']==root for c in animation['channels'])
 time_end=max(acc(s['input'])[-1][0] for s in animation['samplers']);time_start=min(acc(s['input'])[0][0] for s in animation['samplers'])
 assert abs(time_start)<1e-7 and abs(time_end-base['duration'])<1e-6,(name,time_start,time_end)
 max_error=0;root_error=0;rigid_error=0
 first,fp=evaluate(animation,0);last,lp=evaluate(animation,time_end)
 hiptravel=(last[hips].translation-first[hips].translation).length
 loop=max((v-w).length for (_,v),(_,w) in zip(fp,lp))
 initial_lengths={}
 for sample in base['samples']:
  t=(sample['frame']-base['range'][0])/24;mat,points=evaluate(animation,t)
  root_error=max(root_error,max(abs(mat[root][i][j]-first[root][i][j]) for i in range(4) for j in range(4)))
  frame_error=max((v-Vector(sample['vertices'][idx])).length for idx,v in points)
  if frame_error>max_error+1e-4:
   worst=max(points,key=lambda iv:(iv[1]-Vector(sample['vertices'][iv[0]])).length)
   print('DIAGNOSTIC',name,sample['frame'],frame_error,worst[0],list(worst[1]),sample['vertices'][worst[0]],flush=True)
  max_error=max(max_error,frame_error)
  # Inverse-bind + single rigid joint skinning preserves every cuboid by construction.
  for ji in joints:
   rot=mat[ji].to_3x3();rigid_error=max(rigid_error,max(abs(rot.col[k].length-1) for k in range(3)))
 print('MAX_ERROR',name,max_error,flush=True)
 assert root_error<1e-7 and hiptravel<1e-6 and loop<1e-6 and rigid_error<1e-6
 results[name]=dict(duration_seconds=time_end,sample_count=len(base['samples']),max_mesh_difference_from_approved_blender_m=max_error,root_travel_m=root_error,hips_accumulated_world_travel_m=hiptravel,loop_vertex_mismatch_m=loop,rigid_joint_scale_error=rigid_error,channel_count=len(animation['channels']))
assert manifest['protected_hashes']=={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in manifest['protected_hashes']}
# Independently reload the saved preparation copy: it must remain at 24 FPS with
# original unscaled frame coordinates, exactly two actions, and only two objects.
bpy.ops.wm.open_mainfile(filepath=manifest['export_blend'])
assert bpy.context.scene.render.fps==24
assert set(a.name for a in bpy.data.actions)=={'Idle','Run'}
assert set(o.name for o in bpy.data.objects)=={manifest['mesh'],manifest['armature']}
assert list(bpy.data.actions['Run'].frame_range)==[1,17]
assert list(bpy.data.actions['Idle'].frame_range)==[1,49]
report={k:v for k,v in manifest.items() if k not in ['baseline','rest_vertices']}
report.update(validation='PASS',glb_bytes=len(raw),animations=results,node_names=names,mesh_count=len(g['meshes']),skin_count=len(g['skins']),joint_count=len(joints),embedded_images=len(g.get('images',[])),mixamo_absent=True,source_test_production_hashes_unchanged=True,no_scale_or_root_or_object_animation=True,roundtrip_method='Independent glTF TRS evaluation + inverse-bind CPU skinning compared at every quarter authoring-frame against original Blender evaluated mesh',loop_note='glTF does not encode a playback loop flag; enable looping for Idle/Run on Godot import. End key at 0.6666667s closes the Run interval, without adding an extra 1/24s hold.')
(OUT/'player_cuboid_animated_v1_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('GLB_VALIDATION='+json.dumps(report),flush=True)

