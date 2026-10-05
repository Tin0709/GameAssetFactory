"""Connectivity cleanup. Execute through Blender MCP; preserves source revisions."""
import bpy,bmesh,json,hashlib,math
from pathlib import Path
from mathutils import Vector
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
inputs={'Pistol':('pistol/blocky_pistol_v1.blend','blocky_pistol_v2'),'M4A1':('m4a1_blocky/m4a1_blocky_v2.blend','m4a1_blocky_v3'),'Shotgun':('shotgun/blocky_shotgun_v1.blend','blocky_shotgun_v2')}
hashes={f:hashlib.sha256((BASE/f).read_bytes()).hexdigest() for f,stem in inputs.values()}
source=(BASE/'m4a1_blocky/build_m4a1_blocky_v1.py').read_text(encoding='utf-8-sig')
exec(source[source.index('def part('):source.index('# Distinct solid heel stock')])
report={}

def topology(o):
 bm=bmesh.new();bm.from_mesh(o.data);remaining=set(bm.verts);islands=[]
 while remaining:
  stack=[remaining.pop()];vs=[]
  while stack:
   v=stack.pop();vs.append(v)
   for e in v.link_edges:
    n=e.other_vert(v)
    if n in remaining:remaining.remove(n);stack.append(n)
  islands.append(len(vs))
 out={'islands':len(islands),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'loose_vertices':sum(not v.link_faces for v in bm.verts),'duplicate_faces':len(bm.faces)-len(set(tuple(sorted(v.index for v in f.verts)) for f in bm.faces)),'inconsistent_normal_edges':sum(e.is_manifold and not e.is_contiguous for e in bm.edges),'signed_volume':bm.calc_volume(signed=True)}
 bm.free();o.data.calc_loop_triangles();out['triangles']=len(o.data.loop_triangles);return out

def extract(main):
 out={};uvsrc=main.data.uv_layers.active
 for group in main.vertex_groups:
  ids={v.index for v in main.data.vertices if any(g.group==group.index for g in v.groups)}
  polys=[p for p in main.data.polygons if all(i in ids for i in p.vertices)]
  if not polys:continue
  ordered=sorted(ids);remap={v:i for i,v in enumerate(ordered)}
  data=bpy.data.meshes.new(group.name+'_CleanSource');data.from_pydata([main.data.vertices[i].co for i in ordered],[],[[remap[i] for i in p.vertices] for p in polys]);data.update();data.materials.append(mat)
  uv=data.uv_layers.new(name='AtlasUV')
  for p,old in zip(data.polygons,polys):
   for li,oldli in zip(p.loop_indices,old.loop_indices):uv.data[li].uv=uvsrc.data[oldli].uv
  obj=bpy.data.objects.new(group.name+'_CleanPart',data);asset.objects.link(obj);out[group.name]=obj
 bpy.data.objects.remove(main,do_unlink=True)
 return out

def close_source(o):
 bm=bmesh.new();bm.from_mesh(o.data)
 edges=[e for e in bm.edges if e.is_boundary]
 if edges:
  # Muzzle back: bridge concentric rectangular rims, rather than overlapping caps.
  if 'Muzzle' in o.name:
   y=min(v.co.y for v in bm.verts);vs=[v for v in bm.verts if abs(v.co.y-y)<1e-5]
   center=Vector((sum(v.co.x for v in vs)/len(vs),y,sum(v.co.z for v in vs)/len(vs)))
   vs.sort(key=lambda v:(v.co-center).length,reverse=True);outer=vs[:4];inner=vs[4:]
   outer.sort(key=lambda v:math.atan2(v.co.z-center.z,v.co.x-center.x));inner.sort(key=lambda v:math.atan2(v.co.z-center.z,v.co.x-center.x))
   for i in range(4):bm.faces.new([outer[i],outer[(i+1)%4],inner[(i+1)%4],inner[i]])
  else:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()

def union(a,b,operation='UNION'):
 bpy.ops.object.select_all(action='DESELECT');a.select_set(True);bpy.context.view_layer.objects.active=a
 mod=a.modifiers.new('Structural '+operation,'BOOLEAN');mod.operation=operation;mod.solver='EXACT';mod.object=b
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(b,do_unlink=True)

def finish_mesh(o):
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 for p in o.data.polygons:p.use_smooth=False
 o.data.update()

def connector(name,lo,hi):
 return box(name,tuple((a+b)/2 for a,b in zip(lo,hi)),tuple(b-a for a,b in zip(lo,hi)),7,11)

def process(key,file,stem):
 global asset,mat,parts,GRIP_ORIGIN
 bpy.ops.wm.open_mainfile(filepath=str(BASE/file));scene=bpy.context.scene
 root=next(o for o in scene.objects if o.name.endswith('_Root'))
 main=next(o for o in root.children if o.name.endswith('_Base'))
 parent=root;name=main.name;before=sum(topology(o)['triangles'] for o in root.children if o.type=='MESH')
 oldmarkers={o.name:tuple(o.location) for o in root.children if o.type=='EMPTY'}
 oldbounds=[(min((o.matrix_world@v.co)[i] for o in root.children if o.type=='MESH' for v in o.data.vertices),max((o.matrix_world@v.co)[i] for o in root.children if o.type=='MESH' for v in o.data.vertices)) for i in range(3)]
 mat=main.data.materials[0];asset=bpy.data.collections['WEAPON_EXPORT'];parts=[];GRIP_ORIGIN=Vector((0,0,0));objs=extract(main)
 for o in objs.values():close_source(o)
 additions=[];pump=None
 if key=='Pistol':
  for n in ['Pistol_Grip','Pistol_Grip_Heel','Pistol_Guard_Bottom','Pistol_Guard_Front']:bpy.data.objects.remove(objs.pop(n),do_unlink=True)
  additions.append(profile('Integrated_Handgun_Grip',[(-.023,.094),(.047,.067),(.038,.039),(.009,-.055),(.012,-.064),(.012,-.072),(-.038,-.072),(-.038,-.059),(-.026,-.034)],.0445,4,6,.0007))
  additions.append(profile('Closed_Trigger_Guard',[(.026,.073),(.026,.006),(.124,.006),(.124,.073),(.114,.073),(.114,.016),(.036,.016),(.036,.073)],.019,6,14))
  additions.append(connector('Slide_Frame_Internal_Seat',(-.017,-.015,.087),(.017,.18,.095)))
  for n in ['Pistol_Rear_Sight_Left','Pistol_Rear_Sight_Right','Pistol_Front_Sight']:
   o=objs[n];lo=[min(v.co[i] for v in o.data.vertices) for i in range(3)];hi=[max(v.co[i] for v in o.data.vertices) for i in range(3)]
   additions.append(connector(n+'_Foot',(lo[0]+.001,lo[1]+.002,.140),(hi[0]-.001,hi[1]-.002,.147)))
  base=objs.pop('Pistol_Frame')
 elif key=='M4A1':
  for n in ['Trigger_Guard_Bottom','Trigger_Guard_Front']:bpy.data.objects.remove(objs.pop(n),do_unlink=True)
  additions.append(profile('Closed_Trigger_Guard',[(.045,.123),(.045,.034),(.176,.034),(.176,.123),(.164,.123),(.164,.046),(.057,.046),(.057,.123)],.031077588,6,14))
  for n,lo,hi in [('Stock_Internal_Socket',(-.028,-.065,.156),(.028,-.032,.206)),('Rail_Seat',(-.025,-.015,.229),(.025,.235,.242)),('Rear_Sight_Seat',(-.025,-.006,.257),(.025,.025,.269)),('Foreend_Internal_Tenon',(-.032,.275,.145),(.032,.289,.211)),('Barrel_Collar_Tenon',(-.014,.487,.168),(.014,.505,.193)),('Grip_Neck',(-.024,.023,.099),(.024,.065,.132)),('Magazine_Magwell_Tenon',(-.026,.159,.087),(.026,.211,.109))]:additions.append(connector(n,lo,hi))
  base=objs.pop('Receiver')
 else:
  for n in ['Shotgun_Guard_Bottom','Shotgun_Guard_Front']:bpy.data.objects.remove(objs.pop(n),do_unlink=True)
  additions.append(profile('Closed_Trigger_Guard',[(.055,.143),(.055,.0675),(.182,.0675),(.182,.143),(.171,.143),(.171,.0785),(.066,.0785),(.066,.143)],.031,6,14))
  for n,lo,hi in [('Stock_Internal_Socket',(-.032,-.065,.153),(.032,-.031,.202)),('Rib_Seat',(-.014,.07,.237),(.014,.218,.249)),('Grip_Neck',(-.029,.011,.123),(.029,.058,.151))]:additions.append(connector(n,lo,hi))
  pump=bpy.data.objects['Shotgun_Pump'];pumporigin=pump.location.copy()
  # Temporarily bake its local translation for exact booleans, restore the pivot afterward.
  for v in pump.data.vertices:v.co+=pumporigin
  pump.location=(0,0,0)
  collar=objs.pop('Shotgun_Pump_Front_Collar');union(pump,collar)
  union(pump,connector('Pump_Collar_Bridge',(-.027,.451,.108),(.027,.472,.153)))
  bore=connector('Pump_Running_Clearance',(-.023,.245,.108),(.023,.49,.154));union(pump,bore,'DIFFERENCE')
  finish_mesh(pump)
  for v in pump.data.vertices:v.co-=pumporigin
  pump.location=pumporigin
  base=objs.pop('Shotgun_Receiver')
 # Fuse all intersecting pieces, remove coincident/internal interfaces, then weld.
 for o in list(objs.values())+additions:union(base,o)
 finish_mesh(base);base.name=name;base.parent=parent;base.location=(0,0,0);base.rotation_euler=(0,0,0);base.scale=(1,1,1)
 bpy.context.view_layer.update()
 meshes=[base]+([pump] if pump else [])
 audits={o.name:topology(o) for o in meshes}
 for n,t in audits.items():assert t['islands']==1 and t['nonmanifold_edges']==0 and t['loose_vertices']==0 and t['duplicate_faces']==0 and t['inconsistent_normal_edges']==0,(key,n,t)
 assert oldmarkers=={o.name:tuple(o.location) for o in root.children if o.type=='EMPTY'}
 newbounds=[(min((o.matrix_world@v.co)[i] for o in meshes for v in o.data.vertices),max((o.matrix_world@v.co)[i] for o in meshes for v in o.data.vertices)) for i in range(3)]
 assert all(abs(a-b)<1e-5 for aa,bb in zip(oldbounds,newbounds) for a,b in zip(aa,bb)),(key,oldbounds,newbounds)
 folder=(BASE/file).parent
 item={'before_triangles':before,'after_triangles':sum(t['triangles'] for t in audits.values()),'topology':audits,'bounds_m':newbounds,'dimensions_m':{'width':newbounds[0][1]-newbounds[0][0],'length':newbounds[1][1]-newbounds[1][0],'height':newbounds[2][1]-newbounds[2][0]},'markers_blender_m':oldmarkers,'pump_separate':pump is not None,'materials':1,'texture_resolution':[64,64],'blend':str(folder/(stem+'.blend')),'glb':str(folder/(stem+'.glb'))}
 bpy.ops.object.select_all(action='DESELECT')
 for o in [root]+list(root.children):o.select_set(True)
 bpy.context.view_layer.objects.active=base
 bpy.ops.export_scene.gltf(filepath=item['glb'],export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
 # Existing camera matches unchanged dimensions.
 scene.camera=bpy.data.objects['Weapon_Isometric'];scene.render.filepath=str(folder/(stem+'_isometric.png'));bpy.ops.render.render(write_still=True)
 data=bpy.data.cameras.new('Geometry_Validation_Closeup');data.type='ORTHO'
 cam=bpy.data.objects.new(data.name,data);bpy.data.collections['PREVIEW_STUDIO'].objects.link(cam)
 center={'Pistol':Vector((0,.059,.014)),'M4A1':Vector((0,.098,.056)),'Shotgun':Vector((0,.108,.081))}[key]
 cam.location=center+Vector((1.3,-.55,.32));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();data.ortho_scale={'Pistol':.26,'M4A1':.38,'Shotgun':.34}[key]
 scene.camera=cam;scene.render.filepath=str(folder/(stem+'_trigger_closeup.png'));bpy.ops.render.render(write_still=True)
 scene.camera=bpy.data.objects['Weapon_Isometric'];scene['geometry_cleanup_report']=json.dumps(item)
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=item['blend'])
 (folder/(stem+'_cleanup_report.json')).write_text(json.dumps(item,indent=2));report[key]=item
for key,(file,stem) in inputs.items():process(key,file,stem)
assert all(hashlib.sha256((BASE/f).read_bytes()).hexdigest()==h for f,h in hashes.items())
(BASE/'weapon_cleanup_report.json').write_text(json.dumps(report,indent=2))
result=report
