"""Run relevant production suites; retain evidence without tracked report churn."""
import subprocess,json,sys,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PROJECT=ROOT/'game_mobile_3d'
OUT=ROOT/'.validation/locomotion_r6p';OUT.mkdir(parents=True,exist_ok=True)
GODOT=Path('C:/Users/ADMIN/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
names=['animation_v2','blocky_v7_integration','locomotion_stop','movement_weapons','weapon_carry_c1','weapon_behavior_d0','holster_d2','holster_d2_live','draw_d5','draw_d5_live','weapon_sprint_d3','back_carry_d31','back_carry_d31_live','living_ready_e3','ready_e3_live','weapon_select','combat','gameplay','bounce_animation','player_pose_lab']
label=sys.argv[1] if len(sys.argv)>1 else 'review'
environment=os.environ.copy()
environment['APPDATA']=str(PROJECT/'.godot/validation_appdata')
tracked=subprocess.check_output(['git','ls-files','game_mobile_3d/tests/*.json'],cwd=ROOT,text=True).splitlines()
backup={p:(ROOT/p).read_bytes() for p in tracked if (ROOT/p).exists()}
result={}
try:
    for name in names:
        script=PROJECT/'tests'/('validate_'+name+'.gd')
        if not script.exists():raise RuntimeError('Missing relevant suite '+name)
        run=subprocess.run([str(GODOT),'--headless','--path',str(PROJECT),'--script','res://tests/'+script.name,'--fixed-fps','60','--quit-after','12000'],cwd=ROOT,env=environment,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
        text=run.stdout.decode('utf-8',errors='replace');(OUT/(label+'_'+name+'.log')).write_text(text,encoding='utf-8')
        payload=None
        for line in text.splitlines():
            if line.startswith('{'):
                try:payload=json.loads(line)
                except json.JSONDecodeError:pass
        errors=[s for s in text.splitlines() if s.startswith(('ERROR:','SCRIPT ERROR:'))]
        result[name]={'exit':run.returncode,'errors':errors,'report':payload}
        print(label,name,'exit',run.returncode,'errors',len(errors),flush=True)
finally:
    for p,data in backup.items():(ROOT/p).write_bytes(data)
    (OUT/(label+'_regressions.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
sys.exit(0 if all(x['exit']==0 and not x['errors'] for x in result.values()) else 1)
