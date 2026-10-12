"""User-requested reference-matched proportion revision; preserves compact V2."""
import bpy,bmesh,math,json,hashlib,sys,shutil,datetime
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;SHOW=OUT.parent/'showcase'
sys.path.insert(0,str(SHOW));from library_safety import UpdateLock
lock=UpdateLock(SHOW).acquire()
try:
 TARGET=OUT/'Rifle_Stylized_V2.blend';oldhash=hashlib.sha256(TARGET.read_bytes()).hexdigest()
 manifestpath=SHOW/'weapon_manifest.json';oldmanifest=manifestpath.read_bytes();manifest=json.loads(oldmanifest)
 entry=next(e for e in manifest['weapons'] if e['id']=='rifle_stylized_v2')
 assert entry['status']=='Pending' and entry['source_sha256']==oldhash
 archive=OUT/'compact_checkpoint';archive.mkdir(exist_ok=True)
 existing_archive=(archive/'Rifle_Stylized_V2_compact.blend').exists()
 assert not existing_archive or '--refine-iteration' in sys.argv,'Use explicit --refine-iteration after inspecting the pending revision'
 backup=OUT.parents[2]/'.validation/weapon_showcase_v2'/('reference_iteration_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'))
 backup.mkdir(parents=True,exist_ok=True)
 for name in ['Rifle_Stylized_V2.blend','Rifle_Stylized_V2.glb','rifle_v2_palette_64.png','asset_report.json']:
  dest=archive/(name.replace('Rifle_Stylized_V2','Rifle_Stylized_V2_compact'))
  if not existing_archive:shutil.copy2(OUT/name,dest)
  elif (OUT/name).exists():shutil.copy2(OUT/name,backup/name)
 bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.unit_settings.system='METRIC'
 c=bpy.data.collections.new('WEAPON_EXPORT');s.collection.children.link(c)
 root=bpy.data.objects.new('Rifle_Stylized_V2',None);c.objects.link(root);root['review_status']='Pending'
 palette=[(.065,.075,.085,1),(.23,.27,.30,1),(.36,.40,.43,1),(.51,.55,.57,1),(.025,.033,.04,1),(.85,.45,.08,1),(.84,.87,.87,1),(.115,.135,.15,1)]
 W,H=256,128;pixels=[0.]*(W*H*4)
 def paint(x,y,color):
  if 0<=x<W and 0<=y<H:pixels[(y*W+x)*4:(y*W+x)*4+4]=color
 for y in range(H):
  for x in range(W):paint(x,y,palette[x//32] if y>=96 else palette[4])
 for y in range(96,112):
  for x in range(224,256):paint(x,y,(.80,.035,.02,1))
 # Tiny fictional/stock identification marks are atlas pixels, not extra draw surfaces.
 font={'0':['01110','10001','10011','10101','11001','10001','01110'],'1':['00100','01100','00100','00100','00100','00100','01110'],'2':['01110','10001','00001','00010','00100','01000','11111'],'3':['11110','00001','00001','01110','00001','00001','11110'],'4':['00010','00110','01010','10010','11111','00010','00010'],'5':['11111','10000','10000','11110','00001','00001','11110'],'6':['01110','10000','10000','11110','10001','10001','01110'],'A':['01110','10001','10001','11111','10001','10001','10001'],'B':['11110','10001','10001','11110','10001','10001','11110'],'C':['01111','10000','10000','10000','10000','10000','01111'],'E':['11111','10000','10000','11110','10000','10000','11111'],'I':['11111','00100','00100','00100','00100','00100','11111'],'M':['10001','11011','10101','10101','10001','10001','10001'],'N':['10001','11001','10101','10011','10001','10001','10001'],'R':['11110','10001','10001','11110','10100','10010','10001'],'V':['10001','10001','10001','10001','10001','01010','00100'],'X':['10001','10001','01010','00100','01010','10001','10001'],' ':['00000']*7}
 labels={}
 for text,y,color,bg in [('M4A1 CARBINE',2,6,2),('2003451',20,6,2),('5X56',38,6,2),('V4',56,5,1),('200134',74,6,0)]:
  width=len(text)*12
  for py in range(y,y+16):
   for px in range(width):paint(px,py,palette[bg])
  for j,char in enumerate(text):
   for row,bits in enumerate(font[char]):
    for col,bit in enumerate(bits):
     if bit=='1':
      for dx in range(2):
       for dy in range(2):paint(j*12+col*2+dx,y+14-row*2+dy,palette[color])
  labels[text]=(width,y,0)
 labels['SightSerial']=(84,20,160)
 for py in range(20,36):
  for px in range(84):
   color=pixels[(py*W+px)*4:(py*W+px)*4+4]
   paint(160+px,py,palette[0] if color==list(palette[2]) else color)
 clean_atlas=OUT/'rifle_v2_markings_atlas_1024.png'
 if clean_atlas.exists():
  im=bpy.data.images.load(str(clean_atlas),check_existing=False);im.name='Rifle_V2_Clean_Markings_1024';im.pack()
 else:
  im=bpy.data.images.new('Rifle_V2_Reference_Atlas_256',width=W,height=H,alpha=True);im.pixels.foreach_set(pixels)
  im.filepath_raw=str(OUT/'rifle_v2_reference_atlas_256.png');im.file_format='PNG';im.save();im.pack()
 mat=bpy.data.materials.new('Rifle_V2_Reference_Graphite');mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=.12;bs.inputs['Roughness'].default_value=.5
 tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;tx.interpolation='Closest';mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
 parts=[];magparts=[]
 # Reuse dimensioned manifold extrusion helpers; replace their constant-palette UV mapping.
 code=(OUT/'build_rifle.py').read_text();snippet=code[code.index('def part('):code.index('# Broad receiver planes')]
 snippet=snippet.replace('((color*8+4)/64,.5)','((color*32+16)/256,120.5/128)')
 exec(compile(snippet,str(OUT/'build_rifle.py'),'exec'))
 scale=1.20/1777;origin=(560,395)
 def yz(points):return [((x-origin[0])*scale,(origin[1]-y)*scale) for x,y in points]
 def P(name,points,width,tile=1,bevel=0,mag=False,x=0):return profile(name,yz(points),width,tile,bevel,mag,x)
 def B(name,rect,width,tile=1,bevel=0,mag=False,x=0):
  l,t,r,b=rect;return P(name,[(l,t),(r,t),(r,b),(l,b)],width,tile,bevel,mag,x)
 def ring(name,outer,inner,width,tile=0,bevel=0):
  outer=yz(outer);inner=yz(inner);n=len(outer);vs=[(x,y,z) for x in [-width/2,width/2] for points in [outer,inner] for y,z in points];fs=[]
  for i in range(n):
   j=(i+1)%n
   fs.extend([(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),(i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)])
  return part(name,vs,fs,tile,bevel)
 def label(text,x0,x1,y0,y1,depth,mag=False,sides=(-1,1),angle=0):
  width,py,px=labels[text]
  for side in sides:
   cx,cy=(x0+x1)/2,(y0+y1)/2
   points=yz([(cx+(x-cx)*math.cos(angle)-(y-cy)*math.sin(angle),cy+(x-cx)*math.sin(angle)+(y-cy)*math.cos(angle)) for x,y in [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]])
   ob=part('AtlasLabel_'+text,[(side*depth,y,z) for y,z in points],[(0,1,2,3)] if side>0 else [(3,2,1,0)],1,mag=mag)
   uv=ob.data.uv_layers.active
   coords=[((px+.5)/W,(py+15.5)/H),((px+width-.5)/W,(py+15.5)/H),((px+width-.5)/W,(py+.5)/H),((px+.5)/W,(py+.5)/H)]
   if side<0:coords=[coords[1],coords[0],coords[3],coords[2]]
   for li in range(4):uv.data[li].uv=coords[ob.data.loops[li].vertex_index]
 # Match the reference's long stock, shallow receiver and long exposed barrel.
 B('StockUpper',(91,111,481,190),.079,0,.0025)
 P('StockBrace',[(93,180),(394,180),(394,267),(282,267),(207,317),(207,251),(99,350)],.064,4)
 P('StockBraceStep',[(207,251),(264,226),(376,226),(376,260),(283,260),(207,317)],.070,0,.0007)
 B('StockButt',(90,115,105,365),.087,0,.0008)
 for side in [-1,1]:
  for x0 in [118,219,320]:B('StockVent',(x0,140,x0+72,158),.0003,4,x=side*.0396)
 B('BufferCollar',(460,128,535,190),.061,3,.001)
 B('UpperReceiver',(501,132,980,207),.075,2,.002)
 P('LowerReceiver',[(500,204),(973,204),(971,301),(794,324),(794,253),(628,253),(630,325),(554,284),(500,252)],.070,1,.0018)
 ring('CarryHandle',[(550,134),(601,10),(982,25),(985,134)],[(669,106),(690,52),(953,61),(953,111)],.035,0,.0006)
 B('ChargingLatch',(505,103,554,132),.09,0)
 # Distinct silver deflector on one side and marking plate on the other.
 P('ReceiverDeflector',[(531,146),(687,154),(686,181),(531,196)],.008,3,.0005,x=-.040)
 B('ReceiverRaisedInset',(784,152,958,191),.0015,1,x=-.038)
 for x0 in [796,879]:
  P('ReceiverInsetFrame',[(x0,185),(x0,159),(x0+65,159),(x0+65,185),(x0+57,185),(x0+57,167),(x0+8,167),(x0+8,185)],.0004,2,x=-.039)
 for side in [-1,1]:
  for name,rect in [('SafetyRedDot',(584,201,600,217)),('SafetyBar',(542,228,574,239))]:
   control=B(name,rect,.002,5,x=side*.036)
   for uv in control.data.uv_layers.active.data:uv.uv=(240/256,104/128)
  B('SafetyWhiteDot',(629,230,642,243),.002,6,x=side*.036)
  for name,rect in [('SelectorRecess',(584,224,613,253)),('ReceiverPinInset',(511,211,535,234)),('ReceiverPinInset',(927,214,950,243))]:
   inset=B(name,rect,.0004,7,x=side*.0352)
   for uv in inset.data.uv_layers.active.data:uv.uv=(.9375,.625)
 # Broad handguard: alternating planes, shallow eight ribs rather than a tall rail.
 B('GuardSilverCollar',(981,121,1038,225),.088,3,.001)
 B('Handguard',(1037,107,1431,241),.092,0,.001)
 for i in range(8):
  x0=1041+i*48
  B('GuardRib_%02d'%i,(x0,106,x0+24,242),.093,7,.00035)
 ring('FrontSight',[(1431,157),(1510,45),(1541,46),(1541,158)],[(1448,149),(1518,71),(1530,72),(1530,149)],.018,0)
 B('FrontSightBase',(1431,157,1541,202),.05,0)
 # Stepped rectangular barrel, square cap and true dark front opening.
 B('BarrelRear',(1541,163,1602,201),.027,3)
 P('BarrelTaper',[(1601,163),(1640,174),(1640,195),(1601,201)],.026,3)
 B('BarrelLong',(1638,174,1812,196),.022,3)
 z=(395-184)*scale
 # Rectangular hollow cap, matching the reference rather than an octagonal tube.
 vs=[(xx,yy,z+zz) for yy in [(1809-560)*scale,(1867-560)*scale] for w,h in [(.016,.0125),(.009,.007)] for xx,zz in [(-w,-h),(w,-h),(w,h),(-w,h)]]
 fs=[]
 for i in range(4):
  j=(i+1)%4;fs.extend([(i,j,j+8,i+8),(i+4,i+12,j+12,j+4),(i+8,j+8,j+12,i+12),(i,i+4,j+4,j)])
 part('MuzzleBrake',vs,fs,3)
 # Reference grip and open rectangular trigger window, retaining a centered hand origin.
 P('PistolGrip',[(558,282),(651,320),(566,455),(440,426)],.060,0,.002)
 P('GripInset',[(558,299),(623,326),(554,434),(461,412)],.002,4,x=.031)
 P('GripInset',[(558,299),(623,326),(554,434),(461,412)],.002,4,x=-.031)
 ring('TriggerGuard',[(628,253),(790,253),(794,325),(630,325)],[(642,264),(779,264),(781,313),(642,313)],.026,2)
 P('Trigger',[(687,261),(699,261),(717,306),(708,310)],.013,0)
 # Seat the feed mouth inside the lower receiver, retaining the reload pivot.
 P('Magazine',[(794,309),(963,294),(971,391),(1007,509),(848,546),(824,439)],.065,0,.0008,True)
 # Two matched bands share the same curved cross-sections and equal edge margins.
 # Their lower ends are parallel to the magazine base and clear of its serial.
 sections=[((801,344),(968,329)),((820,430),(980,400)),((838,498),(997,461))]
 def band_edge(u):return [(a[0]+(b[0]-a[0])*u,a[1]+(b[1]-a[1])*u) for a,b in sections]
 for side in [-1,1]:
  for index,u in enumerate([.28,.72]):P('MagazineBand_%d'%index,band_edge(u-.06)+list(reversed(band_edge(u+.06))),.0004,4,mag=True,x=side*.0328)
 label('M4A1 CARBINE',529,750,153,183,.0376,sides=(1,))
 label('2003451',828,949,160,182,.0376,sides=(1,))
 label('SightSerial',1440,1534,174,195,.0251,sides=(-1,))
 label('5X56',697,771,159,181,.0376,sides=(-1,))
 label('V4',830,908,249,286,.0351)
 # Keep the magazine serial inside its face with generous bottom/side gutters.
 # Baseline follows the actual sloping magazine base (848,546) -> (1007,509).
 label('200134',858,970,497,519,.034,True,angle=math.atan2(-37,159))
 # Join only the two rigid runtime parts; atlas labels remain part of those surfaces.
 tail=code[code.index('def join('):code.index("body=join(parts,")]
 exec(compile(tail,str(OUT/'build_rifle.py'),'exec'))
 body=join(parts,'Rifle_V2_Body');pivot=Vector((.0,(877-560)*scale,(395-315)*scale));mag=join(magparts,'Rifle_V2_Magazine',pivot)
 mag['role']='Detachable magazine; local -Z removal, root-relative reload pivot'
 markers={'RightHandGrip':(0,0,0),'LeftHandGuide':(0,.375,.125),'Muzzle':(0,(1868-560)*scale,z),'AimReference':(0,(1534-560)*scale,(395-60)*scale),'RecoilPivot':(0,0,0),'HolsterAttach':(0,0,0),'Grip_Point':(0,0,0),'Support_Hand_Point':(0,.375,.125),'Muzzle_Point':(0,(1868-560)*scale,z)}
 for name,pos in markers.items():
  ob=bpy.data.objects.new(name,None);c.objects.link(ob);ob.parent=root;ob.location=pos;ob.empty_display_type='ARROWS';ob.empty_display_size=.03;ob['role']=name
 bpy.context.view_layer.update()
 points=[o.matrix_world@v.co for o in [body,mag] for v in o.data.vertices]
 report={'status':'Pending','revision':'Reference form/surface pass: layered stock and receiver, shallow guard bands, rectangular muzzle, sRGB steel/graphite palette, aligned serial and seated magazine','dimensions_m':[max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)],'meshes':2,'materials':1,'texture':list(im.size),'markers':markers,'topology':{},'compact_source_sha256':hashlib.sha256((archive/'Rifle_Stylized_V2_compact.blend').read_bytes()).hexdigest(),'reference':'User attached blocky-stylized-m4a1-assault-rifle-low-poly-game-ready-3d-model-22c0739a31 (2).jpg'}
 for ob in [body,mag]:
  ob.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(ob.data)
  # Identification planes are intentionally two-sided decals in the same mesh/material.
  report['topology'][ob.name]={'triangles':len(ob.data.loop_triangles),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges_excluding_decals':sum(not e.is_manifold and not e.is_boundary for e in bm.edges),'loose_vertices':sum(not v.link_faces for v in bm.verts)};bm.free()
 report['triangles']=sum(t['triangles'] for t in report['topology'].values());assert report['triangles']<2000
 bpy.ops.object.select_all(action='DESELECT')
 for ob in c.objects:ob.select_set(True)
 bpy.context.view_layer.objects.active=body
 bpy.ops.export_scene.gltf(filepath=str(OUT/'Rifle_Stylized_V2.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
 s['review_status']='Pending';s['asset_report']=json.dumps(report)
 for screen in bpy.data.screens:
  for area in screen.areas:
   if area.type=='VIEW_3D':
    sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False;sp.region_3d.view_location=(0,.28,.08);sp.region_3d.view_distance=1.40
    sp.region_3d.view_rotation=Vector((-3,-.4,.55)).to_track_quat('Z','Y');sp.region_3d.view_perspective='ORTHO'
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
 (OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
 assert manifestpath.read_bytes()==oldmanifest,'Concurrent manifest edit; preserved instead of overwriting'
 entry['source_sha256']=hashlib.sha256(TARGET.read_bytes()).hexdigest();entry['status_note']='Pending reference-matched long revision requested by user; compact checkpoint preserved.'
 if not any(e['id']=='rifle_stylized_v2_compact' for e in manifest['weapons']):manifest['weapons'].append({'id':'rifle_stylized_v2_compact','label':'Rifle — Stylized V2 compact checkpoint','kind':'Rifle','source':'blender/weapons/rifle_stylized_v2/compact_checkpoint/Rifle_Stylized_V2_compact.blend','source_sha256':report['compact_source_sha256'],'status':'Pending','status_note':'Preserved early compact candidate, superseded by user reference steering.'})
 manifestpath.write_text(json.dumps(manifest,indent=2));print('REFERENCE_REVISION_BUILT',json.dumps(report))
finally:lock.release()
