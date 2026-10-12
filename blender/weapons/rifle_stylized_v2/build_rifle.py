"""Original grip-centered stylized rifle. Run in an isolated Blender process."""
import bpy,bmesh,math,json,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
TARGET=OUT/'Rifle_Stylized_V2.blend'
assert not TARGET.exists(),'Version/backup existing source before rebuilding'
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.unit_settings.system='METRIC'
c=bpy.data.collections.new('WEAPON_EXPORT');s.collection.children.link(c)
root=bpy.data.objects.new('Rifle_Stylized_V2',None);c.objects.link(root)
root['review_status']='Pending';root['forward']='+Y';root['origin']='RightHandGrip'
# Broad constant palette tiles: one material, no tiny noisy texture details.
palette=[(.075,.090,.105,1),(.15,.18,.21,1),(.235,.27,.30,1),(.34,.38,.40,1),(.045,.055,.065,1),(.53,.31,.13,1),(.65,.68,.66,1),(.095,.115,.13,1)]
im=bpy.data.images.new('Rifle_V2_Palette_64',width=64,height=64,alpha=True)
pixels=[]
for y in range(64):
 for x in range(64):pixels.extend(palette[x//8])
im.pixels.foreach_set(pixels);im.filepath_raw=str(OUT/'rifle_v2_palette_64.png');im.file_format='PNG';im.save();im.pack()
mat=bpy.data.materials.new('Rifle_V2_Graphite_Atlas');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=.18;bs.inputs['Roughness'].default_value=.48
tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;tx.interpolation='Closest'
mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
parts=[];magparts=[]
def part(name,vs,fs,tile,bevel=0,mag=False):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 ob=bpy.data.objects.new(name,me);c.objects.link(ob);me.materials.append(mat)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 if bevel:
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
  mod=ob.modifiers.new('Single segment edge highlight','BEVEL');mod.width=bevel;mod.segments=1
  bpy.ops.object.modifier_apply(modifier=mod.name)
 uv=me.uv_layers.new(name='PaletteUV')
 for p in me.polygons:
  color=min(tile+1,3) if bevel and p.area<.00012 and tile in (0,1,2) else tile
  for li in p.loop_indices:uv.data[li].uv=((color*8+4)/64,.5)
  p.use_smooth=False
 vg=ob.vertex_groups.new(name=name);vg.add(list(range(len(me.vertices))),1,'REPLACE')
 (magparts if mag else parts).append(ob)
 return ob
def profile(name,yz,width,tile=1,bevel=0,mag=False,x=0):
 n=len(yz);vs=[(x+xx,y,z) for xx in [-width/2,width/2] for y,z in yz]
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return part(name,vs,fs,tile,bevel,mag)
def box(name,xyz,size,tile=1,bevel=0,mag=False):
 x,y,z=xyz;w,l,h=[n/2 for n in size]
 return profile(name,[(y-l,z-h),(y+l,z-h),(y+l,z+h),(y-l,z+h)],w*2,tile,bevel,mag,x)
def tube(name,y0,y1,z,r,inner=0,tile=2):
 n=8;vs=[(math.cos(math.pi/8+i*math.tau/n)*rad,y,z+math.sin(math.pi/8+i*math.tau/n)*rad) for y in [y0,y1] for rad in ([r,inner] if inner else [r]) for i in range(n)]
 if inner:
  fs=[]
  for i in range(n):
   j=(i+1)%n;fs.extend([(i,j,j+16,i+16),(i+8,i+24,j+24,j+8),(i+16,j+16,j+24,i+24),(i,i+8,j+8,j)])
 else:fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return part(name,vs,fs,tile)
# Broad receiver planes, stepped lower and visible side mechanisms.
profile('UpperReceiver',[(-.165,.145),(-.165,.217),(-.13,.24),(.135,.24),(.164,.215),(.15,.145)],.087,1,.0012)
profile('LowerReceiver',[(-.15,.15),(.15,.15),(.135,.079),(.02,.068),(-.065,.082),(-.15,.10)],.078,0,.001)
for side in [-1,1]:
 box('ReceiverCheek', (side*.046,-.005,.176),(.009,.205,.038),2)
 box('EjectionInset' if side<0 else 'ServiceInset',(side*.052,.042,.186),(.004,.092,.022),4)
 box('Latch', (side*.055,-.082,.137),(.008,.025,.018),5)
box('ChargingHandle',(0,-.156,.235),(.108,.024,.014),2)
# Open carry structure with a clear central window, squared rear aperture.
profile('CarryRear',[(-.13,.24),(-.095,.24),(-.087,.301),(-.118,.301)],.035,0)
profile('CarryFront',[(.082,.24),(.112,.24),(.085,.301),(.058,.301)],.035,0)
box('CarryBridge',(0,-.017,.306),(.043,.205,.018),1,.0008)
for x in [-.026,.026]:box('RearSightEar',(x,-.108,.310),(.012,.034,.028),0)
# Adjustable open stock, two beams and a stronger faceted butt.
tube('BufferTube',-.288,-.155,.185,.023,tile=2)
profile('StockUpper',[(-.309,.213),(-.205,.213),(-.18,.195),(-.223,.178),(-.309,.178)],.075,0)
profile('StockLower',[(-.309,.09),(-.285,.09),(-.195,.157),(-.218,.173),(-.309,.12)],.068,1)
profile('StockHeel',[(-.313,.08),(-.286,.08),(-.286,.216),(-.313,.224)],.091,0,.0012)
box('StockPad',(0,-.318,.151),(.096,.012,.151),4)
box('StockAdjust',(0,-.248,.129),(.043,.049,.014),5)
# Distinct longitudinal core with six broad ribs; no micro screws.
profile('HandguardCore',[(.154,.125),(.17,.218),(.41,.211),(.425,.191),(.415,.12)],.077,7)
for i in range(6):
 y=.181+i*.041
 profile('GuardRib_%02d'%i,[(y-.009,.117),(y+.009,.117),(y+.011,.212),(y-.009,.216)],.098,1)
box('LowerSupportPad',(0,.348,.12),(.078,.13,.014),0)
box('HandguardTop',(0,.286,.224),(.048,.255,.015),2)
for y in [.174,.225,.276,.327,.378]:box('RailNotch',(0,y,.236),(.054,.021,.009),0)
tube('Barrel',.417,.632,.18,.018,tile=2)
tube('GasCollar',.432,.455,.18,.027,tile=0)
for x in [-.027,.027]:
 profile('FrontSightEar',[(.444,.18),(.464,.18),(.464,.30),(.446,.30)],.012,0,x=x)
box('FrontSightPost',(0,.454,.286),(.009,.015,.029),3)
box('FrontSightSeat',(0,.454,.216),(.069,.025,.017),1)
tube('MuzzleBrake',.626,.686,.18,.027,.012,0)
for side in [-1,1]:
 for y in [.641,.665]:box('BrakeSlot',(side*.025,y,.18),(.002,.009,.017),4)
# Grip centers at the established runtime origin. Guard has a true opening.
profile('PistolGrip',[(-.007,.102),(.048,.078),(.011,-.087),(-.053,-.078)],.064,0,.001)
profile('GripHeel',[(-.052,-.078),(.012,-.087),(.014,-.102),(-.057,-.091)],.070,4)
profile('TriggerGuard',[(-.001,.082),(.112,.082),(.119,.065),(.108,.025),(.018,.025),(.003,.037),(.003,.048),(.024,.039),(.097,.039),(.105,.066),(-.001,.068)],.026,2)
profile('Trigger',[(.047,.083),(.059,.08),(.054,.051),(.044,.044),(.039,.05),(.045,.056)],.012,4)
# Forward curved magazine is separately parented, pivot at its feed mouth.
profile('Magazine',[(.105,.09),(.184,.09),(.191,.01),(.211,-.065),(.245,-.127),(.168,-.145),(.137,-.08),(.114,-.009)],.066,1,.0008,True)
profile('MagazineFloor',[(.164,-.138),(.247,-.12),(.255,-.139),(.166,-.16)],.076,0,mag=True)
for side in [-1,1]:
 for y in [.14,.17]:profile('MagazineFlute',[(y,.027),(y+.009,.027),(y+.029,-.072),(y+.047,-.116),(y+.037,-.119),(y+.021,-.074)],.003,2,mag=True,x=side*.034)
box('WarmID',(.052,-.033,.182),(.004,.03,.014),5)
box('IDTick',(.054,-.011,.182),(.002,.006,.014),6)
def join(obs,name,pivot=(0,0,0)):
 bpy.ops.object.select_all(action='DESELECT')
 for ob in obs:ob.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 o.data.materials.clear();o.data.materials.append(mat)
 for p in o.data.polygons:p.material_index=0
 for v in o.data.vertices:v.co-=Vector(pivot)
 o.parent=root;o.location=pivot;return o
body=join(parts,'Rifle_V2_Body');mag=join(magparts,'Rifle_V2_Magazine',(0,.145,.09));mag['role']='Detachable reload part; pull down local Z, then forward local Y'
markers={'RightHandGrip':(0,0,0),'LeftHandGuide':(0,.375,.125),'Muzzle':(0,.687,.18),'AimReference':(0,.454,.30),'RecoilPivot':(0,0,0),'HolsterAttach':(0,0,0),'Grip_Point':(0,0,0),'Support_Hand_Point':(0,.375,.125),'Muzzle_Point':(0,.687,.18)}
for name,pos in markers.items():
 o=bpy.data.objects.new(name,None);c.objects.link(o);o.parent=root;o.location=pos;o.empty_display_type='ARROWS';o.empty_display_size=.035
 o['role']='Legacy runtime alias' if name.endswith('_Point') else name
 root[name]=list(pos)
root['HolsterAttach_note']='Grip-origin mount anchor; uses existing Chest-space stow transform'
bpy.ops.object.select_all(action='DESELECT')
for o in c.objects:o.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.ops.export_scene.gltf(filepath=str(OUT/'Rifle_Stylized_V2.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
points=[o.matrix_world@v.co for o in [body,mag] for v in o.data.vertices]
report={'status':'Pending','dimensions_m':[max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)],'meshes':2,'materials':1,'texture':[64,64],'markers':markers,'topology':{}}
for o in [body,mag]:
 bm=bmesh.new();bm.from_mesh(o.data);o.data.calc_loop_triangles()
 report['topology'][o.name]={'triangles':len(o.data.loop_triangles),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'loose_vertices':sum(not v.link_faces for v in bm.verts)};bm.free()
 assert report['topology'][o.name]['nonmanifold_edges']==0
report['triangles']=sum(v['triangles'] for v in report['topology'].values())
assert report['triangles']<=2200,report
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
s['review_status']='Pending';s['asset_report']=json.dumps(report)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print('RIFLE_BUILT',json.dumps(report))
