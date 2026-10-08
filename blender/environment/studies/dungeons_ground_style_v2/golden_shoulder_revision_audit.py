"""Current shoulder-height bush + ordered dense seed head audit; source/read-only export."""
import bpy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Vector,Quaternion

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
EVIDENCE=ROOT/'.validation/flower_patch_v1'
sys.path.insert(0,str(HERE))
from flower_preservation import compare,rna_values,mesh_content,digest

def audit_shoulder_source():
    if (HERE/'golden_connected_head_revision_v1.json').exists():
        from golden_connected_head_audit import audit_connected_source
        return audit_connected_source()
    assert (HERE/'golden_shoulder_revision_v1.json').exists(), 'Missing current shoulder-height bush / dense ordered seed heads (expected initial RED)'
    spec=json.loads((HERE/'golden_shoulder_revision_v1.json').read_text())
    baseline=json.loads((EVIDENCE/'before_shoulder_dense_golden_grass_fingerprints.json').read_text())
    obj=bpy.data.objects['ENV_TallGoldenGrass_1m_V1'];mesh=obj.data
    assert not obj.modifiers and not mesh.shape_keys and len(mesh.materials)==1
    assert tuple(obj.scale)==(1,1,1) and tuple(obj.rotation_euler)==(0,0,0)
    mesh.calc_loop_triangles()
    assert len(mesh.vertices)==1344 and len(mesh.polygons)==336 and len(mesh.loop_triangles)==672
    assert len(mesh.uv_layers)==2 and mesh.uv_layers[0].name=='UV_Stem_Height' and mesh.uv_layers[1].name=='UV_Stem_Root'
    before=baseline['gold_mesh'];after=json.loads(json.dumps(mesh_content(mesh)))
    assert before['materials']==after['materials'] and not mesh.materials[0].use_backface_culling
    lo=[min(v.co[k]for v in mesh.vertices)for k in range(3)]
    hi=[max(v.co[k]for v in mesh.vertices)for k in range(3)]
    assert lo[2]==0 and abs(hi[2]-spec['measured_player_shoulder_m'])<2e-6
    assert all(-.65<=lo[k]<hi[k]<=.65 and hi[k]-lo[k]<=1.3 for k in(0,1))
    actual_heights=[];root_count=0;palettes=[]
    for stem in spec['stems']:
        fid=stem['stem'];h=stem['head_base_height_m'];actual_heights.append(h)
        polys=[p for p in mesh.polygons if mesh.attributes['stem_index'].data[p.index].value==fid]
        green=[p for p in polys if mesh.attributes['part'].data[p.index].value==0]
        gold=[p for p in polys if mesh.attributes['part'].data[p.index].value==1]
        assert len(green)==3 and len(gold)==9
        root=Vector(stem['root_xyz']);u=Vector(stem['blade_width_direction_xyz']);fan=Vector(stem['fan_xyz']);pivot=Vector(stem['head_pivot_xyz'])
        rotation=Quaternion(Vector(stem['head_tilt_axis_xyz']),stem['head_tilt_radians'])
        for ring,p in enumerate(green):
            old_face_index=fid*7+ring
            for corner,li in enumerate(p.loop_indices):
                old_li=old_face_index*4+corner;vi=mesh.loops[li].vertex_index;point=mesh.vertices[vi].co
                uv,rootuv=mesh.uv_layers[0].data[li].uv,mesh.uv_layers[1].data[li].uv
                assert uv.x==before['uv']['UV_Stem_Height'][old_li][0] and abs(uv.y-h)<1e-6
                assert list(rootuv)==before['uv']['UV_Stem_Root'][old_li]
                assert list(mesh.color_attributes['Color'].data[li].color)==before['colors']['Color']['values'][old_li]
                assert abs(point.z-uv.x*h)<1e-6
                if uv.x==0:
                    old_vi=before['faces'][old_face_index][0][corner]
                    assert list(point)==before['vertices'][old_vi] and -.5<=point.x<=.5 and -.5<=point.y<=.5
                    root_count+=1
            width=(mesh.vertices[p.vertices[1]].co-mesh.vertices[p.vertices[0]].co).length
            assert abs(width-stem['blade_width_m'])<1e-6
        assert .65*spec['measured_player_shoulder_m']<=stem['seed_tip_height_m']<=spec['measured_player_shoulder_m']+1e-6
        for p in polys:
            points=[mesh.vertices[vi].co for vi in p.vertices]
            assert len(points)==4 and p.area>1e-7 and max(abs((pt-points[0]).dot(p.normal))for pt in points)<1e-6
            if p in gold:
                for li in p.loop_indices:
                    uv,rootuv=mesh.uv_layers[0].data[li].uv,mesh.uv_layers[1].data[li].uv
                    assert uv.x==1 and abs(uv.y-h)<1e-6
                    assert list(rootuv)==before['uv']['UV_Stem_Root'][(fid*7+3)*4]
                    assert list(mesh.color_attributes['Color'].data[li].color)==before['colors']['Color']['values'][(fid*7+3)*4]
        # Undo the shared head tilt to inspect the orderly mirrored tier geometry.
        for tier in range(4):
            left=gold[1+tier*2];right=gold[2+tier*2]
            local=[rotation.inverted()@(mesh.vertices[vi].co-pivot)for p in(left,right)for vi in p.vertices]
            left_outer=(local[1]+local[2])*.5;right_outer=(local[5]+local[6])*.5
            assert abs(left_outer.dot(u)+right_outer.dot(u))<1e-6 and abs(left_outer.z-right_outer.z)<1e-6
            assert abs((local[1]-local[0]).length-stem['tier_lengths_m'][tier])<1e-6
        assert all(a>b for a,b in zip(stem['tier_lengths_m'],stem['tier_lengths_m'][1:]))
        assert len(set(round(x,5)for x in stem['tier_base_heights_m']))==4
        assert all(abs((b-a)-.035)<1e-6 for a,b in zip(stem['tier_base_heights_m'],stem['tier_base_heights_m'][1:]))
    assert root_count==56 and max(actual_heights)-min(actual_heights)>.20
    changes=compare(baseline['data'])
    allowed={('objects',obj.name),('meshes',mesh.name),('objects','REVIEW_TallGolden_Actual_Height_Label')}
    assert set(changes)==allowed, 'Only authorized gold geometry/UV-height/topology and its display label may change: '+str(changes)
    fields=rna_values(obj)
    for derived in('bound_box','dimensions'):fields.pop(derived,None)
    authored={'fields':fields,'data':obj.data.name,'collections':sorted(c.name for c in obj.users_collection),'parent':obj.parent.name if obj.parent else None,
              'props':dict(obj.items()),'modifiers':[(m.name,m.type,rna_values(m))for m in obj.modifiers]}
    authored=json.loads(json.dumps(authored,default=lambda x:list(x)if hasattr(x,'__iter__')else str(x)))
    old_authored=baseline['gold_object_authored_fields']
    for key,current in [('authoring_status',spec['current_authoring_status']),('wind_contract',spec['current_wind_contract'])]:
        assert authored['props'][key]==current
        authored['props'][key]=old_authored['props'][key]
    assert authored==old_authored, 'Transforms/flags/parent/modifiers unchanged; only accurate source status/wind metadata updated'
    assert bpy.data.objects['REVIEW_TallGolden_Actual_Height_Label'].data.body==spec['current_display_label']
    white_hash=hashlib.sha256((HERE/'exports/white_flower_patch_1m_v1.glb').read_bytes()).hexdigest()
    assert white_hash==baseline['white_glb_sha256']
    measurement=json.loads((EVIDENCE/'player_shoulder_measurement.json').read_text())
    assert abs(measurement['shoulder_top_height_m']-spec['measured_player_shoulder_m'])<1e-8
    assert hashlib.sha256((ROOT/'game_mobile_3d/assets/characters/r15/player_r15_combat_strafe_v1.glb').read_bytes()).hexdigest()==measurement['source_sha256']
    return {'status':'PASS','current_user_request':'Golden bush seed tips at player shoulder; outside shorter/fanned; dense mirrored4pairedtiers',
            'triangles':672,'quads':336,'vertices':1344,'stems':28,'seed_quads_per_stem':9,'green_quads_per_stem':3,
            'bounds_blender':[lo,hi],'player_shoulder_m':spec['measured_player_shoulder_m'],'player_stature_m':1.8,
            'seed_head_base_height_range_m':[min(actual_heights),max(actual_heights)],'root_reserve_m':[1,1],
            'upper_canopy_span_xy_m':[hi[0]-lo[0],hi[1]-lo[1]],'unchanged':'56root vertices, green UV.x/UV2/albedo, golden palette, material; revised white mesh/export; all other original objects',
            'authorized_changes':changes,'prior_fingerprint':digest(baseline['data']),'white_export_preserved_sha256':white_hash,
            'export_scope':'Blender study only; not integrated into game'}

def audit_shoulder_export():
    report=audit_shoulder_source();mesh=bpy.data.objects['ENV_TallGoldenGrass_1m_V1'].data
    path=HERE/'exports/tall_golden_grass_1m_v1.glb';raw=path.read_bytes();jlen=struct.unpack_from('<I',raw,12)[0]
    g=json.loads(raw[20:20+jlen]);binary=raw[20+jlen+8:]
    assert len(g['nodes'])==len(g['meshes'])==len(g['materials'])==1 and len(g['meshes'][0]['primitives'])==1
    assert not any(k in g for k in('animations','skins','cameras','images','textures'))
    assert not g.get('extensions',{}).get('KHR_lights_punctual')
    node=g['nodes'][0];assert node.get('translation',[0,0,0])==[0,0,0] and node.get('scale',[1,1,1])==[1,1,1] and node.get('rotation',[0,0,0,1])==[0,0,0,1]
    assert g['materials'][0]['doubleSided'] and g['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
    prim=g['meshes'][0]['primitives'][0];assert prim.get('mode',4)==4 and not prim.get('targets')
    def accessor(index):
        a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];fmt={5126:'f',5123:'H',5125:'I',5121:'B'}[a['componentType']];w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        size=struct.calcsize('<'+fmt*w);start=v.get('byteOffset',0)+a.get('byteOffset',0)
        rows=[struct.unpack_from('<'+fmt*w,binary,start+i*v.get('byteStride',size))for i in range(a['count'])]
        if a.get('normalized'):rows=[tuple(x/{5121:255,5123:65535}[a['componentType']]for x in row)for row in rows]
        return rows
    attrs={k:accessor(a)for k,a in prim['attributes'].items()};assert {'POSITION','NORMAL','COLOR_0','TEXCOORD_0','TEXCOORD_1'}<=set(attrs)
    assert len(accessor(prim['indices']))//3==report['triangles']
    expected=[]
    for p in mesh.polygons:
        for li in p.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co;c=mesh.color_attributes['Color'].data[li].color
            uv,root,normal=mesh.uv_layers[0].data[li].uv,mesh.uv_layers[1].data[li].uv,mesh.corner_normals[li].vector
            expected.append(((v.x,v.z,-v.y),tuple(c),(uv.x,1-uv.y),(root.x,1-root.y),(normal.x,normal.z,-normal.y)))
    max_errors=[0]*5
    for i,point in enumerate(attrs['POSITION']):
        candidates=[x for x in expected if max(abs(a-b)for a,b in zip(point,x[0]))<1e-6];assert candidates
        got=(point,attrs['COLOR_0'][i],attrs['TEXCOORD_0'][i],attrs['TEXCOORD_1'][i],attrs['NORMAL'][i])
        best=min(candidates,key=lambda x:max(abs(a-b)for ga,ex in zip(got,x)for a,b in zip(ga,ex)))
        errors=[max(abs(a-b)for a,b in zip(ga,ex))for ga,ex in zip(got,best)]
        assert errors[0]<1e-6 and errors[1]<=1/65535+1e-7 and errors[2]<1e-6 and errors[3]<1e-6 and errors[4]<1.5e-4
        assert abs(Vector(attrs['NORMAL'][i]).length-1)<1e-5
        max_errors=[max(a,b)for a,b in zip(max_errors,errors)]
    assert min(uv[1]for uv in attrs['TEXCOORD_0'])<0<max(uv[1]for uv in attrs['TEXCOORD_0']), 'Both positive and negative head-height UV data survive'
    manifest=json.loads((HERE/'tall_golden_grass_v1_manifest.json').read_text());sha=hashlib.sha256(raw).hexdigest();assert manifest['glb_sha256']==sha
    report.update({'glb_sha256':sha,'source_corner_export_max_errors_position_color_uv0_uv2_normal':max_errors,'height_metadata_signs':'Positive and negative UV.y preserved, height=1-UV.y','glb_vertex_count':len(attrs['POSITION'])})
    return report

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
    report=audit_shoulder_export();(EVIDENCE/'validation_golden_shoulder_dense_source_glb.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
