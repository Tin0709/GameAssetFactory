import unittest,tempfile,pathlib,sys
from unittest.mock import patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from checkpoint_manager.blender_views import BlenderViewLauncher
try:from checkpoint_manager.desktop import default_configs
except ImportError:default_configs=None

class TaCZIntegrationTests(unittest.TestCase):
 def test_private_tacz_repo_joins_without_replacing_existing_repos(self):
  self.assertIsNotNone(default_configs,'repository extension not implemented')
  root=pathlib.Path('C:/example/Dev/GameAssetFactory');configs=default_configs(root,pathlib.Path('C:/example'))
  self.assertEqual([c.name for c in configs],['GameAssetFactory','MD2 Research','TaCZ Research'])
  self.assertEqual(configs[-1].path,root.parent/'TaCZ-Research');self.assertTrue(configs[-1].require_private)
  self.assertEqual(configs[-1].expected_remote,'https://github.com/Tin0709/TaCZ-Research.git')
 def test_tacz_open_and_copy_use_existing_external_library_bootstrap(self):
  with tempfile.TemporaryDirectory() as temp:
   base=pathlib.Path(temp);project=base/'GameAssetFactory';lib=base/'TaCZ-Research';exe=base/'blender.exe';exe.write_bytes(b'fixture')
   for n in ['blender/TaCZ_Animation_Library.blend','scripts/bootstrap.py']:
    p=lib/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
   launcher=BlenderViewLauncher(base/'state',blender_exe=exe,project_root=project)
   self.assertEqual(launcher.blend_path('tacz'),lib/'blender/TaCZ_Animation_Library.blend')
   with patch('subprocess.Popen') as run:
    launcher.open('tacz');args=run.call_args.args[0]
    self.assertEqual(args,[str(exe),'--factory-startup','--disable-autoexec',str(lib/'blender/TaCZ_Animation_Library.blend'),'--python',str(lib/'scripts/bootstrap.py')]);self.assertFalse(run.call_args.kwargs.get('shell',False))

if __name__=='__main__':unittest.main()
