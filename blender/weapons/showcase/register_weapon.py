"""Add a new source to the SAME library as Pending, then rebuild with backups.
Blender --background --python register_weapon.py -- --id unique_id --kind Rifle --label "Rifle — New" --source blender/weapons/new/asset.blend
"""
import argparse,bpy,json,hashlib,runpy,sys,shutil,datetime,re,atexit
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE));from library_safety import UpdateLock
update_lock=UpdateLock(HERE).acquire();atexit.register(update_lock.release)
p=argparse.ArgumentParser();p.add_argument('--id',required=True);p.add_argument('--kind',choices=['Rifle','Pistol','Shotgun'],required=True);p.add_argument('--label',required=True);p.add_argument('--source',required=True)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert re.fullmatch('[a-z][a-z0-9_]*',args.id),'Use a stable lowercase identifier'
source=(ROOT/args.source).resolve();source.relative_to(ROOT/'blender/weapons')
assert source.is_file() and source.suffix=='.blend'
with bpy.data.libraries.load(str(source),link=False) as (src,dst):assert 'WEAPON_EXPORT' in src.collections,'Provide one WEAPON_EXPORT collection with grip-centered root'
mf=HERE/'weapon_manifest.json';manifest=json.loads(mf.read_text())
assert all(e['id']!=args.id and e['source']!=source.relative_to(ROOT).as_posix() for e in manifest['weapons']),'Existing entries are immutable; create a distinct version'
backup=ROOT/'.validation/weapon_showcase_v2'/('registration_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir(parents=True)
for name in ['weapon_manifest.json','Weapon_Showcase.blend']:shutil.copy2(HERE/name,backup/name)
manifest['weapons'].append({'id':args.id,'kind':args.kind,'label':args.label,'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'status':'Pending','status_note':'New registration; awaiting explicit visual approval.'})
try:
 mf.write_text(json.dumps(manifest,indent=2));written_manifest_hash=hashlib.sha256(mf.read_bytes()).hexdigest()
 runpy.run_path(str(HERE/'build_showcase.py'),run_name='__main__',init_globals={'_WEAPON_LOCK_HELD':True})
except BaseException:
 # Builder does not overwrite the original blend until its final successful save.
 # Restore only our own manifest write; never roll back somebody else's edits.
 if 'written_manifest_hash' in globals() and hashlib.sha256(mf.read_bytes()).hexdigest()==written_manifest_hash:shutil.copy2(backup/'weapon_manifest.json',mf)
 raise
print('REGISTERED_PENDING',args.id)
