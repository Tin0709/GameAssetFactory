"""Open existing Blender libraries with their matching UI bootstrap."""
import os
from pathlib import Path
import subprocess


VIEW_LABELS = {'animation': 'Animation MD2', 'sabre': 'Valorie + Sabre', 'showcase': 'Animation Showcase'}


class BlenderViewLauncher:
    def __init__(self, state_dir, research_root=None, blender_exe=None, project_root=None):
        self.state_dir = Path(state_dir)
        self.research_root = Path(research_root) if research_root else Path.home() / 'Desktop' / 'MD2 Research'
        self.project_root = Path(project_root) if project_root else Path(__file__).resolve().parents[2]
        self.blender_exe = Path(blender_exe) if blender_exe else Path('C:/Program Files/Blender Foundation/Blender 5.2/blender.exe')
        self.views = {
            'animation': (self.research_root / 'blender/MD2_Animation_Library_BrowserFixed.blend',
                          self.research_root / 'scripts/md2_blender_library.py'),
            'sabre': (self.research_root / 'blender/prototype_sabre/MD2_Valorie_Sabre_Source_Showcase.blend',
                      self.research_root / 'blender/prototype_sabre/source_preview_ui.py'),
            'showcase': (self.project_root / 'blender/animation/showcase/Animation_Showcase.blend',
                         self.project_root / 'scripts/load_showcase_ui.py'),
        }

    def _view(self, key):
        if key not in self.views:
            raise ValueError('Lối tắt Blender không hợp lệ.')
        return self.views[key]

    def blend_path(self, key):
        return self._view(key)[0]

    def open(self, key):
        blend, script = self._view(key)
        for path in (self.blender_exe, blend, script):
            if not path.is_file():
                raise FileNotFoundError('Không tìm thấy: ' + str(path))
        self.state_dir.mkdir(parents=True, exist_ok=True)
        # Match the existing .cmd launchers, directly: no intermediate cmd.exe
        # console, no --background, and no saves or modifications to the blend.
        with (self.state_dir / f'blender-{key}-launch.log').open('ab') as output:
            args = [str(self.blender_exe)]
            if key == 'showcase':
                # Match the project's existing `dev.py blender --viewer animation`.
                args += ['--factory-startup', '--disable-autoexec']
            args += [str(blend), '--python', str(script)]
            process = subprocess.Popen(args,
                                       cwd=blend.parent, stdin=subprocess.DEVNULL,
                                       stdout=output, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        return process.pid
