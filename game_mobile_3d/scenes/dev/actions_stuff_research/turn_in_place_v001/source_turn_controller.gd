extends "res://scenes/dev/actions_stuff_research/source_jump_runtime.gd"
## Isolated agyfrv/irkwzk evaluator. Reuses the existing literal controller VM.
## Head unwrap below is the relevant pre29 subset; gait remains caller-owned.
const TURN_PATH:="res://scenes/dev/actions_stuff_research/turn_in_place_v001/turn_program.json"
func _init(initial_life: float=12.) -> void:
 super(initial_life)
 _program=JSON.parse_string(FileAccess.get_file_as_string(TURN_PATH))
 controllers.clear();env.clear()
 for variable in _program.variable_names:env[variable]=0.
 controllers.agyfrv={"state":"default","time":0.,"clocks":{},"fired":{},"old":null,"fade":0.,"duration":0.,"initialized":false}
func step_turn(source_look_degrees: float,moving: bool,dt: float,interaction: bool=false,attack: float=0.) -> Dictionary:
 env["q.delta_time"]=dt;env["q.is_in_ui"]=0.;env["q.anim_time"]=0.
 env["q.head_y_rotation"]=func(_index: float=0.) -> float:return wrapf(source_look_degrees,-180.,180.)
 env["q.in_range"]=func(x: float,a: float,b: float) -> float:return float(a<=x and x<=b)
 # Exact pre29 unwrap: source controller owns nthjcy, engine look owns hgztwc.
 env["v.hgztwc"]=wrapf(source_look_degrees,-180.,180.)
 env["v.jjzail"]=env["v.hgztwc"]-env["v.jrptkt"]
 var d: float=env["v.jjzail"]
 env["v.qfzzuw"]=d+(360. if d< -180. else (-360. if d>180. else 0.))
 env["v.vyjyhz"]+=env["v.qfzzuw"];env["v.jrptkt"]=env["v.hgztwc"]
 env["v.ccwxuc"]=env["v.vyjyhz"]-env["v.nthjcy"]
 env["v.tjbdov"]=float(moving);env["v.mbqtlv"]=float(interaction);env["v.attack_time"]=attack
 env["v.txvzcq"]=0. if moving else env["v.txvzcq"]+dt
 var layers:=_step_controller("agyfrv",dt)
 life+=dt
 return {"vars":env.duplicate(),"query":{"q.delta_time":dt},"layers":layers,"life":life,"phase":env.get("v.eqhdel",0.),"state":controllers.agyfrv.state,"state_time":controllers.agyfrv.time,"body_degrees":env["v.nthjcy"],"turn_degrees":env.get("v.woataa",0.)}
