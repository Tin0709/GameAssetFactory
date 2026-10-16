"""Independent source-expression/key/controller checks. No Blender/Godot mutation."""
import math,json,sys,argparse
from pathlib import Path
from source_sampler import Sampler,DURATION
from extract_source import extract
p=argparse.ArgumentParser();p.add_argument('--pack',required=True);p.add_argument('--cache',required=True);a=p.parse_args();payload=extract(a.pack,a.cache);s=Sampler(payload);checks=[];err=0.
def close(actual,wanted,label):
 global err
 e=abs(actual-wanted);err=max(err,e);assert e<2e-5,(label,actual,wanted);checks.append(label)
for t in [0,.123,.45,.9,1.8]:
 c=s.value(t);life=14.4+t
 close(c['waist']['rotation'][0],-1.75*math.sin(math.radians(life*400)),'waist pitch400degrees/s')
 close(c['waist']['rotation'][2],-math.cos(math.radians(life*200)),'waist roll200degrees/s')
 close(c['waist']['position'][0],-.4*math.cos(math.radians(life*100-22.5)),'weight100degrees/s,22.5phase')
 close(c['waist']['position'][1],.3*math.cos(math.radians(life*400))-.15,'bounce400degrees/s')
 close(c['head']['rotation'][2],-2*math.sin(math.radians(life*200)),'head independent200degrees/s')
 close(c['rightarm']['rotation'][0],-30,'right this-cancelled pitch')
 close(c['leftarm']['rotation'][0],-70,'left this-cancelled pitch')
 close(c['leftarm']['position'][1],.1*math.sin(math.radians(life*400))-.3,'left inherited pulse and source offset')
 close(c['rightarm']['position'][2],0,'right fore-aft this cancellation')
 close(c['leftarm']['position'][2],-1.2,'left fore-aft this cancellation')
 close(c['body']['rotation'][1],12,'body hold12degrees')
 close(c['rightitem']['rotation'][2],-16,'source item roll retained before rifle calibration')
entry=next(r['time_s'] for r in s.rows if r['controllers']['bjmscc']['state']=='tculwn')
close(s.value(entry+.9167)['head']['rotation'][1],40,'literal head40degree key')
close(s.value(entry+.25)['head']['rotation'][1],-30,'literal head-30degree key')
close(s.value(entry+1.25)['body']['rotation'][1],20,'gesture appended AFTER hold,12+8bodyyaw')
close(s.value(entry+1.375)['rightarm']['rotation'][2],-14,'right source late-layer+6degree key')
close(s.value(entry+1.7917)['leftarm']['rotation'][2],-29,'left source late-layer-4degree key')
assert all(r['controllers']['kcexxa']['state']=='ltqtzr' for r in s.rows)
close(max(abs(s.value(0)[b][c][i]-s.value(DURATION)[b][c][i]) for b in s.value(0) for c in s.value(0)[b] for i in range(3)),0,'three source periods close without key repair')
report={'passed':True,'checks':len(checks),'maximum_error':err,'this_and_layer_order_checked':True,'primary_source_read_directly':a.pack,'gesture_entry_s':entry,'gesture_duration_s':4.2083,'source_loop_duration_s':DURATION,'random_algorithm_adapter':'Python MT19937 seed139; Bedrock PRNG unknown; source branch selection not manually forced'}
(Path(a.cache)/'source_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
