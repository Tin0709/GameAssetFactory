"""Single-writer guard and portable preservation classification."""
import os,json,uuid
from pathlib import Path
def protected_category(path):
 path=str(path).replace('\\','/')
 for prefix,category in [('blender/weapons/','weapons'),('blender/animation/','animations'),('game_mobile_3d/assets/characters/','production_characters')]:
  if path.startswith(prefix):return category
 return 'other'
class UpdateLock:
 def __init__(self,directory):self.path=Path(directory)/'.weapon_library.lock';self.token=uuid.uuid4().hex
 def acquire(self):
  try:fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_EXCL)
  except FileExistsError:raise RuntimeError('Weapon library update already locked: '+str(self.path)+'. Wait for the other build; inspect a stale lock before removing it.')
  with os.fdopen(fd,'w') as f:json.dump({'pid':os.getpid(),'token':self.token},f)
  return self
 def release(self):
  if self.path.exists() and json.loads(self.path.read_text())['token']==self.token:self.path.unlink()
