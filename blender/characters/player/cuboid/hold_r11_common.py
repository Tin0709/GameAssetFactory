"""Simple straight-arm R11 study. No IK, contact solver, elbow or torso compensation."""
from hold_r10wh1_common import *
import ast
OUT=BASE/'weapon_hold_r11_review'
# Long guns pin their actual trigger centre to the right hand end.
# Pistol's grip sits in the upper part of the block hand, leaving its slide visible.
TRIGGER={'Rifle':Vector((0,.118,.080)),'Shotgun':Vector((0,.088,.050)),'Pistol':Vector((0,0,-.115))}
ATTACHMENT_SCALE={'Rifle':.84,'Shotgun':.70,'Pistol':1.0}
# User: enlarge 25%, THEN narrow local X by 15%; Y/Z remain 125%.
STUDY_GUN_SCALE={cat:(base*1.25*.85,base*1.25,base*1.25) for cat,base in ATTACHMENT_SCALE.items()}
GUN_OFFSET={'Rifle':(.065,.035),'Shotgun':(.060,.140),'Pistol':(0,0)} # forward, up; metres

def clone_r11(label,s,cat):
    r,m,ws=clone_r10('R11_'+label,s,cat)
    for o in list(s.objects):
        if o.name.startswith('R10WH1_R11_'):o.name=o.name.replace('R10WH1_R11_','R11_',1)
    next(w for w in ws if '_Base' in w.name).parent.scale=STUDY_GUN_SCALE[cat]
    return r,m,ws

def simple_pose(r,socket,cat,yaw=0,breath=0):
    assign(r,None)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4);p.rotation_mode='QUATERNION'
    # One shared scan yaw. No chest/head counterrotation or delayed arm mechanic.
    r.pose.bones['Chest'].rotation_quaternion=Quaternion((0,1,0),math.radians(yaw))
    r.pose.bones['Spine'].location=(0,.002*breath,0)
    r.pose.bones['Head'].rotation_quaternion=Quaternion((0,0,1),math.radians(2))
    bpy.context.view_layer.update();ch=r.pose.bones['Chest'].matrix.copy()
    # Chest local axes: x=lateral, y=up, z=forward.
    # Canonical front/top/underside images: raised, almost horizontal cuboids.
    # Right reaches farther forward; left crosses to the rear of that hand.
    directions={'R':Vector((.2955,-.10,.9506)).normalized(),'L':Vector((-.30,-.07,.95)).normalized()}
    for side in ['R','L']:
        u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side]
        y=(ch.to_3x3()@directions[side]).normalized();x=ch.to_3x3()@Vector((1,0,0));x=(x-y*x.dot(y)).normalized();z=x.cross(y).normalized()
        rot=Matrix((x,y,z)).transposed().to_4x4();rot.translation=u.head.copy();u.matrix=rot;bpy.context.view_layer.update()
        rot.translation=u.tail.copy();fo.matrix=rot;bpy.context.view_layer.update()
    tip=r.pose.bones['ForeArm.R'].tail.copy()
    forward=(ch.to_3x3()@Vector((0,0,1))).normalized();up=(ch.to_3x3()@Vector((0,1,0))).normalized();x=forward.cross(up).normalized()
    # Crossbow references have no rear firearm stock. Fit the dev long guns
    # to the same straight-arm reach rather than lowering/bending that pose.
    orient=Matrix((x,forward,up)).transposed()
    gm=(orient@Matrix.Diagonal(Vector(STUDY_GUN_SCALE[cat]))).to_4x4()
    offset=GUN_OFFSET[cat]
    # Keep the approved grip placement while enlarging the weapon around it.
    gm.translation=tip-(orient@TRIGGER[cat])*ATTACHMENT_SCALE[cat]+forward*offset[0]+up*offset[1]
    r.pose.bones['WeaponCarrier'].matrix=gm@socket.inverted();bpy.context.view_layer.update()

tree=ast.parse((BASE/'review_onearm_r9w4.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='compose'],type_ignores=[]),'<unchanged gait composition>','exec'))

def studio(name):
    assert name not in bpy.data.scenes
    s=scene(name);bpy.context.window.scene=s;s.render.resolution_x=1600;s.render.resolution_y=800;s.render.fps=24;s.eevee.taa_render_samples=16
    for ob in list(s.objects):
        if ob.type=='LIGHT':s.collection.objects.unlink(ob)
    for ob in bpy.data.scenes['R10WH1_REVIEW_RIFLE_HOLD'].objects:
        if ob.type=='LIGHT':s.collection.objects.link(ob)
    return s

def label(s,cam,text,x,size=.12):
    font=bpy.data.curves.new('R11_Label','FONT');font.body=text;font.align_x='CENTER';font.size=size
    ob=bpy.data.objects.new(font.name,font);s.collection.objects.link(ob);ob.parent=cam;ob.location=(x,cam.data.ortho_scale/(s.render.resolution_x/s.render.resolution_y)/2-.17,-10)
