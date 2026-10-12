"""Original Korth-inspired stylized pistol; isolated authoring, no character edits."""
import bpy,bmesh,math,json,hashlib,sys,shutil,datetime
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TARGET=HERE/'Pistol_Stylized_V2.blend'
if TARGET.exists():
 assert '--refine-iteration' in sys.argv,'Preserve the existing Pending source before refinement'
 backup=ROOT/'.validation/pistol_stylized_v2'/('iteration_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir(parents=True)
 for name in ['Pistol_Stylized_V2.blend','Pistol_Stylized_V2.glb','asset_report.json','pistol_v2_palette_64.png']:
  if (HERE/name).exists():shutil.copy2(HERE/name,backup/name)
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.unit_settings.system='METRIC'
c=bpy.data.collections.new('WEAPON_EXPORT');s.collection.children.link(c)
root=bpy.data.objects.new('Pistol_Stylized_V2',None);c.objects.link(root)
root['review_status']='Pending';root['forward']='+Y';root['origin']='RightHandGrip'
palette=[(42,48,57),(106,123,135),(143,159,170),(105,117,126),(25,31,40),(107,77,62),(239,242,242),(50,57,68)]
im=bpy.data.images.new('Pistol_V2_RifleFamily_Palette',width=64,height=64,alpha=True);im.colorspace_settings.name='sRGB'
im.pixels.foreach_set([v for y in range(64) for x in range(64) for v in (*[n/255 for n in palette[x//8]],1)])
im.filepath_raw=str(HERE/'pistol_v2_palette_64.png');im.file_format='PNG';im.save();im.pack()
mat=bpy.data.materials.new('Pistol_V2_Graphite_Gunmetal');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=.12;bs.inputs['Roughness'].default_value=.5
tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;tx.interpolation='Closest';mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
sets={'Frame':[],'Slide':[],'Magazine':[]}
def part(name,vs,fs,tile=0,bevel=0,set='Frame',face_tiles=None):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 ob=bpy.data.objects.new(name,me);c.objects.link(ob);me.materials.append(mat)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 if bevel:
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
  m=ob.modifiers.new('Single-segment structural chamfer','BEVEL');m.width=bevel;m.segments=1
  bpy.ops.object.modifier_apply(modifier=m.name)
 uv=me.uv_layers.new(name='PaletteUV')
 for p in me.polygons:
  color=face_tiles[p.index] if face_tiles else tile
  if bevel and p.area<.000025:color={0:7,1:2,4:0,7:1}.get(color,color)
  for li in p.loop_indices:uv.data[li].uv=((color*8+4)/64,.5)
  p.use_smooth=False
 vg=ob.vertex_groups.new(name=name);vg.add(list(range(len(me.vertices))),1,'REPLACE');sets[set].append(ob)
 return ob
def P(name,points,width,tile=0,bevel=0,set='Frame',x=0):
 n=len(points);vs=[(x+xx,y,z) for xx in [-width/2,width/2] for y,z in points]
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return part(name,vs,fs,tile,bevel,set)
def B(name,y0,y1,z0,z1,width,tile=0,bevel=0,set='Frame',x=0):return P(name,[(y0,z1),(y1,z1),(y1,z0),(y0,z0)],width,tile,bevel,set,x)
def ring(name,outer,inner,width,tile=1):
 n=len(outer);assert n==len(inner)
 vs=[(x,y,z) for x in [-width/2,width/2] for points in [outer,inner] for y,z in points];fs=[]
 for i in range(n):
  j=(i+1)%n;fs.extend([(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),(i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)])
 return part(name,vs,fs,tile)
def pin(name,y,z,x,r=.0028):
 n=6;vs=[(xx,y+math.cos(i*math.tau/n)*r,z+math.sin(i*math.tau/n)*r) for xx in [x-.00045,x+.00045] for i in range(n)]
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return part(name,vs,fs,3)
# A chamfered long slide with a real front recess, leaving a visible barrel opening.
cross=[(-.017,.088),(.017,.088),(.020,.091),(.020,.120),(.016,.124),(-.016,.124),(-.020,.120),(-.020,.091)]
inner=[(math.cos(-math.pi/2+i*math.tau/8)*.0105,.103+math.sin(-math.pi/2+i*math.tau/8)*.0105) for i in range(8)]
vs=[(x,y,z) for y,points in [(-.050,cross),(.202,cross),(.202,inner),(-.046,inner)] for x,z in points];fs=[];tiles=[]
for i in range(8):
 j=(i+1)%8
 fs.extend([(i,j,j+8,i+8),(i+8,j+8,j+16,i+16),(i+16,j+16,j+24,i+24)])
 tiles.extend([1 if i in [1,3,5,7] else 0,3,4])
fs.extend([tuple(reversed(range(8))),tuple(range(24,32))]);tiles.extend([0,4])
part('FacetedLongSlide',vs,fs,set='Slide',face_tiles=tiles)
# Original stepped chamber saddle and broad mechanical planes.
B('RearChamberSaddle',-.046,.044,.123,.127,.027,0,.0006,'Slide')
for side in [-1,1]:
 P('SlideSideStep',[(.058,.115),(.182,.115),(.190,.111),(.065,.111)],.0005,7,set='Slide',x=side*.0202)
 for i in range(6):B('RearSerration_%02d'%i,-.042+i*.010,-.039+i*.010,.091,.117,.0004,4,set='Slide',x=side*.0202)
# Ejection recess and extractor are distinct from the source silhouette/decoration.
B('EjectionPortInset',.017,.055,.112,.120,.0005,4,set='Slide',x=.02025)
P('ExtractorLip',[(.012,.113),(.019,.113),(.019,.116),(.014,.116)],.0012,3,set='Slide',x=.0204)
B('RearSightBase',-.045,-.026,.127,.130,.024,1,set='Slide')
for x in [-.0085,.0085]:B('RearSightNotch',-.044,-.033,.130,.134,.006,0,set='Slide',x=x)
P('FrontSight',[(.177,.124),(.193,.124),(.189,.134),(.185,.134)],.008,1,set='Slide')
# Layered frame, rear spur and slimmer grip retain the established grip origin.
P('LowerFrame',[(-.050,.086),(.198,.086),(.199,.075),(.192,.067),(.061,.067),(.054,.052),(.040,.052),(.035,.066),(-.047,.068)],.032,1,.0008)
P('Beavertail',[(-.050,.090),(-.067,.078),(-.058,.068),(-.030,.068),(-.026,.080)],.026,0,.0006)
B('UnderBarrelDustCover',.112,.192,.063,.0675,.028,0)
for side in [-1,1]:
 B('FrameRailSeam',.063,.183,.074,.076,.0005,4,x=side*.0162)
 pin('FramePivotPin',.031,.066,side*.0167)
 P('SlideRelease',[(.030,.073),(.050,.073),(.050,.070),(.038,.069),(.036,.065),(.030,.065)],.0012,0,x=side*.017)
# Hollow three-section grip. The magazine can be removed through a genuine open well.
def octagon(hx,hy,ch):return [(-hx+ch,-hy),(hx-ch,-hy),(hx,-hy+ch),(hx,hy-ch),(hx-ch,hy),(-hx+ch,hy),(-hx,hy-ch),(-hx,-hy+ch)]
sections=[(.068,.017,.016,.036),(.000,-.0025,.0165,.0345),(-.074,-.026,.0155,.033)]
vs=[]
for z,y,hx,hy in sections:
 for points in [octagon(hx,hy,.002),octagon(.0105,.018,.001)]:vs.extend((x,y+dy,z) for x,dy in points)
fs=[]
for section in range(2):
 for i in range(8):
  j=(i+1)%8;a=section*16
  fs.extend([(a+i,a+j,a+j+16,a+i+16),(a+i+8,a+i+24,a+j+24,a+j+8)])
for a in [0,32]:
 for i in range(8):
  j=(i+1)%8;fs.append((a+i,a+i+8,a+j+8,a+j))
part('AngledGripOpenMagwell',vs,fs,0)
for side in [-1,1]:
 P('GripPanel',[(-.017,.054),(.043,.054),(.030,.012),(.001,-.060),(-.048,-.064),(-.030,-.010)],.0026,5,.0007,x=side*.0175)
 for dy in [0,.018]:P('GripPanelChannel',[(dy-.017,.030),(dy-.012,.030),(dy-.032,-.039),(dy-.037,-.039)],.0004,4,x=side*.019)
 pin('GripPanelFastener',-.036,-.054,side*.0194,.0026)
 B('MagazineRelease',.032,.037,.040,.045,.0007,3,x=side*.019)
# Open angular guard, with generous visible trigger clearance.
ring('TriggerGuard',[(.044,.070),(.103,.070),(.115,.053),(.116,.021),(.104,.010),(.065,.009),(.046,.020),(.040,.042)],[(.053,.058),(.099,.058),(.108,.049),(.109,.026),(.101,.018),(.068,.017),(.053,.024),(.048,.042)],.018,1)
P('Trigger',[(.071,.070),(.077,.070),(.075,.039),(.082,.030),(.078,.025),(.069,.035),(.066,.047)],.009,3)
# Faceted loop hammer suggests the reference without reproducing its exact circular form.
outer=[(-.051,.116),(-.058,.124),(-.056,.134),(-.048,.138),(-.040,.133),(-.040,.121)]
center=Vector((-.049,.127));inside=[tuple(center+(Vector(p)-center)*.45) for p in outer]
ring('HexLoopHammer',outer,inside,.014,3)
# Static barrel recessed in the slide; eight sides with an actual dark inner bore.
n=8;vs=[(math.cos(i*math.tau/n)*r,y,.103+math.sin(i*math.tau/n)*r) for y in [.170,.207] for r in [.009,.0055] for i in range(n)];fs=[]
for i in range(n):
 j=(i+1)%n;fs.extend([(i,j,j+16,i+16),(i+8,i+24,j+24,j+8),(i+16,j+16,j+24,i+24),(i,i+8,j+8,j)])
part('HollowBarrel',vs,fs,3)
P('MagazineShell',[(-.003,.050),(.029,.050),(-.010,-.078),(-.042,-.078)],.020,3,set='Magazine')
B('MagazineFloorplate',-.061,.011,-.081,-.073,.035,7,.0006,'Magazine')
def join(objects,name,pivot):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co-=pivot
 o.location=pivot;o.parent=root
 # All components share one atlas surface after joining.
 for poly in o.data.polygons:poly.material_index=0
 while len(o.data.materials)>1:o.data.materials.pop(index=len(o.data.materials)-1)
 return o
frame=join(sets['Frame'],'Pistol_V2_Frame',Vector((0,0,0)))
slide=join(sets['Slide'],'Pistol_V2_Slide',Vector((0,-.050,.103)))
mag=join(sets['Magazine'],'Pistol_V2_Magazine',Vector((0,.013,.050)))
slide['role']='Independent rigid slide; reference travel local Y -18mm; no Action authored'
mag['role']='Independent magazine; extract along (0,-0.035,-0.11); open grip well'
markers={'RightHandGrip':(0,0,0),'LeftHandGuide':(0,.034,0),'Muzzle':(0,.208,.103),'AimReference':(0,.180,.134),'RecoilPivot':(0,0,0),'HolsterAttach':(0,0,0),'Grip_Point':(0,0,0),'Support_Hand_Point':(0,.034,0),'Muzzle_Point':(0,.208,.103),'MagazineFeed':(0,.013,.050)}
for name,pos in markers.items():
 o=bpy.data.objects.new(name,None);c.objects.link(o);o.parent=root;o.location=pos;o.empty_display_type='ARROWS';o.empty_display_size=.012
 o['role']=name
bpy.context.view_layer.update();meshes=[frame,slide,mag];points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
topology={}
for o in meshes:
 o.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(o.data)
 topology[o.name]={'triangles':len(o.data.loop_triangles),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'signed_volume':bm.calc_volume(signed=True)};bm.free()
report={'status':'Pending','name':'Pistol_Stylized_V2','dimensions_m':{'width':max(p.x for p in points)-min(p.x for p in points),'length':max(p.y for p in points)-min(p.y for p in points),'height':max(p.z for p in points)-min(p.z for p in points)},'triangles':sum(t['triangles'] for t in topology.values()),'meshes':3,'materials':1,'texture':[64,64],'topology':topology,'markers':markers,'palette_srgb':palette,'reference':'User attached Korth 9mm silhouette and Sketchfab URL; original redesigned geometry, not a downloaded mesh','source_reference_url':'https://sketchfab.com/3d-models/low-poly-korth-9mm-dfbc4819b85745e4b882590ba770e37b','workflow':'Rigid slide and magazine; no character or weapon Action; static existing-pose fit only'}
assert report['triangles']<=1400,report['triangles']
assert all(t['nonmanifold_edges']==0 and t['signed_volume']>0 for t in topology.values()),topology
bpy.ops.object.select_all(action='DESELECT')
for o in c.objects:o.select_set(True)
bpy.context.view_layer.objects.active=frame
bpy.ops.export_scene.gltf(filepath=str(HERE/'Pistol_Stylized_V2.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
s['asset_report']=json.dumps(report);s['review_status']='Pending'
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
   sp.region_3d.view_location=(0,.07,.03);sp.region_3d.view_distance=.44;sp.region_3d.view_rotation=Vector((3,-.7,.7)).to_track_quat('Z','Y');sp.region_3d.view_perspective='ORTHO'
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
(HERE/'asset_report.json').write_text(json.dumps(report,indent=2));print('PISTOL_BUILT',json.dumps(report))
