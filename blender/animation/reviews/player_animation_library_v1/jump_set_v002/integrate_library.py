"""Add the three review entries and refresh the embedded library panel."""
import bpy,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
def integrate():
    m=json.loads((OUT/'manifest.json').read_text())
    sc=bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1'];catalog=json.loads(sc['review_catalog'])
    ids={e['id'] for e in catalog}
    for kind,c in m['cases'].items():
        identity='jump_'+kind+'_v002'
        assert identity not in ids,'Review entry already exists'
        catalog.append({'id':identity,'label':c['label'],'group':'Jump (study only)',
            'scene':c['scene'],'review_rig':c['rig'],'review_carrier':c['carrier'],'action':c['action'],
            'start':1,'end':c['end'],'fps':30,'duration_seconds':(c['end']-1)/30,
            'status':'New three-reference Blender study; awaiting human review; not integrated into game',
            'review_note':'New '+kind+' jump / Blender only',
            'phase_note':f"F{(c['take']+c['land'])//2} apex / F{c['land']} contact / F{c['end']} end",
            'carrier_note':'Carrier = preview height + travel'})
    sc['review_catalog']=json.dumps(catalog)
    path=OUT.parent/'review_manifest.json';rm=json.loads(path.read_text(encoding='utf-8'))
    rm['catalog']=catalog;rm['catalog_entries']=len(catalog);rm['total_actions']=len(bpy.data.actions)
    rm['jump_set_v002']={'manifest':'jump_set_v002/manifest.json','cases':list(m['cases']),
        'preserved_previous_actions':len(m['preserved_action_hashes']),'blender_only':True}
    rm['default_review']='jump_stationary_v002'
    path.write_text(json.dumps(rm,indent=2),encoding='utf-8')
    source=(OUT.parent/'review_controls.py').read_text(encoding='utf-8')
    txt=bpy.data.texts['START_HERE_review_controls.py'];txt.clear();txt.write(source)
    exec(compile(source,'review_controls.py','exec'),{'__name__':'player_review_controls'})
    sc.player_review_group='Jump (study only)'
    bpy.ops.player_review.select(clip_id='jump_stationary_v002')
    bpy.context.scene.frame_set(13)
    return {'catalog':len(catalog),'actions':len(bpy.data.actions),'selected':sc['review_selected']}
if __name__=='__main__':result=integrate()
