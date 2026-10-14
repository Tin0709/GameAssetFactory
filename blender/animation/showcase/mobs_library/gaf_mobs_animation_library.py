bl_info = {'name':'Mobs Animation Library','author':'GameAssetFactory','version':(1,0,0),'blender':(5,2,0),'location':'3D View > N > Mobs Animation Library','description':'Independent native-rig mob animation review library','category':'Animation'}
import bpy,json,hashlib,re,time
from bpy.props import StringProperty,IntProperty,EnumProperty,CollectionProperty,BoolProperty
from bpy.app.handlers import persistent

TAG='gaf_mobs_library'
STATUSES=[(v,v,'') for v in ['Pending','Approved','Rejected','Backup']]
_busy=False
_enum_cache={}

def registry(scene):
    data=json.loads(scene.get('mobs_registry','{"schema":1,"mobs":[],"clips":[]}'))
    if data.get('schema')!=1:raise ValueError('Unsupported mob library schema')
    return data

def store(scene,data):
    scene['mobs_registry']=json.dumps(data,ensure_ascii=False)

def mob_items(self,context):
    # EnumProperty keeps pointers to returned strings: retain every item list.
    try:key=tuple((m['id'],m['label']) for m in registry(self)['mobs'])
    except Exception:key=()
    if key not in _enum_cache:_enum_cache[key]=[(ident,label,'') for ident,label in key]
    return _enum_cache[key]

def action_signature(action):
    channels=[]
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for c in bag.fcurves:
                    channels.append((c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points]))
    return hashlib.sha256(json.dumps(channels,sort_keys=True).encode()).hexdigest()

def register_mob(scene,mob_id,label,collection,rig):
    data=registry(scene)
    if rig.type!='ARMATURE' or rig not in list(collection.all_objects):raise ValueError('Mob rig must belong to its collection')
    if any(m['id']==mob_id or m['rig']==rig.name or m['collection']==collection.name for m in data['mobs']):raise ValueError('Mob ID, rig and collection must be unique')
    if any(set(collection.all_objects)&set(bpy.data.collections[m['collection']].all_objects) for m in data['mobs']):raise ValueError('Mob collections may not share objects')
    data['mobs'].append({'id':mob_id,'label':label,'collection':collection.name,'rig':rig.name})
    store(scene,data)

def register_clip(scene,mob_id,action,start,end,fps,slot):
    data=registry(scene)
    if not any(m['id']==mob_id for m in data['mobs']):raise ValueError('Unknown mob')
    if any(c['action']==action.name for c in data['clips']):raise ValueError('Action already registered; create a new revision')
    if slot not in list(action.slots) or slot.target_id_type!='OBJECT':raise ValueError('Invalid native Action slot')
    if end<start or fps<=0:raise ValueError('Invalid playback range or frame rate')
    mob=next(m for m in data['mobs'] if m['id']==mob_id);rig=bpy.data.objects[mob['rig']]
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    if not re.fullmatch(r'pose\.bones\["[^"\n]+"\]\.(location|rotation_euler|rotation_quaternion|rotation_axis_angle|scale)',curve.data_path):
                        raise ValueError('Only pose-bone transforms are supported; bake travel/custom properties separately')
                    try:values=rig.path_resolve(curve.data_path)
                    except Exception:raise ValueError('Action targets a bone absent from this mob rig')
                    if not 0<=curve.array_index<len(values):raise ValueError('Invalid bone transform channel index')
    action.use_fake_user=True;action['review_status']='Pending'
    data['clips'].append({'mob':mob_id,'action':action.name,'slot':slot.identifier,'start':int(start),'end':int(end),'fps':int(fps),'status':'Pending'})
    store(scene,data)

def current(scene):
    if not scene.mobs_clips:return None
    i=min(scene.mobs_active_index,len(scene.mobs_clips)-1)
    return json.loads(scene.mobs_clips[i].entry_json)

def reset_rig(rig):
    if rig.animation_data:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks:track.mute=True
    for pb in rig.pose.bones:
        pb.location=(0,0,0);pb.rotation_euler=(0,0,0);pb.rotation_quaternion=(1,0,0,0);pb.rotation_axis_angle=(0,0,1,0);pb.scale=(1,1,1)

def activate(scene):
    if not scene.get(TAG):return
    try:
        data=registry(scene)
        if not data['mobs']:return
        selected=scene.mobs_mob
        # Validate every reference before changing the preview.
        for mob in data['mobs']:
            if mob['rig'] not in bpy.data.objects or mob['collection'] not in bpy.data.collections:raise ValueError('Missing mob rig/collection; restore the saved library')
        clip=current(scene);action=None;slot=None
        if clip:
            action=bpy.data.actions.get(clip['action'])
            if action is None:raise ValueError('Missing Action: '+clip['action'])
            slot=next((s for s in action.slots if s.identifier==clip['slot']),None)
            if slot is None:raise ValueError('Missing native Action slot')
        for mob in data['mobs']:
            rig=bpy.data.objects[mob['rig']];reset_rig(rig)
            col=bpy.data.collections[mob['collection']]
            col.hide_viewport=mob['id']!=selected;col.hide_render=mob['id']!=selected
        if clip:
            mob=next(m for m in data['mobs'] if m['id']==selected)
            rig=bpy.data.objects[mob['rig']];rig.animation_data_create()
            rig.animation_data.action=action;rig.animation_data.action_slot=slot
            scene.render.fps=clip['fps'];scene.render.fps_base=1
            scene.frame_start=clip['start'];scene.frame_end=clip['end']
            scene.use_preview_range=False;scene.frame_set(clip['start'])
            if rig.name in bpy.context.view_layer.objects:
                for ob in bpy.context.selected_objects:ob.select_set(False)
                rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
        else:
            scene.frame_start=1;scene.frame_end=1;scene.frame_set(1)
        scene.mobs_error=''
    except Exception as exc:scene.mobs_error=str(exc)

def rebuild(scene):
    global _busy
    if not scene.get(TAG):return
    try:
        _busy=True;scene.mobs_clips.clear()
        for clip in registry(scene)['clips']:
            if clip['mob']!=scene.mobs_mob:continue
            item=scene.mobs_clips.add();item.name=clip['action'];item.status=clip['status'];item.entry_json=json.dumps(clip)
        scene.mobs_active_index=min(scene.mobs_active_index,max(0,len(scene.mobs_clips)-1))
    finally:_busy=False

def changed_mob(scene,context):
    if _busy:return
    scene.mobs_active_index=0;rebuild(scene);activate(scene)

def changed_clip(scene,context):
    if not _busy:activate(scene)

class MOBS_Clip(bpy.types.PropertyGroup):
    status:StringProperty();entry_json:StringProperty()

class MOBS_UL_clips(bpy.types.UIList):
    def draw_item(self,context,layout,data,item,icon,active_data,active_propname,index):
        row=layout.row();row.label(text=item.name,icon={'Pending':'TIME','Approved':'CHECKMARK','Rejected':'CANCEL','Backup':'FILE_BACKUP'}.get(item.status,'ACTION'))

class MOBS_OT_play(bpy.types.Operator):
    bl_idname='mobs.play_pause';bl_label='Play / Pause'
    def execute(self,context):
        if not current(context.scene):return {'CANCELLED'}
        if not context.screen.is_animation_playing and context.scene.frame_current>=context.scene.frame_end:context.scene.frame_set(context.scene.frame_start)
        bpy.ops.screen.animation_play();return {'FINISHED'}

class MOBS_OT_restart(bpy.types.Operator):
    bl_idname='mobs.restart';bl_label='Restart'
    def execute(self,context):context.scene.frame_set(context.scene.frame_start);return {'FINISHED'}

class MOBS_OT_status(bpy.types.Operator):
    bl_idname='mobs.set_status';bl_label='Set Review Status'
    status:EnumProperty(items=STATUSES)
    def execute(self,context):
        scene=context.scene;clip=current(scene)
        if not clip:return {'CANCELLED'}
        data=registry(scene)
        entry=next(c for c in data['clips'] if c['action']==clip['action'])
        action=bpy.data.actions[clip['action']]
        old=entry['status'];entry['status']=self.status;action['review_status']=self.status
        if self.status=='Approved':action['approved_signature']=action_signature(action)
        data.setdefault('review_history',[]).append({'action':action.name,'from':old,'to':self.status,'utc_epoch':time.time()})
        store(scene,data);rebuild(scene)
        self.report({'INFO'},'Status updated. Save the Blender file to retain the decision.')
        return {'FINISHED'}

class MOBS_OT_revision(bpy.types.Operator):
    bl_idname='mobs.new_revision';bl_label='New Revision Copy';bl_description='Duplicate the selected Action as Pending; preserve the original'
    name:StringProperty(name='New Action Name')
    def invoke(self,context,event):
        clip=current(context.scene)
        if not clip:return {'CANCELLED'}
        match=re.search(r'_V(\d+)$',clip['action'])
        base=clip['action'][:match.start()] if match else clip['action']
        version=int(match.group(1))+1 if match else 2
        while base+'_V'+str(version) in bpy.data.actions:version+=1
        self.name=base+'_V'+str(version)
        return context.window_manager.invoke_props_dialog(self,width=440)
    def execute(self,context):
        scene=context.scene;clip=current(scene)
        name=self.name.strip()
        if not clip or not name or name in bpy.data.actions:
            self.report({'WARNING'},'Choose a unique Action name; existing Actions are never overwritten.');return {'CANCELLED'}
        original=bpy.data.actions[clip['action']];new=original.copy();new.name=name
        if 'approved_signature' in new:del new['approved_signature']
        slot=next(s for s in new.slots if s.identifier==clip['slot'])
        register_clip(scene,clip['mob'],new,clip['start'],clip['end'],clip['fps'],slot)
        rebuild(scene);scene.mobs_active_index=len(scene.mobs_clips)-1;activate(scene)
        self.report({'INFO'},'Pending revision created. Save the Blender file.')
        return {'FINISHED'}

class MOBS_OT_view(bpy.types.Operator):
    bl_idname='mobs.view';bl_label='Preview View'
    direction:EnumProperty(items=[('THREE_QUARTER','3/4',''),('FRONT','Front',''),('SIDE','Side','')])
    def execute(self,context):
        cam=bpy.data.objects.get('Mobs Camera '+self.direction)
        if cam:context.scene.camera=cam
        for area in context.screen.areas:
            if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
        return {'FINISHED'}

class MOBS_PT_library(bpy.types.Panel):
    bl_label='Mobs Animation Library';bl_idname='MOBS_PT_library';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Mobs Animation Library'
    @classmethod
    def poll(cls,context):return bool(context.scene.get(TAG))
    def draw(self,context):
        s=context.scene;l=self.layout
        l.prop(s,'mobs_mob',text='Mob')
        l.template_list('MOBS_UL_clips','',s,'mobs_clips',s,'mobs_active_index',rows=4)
        c=current(s)
        if c:
            box=l.box();box.label(text=c['action'])
            box.label(text=f"{(c['end']-c['start']+1)/c['fps']:.2f} s  |  {c['fps']} FPS  |  F{c['start']}–{c['end']}")
            box.label(text='Status: '+c['status'],icon='TIME' if c['status']=='Pending' else 'INFO')
        else:l.label(text='No animations registered for this mob.')
        row=l.row(align=True);row.enabled=bool(c)
        row.operator('mobs.play_pause',text='Pause' if context.screen.is_animation_playing else 'Play',icon='PAUSE' if context.screen.is_animation_playing else 'PLAY')
        row.operator('mobs.restart',text='Restart',icon='REW')
        l.prop(s,'mobs_loop',text='Loop playback')
        row=l.row(align=True)
        for label,direction in [('Front','FRONT'),('3/4','THREE_QUARTER'),('Side','SIDE')]:row.operator('mobs.view',text=label).direction=direction
        l.separator();l.operator_menu_enum('mobs.set_status','status',text='Set Review Status')
        l.operator('mobs.new_revision',icon='DUPLICATE')
        l.label(text='Save file to keep review decisions.',icon='INFO')
        if s.mobs_error:
            for start in range(0,len(s.mobs_error),38):l.label(text=s.mobs_error[start:start+38],icon='ERROR')

@persistent
def loaded(_):
    for scene in bpy.data.scenes:
        if scene.get(TAG):
            try:rebuild(scene);activate(scene)
            except Exception as exc:scene.mobs_error=str(exc)

@persistent
def stop_at_end(scene,*args):
    if not scene.get(TAG) or scene.mobs_loop or scene.frame_current<scene.frame_end:return
    for window in bpy.context.window_manager.windows:
        if window.scene==scene and window.screen.is_animation_playing:
            with bpy.context.temp_override(window=window,screen=window.screen):bpy.ops.screen.animation_cancel(restore_frame=False)

CLASSES=[MOBS_Clip,MOBS_UL_clips,MOBS_OT_play,MOBS_OT_restart,MOBS_OT_status,MOBS_OT_revision,MOBS_OT_view,MOBS_PT_library]
def initialize_after_registration():
    if hasattr(bpy.types.Scene,'mobs_clips'):loaded(None)
    return None

def register():
    if hasattr(bpy.types.Scene,'mobs_clips'):return
    for cls in CLASSES:bpy.utils.register_class(cls)
    bpy.types.Scene.mobs_clips=CollectionProperty(type=MOBS_Clip)
    bpy.types.Scene.mobs_mob=EnumProperty(name='Mob',items=mob_items,update=changed_mob)
    bpy.types.Scene.mobs_active_index=IntProperty(default=0,min=0,update=changed_clip)
    bpy.types.Scene.mobs_loop=BoolProperty(default=True)
    bpy.types.Scene.mobs_error=StringProperty()
    bpy.app.handlers.load_post.append(loaded);bpy.app.handlers.frame_change_post.append(stop_at_end)
    # Blender restricts bpy.data during add-on registration. Scene access must wait.
    bpy.app.timers.register(initialize_after_registration,first_interval=.1)

def unregister():
    if bpy.app.timers.is_registered(initialize_after_registration):bpy.app.timers.unregister(initialize_after_registration)
    for handlers,fn in [(bpy.app.handlers.load_post,loaded),(bpy.app.handlers.frame_change_post,stop_at_end)]:
        if fn in handlers:handlers.remove(fn)
    for prop in ['mobs_clips','mobs_mob','mobs_active_index','mobs_loop','mobs_error']:
        if hasattr(bpy.types.Scene,prop):delattr(bpy.types.Scene,prop)
    for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)

if __name__=='__main__':register()
