"""Presentation-only grouping over the complete animation registry."""
import unicodedata

FILTER_ITEMS=[
 ('AS_WALKRUN','A&S | Walk / Run','The two original Actions & Stuff walking/running source studies'),
 ('CURRENT_JUMP','Jump | Current v004','Current attached-shoulder jump and landing review'),
 ('AS_SOURCE','A&S | Other source','Idle, directional movement, jump and landing source studies'),
 ('AUTHORED','Original | Walk / Run','Own authored A&S-inspired and hybrid locomotion experiments'),
 ('COMBAT','Combat | Sword','Original sword ready, attacks, guard, parry and other combat'),
 ('RIFLE','Rifle / Crossbow','Rifle and crossbow ready, movement, aim and fire studies'),
 ('JUMP_STUDIES','Jump | Earlier studies','Previous jump/landing versions; all preserved'),
 ('ARCHIVE','Earlier experiments','Older expressive, snappy and rig experiments'),
 ('ALL','All animations','Every registered action and research sequence'),
]
ALIASES={
 'Walk_ActionsStuff_Source_Test_v001':'Walking - A&S source',
 'Run_ActionsStuff_Source_Test_v001':'Running - A&S source',
 'Idle_ActionsStuff_Source_Test_v001':'Idle - A&S source',
 'Jump_AS_Stationary_ShouldersAttached_v004_RESEARCH':'Jump v004 - Stationary',
 'Jump_AS_Moving_ShouldersAttached_v004_RESEARCH':'Jump v004 - Moving',
 'as_landing_shoulders_v004':'Jump v004 - Side-by-side review',
 'Walk_ASInspired_Original_v001_PENDING':'Walking - Own A&S-inspired v001',
 'Run_ASInspired_Original_v001_PENDING':'Running - Own A&S-inspired v001',
}
SOURCE_WALKRUN=('Walk_ActionsStuff_Source_Test_v001','Run_ActionsStuff_Source_Test_v001')

def category(entry):
 name=entry['id'];lower=name.casefold()
 if name in SOURCE_WALKRUN:return 'AS_WALKRUN'
 if 'shouldersattached_v004' in lower or name=='as_landing_shoulders_v004':return 'CURRENT_JUMP'
 if 'rifle' in lower or 'crossbow' in lower:return 'RIFLE'
 if lower.startswith('sword_'):return 'COMBAT'
 if ('_actionsstuff_source_test_' in lower or name in ['actions_stuff_directional_v001','actions_stuff_jump_landing_v001']):return 'AS_SOURCE'
 if 'asinspired_original' in lower or name.startswith(('as_primary_walkrun_','Run_Hybrid_','hybrid_run_comparison')) or 'WalkRun_PhaseTransition' in name:return 'AUTHORED'
 if any(word in lower for word in ['jump','landing','airpose','fall_']):return 'JUMP_STUDIES'
 return 'ARCHIVE'

def normalize(text):
 return ''.join(c for c in unicodedata.normalize('NFKD',text.casefold().replace('đ','d')) if not unicodedata.combining(c))

def visible_entries(entries,group='AS_WALKRUN',search=''):
 """Search covers ALL groups. Filtering never alters registry IDs/status/data."""
 terms=normalize(search).split();out=[]
 for entry in entries:
  item=dict(entry);item['label']=ALIASES.get(item['id'],item['label']);item['category']=category(item)
  tags='walking di bo actions stuff source' if item['id']==SOURCE_WALKRUN[0] else ('running chay actions stuff source' if item['id']==SOURCE_WALKRUN[1] else '')
  haystack=normalize(' '.join([item['label'],item['id'],item['category'],tags]))
  if (terms and all(term in haystack for term in terms)) or (not terms and (group=='ALL' or item['category']==group)):out.append(item)
 order={key:i for i,(key,_,_) in enumerate(FILTER_ITEMS)}
 # Prioritize the actual requested source Walk/Run, without renaming Actions.
 out.sort(key=lambda e:(order[e['category']],SOURCE_WALKRUN.index(e['id']) if e['id'] in SOURCE_WALKRUN else 2))
 return out
