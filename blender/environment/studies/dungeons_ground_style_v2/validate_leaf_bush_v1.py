"""Read-only exact dimensions, unit blocks, constant texel density and preservation."""
import bpy,json,sys,hashlib,struct
from pathlib import Path
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare

def audit_bush():
    obj=bpy.data.objects.get('ENV_LeafBush_3x3x2m_V1');assert obj,'Missing3×3×2m leaf bush (expected initial RED)'
    m=obj.data;m.calc_loop_triangles();lo=[min(v.co[k]for v in m.vertices)for k in range(3)];hi=[max(v.co[k]for v in m.vertices)for k in range(3)]
    assert lo==[-1.5,-1.5,0] and hi==[1.5,1.5,2]
    assert not obj.modifiers
    assert tuple(obj.scale)==(1,1,1) and tuple(obj.rotation_euler)==(0,0,0) and len(m.materials)==1
    mat=m.materials[0];image=bpy.data.images['IMG_LeafBush_V1_OriginalClusterAtlas'];assert image.packed_file and list(image.size)==[336,224]
    tex=[n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'];assert len(tex)==1 and tex[0].image==image and tex[0].interpolation=='Closest'
    assert not mat.use_backface_culling if hasattr(mat,'use_backface_culling')else True
    errors=[]
    cellids=set(m.attributes['block_index'].data[i].value for i in range(len(m.polygons)))
    cells={(i%3,(i//3)%3,i//9)for i in cellids}
    dirs=[(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]
    expected={(c,axis)for c in cells for axis,d in enumerate(dirs)if tuple(c[k]+d[k]for k in range(3))not in cells}
    actual={((i%3,(i//3)%3,i//9),m.attributes['face_axis'].data[p.index].value)for p in m.polygons for i in [m.attributes['block_index'].data[p.index].value]}
    assert actual==expected and len(m.polygons)==len(expected) and len(m.loop_triangles)==2*len(expected)
    assert all(abs((v.co[k]+(1.5 if k<2 else 0))-round(v.co[k]+(1.5 if k<2 else 0)))<1e-6 for v in m.vertices for k in range(3))
    for p in m.polygons:
        assert len(p.vertices)==4 and abs(p.area-1)<1e-6 and abs(p.normal.length-1)<1e-6
        points=[m.vertices[i].co for i in p.vertices]
        assert sum(abs(v)>1e-6 for v in p.normal)==1
        uvs=[m.uv_layers[0].data[li].uv for li in p.loop_indices]
        for i in range(4):
            a,b=uvs[i],uvs[(i+1)%4];pixels=((a.x-b.x)*336)**2+((a.y-b.y)*224)**2
            edge=(points[i]-points[(i+1)%4]).length
            assert abs(edge-1)<1e-6,'Every exposed unit-block face must have square1m edges'
            errors.append(abs(pixels**.5/edge-32));assert errors[-1]<2e-5
    baseline=json.loads((EVIDENCE/'before_leaf_bush_fingerprints.json').read_text());assert not compare(baseline['data']), 'All prior authored data must be preserved'
    return {'status':'PASS','bounds_blender':[lo,hi],'dimensions_m':[3,3,2],'occupied_unit_blocks':len(cells),'exterior_quads':len(m.polygons),'triangles':len(m.loop_triangles),'texels_per_m':32,'texel_density_max_error':max(errors),'atlas_size':[336,224],'texture_filter':'Closest','prior_data_preserved':True,'scope':'Blender-only study'}

def audit_export():
    report=audit_bush();path=HERE/'exports/leaf_bush_3x3x2m_v1.glb';raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+length]);binary=raw[28+length:]
    assert len(g['meshes'])==len(g['nodes'])==len(g['materials'])==len(g['images'])==1 and len(g['meshes'][0]['primitives'])==1
    assert not any(k in g for k in ('skins','animations','cameras')) and not g.get('extensions',{}).get('KHR_lights_punctual')
    node=g['nodes'][0];assert node.get('translation',[0,0,0])==[0,0,0] and node.get('scale',[1,1,1])==[1,1,1]
    sampler=g['samplers'][0];assert sampler['magFilter']==9728 and sampler['minFilter'] in (9728,9984)
    assert g['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
    p=g['meshes'][0]['primitives'][0];assert g['accessors'][p['indices']]['count']==report['triangles']*3
    def accessor(index):
        a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];fmt={5126:'f',5123:'H',5125:'I'}[a['componentType']];n={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']];size=struct.calcsize('<'+fmt*n);start=view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*n,binary,start+i*view.get('byteStride',size))for i in range(a['count'])]
    positions=accessor(p['attributes']['POSITION']);uvs=accessor(p['attributes']['TEXCOORD_0']);m=bpy.data.objects['ENV_LeafBush_3x3x2m_V1'].data
    expected=[]
    for li in m.loops:
        v=m.vertices[li.vertex_index].co;uv=m.uv_layers[0].data[li.index].uv;expected.append(((v.x,v.z,-v.y),(uv.x,1-uv.y)))
    assert all(any(max(abs(a-b)for a,b in zip(v,e[0]))<1e-6 and max(abs(a-b)for a,b in zip(uv,e[1]))<1e-6 for e in expected)for v,uv in zip(positions,uvs))
    manifest=json.loads((HERE/'leaf_bush_v1_manifest.json').read_text());sha=hashlib.sha256(raw).hexdigest();assert sha==manifest['sha256']
    report.update({'glb_sha256':sha,'one_surface':True,'embedded_original_leaf_texture':True,'source_binary_position_uv_agreement':True,'nearest_sampler':sampler})
    return report

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
    report=audit_export();(EVIDENCE/'validation_leaf_bush_source.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
