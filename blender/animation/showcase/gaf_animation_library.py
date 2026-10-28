"""Persistent, scene-local Animation Library controls for GameAssetFactory."""
bl_info={'name':'GameAssetFactory Animation Library','author':'GameAssetFactory','version':(1,0,0),'blender':(5,2,0),'location':'3D View > N > Animation Library','description':'Select and review independent character Actions','category':'Animation'}
import bpy,json,hashlib,re,math
from mathutils import Matrix
from pathlib import Path
from bpy.app.handlers import persistent
from bpy.props import StringProperty,IntProperty,BoolProperty,CollectionProperty,EnumProperty
from gaf_animation_browser import FILTER_ITEMS,visible_entries

SCENE_TAG='gaf_animation_showcase';RIG='Showcase_Player_Rig';BASELINE='GAF_Neutral_Pose.json'
REVIEW_TAG='gaf_review_sequence_id';REVIEW_ENTRY='gaf_review_entry_json'
PREVIEW_PROPS={
    'rifle_stylized_v2':('GAF_Rifle_V2_Preview','GAF_Rifle_V2_Attachment','WeaponCarrier'),
    'sword_sand_block_v1':('GAF_Sword_Sand_Block_V1_Preview','GAF_Sword_Sand_Block_V1_Attachment','WeaponCarrier'),
}
PREVIEW_PROP_ROOTS={'rifle_stylized_v2':'Rifle_Stylized_V2','sword_sand_block_v1':'Sword_Sand_Block_V1'}
PREVIEW_PROP_LABELS={'rifle_stylized_v2':'Rifle Stylized V2 attached','sword_sand_block_v1':'Sword Sand Block V1 attached'}
_switching=False

def curves(action):
    return [c for layer in action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]

def action_signature(action):
    # Include evaluation settings; exclude editor selection, names and colors.
    def props(obj):
        return [(p.identifier,getattr(obj,p.identifier)) for p in obj.bl_rna.properties if p.type in {'BOOLEAN','INT','FLOAT','ENUM'} and not p.is_readonly and p.identifier not in {'show_expanded','active'}]
    data=[(c.data_path,c.array_index,c.mute,c.group.mute if c.group else False,c.extrapolation,c.auto_smoothing,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type,k.easing,k.back,k.amplitude,k.period) for k in c.keyframe_points],[(m.type,props(m)) for m in c.modifiers]) for c in curves(action)]
    structure=[(props(layer),[(strip.type,props(strip),[bag.slot_handle for bag in strip.channelbags]) for strip in layer.strips]) for layer in action.layers]
    return hashlib.sha256(repr(([(s.identifier,s.target_id_type) for s in action.slots],structure,data)).encode()).hexdigest()

def rest_signature(armature):
    return hashlib.sha256(repr([(b.name,b.parent.name if b.parent else None,[list(x) for x in b.matrix_local],b.use_deform,b.inherit_scale,b.use_local_location,b.use_inherit_rotation) for b in armature.bones]).encode()).hexdigest()

def location():
    return Path(bpy.path.abspath('//')).resolve()

def root():
    return location().parents[2]

def manifest_path():return location()/'animation_manifest.json'

def load_manifest():
    data=json.loads(manifest_path().read_text(encoding='utf-8'))
    if data.get('schema') not in {1,2} or not isinstance(data.get('animations'),list):raise ValueError('Unsupported animation manifest')
    if data.get('schema')!=2 and any(e.get('external_linked_research') is True for e in data['animations']):
        raise ValueError('External research links require manifest schema 2; older viewers must not append private source keys')
    names=[e['action'] for e in data['animations']]
    if not names or len(names)!=len(set(names)):raise ValueError('Animation names must be nonempty and unique')
    for e in data['animations']:
        if e['status'] not in ['approved','pending']:raise ValueError('Use approved or pending status explicitly')
        validate_timing(e)
    sequences=data.get('review_sequences',[])
    if not isinstance(sequences,list):raise ValueError('Review sequences must be a list')
    ids=[e['id'] for e in sequences]
    if len(ids)!=len(set(ids)) or any(not isinstance(i,str) or not i for i in ids):raise ValueError('Review sequence IDs must be nonempty and unique')
    for e in sequences:validate_timing(e)
    ordered_library_entries(data,False)
    return data

def validate_timing(e):
    if any(type(e[k]) is not int for k in ['start','end','fps']):raise ValueError('Playback frame bounds and FPS must be integers; use fps_base for fractional rates')
    if not (1<=e['start']<=e['end']<=1048574 and 1<=e['fps']<=32767 and isinstance(e['fps_base'],(int,float)) and math.isfinite(e['fps_base']) and 1e-5<=e['fps_base']<=1e6):raise ValueError('Invalid frame range or timing')
    floor=e.get('preview_floor_z_m',0.0)
    if type(floor) not in [int,float] or not math.isfinite(floor) or not -10<=floor<=10:raise ValueError('Invalid preview floor height')

# Explicit, source-bound exception for this private Jump/Landing reconstruction.
# Original Run and directional policies below remain unchanged.
JUMP_SCALE_PROFILE='actions_stuff_jump_v001'
JUMP_SOURCE_IDS={'animation.oreville_ans.'+n for n in ['mykcsi','bevrbk','nvxqkp','xvdslp','jmjgft','dwzzez']}
JUMP_ROOT_SOURCE_IDS=JUMP_SOURCE_IDS-{'animation.oreville_ans.dwzzez'}

def jump_scale_policy(entry,sequence=False):
    if 'research_scale_profile' not in entry:return None
    if (entry.get('research_scale_profile')!=JUMP_SCALE_PROFILE
            or entry.get('research_only') is not True or entry.get('production_eligible') is not False
            or entry.get('source_pack_sha256')!='9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d'):
        raise ValueError('Jump scale requires the verified private source profile and provenance')
    if sequence:
        sources=entry.get('source_scale_animations')
        if (not isinstance(sources,list) or not sources or any(not isinstance(v,str) for v in sources)
                or len(sources)!=len(set(sources)) or set(sources)-(JUMP_SOURCE_IDS|{'animation.oreville_ans.fngydr'})
                or not set(sources)&JUMP_ROOT_SOURCE_IDS):
            raise ValueError('Jump sequence scale sources must be unique verified Jump/Landing IDs')
        sources=set(sources)
    else:
        source=entry.get('source_animation')
        if source not in JUMP_SOURCE_IDS:raise ValueError('Unverified Jump/Landing source animation')
        sources={source}
    policy=entry.get('research_scale_channels',{})
    if not isinstance(policy,dict):raise ValueError('Jump scale policy must be a channel map')
    for bone,rule in policy.items():
        if not isinstance(rule,dict):raise ValueError('Invalid Jump scale rule')
        if bone=='Root' and sources&JUMP_ROOT_SOURCE_IDS:
            if (set(rule)!={'axes','min','max'} or rule['axes']!=[0,1,2]
                    or any(type(v) is not int for v in rule['axes'])):raise ValueError('Jump Root scale requires axes 0, 1 and 2')
            low,high=.85,1.15
        elif bone in ['Leg.L','Leg.R'] and sources&{'animation.oreville_ans.mykcsi','animation.oreville_ans.fngydr'}:
            if set(rule)!={'axis','min','max'} or type(rule['axis']) is not int or rule['axis']!=1:raise ValueError('Jump leg scale supports only local Y')
            low,high=(.95,1.30) if 'animation.oreville_ans.mykcsi' in sources else (1.,1.11)
        else:raise ValueError('Scale channel is not authored by the declared Jump/Landing sources')
        if (type(rule['min']) not in [int,float] or type(rule['max']) not in [int,float]
                or not math.isfinite(rule['min']) or not math.isfinite(rule['max'])
                or not low<=rule['min']<=1.<=rule['max']<=high):raise ValueError('Jump scale policy exceeds verified research bounds')
    return policy

def validate_jump_scale_curve(curve,policy):
    bone=curve.data_path.split('"')[1];rule=policy.get(bone)
    allowed=rule is not None and curve.array_index in rule.get('axes',[rule.get('axis')])
    low,high=(rule['min'],rule['max']) if allowed else (1.,1.)
    if (curve.modifiers or any(k.interpolation!='LINEAR' or not math.isfinite(k.co.y)
            or k.co.y<low-1e-6 or k.co.y>high for k in curve.keyframe_points)):
        raise ValueError('Jump scale keys exceed declared source bounds or are not finite LINEAR keys')

def validate_action(action,entry,rig):
    validate_timing(entry)
    jump_policy=jump_scale_policy(entry)
    if entry.get('rotation_modes')!={b.name:b.rotation_mode for b in rig.pose.bones}:raise ValueError('Incompatible pose rotation modes')
    if len(action.slots)!=1 or action.slots[0].target_id_type!='OBJECT':raise ValueError('Viewer requires one rig-only OBJECT Action slot')
    if len(action.layers)!=1 or len(action.layers[0].strips)!=1 or len(action.layers[0].strips[0].channelbags)!=1:raise ValueError('Viewer requires one baked layer, strip and channel bag')
    if action.slots[0].identifier!=entry['slot_identifier']:raise ValueError('Action slot identifier changed')
    if action_signature(action)!=entry['action_sha256']:raise ValueError('Action content differs from its registered source')
    if list(action.frame_range)!=entry['action_frame_range']:raise ValueError('Action key range changed')
    if not action.frame_range[0]<=entry['start']<=entry['end']<=action.frame_range[1]:raise ValueError('Playback range is outside Action keys')
    for c in curves(action):
        if c.sampled_points or any(m.type!='CYCLES' for m in c.modifiers):raise ValueError('Only keyed curves and optional CYCLES modifiers are supported')
        if not re.fullmatch(r'pose\.bones\["[^"\n]+"\]\.(location|rotation_euler|rotation_quaternion|scale)',c.data_path):raise ValueError('Only baked rig pose transforms are supported: '+c.data_path)
        values=rig.path_resolve(c.data_path)
        if not 0<=c.array_index<len(values):raise ValueError('Invalid bone transform channel')
        if jump_policy is not None:
            bone_name=c.data_path.split('"')[1]
            if bone_name.startswith('ForeArm.'):
                prop=c.data_path.rsplit('.',1)[1]
                neutral=1. if prop=='scale' or (prop=='rotation_quaternion' and c.array_index==0) else 0.
                if any(not math.isfinite(k.co.y) or abs(k.co.y-neutral)>1e-6 for k in c.keyframe_points):raise ValueError('Jump reconstruction cannot invent ForeArm articulation')
            if c.data_path.endswith('scale'):validate_jump_scale_curve(c,jump_policy)
        elif c.data_path.endswith('scale') and any(abs(k.co.y-1)>1e-6 for k in c.keyframe_points):
            policy=entry.get('research_scale_channels',{})
            bone_name=c.data_path.split('\"')[1]
            rule=policy.get(bone_name)
            eligible=(entry.get('research_only') is True and entry.get('production_eligible') is False
                      and entry.get('source_animation')=='animation.oreville_ans.fngydr'
                      and entry.get('source_pack_sha256')=='9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d'
                      and bone_name in ['Leg.L','Leg.R'] and c.array_index==1 and rule=={'axis':1,'min':1.0,'max':1.070002})
            if not eligible:raise ValueError('Animated limb scaling is not supported outside the verified research Run leg channels')
            if c.modifiers or any(k.interpolation!='LINEAR' or not math.isfinite(k.co.y) or k.co.y<rule['min']-1e-6 or k.co.y>rule['max'] for k in c.keyframe_points):
                raise ValueError('Research leg scale exceeds verified source bounds or uses unsupported interpolation')

def validate_preview_prop(entry,rig):
    key=entry.get('preview_prop')
    if key is None:return
    if key not in PREVIEW_PROPS:raise ValueError('Unknown preview prop: '+str(key))
    collection,name,bone=PREVIEW_PROPS[key];c=bpy.data.collections.get(collection);o=bpy.data.objects.get(name)
    if c is None or o is None or o.name not in c.all_objects:raise ValueError('Registered preview prop is missing; refresh the library')
    if o.parent!=rig or o.parent_type!='BONE' or o.parent_bone!=bone:raise ValueError('Preview prop attachment is incompatible')
    if not any(x.type=='MESH' for x in c.all_objects):raise ValueError('Preview prop has no visible model')

def show_preview_prop(scene,entry):
    for key,(collection,_,_) in PREVIEW_PROPS.items():
        c=bpy.data.collections.get(collection)
        if c:c.hide_render=c.hide_viewport=(entry.get('preview_prop')!=key)

def review_entries(scene):
    """Saved data remains usable when a study is opened outside the library folder."""
    if scene.get(SCENE_TAG):
        return json.loads(scene.get('gaf_manifest_snapshot','{}')).get('review_sequences',[])
    if scene.get(REVIEW_TAG):return [json.loads(scene[REVIEW_ENTRY])]
    return []

def library_home(scene):
    if scene.get(SCENE_TAG):return scene
    if scene.get(REVIEW_TAG):
        return bpy.data.scenes.get(json.loads(scene[REVIEW_ENTRY])['return_scene'])
    return None

def ordered_library_entries(data,show_archived):
    """Visibility is a view over the full registry; never remove registrations."""
    entries=[{'kind':'action','id':e['action'],'label':e['action'],'status':e['status']} for e in data.get('animations',[])]
    entries += [{'kind':'review_sequence','id':e['id'],'label':e.get('label',e['id']),'status':e['status']} for e in data.get('review_sequences',[])]
    focus=data.get('library_focus')
    if focus is None:return entries
    keys=[(e['kind'],e['id']) for e in focus['entries']]
    lookup={(e['kind'],e['id']):e for e in entries}
    if not keys or len(keys)!=len(set(keys)) or any(k not in lookup for k in keys):raise ValueError('Library focus must reference unique registered entries')
    return [lookup[k] for k in keys]+([e for e in entries if (e['kind'],e['id']) not in keys] if show_archived else [])

def library_entries(scene,show_archived=None):
    home=library_home(scene)
    if home is None:return []
    if show_archived is None:show_archived=home.gaf_show_archived
    return ordered_library_entries(json.loads(home['gaf_manifest_snapshot']),show_archived)

def focused_index(scene,index):
    if scene.gaf_show_archived:return index
    names=[e['id'] for e in library_entries(scene,False) if e['kind']=='action']
    if names and scene.gaf_clips[index].action not in names:
        return next(i for i,c in enumerate(scene.gaf_clips) if c.action==names[0])
    return index

def archive_visibility_changed(scene,context):
    if not _switching and scene.get(SCENE_TAG) and scene.gaf_clips:
        index=focused_index(scene,scene.gaf_active_index)
        if index!=scene.gaf_active_index:scene.gaf_active_index=index

def select_registered_action(context,action_name):
    home=library_home(context.scene)
    if home is None:raise ValueError('Animation Library is unavailable')
    index=next((i for i,c in enumerate(home.gaf_clips) if c.action==action_name),None)
    if index is None:raise ValueError('Action is not registered: '+action_name)
    if context.scene!=home:return_library(context)
    if home.gaf_active_index!=index:home.gaf_active_index=index
    return home

def validate_review_sequence(entry):
    """Validate an isolated research take without widening reusable Action policy."""
    validate_timing(entry)
    if entry.get('status') not in {'pending','approved'} or entry.get('research_only') is not True or entry.get('production_eligible') is not False or entry.get('seamless_loop') is not False:
        raise ValueError('Review sequences must have a review status and remain nonseamless research only')
    scene=bpy.data.scenes.get(entry['scene']);rig=bpy.data.objects.get(entry['rig']);mesh=bpy.data.objects.get(entry['mesh']);world=bpy.data.objects.get(entry['world_root'])
    if scene is None or scene.get(REVIEW_TAG)!=entry['id'] or scene.get(SCENE_TAG):raise ValueError('Registered review scene is missing or incompatible')
    if rig is None or rig.type!='ARMATURE' or rig.name==RIG or mesh is None or mesh.type!='MESH' or world is None or world.type!='EMPTY':raise ValueError('Review sequence requires its own rig, mesh and presentation Empty')
    if any(o.name not in scene.objects for o in [rig,mesh,world]):raise ValueError('Review actor is outside the registered scene')
    native=bpy.data.objects[RIG]
    if rest_signature(rig.data)!=entry['rig_sha256'] or entry['rig_sha256']!=rest_signature(native.data):raise ValueError('Review sequence rest rig differs from the native rig')
    if len(rig.pose.bones)!=13 or entry.get('rotation_modes')!={b.name:b.rotation_mode for b in rig.pose.bones}:raise ValueError('Review sequence bone count or rotation modes differ')
    if rig.parent!=world or world.parent is not None or mesh.parent!=rig or not any(m.type=='ARMATURE' and m.object==rig for m in mesh.modifiers):raise ValueError('Review sequence actor parentage is incompatible')
    identity=Matrix.Identity(4)
    if any(abs(rig.matrix_parent_inverse[i][j]-identity[i][j])>1e-6 or abs(rig.matrix_basis[i][j]-identity[i][j])>1e-6 for i in range(4) for j in range(4)) or any(abs(v-1)>1e-6 for v in world.scale):raise ValueError('Review rig basis, parent inverse and presentation scale must be identity')
    for obj in [rig,mesh,world]:
        if obj.constraints or (obj.animation_data and (obj.animation_data.nla_tracks or obj.animation_data.drivers)):raise ValueError('Review sequences require baked transforms without constraints, NLA or drivers')
    if any(b.constraints for b in rig.pose.bones):raise ValueError('Review sequence bone constraints are unsupported')
    jump_policy=jump_scale_policy(entry,sequence=True)
    scale_policy=entry.get('research_scale_channels',{})
    if jump_policy is None and 'research_scale_channels' in entry:
        if (entry.get('source_pack_sha256')!='9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d'
                or entry.get('directional_weight_adapter')!='positive_only_not_normalized'
                or not isinstance(scale_policy,dict) or not scale_policy or set(scale_policy)-{'Leg.L','Leg.R'}):raise ValueError('Mixed directional scale requires verified source provenance and leg-only bounds')
        for rule in scale_policy.values():
            if (not isinstance(rule,dict) or set(rule)!={'axis','min','max'} or type(rule['axis']) is not int or rule['axis']!=1
                    or type(rule['min']) not in [int,float] or rule['min']!=1.
                    or type(rule['max']) not in [int,float] or not math.isfinite(rule['max']) or not 1.<=rule['max']<=1.105002):raise ValueError('Mixed directional leg scale policy exceeds the verified axis or theoretical bounds')
    for prefix,obj in [('pose',rig),('presentation',world)]:
        action=bpy.data.actions.get(entry[prefix+'_action'])
        if action is None or len(action.slots)!=1 or action.slots[0].target_id_type!='OBJECT' or action.slots[0].identifier!=entry[prefix+'_slot_identifier']:raise ValueError('Review sequence Action slot is incompatible')
        if len(action.layers)!=1 or len(action.layers[0].strips)!=1 or len(action.layers[0].strips[0].channelbags)!=1 or action.layers[0].strips[0].channelbags[0].slot_handle!=action.slots[0].handle:raise ValueError('Review sequences require one baked layer, strip and channel bag')
        if action_signature(action)!=entry[prefix+'_action_sha256']:raise ValueError('Review sequence Action signature changed')
        if not action.frame_range[0]<=entry['start']<=entry['end']<=action.frame_range[1]:raise ValueError('Review sequence playback is outside Action keys')
        if not curves(action):raise ValueError('Review sequence Action has no keys')
        for c in curves(action):
            if c.sampled_points or c.modifiers or not c.keyframe_points:raise ValueError('Review sequences require keyed curves without modifiers')
            if any(k.interpolation!='LINEAR' or any(not math.isfinite(v) for p in [k.co,k.handle_left,k.handle_right] for v in p) for k in c.keyframe_points):raise ValueError('Review sequence keys must be finite and LINEAR')
            if prefix=='presentation':
                if c.data_path not in ['location','rotation_euler'] or not 0<=c.array_index<3:raise ValueError('Presentation Action supports only Empty location and Euler rotation')
                continue
            match=re.fullmatch(r'pose\.bones\["([^"\n]+)"\]\.(location|rotation_euler|rotation_quaternion|scale)',c.data_path)
            if match is None:raise ValueError('Review pose Action supports only bone transforms')
            bone_name,prop=match.groups()
            if bone_name not in rig.pose.bones or not 0<=c.array_index<len(rig.path_resolve(c.data_path)):raise ValueError('Invalid review bone transform channel')
            if bone_name.startswith('ForeArm.'):
                neutral=1. if (prop=='scale' or (prop=='rotation_quaternion' and c.array_index==0)) else 0.
                if any(abs(k.co.y-neutral)>1e-6 for k in c.keyframe_points):raise ValueError('Review sequence cannot invent ForeArm articulation')
            if prop=='scale' and jump_policy is not None:
                validate_jump_scale_curve(c,jump_policy)
            elif prop=='scale':
                low,high=(1.,1.070002) if bone_name in ['Leg.L','Leg.R'] and c.array_index==1 else (1.,1.)
                if bone_name in scale_policy and c.array_index==1:high=scale_policy[bone_name]['max']
                if any(k.co.y<low-1e-6 or k.co.y>high for k in c.keyframe_points):raise ValueError('Review scale exceeds the verified leg Y bounds')
    if entry['pose_action']==entry['presentation_action']:raise ValueError('Pose and presentation Actions must be separate')
    cameras=entry.get('cameras',{})
    if set(cameras)!={'FRONT','THREE_QUARTER','SIDE'}:raise ValueError('Review sequence requires Front, 3/4 and Side cameras')
    for name in cameras.values():
        camera=bpy.data.objects.get(name)
        if camera is None or camera.type!='CAMERA' or name not in scene.objects:raise ValueError('Registered review camera is missing')
    if 'hud_root' in entry:
        hud=bpy.data.objects.get(entry['hud_root'])
        if hud is None or hud.type!='EMPTY' or hud.name not in scene.objects or hud.parent is None or hud.parent.name not in cameras.values():raise ValueError('Review HUD requires an Empty parented to a registered camera in its scene')
    home=bpy.data.scenes.get(entry['return_scene'])
    if home is None or not home.get(SCENE_TAG):raise ValueError('Review sequence return library is missing')
    return scene

def stop_playback(context):
    if context.screen and context.screen.is_animation_playing:
        with bpy.context.temp_override(window=context.window,screen=context.screen):bpy.ops.screen.animation_cancel(restore_frame=False)

def open_review_sequence(context,sequence_id):
    entries=[e for scene in bpy.data.scenes if scene.get(SCENE_TAG) for e in review_entries(scene)]
    entry=next((e for e in entries if e['id']==sequence_id),None)
    if entry is None:
        entry=next((e for e in review_entries(context.scene) if e['id']==sequence_id),None)
    if entry is None:raise ValueError('Review sequence is not registered: '+sequence_id)
    scene=validate_review_sequence(entry)
    stop_playback(context);context.window.scene=scene
    rig=bpy.data.objects[entry['rig']];world=bpy.data.objects[entry['world_root']]
    for prefix,obj in [('pose',rig),('presentation',world)]:
        action=bpy.data.actions[entry[prefix+'_action']]
        obj.animation_data_create();obj.animation_data.action=action;obj.animation_data.action_slot=action.slots[0]
    scene[REVIEW_ENTRY]=json.dumps(entry)
    scene.frame_start=entry['start'];scene.frame_end=entry['end'];scene.render.fps=entry['fps'];scene.render.fps_base=entry['fps_base']
    scene.use_preview_range=False;scene.sync_mode='FRAME_DROP' if entry.get('playback_sync')=='FRAME_DROP' else 'NONE';scene.gaf_loop=False;scene.gaf_error='';scene.frame_set(entry['start'])
    for obj in context.window.view_layer.objects:obj.select_set(False)
    context.window.view_layer.objects.active=rig;rig.select_set(True)
    view(scene,'THREE_QUARTER')
    return scene

def return_library(context):
    entry=json.loads(context.scene[REVIEW_ENTRY]);home=bpy.data.scenes.get(entry['return_scene'])
    if home is None or not home.get(SCENE_TAG):raise ValueError('Review sequence return library is missing')
    stop_playback(context);context.window.scene=home
    for area in context.window.screen.areas:area.tag_redraw()
    return home

def activate(scene,index):
    if not scene.get(SCENE_TAG) or not scene.gaf_clips:return
    e=json.loads(scene.gaf_clips[index].entry_json);rig=bpy.data.objects[RIG];a=bpy.data.actions[e['action']]
    validate_action(a,e,rig)
    validate_preview_prop(e,rig)
    # Partial Actions must not inherit a previous clip's unkeyed legs/chest.
    rig.animation_data_create();rig.animation_data.action=None
    neutral=json.loads(bpy.data.texts[BASELINE].as_string())
    for bone in rig.pose.bones:
        for key,value in neutral[bone.name].items():setattr(bone,key,value)
    rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
    scene.frame_start=e['start'];scene.frame_end=e['end'];scene.render.fps=e['fps'];scene.render.fps_base=e['fps_base']
    scene.use_preview_range=False;scene.sync_mode='FRAME_DROP' if e.get('playback_sync')=='FRAME_DROP' else 'NONE';scene.frame_set(e['start'])
    show_preview_prop(scene,e)
    floor=bpy.data.objects.get('Showcase_FixedFloor')
    if floor:floor.location.z=e.get('preview_floor_z_m',0.0)
    for window in bpy.context.window_manager.windows:
        if window.scene==scene:
            window.view_layer.objects.active=rig
            rig.select_set(True)
            for area in window.screen.areas:area.tag_redraw()

def selection_changed(self,context):
    if not _switching:
        try:activate(self,self.gaf_active_index);self.gaf_error=''
        except Exception as error:self.gaf_error=str(error)

def refresh(scene,import_missing=True):
    global _switching
    data=load_manifest();rig=bpy.data.objects[RIG]
    if rest_signature(rig.data)!=data['rig_sha256']:raise ValueError('Showcase rig differs from the registered rest rig')
    new_actions=[];new_props=[]
    try:
        # Validate the complete request before replacing the visible list/selection.
        for e in data['animations']:
            source=(root()/e['source']).resolve()
            if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest()!=e['source_sha256']:raise ValueError('Source missing or changed: '+e['source'])
            linked_research=e.get('external_linked_research') is True
            if linked_research and (e.get('research_only') is not True or e.get('production_eligible') is not False or source.is_relative_to(root()) or source.suffix.lower()!='.blend'):
                raise ValueError('External research must stay private outside this project and remain production-ineligible')
            action=bpy.data.actions.get(e['action'])
            if action is None:
                if not import_missing:raise ValueError('Action missing from saved showcase: '+e['action'])
                imported_armature=None
                try:
                    with bpy.data.libraries.load(str(source),link=linked_research) as (src,dst):
                        if e['action'] not in src.actions or e['source_armature'] not in src.armatures:raise ValueError('Named Action or source armature missing')
                        dst.actions=[e['action']];dst.armatures=[e['source_armature']]
                    action=dst.actions[0];new_actions.append(action);imported_armature=dst.armatures[0]
                    if rest_signature(imported_armature)!=data['rig_sha256']:raise ValueError('Incompatible source rig: '+e['action'])
                    if not linked_research:action.use_fake_user=True
                finally:
                    if imported_armature:bpy.data.armatures.remove(imported_armature)
            if linked_research and (action.library is None or Path(bpy.path.abspath(action.library.filepath)).resolve()!=source):
                raise ValueError('Private research Action must remain linked; do not make a local copy')
            validate_action(action,e,rig)
            key=e.get('preview_prop')
            if key is not None:
                if key not in PREVIEW_PROPS:raise ValueError('Unknown preview prop: '+str(key))
                collection,name,bone=PREVIEW_PROPS[key]
                if collection not in bpy.data.collections:
                    # Import only the prop assembly, never another character or rig.
                    prop_source=(root()/e['preview_prop_source']).resolve()
                    if not prop_source.is_relative_to(root()) or hashlib.sha256(prop_source.read_bytes()).hexdigest()!=e['preview_prop_source_sha256']:raise ValueError('Preview prop source missing or changed')
                    with bpy.data.libraries.load(str(prop_source),link=False) as (src,dst):
                        if 'WEAPON_EXPORT' not in src.collections:raise ValueError('Preview prop collection missing from source')
                        dst.collections=['WEAPON_EXPORT']
                    c=dst.collections[0];c.name=collection;new_props.append(c)
                    scene.collection.children.link(c)
                    o=next(x for x in c.all_objects if x.name==PREVIEW_PROP_ROOTS[key]);o.name=name
                    if any(x.type=='ARMATURE' for x in c.all_objects):raise ValueError('Preview prop must not contain a rig')
                    o.parent=rig;o.parent_type='BONE';o.parent_bone=bone
                    o.matrix_parent_inverse=Matrix.Translation((0,-rig.data.bones[bone].length,0));o.matrix_basis=Matrix.Identity(4)
                    c['gaf_preview_prop']=key
                    for child in list(c.all_objects):
                        if child is None:raise ValueError('Preview prop contains an invalid object')
                        child.hide_render=child.type!='MESH'
                        if child.type=='EMPTY':child.empty_display_size=.025
                validate_preview_prop(e,rig)
        for e in data.get('review_sequences',[]):validate_review_sequence(e)
    except Exception:
        for action in new_actions:bpy.data.actions.remove(action)
        for c in new_props:
            for o in list(c.all_objects):bpy.data.objects.remove(o,do_unlink=True)
            bpy.data.collections.remove(c)
        raise
    current=rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else None
    _switching=True
    try:
        scene.gaf_clips.clear()
        for e in data['animations']:
            clip=scene.gaf_clips.add();clip.name=e['action'];clip.action=e['action'];clip.status=e['status'];clip.entry_json=json.dumps(e)
        scene['gaf_manifest_snapshot']=json.dumps(data)
        index=next((i for i,e in enumerate(data['animations']) if e['action']==current),0)
        scene.gaf_active_index=focused_index(scene,index)
        scene.gaf_error=''
    finally:_switching=False
    activate(scene,scene.gaf_active_index)
    return len(new_actions)

def view(scene,direction):
    name=json.loads(scene[REVIEW_ENTRY])['cameras'][direction] if scene.get(REVIEW_TAG) else 'Showcase_'+direction
    scene.camera=bpy.data.objects[name]
    if scene.get(REVIEW_TAG):
        entry=json.loads(scene[REVIEW_ENTRY])
        if entry.get('hud_root'):
            hud=bpy.data.objects[entry['hud_root']];hud.parent=scene.camera
            hud.matrix_parent_inverse=Matrix.Identity(4);hud.matrix_basis=Matrix.Identity(4)
    for window in bpy.context.window_manager.windows:
        if window.scene==scene:
            for area in window.screen.areas:
                if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'

class GAF_Clip(bpy.types.PropertyGroup):
    action:StringProperty();status:StringProperty();entry_json:StringProperty()

class GAF_UL_animations(bpy.types.UIList):
    def draw_item(self,context,layout,data,item,icon,active_data,active_propname,index):
        layout.label(text=item.action,icon='CHECKMARK' if item.status=='approved' else 'TIME')

class GAF_OT_refresh(bpy.types.Operator):
    bl_idname='gaf.refresh_library';bl_label='Refresh Library';bl_description='Validate manifest and import only registered compatible Actions; never overwrite an Action'
    def execute(self,context):
        try:
            n=refresh(context.scene);self.report({'INFO'},f'Library refreshed; {n} new Actions. Save the showcase to retain imports.')
            return {'FINISHED'}
        except Exception as error:context.scene.gaf_error=str(error);self.report({'ERROR'},str(error));return {'CANCELLED'}

class GAF_OT_play(bpy.types.Operator):
    bl_idname='gaf.play_pause';bl_label='Play / Pause'
    def execute(self,context):
        if not context.screen.is_animation_playing and context.scene.frame_current>=context.scene.frame_end:context.scene.frame_set(context.scene.frame_start)
        bpy.ops.screen.animation_play();return {'FINISHED'}

class GAF_OT_restart(bpy.types.Operator):
    bl_idname='gaf.restart';bl_label='Restart';bl_description='Return to the first playback frame'
    def execute(self,context):context.scene.frame_set(context.scene.frame_start);return {'FINISHED'}

class GAF_OT_view(bpy.types.Operator):
    bl_idname='gaf.view';bl_label='Change Preview View'
    direction:StringProperty(default='THREE_QUARTER')
    def execute(self,context):view(context.scene,self.direction);return {'FINISHED'}

class GAF_OT_open_review_sequence(bpy.types.Operator):
    bl_idname='gaf.open_review_sequence';bl_label='Open Research Sequence'
    sequence_id:StringProperty()
    def execute(self,context):
        try:open_review_sequence(context,self.sequence_id);return {'FINISHED'}
        except Exception as error:context.scene.gaf_error=str(error);self.report({'ERROR'},str(error));return {'CANCELLED'}

class GAF_OT_select_action(bpy.types.Operator):
    bl_idname='gaf.select_action';bl_label='Select Registered Animation'
    action_name:StringProperty()
    def execute(self,context):
        try:select_registered_action(context,self.action_name);return {'FINISHED'}
        except Exception as error:context.scene.gaf_error=str(error);self.report({'ERROR'},str(error));return {'CANCELLED'}

class GAF_OT_return_library(bpy.types.Operator):
    bl_idname='gaf.return_library';bl_label='Return to Animation Library'
    def execute(self,context):
        try:return_library(context);return {'FINISHED'}
        except Exception as error:context.scene.gaf_error=str(error);self.report({'ERROR'},str(error));return {'CANCELLED'}

class GAF_OT_browse_group(bpy.types.Operator):
    bl_idname='gaf.browse_group';bl_label='Browse Animation Group'
    group_id:StringProperty(default='AS_WALKRUN')
    def execute(self,context):
        home=library_home(context.scene)
        if home is None:return {'CANCELLED'}
        home.gaf_library_group=self.group_id;home.gaf_library_search=''
        return {'FINISHED'}

def draw_focus_selector(layout,scene):
    home=library_home(scene)
    data=json.loads(home['gaf_manifest_snapshot']) if home else {}
    if home is None:return False
    all_entries=ordered_library_entries(data,True)
    box=layout.box()
    row=box.row();row.scale_y=1.15
    row.operator('gaf.browse_group',text='A&S - Walking / Running',icon='BOOKMARKS',depress=home.gaf_library_group=='AS_WALKRUN' and not home.gaf_library_search).group_id='AS_WALKRUN'
    box.prop(home,'gaf_library_group',text='Group')
    box.prop(home,'gaf_library_search',text='',icon='VIEWZOOM',placeholder='Search all animations...')
    entries=visible_entries(all_entries,home.gaf_library_group,home.gaf_library_search)
    box.label(text=f'{len(entries)} shown / {len(all_entries)} entries',icon='FILTER')
    if not entries:box.label(text='No matching animations',icon='INFO')
    active=bpy.data.objects[RIG].animation_data.action
    for e in entries:
        row=box.row(align=True)
        row.scale_y=1.15
        if e['kind']=='action':
            row.operator('gaf.select_action',text=e['label'],icon='CHECKMARK' if e['status']=='approved' else 'TIME',depress=bool(scene==home and active and active.name==e['id'])).action_name=e['id']
        else:
            row.operator('gaf.open_review_sequence',text=e['label'],icon='SCENE_DATA',depress=scene.get(REVIEW_TAG)==e['id']).sequence_id=e['id']
    return True

class GAF_PT_animation_library(bpy.types.Panel):
    bl_label='Animation Library';bl_idname='GAF_PT_animation_library';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Animation Library'
    @classmethod
    def poll(cls,context):return bool(context.scene.get(SCENE_TAG) or context.scene.get(REVIEW_TAG))
    def draw(self,context):
        layout=self.layout;s=context.scene
        focused=draw_focus_selector(layout,s)
        if s.get(REVIEW_TAG):
            try:e=json.loads(s[REVIEW_ENTRY])
            except (KeyError,ValueError):layout.label(text='Review registration is missing',icon='ERROR');return
            box=layout.box();box.label(text=e.get('label',e['id']));box.label(text=e['status'].upper()+(' — ORIGINAL MOTION COMPARISON' if e.get('original_authored_comparison') else ' — SOURCE RESEARCH ONLY'),icon='CHECKMARK' if e['status']=='approved' else 'TIME')
            box.label(text=f"F{e['start']}–{e['end']}  |  {e['fps']/e['fps_base']:g} FPS")
            box.label(text='Continuous take; replay resets clocks')
            row=layout.row(align=True);row.operator('gaf.play_pause',text='Pause' if context.screen.is_animation_playing else 'Play',icon='PAUSE' if context.screen.is_animation_playing else 'PLAY');row.operator('gaf.restart',icon='REW')
            layout.prop(s,'gaf_loop',text='Loop playback')
            row=layout.row(align=True)
            for text,direction in [('Front','FRONT'),('3/4','THREE_QUARTER'),('Side','SIDE')]:row.operator('gaf.view',text=text).direction=direction
            layout.operator('gaf.return_library',icon='BACK')
            if s.gaf_error:
                for line in [s.gaf_error[i:i+42] for i in range(0,len(s.gaf_error),42)]:layout.label(text=line,icon='ERROR')
            return
        if not focused:
            layout.template_list('GAF_UL_animations','',s,'gaf_clips',s,'gaf_active_index',rows=5)
        if s.gaf_clips:
            item=s.gaf_clips[s.gaf_active_index];e=json.loads(item.entry_json)
            box=layout.box();box.label(text=item.action);box.label(text=f"F{e['start']}–{e['end']}  |  {e['fps']/e['fps_base']:g} FPS  |  {item.status.upper()}")
            box.label(text='Seamless cycle' if e.get('seamless_loop') else 'One-shot; replay resets to start',icon='INFO')
            if e.get('preview_prop'):box.label(text=PREVIEW_PROP_LABELS[e['preview_prop']],icon='OUTLINER_OB_MESH')
        row=layout.row(align=True);row.operator('gaf.play_pause',text='Pause' if context.screen.is_animation_playing else 'Play',icon='PAUSE' if context.screen.is_animation_playing else 'PLAY');row.operator('gaf.restart',text='Restart',icon='REW')
        if s.gaf_clips and json.loads(s.gaf_clips[s.gaf_active_index].entry_json).get('research_only'):
            layout.label(text='SOURCE RESEARCH ONLY — DO NOT SHIP',icon='INFO')
            layout.label(text='Continuous take; replay resets clocks')
        layout.prop(s,'gaf_loop',text='Loop playback')
        row=layout.row(align=True)
        for text,direction in [('Front','FRONT'),('3/4','THREE_QUARTER'),('Side','SIDE')]:row.operator('gaf.view',text=text).direction=direction
        layout.separator();layout.operator('gaf.refresh_library',icon='FILE_REFRESH')
        primary={e['id'] for e in library_entries(s,False) if e['kind']=='review_sequence'} if focused else set()
        sequences=[e for e in review_entries(s) if not focused]
        if sequences:
            box=layout.box();box.label(text='Research Sequences',icon='SCENE_DATA')
            for e in sequences:box.operator('gaf.open_review_sequence',text=e.get('label',e['id']),icon='SCENE_DATA').sequence_id=e['id']
        if s.gaf_error:
            for line in [s.gaf_error[i:i+42] for i in range(0,len(s.gaf_error),42)]:layout.label(text=line,icon='ERROR')

@persistent
def stop_one_shot(scene,*args):
    if not (scene.get(SCENE_TAG) or scene.get(REVIEW_TAG)) or scene.gaf_loop or scene.frame_current<scene.frame_end:return
    for window in bpy.context.window_manager.windows:
        if window.scene==scene and window.screen.is_animation_playing:
            with bpy.context.temp_override(window=window,screen=window.screen):bpy.ops.screen.animation_cancel(restore_frame=False)

@persistent
def loaded(_):
    # Restore saved list without trusting/running any embedded Python text.
    global _switching
    for s in bpy.data.scenes:
        if not s.get(SCENE_TAG):continue
        try:
            snapshot=json.loads(s['gaf_manifest_snapshot'])
            saved_frame=s.frame_current;saved_subframe=s.frame_subframe
            _switching=True;s.gaf_clips.clear()
            for e in snapshot['animations']:
                c=s.gaf_clips.add();c.name=e['action'];c.action=e['action'];c.status=e['status'];c.entry_json=json.dumps(e)
            s.gaf_active_index=focused_index(s,min(s.gaf_active_index,len(s.gaf_clips)-1))
            _switching=False
            activate(s,s.gaf_active_index)
            s.frame_set(saved_frame,subframe=saved_subframe)
        except Exception as error:s.gaf_error=str(error)
        finally:_switching=False
    for s in bpy.data.scenes:
        if not s.get(REVIEW_TAG):continue
        try:validate_review_sequence(json.loads(s[REVIEW_ENTRY]));s.gaf_error=''
        except Exception as error:s.gaf_error=str(error)

CLASSES=[GAF_Clip,GAF_UL_animations,GAF_OT_refresh,GAF_OT_play,GAF_OT_restart,GAF_OT_view,GAF_OT_open_review_sequence,GAF_OT_select_action,GAF_OT_return_library,GAF_OT_browse_group,GAF_PT_animation_library]
def register():
    for cls in CLASSES:bpy.utils.register_class(cls)
    bpy.types.Scene.gaf_clips=CollectionProperty(type=GAF_Clip)
    bpy.types.Scene.gaf_active_index=IntProperty(default=0,min=0,update=selection_changed)
    bpy.types.Scene.gaf_loop=BoolProperty(default=True)
    bpy.types.Scene.gaf_show_archived=BoolProperty(default=False,update=archive_visibility_changed,description='Show every registered animation without removing or changing archived data')
    bpy.types.Scene.gaf_error=StringProperty()
    bpy.types.Scene.gaf_library_group=EnumProperty(items=FILTER_ITEMS,default='AS_WALKRUN',description='Browse a compact group without removing any animation')
    bpy.types.Scene.gaf_library_search=StringProperty(default='',description='Search names across every group; clear to return to the chosen group')
    bpy.app.handlers.load_post.append(loaded);bpy.app.handlers.frame_change_post.append(stop_one_shot)

def unregister():
    for handlers,fn in [(bpy.app.handlers.load_post,loaded),(bpy.app.handlers.frame_change_post,stop_one_shot)]:
        if fn in handlers:handlers.remove(fn)
    for name in ['gaf_clips','gaf_active_index','gaf_loop','gaf_show_archived','gaf_error','gaf_library_group','gaf_library_search']:delattr(bpy.types.Scene,name)
    for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)
