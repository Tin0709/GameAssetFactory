"""One deterministic field cache/upload and a neutral review proxy, no blade physics."""
import json
import math
import time
import bpy
import numpy as np
from bpy.app.handlers import persistent
from field import CONTROLS, FieldCache, route, phase

_cache=None;_key=None;_last=None;_updating=False


def record(scene=None):
    return json.loads((scene or bpy.context.scene).get('md2_interaction_review','{}'))


def params(scene=None):
    info=record(scene)
    return {k:bpy.data.objects[info['controller']][k] for k in CONTROLS}


def ensure_cache(scene=None):
    global _cache,_key,_last
    p=params(scene);key=tuple(float(p[k]) for k in CONTROLS if k!='Player Interaction On/Off')
    if key!=_key:
        start=time.perf_counter();_cache=FieldCache(p);_key=key;_last=None
        print('MD2_INTERACTION_CACHE',round(time.perf_counter()-start,3),_cache.frames.shape,flush=True)
    return _cache


def update(scene=None,force=False):
    global _last,_updating
    scene=scene or bpy.context.scene;info=record(scene)
    if _updating or not info:return
    if not force and bpy.context.view_layer.name!=info['layer']:return
    _updating=True
    try:
        cache=ensure_cache(scene);p=params(scene);speed=float(p['Walk/Run Preview Speed'])
        seconds=(scene.frame_current+scene.frame_subframe)/(scene.render.fps/scene.render.fps_base)
        signature=(_key,seconds,bool(p['Player Interaction On/Off']))
        if not force and signature==_last:return
        _last=signature
        image=bpy.data.images[info['image']]
        image.pixels.foreach_set(cache.rgba(seconds).ravel());image.update()
        # A single shared tag also refreshes every user when controls change while paused.
        bpy.data.node_groups[info['group']].update_tag()
        pos,vel=route(seconds,speed);moving=float(np.linalg.norm(vel))
        previous_velocity=vel
        if moving<.01:
            for offset in [.05,.2,.5,1.,2.,3.]:
                previous_velocity=route(max(0.,seconds-offset),speed)[1]
                if np.linalg.norm(previous_velocity)>.01:break
        heading=math.atan2(previous_velocity[1],previous_velocity[0])+math.pi/2 if np.linalg.norm(previous_velocity)>.01 else 0.
        root=bpy.data.objects[info['proxy']['root']];root.location=(float(pos[0]),float(pos[1]),1.)
        root.rotation_euler.z=heading
        gait=cache.travelled(seconds)*math.tau/1.25
        strength=min(1.,moving/.9);swing=math.sin(gait)*(.30+min(moving,4.)*.055)*strength
        root.location.z+=abs(math.sin(gait))*.025*strength
        for part,sign in [('leg_l',1),('leg_r',-1),('arm_l',-1),('arm_r',1)]:
            bpy.data.objects[info['proxy'][part]].rotation_euler.x=sign*swing
        controller=bpy.data.objects[info['controller']]
        # Status is UI information on this new controller only.
        status=phase(seconds,speed)
        if controller.get('Preview Phase')!=status:controller['Preview Phase']=status
        if scene.get('md2_interaction_view_active'):
            end=round(cache.duration*scene.render.fps/scene.render.fps_base)
            if scene.frame_preview_end!=end:
                scene.frame_end=max(scene.frame_end,end);scene.frame_preview_end=end
    finally:_updating=False


@persistent
def frame_update(scene,*_):update(scene)


@persistent
def paused_update(scene,*_):update(scene)


def register():
    for handlers,fn in [(bpy.app.handlers.frame_change_pre,frame_update),(bpy.app.handlers.depsgraph_update_post,paused_update)]:
        for old in list(handlers):
            if getattr(old,'__module__','')==__name__:handlers.remove(old)
        handlers.append(fn)


def unregister():
    for handlers in [bpy.app.handlers.frame_change_pre,bpy.app.handlers.depsgraph_update_post]:
        for old in list(handlers):
            if getattr(old,'__module__','')==__name__:handlers.remove(old)
