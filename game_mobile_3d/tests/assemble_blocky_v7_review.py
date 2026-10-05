from pathlib import Path
from PIL import Image
import json,statistics
p=Path(__file__).parent
images=[Image.open(p/f'blocky_v7_motion_{i:02d}.png').convert('RGB').resize((768,432)) for i in range(16)]
images[0].save(p/'blocky_v7_in_game_run.gif',save_all=True,append_images=images[1:],duration=50,loop=0)
report=json.loads((p/'blocky_v7_integration_validation.json').read_text())
vel=report['metrics']['support_sole_world_z_velocity_mps']
report['metrics']['support_forward_sliding_median_mps']=statistics.median(vel)
report['metrics']['foot_sliding_observation']='Forward sliding relative to ground, conspicuous at 6.25 m/s with authored 1.5 cycles/s. Rigid rolling-corner measurements include corner-switch spikes; median is an approximate diagnostic, not an IK plant estimate.'
(p/'blocky_v7_integration_validation.json').write_text(json.dumps(report,indent=2))
print('Forward support sliding median:',statistics.median(vel))
