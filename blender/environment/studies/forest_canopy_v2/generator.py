"""Original Forest Canopy V2 authoring/export study. Blender 5.2 background.

Run from repository root:
  blender --background --factory-startup --python blender/environment/studies/forest_canopy_v2/generator.py

Authored voxel silhouettes and vertex-color rectangles; no third-party geometry,
textures, or copied game assets. Source stays editable and the review studio is
excluded from all exports. Blender Z-up -> glTF Y-up happens only at export.
"""
import bpy
import json
import math
import os
import struct
from collections import defaultdict
from mathutils import Vector
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUT = ROOT / 'game_mobile_3d/assets/environment/forest_canopy_v2'
OUT.mkdir(parents=True, exist_ok=True)

LEAVES = ['#466e32', '#58853b', '#709446', '#638b40', '#3d612e', '#7b9b50']
BARK = ['#655034', '#78603c', '#8a7047', '#58432e', '#977a4b']
FERN = ['#5d813a', '#729445', '#839f50', '#496f33', '#678841', '#8fa659']


def rgb(h):
    return tuple(int(h[n:n+2], 16)/255.0 for n in (1, 3, 5)) + (1.0,)


def srgb_linear(v):
    return v / 12.92 if v <= .04045 else ((v + .055)/1.055)**2.4


def material(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value = .96
    p.inputs['Metallic'].default_value = 0
    p.inputs['Specular IOR Level'].default_value = .15
    c = m.node_tree.nodes.new('ShaderNodeVertexColor')
    c.layer_name = 'Color'
    m.node_tree.links.new(c.outputs['Color'], p.inputs['Base Color'])
    return m


class Geometry:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.colors = []

    def face(self, points, color):
        n = len(self.verts)
        self.verts.extend(points)
        self.faces.append(tuple(range(n, n+len(points))))
        self.colors.append(color)

    def mesh(self, name, collection, mat, palette):
        mesh = bpy.data.meshes.new(name + '_EditableMesh')
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        c = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
        for face, ci in zip(mesh.polygons, self.colors):
            for li in face.loop_indices:
                c.data[li].color_srgb = rgb(palette[ci % len(palette)])
            face.use_smooth = False
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        mesh.materials.append(mat)
        obj['authoring_status'] = 'ORIGINAL STUDY - AWAITING HUMAN ART REVIEW'
        obj['units'] = 'metres; bottom-centre origin; Blender Z-up'
        return obj


def stable_hash(a, b, c, seed):
    # Spatially grouped deterministic rectangles, not per-leaf random noise.
    return ((a*73856093) ^ (b*19349663) ^ (c*83492791) ^ (seed*2654435761)) & 0xffffffff


def leaf_color(i, j, k, direction, seed):
    # Broad clusters: 2-4 voxels wide. Side patterns also use long vertical runs.
    normal_axis, sign = direction
    if normal_axis == 2:
        value = stable_hash((i+1)//3, (j-1)//2, k//3, seed) % 11
        if sign == -1:
            return 4 if value < 8 else 0
        return 1 if value < 3 else (2 if value < 7 else (3 if value < 10 else 5))
    value = stable_hash(i//3, j//3, k//2, seed) % 12
    return 0 if value < 4 else (1 if value < 8 else (3 if value < 11 else 2))


def voxel_mesh(cells, cell, origin, seed, color_fn=leaf_color):
    """Cull shared voxel faces and merge same-color coplanar rectangles."""
    faces_by_plane = defaultdict(dict)
    for coord in cells:
        for axis in range(3):
            u, v = (axis+1) % 3, (axis+2) % 3
            for sign in (-1, 1):
                neighbor = list(coord)
                neighbor[axis] += sign
                if tuple(neighbor) in cells:
                    continue
                plane = coord[axis] + (1 if sign == 1 else 0)
                color = color_fn(*coord, (axis, sign), seed)
                faces_by_plane[(axis, sign, plane)][(coord[u], coord[v])] = color
    g = Geometry()
    raw_faces = sum(len(x) for x in faces_by_plane.values())
    for (axis, sign, plane), positions in sorted(faces_by_plane.items()):
        u, v = (axis+1) % 3, (axis+2) % 3
        while positions:
            a, b = min(positions)
            color = positions[(a, b)]
            width = 1
            while positions.get((a+width, b), -1) == color:
                width += 1
            height = 1
            while all(positions.get((a+x, b+height), -1) == color for x in range(width)):
                height += 1
            corners = [(a, b), (a+width, b), (a+width, b+height), (a, b+height)]
            points = []
            for cu, cv in corners:
                point = [0, 0, 0]
                point[axis], point[u], point[v] = plane, cu, cv
                points.append(tuple(origin[q] + point[q]*cell[q] for q in range(3)))
            if sign == -1:
                points.reverse()
            g.face(points, color)
            for x in range(width):
                for y in range(height):
                    del positions[(a+x, b+y)]
    return g, raw_faces


def occupancy(lobes, cell, zmin=0, holes=()):
    # Lp ellipsoids retain broad rectilinear faces without uniform piled boxes.
    mins = [min(p[q]-p[3+q] for p in lobes) for q in range(3)]
    maxs = [max(p[q]+p[3+q] for p in lobes) for q in range(3)]
    ranges = [range(math.floor(mins[q]/cell[q]), math.ceil(maxs[q]/cell[q])) for q in range(3)]
    cells = set()
    for i in ranges[0]:
        for j in ranges[1]:
            for k in ranges[2]:
                point = ((i+.5)*cell[0], (j+.5)*cell[1], (k+.5)*cell[2])
                if point[2] < zmin:
                    continue
                if not any(sum(abs((point[q]-p[q])/p[q+3])**p[6] for q in range(3)) < 1 for p in lobes):
                    continue
                if any(sum(((point[q]-h[q])/h[q+3])**2 for q in range(3)) < 1 for h in holes):
                    continue
                cells.add((i,j,k))
    return cells


def segment(g, start, end, w0, w1, palette_offset=0, splits=1):
    """Squared branch with broad bark panels, deliberately flat normals."""
    start, end = Vector(start), Vector(end)
    d = (end-start).normalized()
    u = d.cross(Vector((0,1,0))).normalized()
    if u.length < .01:
        u = d.cross(Vector((1,0,0))).normalized()
    v = d.cross(u).normalized()
    # Square with clipped corners: gives root/trunk transition some extra planes.
    xy = [(-1,-.68),(-.68,-1),(.68,-1),(1,-.68),(1,.68),(.68,1),(-.68,1),(-1,.68)]
    rings = []
    for n in range(splits+1):
        t = n/splits
        c, w = start.lerp(end,t), .5*(w0*(1-t)+w1*t)
        rings.append([tuple(c + u*x*w + v*y*w) for x,y in xy])
    for n in range(splits):
        for q in range(8):
            r = (q+1)%8
            color = [0,3,0,1,2,1,0,3][q]
            if (q + 2*n + palette_offset) % 7 == 0:
                color = 4
            g.face([rings[n][q],rings[n][r],rings[n+1][r],rings[n+1][q]], color)
    g.face(list(reversed(rings[0])),3)
    g.face(rings[-1],1)


def trunk_mesh(variant):
    g = Geometry()
    if variant == 'a':
        spine = [(0,0,0),(.04,.02,.55),(-.035,.025,1.25),(.10,0,2.05),(.16,.02,2.75),(.24,.10,3.72)]
        widths = [.60,.48,.41,.35,.24,.15]
        branches = [
            ((.06,0,1.73),(-.47,.03,2.38),.30,.22),
            ((-.47,.03,2.38),(-1.17,.02,3.12),.22,.12),
            ((.11,0,2.12),(.65,-.14,2.63),.27,.20),
            ((.65,-.14,2.63),(1.34,-.26,3.45),.20,.11),
            ((.02,.02,1.95),(-.17,.65,2.57),.24,.18),
            ((-.17,.65,2.57),(-.40,1.15,3.28),.18,.11),
            ((.17,.02,2.68),(.36,-.62,3.17),.20,.12)]
    else:
        spine = [(0,0,0),(-.04,0,.50),(.05,.015,1.2),(.14,.03,1.93),(.27,.08,2.6),(.34,.16,3.45)]
        widths = [.56,.45,.39,.31,.22,.12]
        branches = [
            ((.10,.02,1.60),(-.39,.08,2.10),.30,.25),
            ((-.39,.08,2.1),(-.96,.12,2.81),.25,.12),
            ((.14,.03,1.95),(.61,-.25,2.48),.25,.19),
            ((.61,-.25,2.48),(1.18,-.49,3.03),.19,.11),
            ((.05,.015,1.55),(-.18,.46,2.12),.23,.18),
            ((-.18,.46,2.12),(-.1,1.0,2.9),.18,.10),
            ((.20,.04,2.3),(.39,-.66,2.94),.20,.12)]
    for n in range(len(spine)-1):
        segment(g, spine[n], spine[n+1], widths[n], widths[n+1], n, splits=2)
    for a,b,w0,w1 in branches:
        segment(g,a,b,w0,w1,2,2)
    # Buttress roots set below grade then clipped to an exact bottom of zero.
    roots = [(0.86,.08),(-.73,-.17),(.27,-.78),(-.16,.70),(-.58,.52)]
    for n,(x,y) in enumerate(roots):
        segment(g, (x*.12,y*.12,.24),(x,y,.055), .27,.10,n,1)
    g.verts = [(x,y,max(0,z)) for x,y,z in g.verts]
    return g


def trees(asset_collection, mats):
    specs = {
        'tree_oak_a': [
            (.12,.08,3.74,1.13,1.02,.82,2.7),
            (.25,.20,4.37,.83,.79,.43,2.4),
            (-.99,.02,3.30,.85,.83,.57,2.5),
            (1.10,-.14,3.64,.80,.76,.58,2.5),
            (-.28,1.04,3.38,.87,.72,.58,2.5),
            (.22,-.97,3.18,.93,.64,.60,2.4),
            (-1.23,-.72,2.80,.53,.54,.43,2.2),
            (1.32,.60,3.08,.52,.52,.42,2.2),
            (-.60,1.23,2.78,.56,.50,.46,2.3),
            (.98,-.97,2.66,.48,.41,.42,2.2),
            (-.79,-.05,4.13,.57,.55,.41,2.4),
        ],
        'tree_oak_b': [
            (.29,.08,3.28,1.13,1.03,.62,2.8),
            (.52,.18,3.91,.81,.73,.40,2.4),
            (-.88,.07,2.93,.88,.83,.62,2.5),
            (1.03,-.46,2.96,.77,.70,.55,2.5),
            (-.13,.94,3.03,.85,.65,.59,2.4),
            (-.29,-.82,2.85,.81,.65,.49,2.5),
            (-1.21,-.52,2.38,.49,.49,.40,2.2),
            (1.33,.44,2.48,.43,.50,.37,2.4),
            (.37,1.24,2.45,.49,.44,.38,2.3),
            (-.59,.34,3.69,.59,.62,.44,2.4),
        ],
    }
    result = {}
    for name, lobes in specs.items():
        collection = bpy.data.collections.new(name)
        asset_collection.children.link(collection)
        variant = name[-1]
        cell = (.225,.225,.225)
        holes = [(-.54,-.91,3.18,.30,.27,.23), (.72,.83,3.15,.28,.28,.29)] if variant == 'a' else [(-.46,-.8,3.01,.28,.26,.22)]
        cells = occupancy(lobes,cell,2.10,holes)
        leaf_geometry, raw_faces = voxel_mesh(cells,cell,(0,0,0),5 if variant=='a' else 9)
        bark = trunk_mesh(variant).mesh('Bark', collection, mats['bark'],BARK)
        leaf = leaf_geometry.mesh('Leaves',collection,mats['leaf'],LEAVES)
        for o in (bark,leaf):
            o['asset_id'] = name
        result[name] = {'objects':[bark,leaf], 'voxel_size_m':cell, 'filled_leaf_voxels':len(cells),
                        'leaf_exposed_quads_before_merge':raw_faces,'leaf_quads_after_merge':len(leaf_geometry.faces)}
    return result


def leaf_strip(g, origin, angle, length, peak, width, color):
    """A broad stepped frond with squared leaflets and a folded thick blade."""
    origin = Vector(origin)
    forward = Vector((math.cos(angle),math.sin(angle),0))
    side = Vector((-math.sin(angle),math.cos(angle),0))
    # Squared plan silhouette, one uninterrupted top with a chunky lower rim.
    shape = [(0,-.28),(.16,-.28),(.16,-.65),(.38,-.65),(.38,-1),(.61,-1),
             (.61,-.78),(.83,-.78),(.83,-.36),(1,-.36),(1,.36),(.83,.36),
             (.83,.78),(.61,.78),(.61,1),(.38,1),(.38,.65),(.16,.65),(.16,.28),(0,.28)]
    # Two slabs plus broad square tips. Profile peaks near halfway.
    # Each strip is a closed extruded polygon, triangulated by glTF exporter.
    points=[]
    for t,w in shape:
        z = peak*(math.sin(t*math.pi*.72)) + .035
        point = origin + forward*(length*t)+side*(width*.5*w)+Vector((0,0,z))
        points.append(tuple(point))
    lower=[(x,y,z-.032) for x,y,z in points]
    # Top uses a central ridge and a fan across the contour, avoiding n-gon issues.
    center = origin + forward*length*.49 + Vector((0,0,peak*.99+.055))
    for n in range(len(points)):
        q=(n+1)%len(points)
        g.face([tuple(center),points[n],points[q]], color if n%5 else (color+1)%3)
        g.face([points[n],lower[n],lower[q],points[q]],3)
    g.face(list(reversed(lower)),3)


def shrubs(asset_collection,mats):
    result={}
    col=bpy.data.collections.new('shrub_fern')
    asset_collection.children.link(col)
    g=Geometry()
    for n in range(6):
        angle=n*math.tau/6+.13
        length=[.59,.67,.50,.61,.69,.53,.63][n]
        leaf_strip(g,(0,0,.005),angle,length,[.37,.44,.49,.36,.46,.48,.39][n],.31, n%3)
    for n in range(2):
        leaf_strip(g,(.015,-.02,.10),n*math.pi+.4,.36,.65,.26,1)
    # Soil contact block stem just .12 m wide, unobtrusive under leaf overlaps.
    stem_cells={(0,0,0),(0,0,1)}
    stem_g,_=voxel_mesh(stem_cells,(.12,.12,.08),(-.06,-.06,0),1)
    for p,c in zip(stem_g.faces,stem_g.colors):
        g.face([stem_g.verts[k] for k in p],3)
    obj=g.mesh('Leaves',col,mats['fern'],FERN)
    result['shrub_fern']={'objects':[obj]}
    col=bpy.data.collections.new('shrub_leaf')
    asset_collection.children.link(col)
    lobes=[(-.22,.02,.38,.32,.36,.28,2.5),(.17,.17,.53,.35,.31,.30,2.3),
           (.35,-.20,.31,.29,.28,.23,2.5),(-.18,-.30,.27,.29,.26,.22,2.4),
           (-.14,.34,.27,.30,.28,.21,2.5),(.01,.02,.69,.26,.26,.21,2.3)]
    cell=(.14,.14,.14)
    cells=occupancy(lobes,cell)
    # Bottom stem/lower leaf so root origin really touches ground.
    cells.update({(0,0,0),(0,0,1),(-1,0,0)})
    geo,raw=voxel_mesh(cells,cell,(0,0,0),16)
    obj=geo.mesh('Leaves',col,mats['leaf'],LEAVES)
    result['shrub_leaf']={'objects':[obj],'voxel_size_m':cell,'filled_leaf_voxels':len(cells),
                          'leaf_exposed_quads_before_merge':raw,'leaf_quads_after_merge':len(geo.faces)}
    for name,data in result.items():
        for o in data['objects']:o['asset_id']=name
    return result


def export_all(assets):
    manifest={'version':2,'authoring_status':'ORIGINAL STUDY - NOT USER APPROVED',
              'reference_use':'Original broadleaf forest interpretation; no copied game assets or textures.',
              'source':'forest_canopy_v2.blend','unit':'metres','origin':'bottom centre of trunk / rooted shrub',
              'color_pipeline':'Palette values are sRGB; Blender Color.color_srgb writes linear float Color; glTF COLOR_0 stores linear albedo. Material multiplies white baseColor by vertex color.',
              'rendering':'Opaque, single-sided, flat-normal vertex-colored meshes. No textures; no transparent cards.',
              'assets':{}}
    for name, data in assets.items():
        bpy.ops.object.select_all(action='DESELECT')
        # Exact runtime names are assigned one asset at a time; restore authoring IDs after.
        oldnames=[]
        for n,obj in enumerate(data['objects']):
            oldnames.append(obj.name)
            obj.name=('Bark' if len(data['objects'])==2 and n==0 else 'Leaves')
            obj.select_set(True)
        bpy.context.view_layer.objects.active=data['objects'][0]
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,
                                  export_apply=True,export_yup=True,export_normals=True,
                                  export_materials='EXPORT',export_animations=False,
                                  export_cameras=False,export_lights=False,export_attributes=False)
        vertices=[v.co[:] for o in data['objects'] for v in o.data.vertices]
        low=[min(v[q] for v in vertices) for q in range(3)]
        high=[max(v[q] for v in vertices) for q in range(3)]
        tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in data['objects'])
        entry={k:v for k,v in data.items() if k!='objects'}
        entry.update({'file':name+'.glb','triangle_count':tris,
                      'bounds_blender_min':low,'bounds_blender_max':high,
                      'dimensions_m':[high[q]-low[q] for q in range(3)],
                      'meshes':[{'name':o.name,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),
                                 'materials':[m.name for m in o.data.materials],
                                 'color_attribute':'Color','flat_normals':True} for o in data['objects']]})
        manifest['assets'][name]=entry
        for obj,old in zip(data['objects'],oldnames):obj.name=name+'__'+('Bark' if 'Bark' in old else 'Leaves')
    return manifest


def plain_mat(name,color):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=tuple(srgb_linear(x) for x in color)+(1,)
    p.inputs['Roughness'].default_value=.9
    return m


def look_at(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def studio(assets):
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1400
    scene.render.resolution_y=900
    scene.render.resolution_percentage=100
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='None'
    scene.view_settings.exposure=0
    scene.view_settings.gamma=1
    scene.world.color=(.22,.25,.28)
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value=(.45,.56,.65,1)
    bg.inputs['Strength'].default_value=.50
    # Collection offset preserves mesh-local geometry and export origins.
    offsets={'tree_oak_a':(-2.65,.3,0),'tree_oak_b':(2.0,.0,0),
             'shrub_fern':(-1.55,-2.80,0),'shrub_leaf':(.65,-2.70,0)}
    for name,data in assets.items():
        for obj in data['objects']:obj.location=offsets[name]
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015))
    plane=bpy.context.object
    plane.name='STUDIO_Ground_ExcludedFromExport'
    plane.data.materials.append(plain_mat('STUDIO_Backdrop',(.20,.24,.22)))
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,9))
    key=bpy.context.object
    key.name='STUDIO_WarmKey'
    key.data.energy=1350
    key.data.shape='DISK'
    key.data.size=5.0
    key.data.color=(1.0,.91,.75)
    look_at(key,(0,0,1.8))
    bpy.ops.object.light_add(type='AREA',location=(4,2,6))
    fill=bpy.context.object
    fill.name='STUDIO_CoolRim'
    fill.data.energy=950
    fill.data.size=5
    fill.data.color=(.68,.81,1.0)
    look_at(fill,(0,0,2))
    bpy.ops.object.camera_add(location=(8,-13,10))
    camera=bpy.context.object
    camera.name='DIAGNOSTIC_ElevatedGameplayAngle'
    look_at(camera,(0,0,2.05))
    camera.data.type='ORTHO'
    camera.data.ortho_scale=11.4
    scene.camera=camera
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(HERE/'diagnostic_contact_sheet.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'forest_canopy_v2.blend'))
    bpy.ops.render.render(write_still=True)


def audit_glb(path):
    raw=path.read_bytes()
    magic,version,total=struct.unpack_from('<III',raw,0)
    assert magic==0x46546c67 and version==2 and total==len(raw)
    json_len,json_type=struct.unpack_from('<II',raw,12)
    doc=json.loads(raw[20:20+json_len])
    accessors=doc['accessors']
    names=[n.get('name','') for n in doc.get('nodes',[]) if 'mesh' in n]
    prims=[p for m in doc['meshes'] for p in m['primitives']]
    assert all('COLOR_0' in p['attributes'] and 'NORMAL' in p['attributes'] for p in prims)
    assert all(m.get('alphaMode','OPAQUE')=='OPAQUE' and not m.get('doubleSided',False) for m in doc['materials'])
    assert len(doc.get('images',[]))==0
    tris=sum(accessors[p['indices']]['count']//3 for p in prims)
    bounds=[accessors[p['attributes']['POSITION']] for p in prims]
    mins=[min(x['min'][q] for x in bounds) for q in range(3)]
    maxs=[max(x['max'][q] for x in bounds) for q in range(3)]
    assert abs(mins[1]) < .0001, (path.name,mins)
    assert tris < (3500 if path.stem.startswith('tree') else 700),(path.name,tris)
    assert len(prims)==(2 if path.stem.startswith('tree') else 1)
    assert len(set(names))==len(names)
    return {'file':path.name,'bytes':len(raw),'triangles':tris,'mesh_names':names,
            'primitive_count':len(prims),'material_count':len(doc['materials']),
            'bounds_gltf_min':mins,'bounds_gltf_max':maxs,'COLOR_0':True,
            'all_opaque_single_sided':True,'textures':0,'validation':'PASS'}


def main():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.name='Original_Forest_Canopy_V2_Study'
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.context.scene.unit_settings.scale_length=1
    col=bpy.data.collections.new('ORIGINAL_ASSETS_NotUserApproved')
    bpy.context.scene.collection.children.link(col)
    mats={'leaf':material('Forest_Leaf_VertexColor'), 'bark':material('Forest_Bark_VertexColor'),
          'fern':material('Forest_Fern_VertexColor')}
    assets=trees(col,mats)
    assets.update(shrubs(col,mats))
    manifest=export_all(assets)
    manifest['validation']=[audit_glb(OUT/(name+'.glb')) for name in assets]
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('FOREST_EXPORT_AUDIT '+json.dumps(manifest['validation']))
    studio(assets)
    print('FOREST_V2_COMPLETE')


if __name__=='__main__':
    main()
