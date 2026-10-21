extends RefCounted
## Runtime port of the existing Soldier expression_model.py. Authored data is
## exported read-only from that module; preview-only head channels never drive bones.
var data:Dictionary
var channels:Dictionary
var base:Dictionary
var ages:=PackedFloat64Array()
var event_names:Array[String]=[]
var time:=0.
var blink_age:=1.
var next_blink:=3.1
var rng:=RandomNumberGenerator.new()
var celebration_age:=10.
func _init(model:Dictionary):
 data=model;channels=data.neutral.duplicate();base=channels.duplicate()
 for key in data.events:event_names.append(key)
 ages.resize(event_names.size());ages.fill(100.)
 rng.seed=1701
func reset():
 time=0.;blink_age=1.;next_blink=3.1;ages.fill(100.);celebration_age=10.
 rng.seed=1701;base=data.neutral.duplicate();channels=base.duplicate()
func request(key:String):
 var index:=event_names.find(key)
 # A retrigger still inside attack/hold must not erase the visible reaction.
 if index>=0:
  var spec:Array=data.events[key]
  if ages[index]>=float(spec[1])+float(spec[2]):ages[index]=0.
 elif key=="Victory_Small":celebration_age=0.
func target(key:String)->Dictionary:
 var result:Dictionary=data.neutral.duplicate();result.merge(data.presets[key].target,true);return result
static func smooth(t:float)->float:
 t=clampf(t,0.,1.);return t*t*(3.-2.*t)
static func pulse(t:float,duration:float,attack:float,hold:float)->float:
 if t<=0. or t>=duration:return 0.
 if t<attack:return smooth(t/attack)
 if t<attack+hold:return 1.
 return 1.-smooth((t-attack-hold)/maxf(.001,duration-attack-hold))
func blend(a:Dictionary,b:Dictionary,w:float):
 for key in a:a[key]=lerpf(a[key],b[key],w)
func advance(delta:float,state:String,low_hp:float,dead:bool)->Dictionary:
 time+=delta;celebration_age+=delta
 var name:String={"Idle":"Neutral_Idle","Walk":"Move_Effort_Light","Run":"Run_Effort","Rifle Ready Idle":"Enemy_Nearby","Aim":"Focused_Aim"}.get(state,"Neutral_Idle")
 var desired:=target(name)
 if state=="Rifle Ready Idle":
  desired.open_l=1.02;desired.open_r=1.02;desired.gaze_x=.15*pulse(fmod(time,7.2)-2.1,2.,.3,.5)
 elif state=="Idle":
  var t:=fmod(time,9.)
  desired.gaze_x=.13*pulse(t-2.2,2.,.25,.8)-.09*pulse(t-5.2,1.7,.25,.6)
  desired.open_l=1.-.008*(.5-.5*cos(t*PI*4./9.));desired.open_r=desired.open_l
 elif state=="Walk" or state=="Run":
  desired.open_l+=.012*sin(time*TAU*(5./4. if state=="Walk" else 10./6.));desired.open_r=desired.open_l
 blend(desired,target("Low_HP_Tense"),clampf(low_hp,0.,1.)*.48)
 blend(base,desired,1.-exp(-20.*delta));channels=base.duplicate()
 # One persistent blink clock, never restarted by Aim/Run/Fire transitions.
 blink_age+=delta;next_blink-=delta
 if next_blink<=0.:
  blink_age=0.;next_blink=rng.randf_range(5.6,8.2) if state=="Aim" else rng.randf_range(2.65,4.8)
 channels.blink_auto=pulse(blink_age,.18,.075,.02)
 if state!="Aim":blend(channels,target("Victory_Small"),pulse(celebration_age,3.,.16,2.1))
 # Sorted ascending priorities, max envelope per event, no additive stacking.
 for i in event_names.size():
  ages[i]+=delta;var spec:Array=data.events[event_names[i]]
  var w:=pulse(ages[i],spec[0],spec[1],spec[2])
  if dead and event_names[i]=="Death_Stunned":w=maxf(w,smooth(ages[i]/.09))
  blend(channels,target(event_names[i]),w)
 for key in channels:
  var bounds:Array=data.limits[key];channels[key]=clampf(channels[key],bounds[0],bounds[1])
 return channels
