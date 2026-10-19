"""Reference-scaled sand/graphite sniper prop, +Y forward, grip-centered."""
import argparse,bmesh,bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
TARGET=OUT/'Sniper_Sand_Block_V1.blend'
p=argparse.ArgumentParser();p.add_argument('--rebuild',action='store_true');p.add_argument('--no-render',action='store_true')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
assert args.rebuild or not TARGET.exists(),'Explicit --rebuild required for this Pending source'
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.name='Sniper Sand Block V1 — Reference Review'
s.unit_settings.system='METRIC'
c=bpy.data.collections.new('WEAPON_EXPORT');s.collection.children.link(c)
root=bpy.data.objects.new('Sniper_Sand_Block_V1',None);c.objects.link(root)
root['review_status']='Pending';root['forward']='+Y';root['origin']='RightHandGrip'
root['reference']='reference.png — user multi-view sniper reference 2026-10-19'
atlas=bpy.data.images.load(str(OUT/'sniper_sand_atlas_256.png'),check_existing=False)
atlas.name='Sniper_Sand_Atlas_256';atlas.pack()
mat=bpy.data.materials.new('Sniper_Sand_Graphite_Atlas');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF')
bs.inputs['Metallic'].default_value=.14;bs.inputs['Roughness'].default_value=.70
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
parts={'Frame':[],'Magazine':[],'Bolt':[],'Lenses':[]}

# Reference side-view pixel coordinates, transformed once into prop metres.
def Y(px):return (px-137)*.0019
def Z(py):return (134-py)*.0019
def P(px,py,x=0):return (x,Y(px),Z(py))
def part(name,vertices,faces,tile=0,bevel=0,group='Frame',face_tiles=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(vertices,[],faces)
    me.update()
    ob = bpy.data.objects.new(name,me)
    c.objects.link(ob)
    me.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    if bevel:
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        mod = ob.modifiers.new('Block edge chamfer','BEVEL')
        mod.width,mod.segments = bevel,1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    uv = me.uv_layers.new(name='SniperAtlasUV')
    lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
    spans = [max(v.co[i] for v in me.vertices)-lo[i] for i in range(3)]
    density = min(8.0,.84/max(spans))
    for face in me.polygons:
        face_tile = face_tiles[face.index] if face_tiles else tile
        drop = max(range(3),key=lambda i:abs(face.normal[i]))
        axes = [i for i in range(3) if i != drop]
        for li in face.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u,v = [.08+(co[a]-lo[a])*density for a in axes]
            uv.data[li].uv = ((face_tile%4+u)/4,(face_tile//4+v)/4)
        face.use_smooth = False
    vg = ob.vertex_groups.new(name=name)
    vg.add(list(range(len(me.vertices))),1,'REPLACE')
    parts[group].append(ob)
    return ob


def profile(name,yz,width,tile=0,bevel=0,group='Frame',x=0):
    n = len(yz)
    vs = [(x+xx,y,z) for xx in [-width/2,width/2] for y,z in yz]
    fs = [tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return part(name,vs,fs,tile,bevel,group)


def box(name,center,dims,tile=0,bevel=0,group='Frame'):
    x,y,z = center
    w,l,h = dims
    return profile(name,[(y-l/2,z-h/2),(y+l/2,z-h/2),
                         (y+l/2,z+h/2),(y-l/2,z+h/2)],w,tile,bevel,group,x)


def octagon(w,h,ch):
    return [(-w/2+ch,-h/2),(w/2-ch,-h/2),(w/2,-h/2+ch),(w/2,h/2-ch),
            (w/2-ch,h/2),(-w/2+ch,h/2),(-w/2,h/2-ch),(-w/2,-h/2+ch)]


def housing(name,rings,z,tile=4,hole=None,through=False,group='Frame',hole_chamfer=.0008,hole_z=None):
    # Cross sections along +Y; optional closed deep recess or open ring sleeve.
    vs = [(x,y,z+zz) for y,w,h,ch in rings for x,zz in octagon(w,h,ch)]
    fs = [] if through else [tuple(reversed(range(8)))]
    for j in range(len(rings)-1):
        fs += [(j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i) for i in range(8)]
    last = (len(rings)-1)*8
    if hole:
        w,h,depth = hole
        start = len(vs)
        for y in [rings[-1][0],rings[0][0] if through else rings[-1][0]-depth]:
            vs += [(x,y,(z if hole_z is None else hole_z)+zz) for x,zz in octagon(w,h,hole_chamfer)]
        for i in range(8):
            k = (i+1)%8
            fs += [(last+i,last+k,start+k,start+i),(start+i,start+k,start+8+k,start+8+i)]
        if through:
            fs += [(i,start+8+i,start+8+(i+1)%8,(i+1)%8) for i in range(8)]
        else:
            fs.append(tuple(start+8+i for i in range(8)))
    else:
        fs.append(tuple(last+i for i in range(8)))
    ob = part(name,vs,fs,tile,group=group)
    if hole and not through:
        for li in ob.data.polygons[-1].loop_indices:
            ob.data.uv_layers.active.data[li].uv = (.875,.875)
    return ob


def yz_ring(name,outer,inner,width,tile=0,bevel=0):
    n = len(outer)
    assert n == len(inner)
    vs = [(x,y,z) for x in [-width/2,width/2] for loop in [outer,inner] for y,z in loop]
    fs = []
    for i in range(n):
        j = (i+1)%n
        fs += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
               (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    return part(name,vs,fs,tile,bevel)

def shape(name,pixels,width,tile=0,bevel=.0007,group='Frame',x=0):
    return profile(name,[(Y(y),Z(z)) for y,z in pixels],width,tile,bevel,group,x)

def block(name,px,py,length,height,width,tile=0,bevel=.0006,group='Frame',x=0):
    return box(name,P(px,py,x),(width,length*.0019,height*.0019),tile,bevel,group)

def sleeve(name,sections,py,tile=4,bore=None,group='Frame'):
    return housing(name,[(Y(y),w,h,ch) for y,w,h,ch in sections],Z(py),tile,
                   hole=(bore[0],bore[1],.001) if bore else None,through=bool(bore),group=group)

# Broad upper beam, raised cheek pad, narrow stepped post and lower slider.
shape('Stock_Graphite_Buttpad',[(10,72),(15,66),(31,67),(32,158),(27,162),(10,161)],.066,6,.0012)
shape('Stock_Sand_Rear_Post',[(32,70),(61,70),(65,150),(56,150),(56,157),(33,158)],.057,0,.0009)
shape('Stock_Sand_Upper_Beam',[(55,88),(105,88),(111,81),(149,82),(150,110),
    (111,111),(109,120),(84,120),(84,114),(56,114)],.054,0,.0009)
block('Stock_Cheek_Riser',76,85,68,13,.043,8)
block('Stock_Raised_Cheek_Pad',72,75,65,21,.064,1,.0010)
block('Stock_Lower_Graphite_Slider',84,145,51,14,.036,6)
block('Stock_Slider_Stop',108,143,12,18,.045,4)
for side in [-1,1]:
    for name,px,py,size in [('Cheek',60,99,12),('Toe',51,142,7)]:
        block('Stock_'+name+'_Square_Fastener',px,py,size,size,.0038,4,.0004,x=side*.030)
        block('Stock_'+name+'_Pin',px,py,3,4,.0014,7,.0002,x=side*.0323)

# Shallow receiver with a real recessed bolt/ejection channel beneath its roof.
shape('Receiver_Lower_Sand',[(147,82),(270,82),(271,88),(301,88),(301,106),
    (272,107),(272,114),(178,113),(174,123),(146,121)],.061,0,.0009)
block('Receiver_Top_Sand_Roof',214,73,126,9,.059,1)
# Half-millimetre side steps avoid coincident faces where these walls overlap
# the roof and lower shell; a shared face plane creates black render seams.
block('Receiver_Slot_Rear_Wall',163,79,31,18,.060,0)
block('Receiver_Slot_Front_Wall',251,79,33,18,.060,0)
block('Receiver_Front_Upper_Bridge',286,80,30,21,.060,0)
block('Receiver_Recessed_Dark_Bolt',205,79.3,59,9,.042,6,.0005)
for side in [-1,1]:
    block('Receiver_Inset_Port_Sill',205,84,60,3,.005,2,.0003,x=side*.0279)
    for name,px,py,size in [('Rear',137,93,7),('Forward',254,96,11)]:
        block('Receiver_'+name+'_Square_Control',px,py,size,size,.004,4,.0004,x=side*.032)
        block('Receiver_'+name+'_Control_Pin',px,py,2.7,3,.0014,7,.0002,x=side*.0346)

# Raked tan grip and a small open, connected trigger guard.
shape('Grip_Sand_Core',[(143,108),(169,112),(142,158),(132,159),
    (106,151),(107,139),(126,140)],.041,0,.0010)
shape('Grip_Dark_Heel',[(106,150),(141,158),(138,165),(103,156)],.044,6,.0007)
shape('Grip_Dark_Backstrap',[(140,109),(144,110),(125,142),(107,142),(107,139),(126,140)],.042,6,.0005)
yz_ring('Open_Tan_Trigger_Guard',[(Y(a),Z(b)) for a,b in [(156,111),(184,111),(180,135),(150,135),(146,126)]],
    [(Y(a),Z(b)) for a,b in [(161,116),(177,116),(173,129),(154,129),(152,125)]],.025,2,.0006)
shape('Dark_Stepped_Trigger',[(166,114),(171,114),(170,123),(173,127),(169,129),(164,125)],.012,8,.0004)

# Straight removable box with broad dark panels and narrow vertical grooves.
block('Magazine_Core',214,129,51,43,.046,4,.0008,'Magazine')
block('Magazine_Floorplate',214,153,57,6,.051,9,.0005,'Magazine')
block('Magazine_Floorplate_Dark_Base',214,156,54,2,.048,6,.0002,'Magazine')
for side in [-1,1]:
    for i,px in enumerate([196,214,232]):
        block('Magazine_Panel_%d'%i,px,130,14.5,39,.0018,5 if i==1 else 4,.0002,'Magazine',side*.024)
    for px in [204.5,223]:
        block('Magazine_Recessed_Groove',px,130,2,39,.0008,8,0,'Magazine',side*.0235)

# Five horizontal open handguard vents on each face, with beveled rims.
def vent_panel(side):
    ys=[Y(300)]
    for px in [316,342,368,394,420]:ys += [Y(px-8),Y(px+8)]
    ys.append(Y(450))
    zs=[Z(105),Z(93),Z(85),Z(76)]
    occupied={(j,k) for j in range(len(ys)-1) for k in range(3) if k!=1 or j%2==0}
    vs=[];fs=[];lookup={};xs=[side*.031-.0045,side*.031+.0045]
    def vertex(i,j,k):
        key=(i,j,k)
        if key not in lookup:lookup[key]=len(vs);vs.append((xs[i],ys[j],zs[k]))
        return lookup[key]
    for j,k in sorted(occupied):
        for i in [0,1]:fs.append(tuple(vertex(i,jj,kk) for jj,kk in [(j,k),(j+1,k),(j+1,k+1),(j,k+1)]))
        if (j-1,k) not in occupied:fs.append(tuple(vertex(i,j,kk) for i,kk in [(0,k),(1,k),(1,k+1),(0,k+1)]))
        if (j+1,k) not in occupied:fs.append(tuple(vertex(i,j+1,kk) for i,kk in [(0,k),(1,k),(1,k+1),(0,k+1)]))
        if (j,k-1) not in occupied:fs.append(tuple(vertex(i,jj,k) for i,jj in [(0,j),(1,j),(1,j+1),(0,j+1)]))
        if (j,k+1) not in occupied:fs.append(tuple(vertex(i,jj,k+1) for i,jj in [(0,j),(1,j),(1,j+1),(0,j+1)]))
    return part('Handguard_Open_Vent_Panel_'+str(side),vs,fs,0,.0006)
for side in [-1,1]:
    vent_panel(side)
    block('Handguard_Front_Square_Screw',443,90,8,11,.003,4,.0004,x=side*.037)
    block('Handguard_Screw_Pin',443,90,2,3,.001,7,.0001,x=side*.039)
block('Handguard_Top_Sand_Bridge',375,77,150,5,.061,1)
block('Handguard_Lower_Sand_Bridge',375,103,150,4,.061,2)
sleeve('Handguard_Recessed_Barrel',[(298,.025,.026,.003),(462,.025,.026,.003)],79,6,(.016,.016))
# The collar's bore follows the upper barrel axis, above its geometric center.
housing('Handguard_Front_Collar',[(Y(449),.062,.060,.004),(Y(458),.062,.060,.004),
    (Y(466),.047,.043,.004)],Z(86),4,hole=(.029,.029,.001),through=True,hole_z=Z(79))

# Low square rail teeth follow the long handguard/receiver silhouette.
block('Rail_Base',306,70,305,5,.043,6,.0004)
for i in range(27):
    block('Rail_Tooth_%02d'%i,151+i*11.35,65.8,7.5,5,.049,7 if i%5==0 else 4,.0004)
block('Front_Block_Sight_Base',449,67,20,11,.046,4,.0005)
block('Front_Block_Sight_Insert',449,61,9,4,.020,7,.0003)

# Long exposed barrel, stepped coupling and a genuinely slotted muzzle brake.
sleeve('Long_Faceted_Barrel',[(460,.031,.029,.004),(571,.029,.027,.0035),
    (585,.029,.027,.0035)],79,5,(.018,.018))
sleeve('Muzzle_Rear_Coupling',[(570,.039,.039,.005),(578,.043,.043,.005),
    (585,.043,.043,.005)],79,4,(.020,.020))
brake=sleeve('Muzzle_Brake_Slotted_Body',[(581,.055,.053,.006),(587,.061,.060,.006),
    (631,.061,.060,.006),(636,.054,.056,.004)],79,5,(.025,.025))
for px in [608,624]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=P(px,79))
    cutter=bpy.context.object;cutter.dimensions=(.13,.0095,.031)
    cutter.data.materials.append(mat)
    for layer in list(cutter.data.uv_layers):cutter.data.uv_layers.remove(layer)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=brake
    mod=brake.modifiers.new('Open brake side window','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
me=brake.data;me.update();uv=me.uv_layers.active
lo=[min(v.co[i] for v in me.vertices) for i in range(3)]
density=min(8,.84/max(max(v.co[i] for v in me.vertices)-lo[i] for i in range(3)))
for face in me.polygons:
    drop=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=drop]
    tile=6 if abs(face.center.x)<.025 and abs(face.normal.x)>.5 else 5
    for li in face.loop_indices:
        co=me.vertices[me.loops[li].vertex_index].co
        u,v=[.08+(co[a]-lo[a])*density for a in axes]
        uv.data[li].uv=((tile%4+u)/4,(tile//4+v)/4)
sleeve('Muzzle_Warm_Front_Rim',[(633,.056,.057,.004),(638,.056,.057,.004)],79,9,(.026,.026))
block('Muzzle_Top_Lug',615,62,10,3,.021,6,.0003)

# Visible side bolt lever: seated pivot, downward/back rake, blocky knob.
block('Bolt_Track',205,78.5,58,7,.043,6,.0004,'Bolt')
block('Bolt_Pivot',181,80,10,8,.018,5,.0004,'Bolt',.037)
shape('Bolt_Angled_Handle',[(180,79),(187,81),(174,100),(168,97)],.014,5,.0006,'Bolt',.047)
knob=block('Bolt_Block_Knob',170,99,14,12,.028,4,.0018,'Bolt',.057)
block('Bolt_Knob_Face',170,99,8,7,.0016,7,.0005,'Bolt',.0717)

# Long squared optical tube: all metal components are open sleeves.
glass=bpy.data.materials.new('Sniper_Rear_Red_Orange_Glass');glass.use_nodes=True
glass.diffuse_color=(.85,.16,.025,.56)
gb=glass.node_tree.nodes.get('Principled BSDF')
for key,val in {'Base Color':(.85,.16,.025,1),'Emission Color':(.85,.16,.025,1),
    'Emission Strength':.22,'Metallic':0,'Roughness':.065,'Transmission Weight':.96,
    'IOR':1.46,'Coat Weight':.22,'Coat Roughness':.045,'Alpha':.56}.items():gb.inputs[key].default_value=val
glass.surface_render_method='DITHERED';glass.use_raytrace_refraction=True;glass.use_transparent_shadow=True
front_glass=glass.copy();front_glass.name='Sniper_Front_Red_Orange_Glass'
for px in [170,251]:
    block('Scope_Mount_Foot',px,63.5,22,8,.068,6,.0005)
    block('Scope_Mount_Riser',px,57,13,12,.035,4,.0005)
    for side in [-1,1]:block('Scope_Mount_Pin',px,63,4,3,.002,8,.0002,x=side*.035)
sleeve('Scope_Center_Tube',[(136,.048,.043,.006),(310,.048,.043,.006)],42,5,(.034,.030))
sleeve('Scope_Rear_Ocular',[(106,.049,.047,.006),(110,.066,.057,.007),
    (139,.066,.057,.007),(145,.052,.047,.005)],42,4,(.037,.033))
sleeve('Scope_Rear_Rubber_Rim',[(103,.050,.047,.006),(109,.050,.047,.006)],42,6,(.036,.032))
for i,(a,b) in enumerate([(145,153),(164,173),(185,195),(215,227),(262,272),(285,294)]):
    sleeve('Scope_Ring_%02d'%i,[(a,.057,.053,.006),(b,.057,.053,.006)],42,7 if i in [1,3] else 4,(.048,.043))
sleeve('Scope_Objective_Shoulder',[(290,.052,.047,.006),(296,.076,.061,.006),
    (337,.076,.061,.006)],42,5,(.037,.033))
sleeve('Scope_Objective_Front_Rim',[(334,.079,.063,.003),(345,.079,.063,.003)],42,9,(.052,.047))
sleeve('Scope_Objective_Lens_Seat',[(337,.056,.051,.004),(341,.056,.051,.004)],42,6,(.050,.045))
sleeve('Scope_Ocular_Lens_Seat',[(110,.042,.038,.004),(115,.042,.038,.004)],42,6,(.036,.032))

def lens(name,px,w,h,material):
    outline=octagon(w,h,.003);y=Y(px);z=Z(42)
    vs=[(x,y,z+zz) for x,zz in outline]
    for sign in [-1,1]:
        vs += [(x*.64,y+sign*.00065,z+zz*.64) for x,zz in outline]
        vs.append((0,y+sign*.0009,z))
    fs=[]
    for start,center in [(8,16),(17,25)]:
        for i in range(8):
            k=(i+1)%8;fs += [(i,k,start+k,start+i),(start+i,start+k,center)]
    ob=part(name,vs,fs,12,group='Lenses');ob.data.materials.clear();ob.data.materials.append(material)
    for f in ob.data.polygons:f.use_smooth=True
    return ob
lens('Scope_Rear_Optical_Lens',113,.037,.033,glass)
lens('Scope_Front_Optical_Lens',339,.051,.046,front_glass)

# Knurled top turret: sixteen broad facets with visible vertical index ribs.
def vertical_oct(name,center,radius,height,tile=4,n=16):
    x,y,z=center
    vs=[(x+radius*math.cos(i*2*math.pi/n),y+radius*math.sin(i*2*math.pi/n),z+zz)
        for zz in [-height/2,height/2] for i in range(n)]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return part(name,vs,fs,tile)
sleeve('Scope_Turret_Saddle',[(189.5,.055,.050,.004),(216.5,.055,.050,.004)],42,4,(.034,.030))
vertical_oct('Scope_Top_Turret_Stem',P(203,24),.017,.016,6)
vertical_oct('Scope_Top_Turret_Drum',P(203,16),.025,.024,4)
vertical_oct('Scope_Turret_Warm_Cap',P(203,9),.025,.004,9)
for i in range(12):
    a=2*math.pi*i/12
    ob=box('Scope_Turret_Knurl',(math.cos(a)*.024,Y(203)+math.sin(a)*.024,Z(16)),(.003,.004,.018),7 if i%3==0 else 5,.0003)
    # Rotate only the rib around its own center, preserving the common drum.
    center=Vector((math.cos(a)*.024,Y(203)+math.sin(a)*.024,Z(16)))
    from mathutils import Matrix
    rot=Matrix.Rotation(a,3,'Z')
    for v in ob.data.vertices:v.co=center+rot@(v.co-center)
block('Scope_Side_Turret_Base',199,42,23,23,.026,4,.0011,x=.036)
block('Scope_Side_Turret_Cap',199,42,17,18,.009,7,.0013,x=.052)

def join(name,group,pivot=(0,0,0)):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts[group]:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[group][0];bpy.ops.object.join()
    ob=bpy.context.object;ob.name=name;pivot=Vector(pivot)
    for v in ob.data.vertices:v.co-=pivot
    ob.parent=root;ob.location=pivot
    return ob
frame=join('Sniper_Sand_Frame','Frame')
mag=join('Sniper_Sand_Magazine','Magazine',P(214,110))
bolt=join('Sniper_Sand_Bolt','Bolt',P(181,80,.037))
lenses=join('Sniper_Scope_Lenses','Lenses');lenses['lens_count']=2
mag['role']='Separate static magazine';bolt['role']='Separate static bolt assembly; no animation authored'
markers={'RightHandGrip':(0,0,0),'RecoilPivot':(0,0,0),'HolsterAttach':(0,0,0),'Grip_Point':(0,0,0),
    'LeftHandGuide':P(370,101),'Support_Hand_Point':P(370,101),
    'Muzzle':P(638,79),'Muzzle_Point':P(638,79),'AimReference':P(345,42),
    'MagazineFeed':P(214,110),'BoltHandle':P(170,99,.057)}
for name,pos in markers.items():
    ob=bpy.data.objects.new(name,None);c.objects.link(ob);ob.parent=root;ob.location=pos
    ob.empty_display_type='ARROWS';ob.empty_display_size=.018;root[name]=list(pos)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for ob in c.all_objects:ob.select_set(True)
bpy.context.view_layer.objects.active=frame
bpy.ops.export_scene.gltf(filepath=str(OUT/'Sniper_Sand_Block_V1.glb'),export_format='GLB',
    use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
meshes=[frame,mag,bolt,lenses]
points=[ob.matrix_world@v.co for ob in meshes for v in ob.data.vertices]
report={'status':'Pending','meshes':4,'materials':3,'atlas_size':[256,256],'forward':'+Y',
    'reference':'reference.png','markers':markers,'topology':{},
    'dimensions_m':[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]}
for ob in meshes:
    ob.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(ob.data)
    info={'triangles':len(ob.data.loop_triangles),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
        'loose_vertices':sum(not v.link_faces for v in bm.verts)};bm.free()
    assert not info['nonmanifold_edges'] and not info['loose_vertices'],(ob.name,info)
    report['topology'][ob.name]=info
report['triangles']=sum(v['triangles'] for v in report['topology'].values())
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
s['review_status']='Pending';s['asset_report']=json.dumps(report)

studio=bpy.data.collections.new('SOURCE_REVIEW_STUDIO');s.collection.children.link(studio)
world=bpy.data.worlds.new('Sniper Graphite Studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.028,.033,.044,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35;s.world=world
fm=bpy.data.materials.new('Sniper Review Floor');fm.use_nodes=True
fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.003,.004,.006,1)
fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,min(p.z for p in points)-.002))
floor=bpy.context.object
for col in list(floor.users_collection):col.objects.unlink(floor)
studio.objects.link(floor);floor.name='Sniper_Review_Ground';floor.data.materials.append(fm)
focus=Vector(P(320,83))
for name,loc,power,size,color in [
    ('Sniper Key',(1.4,-.8,2.2),360,2.0,(1,.91,.79)),
    ('Sniper Fill',(1.3,1.9,.8),160,1.6,(.76,.85,1)),
    ('Sniper Rim',(-1.4,-.4,1.8),460,1.7,(1,.86,.69))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=color
    ob=bpy.data.objects.new(name,data);studio.objects.link(ob);ob.location=loc
    ob.rotation_euler=(focus-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Sniper_Review_Camera',bpy.data.cameras.new('Sniper_Review_Camera'))
studio.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=1.38
cam.location=focus+Vector((1.7,.62,.43))
cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True
s.render.threads_mode='FIXED';s.render.threads=8
s.render.resolution_x,s.render.resolution_y=1700,1050;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX'
bpy.ops.object.select_all(action='DESELECT');frame.select_set(True);bpy.context.view_layer.objects.active=frame
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
            sp.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            sp.region_3d.view_location=focus;sp.region_3d.view_distance=1.6;sp.region_3d.view_perspective='ORTHO'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print('SNIPER_SAVED',json.dumps(report),flush=True)
review=OUT/'review';review.mkdir(exist_ok=True)
if not args.no_render:
    for name,direction,ortho in [('three_quarter',(1.7,.62,.43),1.38),('side',(1.7,0,.008),1.38),
        ('opposite',(-1.7,0,.008),1.38),('top',(0,0,1.7),1.38),('front',(0,1.7,.01),.55)]:
        cam.location=focus+Vector(direction)
        cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
        if name=='top':cam.rotation_euler=(0,0,math.pi/2)
        floor.hide_render=name!='three_quarter'
        cam.data.ortho_scale=ortho;s.render.filepath=str(review/(name+'.png'));bpy.ops.render.render(write_still=True)
print('SNIPER_SAND_BLOCK_BUILT',flush=True)

