"""Persistent, scene-local Animation Library controls for GameAssetFactory."""
bl_info={'name':'GameAssetFactory Animation Library','author':'GameAssetFactory','version':(1,0,0),'blender':(5,2,0),'location':'3D View > N > Animation Library','description':'Select and review independent character Actions','category':'Animation'}
import bpy,json,hashlib,re,math
from pathlib import Path
from bpy.app.handlers import persistent
from bpy.props import StringProperty,IntProperty,BoolProperty,CollectionProperty

SCENE_TAG='gaf_animation_showcase';RIG='Showcase_Player_Rig';BASELINE='GAF_Neutral_Pose.json'
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
    if data.get('schema')!=1 or not isinstance(data.get('animations'),list):raise ValueError('Unsupported animation manifest')
    names=[e['action'] for e in data['animations']]
    if not names or len(names)!=len(set(names)):raise ValueError('Animation names must be nonempty and unique')
    for e in data['animations']:
        if e['status'] not in ['approved','pending']:raise ValueError('Use approved or pending status explicitly')
        validate_timing(e)
    return data

def validate_timing(e):
    if any(type(e[k]) is not int for k in ['start','end','fps']):raise ValueError('Playback frame bounds and FPS must be integers; use fps_base for fractional rates')
    if not (1<=e['start']<=e['end']<=1048574 and 1<=e['fps']<=32767 and isinstance(e['fps_base'],(int,float)) and math.isfinite(e['fps_base']) and 1e-5<=e['fps_base']<=1e6):raise ValueError('Invalid frame range or timing')
    floor=e.get('preview_floor_z_m',0.0)
    if type(floor) not in [int,float] or not math.isfinite(floor) or not -10<=floor<=10:raise ValueError('Invalid preview floor height')

def validate_action(action,entry,rig):
    validate_timing(entry)
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
        if c.data_path.endswith('scale') and any(abs(k.co.y-1)>1e-6 for k in c.keyframe_points):raise ValueError('Animated limb scaling is not supported')

def activate(scene,index):
    if not scene.get(SCENE_TAG) or not scene.gaf_clips:return
    e=json.loads(scene.gaf_clips[index].entry_json);rig=bpy.data.objects[RIG];a=bpy.data.actions[e['action']]
    validate_action(a,e,rig)
    # Partial Actions must not inherit a previous clip's unkeyed legs/chest.
    rig.animation_data_create();rig.animation_data.action=None
    neutral=json.loads(bpy.data.texts[BASELINE].as_string())
    for bone in rig.pose.bones:
        for key,value in neutral[bone.name].items():setattr(bone,key,value)
    rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
    scene.frame_start=e['start'];scene.frame_end=e['end'];scene.render.fps=e['fps'];scene.render.fps_base=e['fps_base']
    scene.use_preview_range=False;scene.sync_mode='NONE';scene.frame_set(e['start'])
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
    new_actions=[]
    try:
        # Validate the complete request before replacing the visible list/selection.
        for e in data['animations']:
            source=(root()/e['source']).resolve()
            if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest()!=e['source_sha256']:raise ValueError('Source missing or changed: '+e['source'])
            action=bpy.data.actions.get(e['action'])
            if action is None:
                if not import_missing:raise ValueError('Action missing from saved showcase: '+e['action'])
                imported_armature=None
                try:
                    with bpy.data.libraries.load(str(source),link=False) as (src,dst):
                        if e['action'] not in src.actions or e['source_armature'] not in src.armatures:raise ValueError('Named Action or source armature missing')
                        dst.actions=[e['action']];dst.armatures=[e['source_armature']]
                    action=dst.actions[0];new_actions.append(action);imported_armature=dst.armatures[0]
                    if rest_signature(imported_armature)!=data['rig_sha256']:raise ValueError('Incompatible source rig: '+e['action'])
                    action.use_fake_user=True
                finally:
                    if imported_armature:bpy.data.armatures.remove(imported_armature)
            validate_action(action,e,rig)
    except Exception:
        for action in new_actions:bpy.data.actions.remove(action)
        raise
    current=rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else None
    _switching=True
    try:
        scene.gaf_clips.clear()
        for e in data['animations']:
            clip=scene.gaf_clips.add();clip.name=e['action'];clip.action=e['action'];clip.status=e['status'];clip.entry_json=json.dumps(e)
        scene.gaf_active_index=next((i for i,e in enumerate(data['animations']) if e['action']==current),0)
        scene['gaf_manifest_snapshot']=json.dumps(data)
        scene.gaf_error=''
    finally:_switching=False
    activate(scene,scene.gaf_active_index)
    return len(new_actions)

def view(scene,direction):
    scene.camera=bpy.data.objects['Showcase_'+direction]
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

class GAF_PT_animation_library(bpy.types.Panel):
    bl_label='Animation Library';bl_idname='GAF_PT_animation_library';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Animation Library'
    @classmethod
    def poll(cls,context):return bool(context.scene.get(SCENE_TAG))
    def draw(self,context):
        layout=self.layout;s=context.scene
        layout.template_list('GAF_UL_animations','',s,'gaf_clips',s,'gaf_active_index',rows=5)
        if s.gaf_clips:
            item=s.gaf_clips[s.gaf_active_index];e=json.loads(item.entry_json)
            box=layout.box();box.label(text=item.action);box.label(text=f"F{e['start']}–{e['end']}  |  {e['fps']/e['fps_base']:g} FPS  |  {item.status.upper()}")
            box.label(text='Seamless cycle' if e.get('seamless_loop') else 'One-shot; replay resets to start',icon='INFO')
        row=layout.row(align=True);row.operator('gaf.play_pause',text='Pause' if context.screen.is_animation_playing else 'Play',icon='PAUSE' if context.screen.is_animation_playing else 'PLAY');row.operator('gaf.restart',text='Restart',icon='REW')
        layout.prop(s,'gaf_loop',text='Loop playback')
        row=layout.row(align=True)
        for text,direction in [('Front','FRONT'),('3/4','THREE_QUARTER'),('Side','SIDE')]:row.operator('gaf.view',text=text).direction=direction
        layout.separator();layout.operator('gaf.refresh_library',icon='FILE_REFRESH')
        if s.gaf_error:
            for line in [s.gaf_error[i:i+42] for i in range(0,len(s.gaf_error),42)]:layout.label(text=line,icon='ERROR')

@persistent
def stop_one_shot(scene,*args):
    if not scene.get(SCENE_TAG) or scene.gaf_loop or scene.frame_current<scene.frame_end:return
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
            _switching=True;s.gaf_clips.clear()
            for e in snapshot['animations']:
                c=s.gaf_clips.add();c.name=e['action'];c.action=e['action'];c.status=e['status'];c.entry_json=json.dumps(e)
            s.gaf_active_index=min(s.gaf_active_index,len(s.gaf_clips)-1)
            _switching=False
            activate(s,s.gaf_active_index)
        except Exception as error:s.gaf_error=str(error)
        finally:_switching=False

CLASSES=[GAF_Clip,GAF_UL_animations,GAF_OT_refresh,GAF_OT_play,GAF_OT_restart,GAF_OT_view,GAF_PT_animation_library]
def register():
    for cls in CLASSES:bpy.utils.register_class(cls)
    bpy.types.Scene.gaf_clips=CollectionProperty(type=GAF_Clip)
    bpy.types.Scene.gaf_active_index=IntProperty(default=0,min=0,update=selection_changed)
    bpy.types.Scene.gaf_loop=BoolProperty(default=True)
    bpy.types.Scene.gaf_error=StringProperty()
    bpy.app.handlers.load_post.append(loaded);bpy.app.handlers.frame_change_post.append(stop_one_shot)

def unregister():
    for handlers,fn in [(bpy.app.handlers.load_post,loaded),(bpy.app.handlers.frame_change_post,stop_one_shot)]:
        if fn in handlers:handlers.remove(fn)
    for name in ['gaf_clips','gaf_active_index','gaf_loop','gaf_error']:delattr(bpy.types.Scene,name)
    for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)
