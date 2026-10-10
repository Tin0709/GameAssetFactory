"""Expose V003 beside every previous review; never replace V002 selections."""
import bpy,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
def integrate():
    m=json.loads((OUT/'manifest.json').read_text());lib=bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1']
    catalog=json.loads(lib['review_catalog']);ids={x['id'] for x in catalog}
    for kind,c in m['cases'].items():
        identity='jump_'+kind+'_loop_v003';assert identity not in ids
        catalog.append({'id':identity,'label':('Walk' if kind=='walk' else 'Run')+' + Jump LOOP V003',
            'group':'Jump (study only)','scene':c['scene'],'review_rig':c['rig'],'review_carrier':c['carrier'],'action':c['action'],
            'start':1,'end':c['preview_end'],'fps':30,'duration_seconds':c['preview_end']/30,
            'review_note':'Continuous footwork / Blender study',
            'phase_note':f"Loop {c['period']/30:.3f} s / 3 continuous cycles",
            'carrier_note':'No pause / Root travel = preview only',
            'status':'Loop pose/tangents checked; pending visual review and future runtime phase integration'})
    lib['review_catalog']=json.dumps(catalog)
    p=OUT.parent/'review_manifest.json';rm=json.loads(p.read_text(encoding='utf-8'))
    rm['catalog']=catalog;rm['catalog_entries']=len(catalog);rm['total_actions']=len(bpy.data.actions)
    rm['jump_loop_v003']={'manifest':'jump_loop_v003/manifest.json','preserved_previous_actions':len(m['previous_action_hashes']),'runtime_integrated':False}
    rm['default_review']='jump_run_loop_v003';p.write_text(json.dumps(rm,indent=2),encoding='utf-8')
    source=(OUT.parent/'review_controls.py').read_text(encoding='utf-8')
    txt=bpy.data.texts['START_HERE_review_controls.py'];txt.clear();txt.write(source)
    exec(compile(source,'review_controls.py','exec'),{'__name__':'player_review_controls'})
    lib.player_review_group='Jump (study only)';bpy.ops.player_review.select(clip_id='jump_run_loop_v003')
    return {'catalog':len(catalog),'actions':len(bpy.data.actions)}
if __name__=='__main__':result=integrate()
