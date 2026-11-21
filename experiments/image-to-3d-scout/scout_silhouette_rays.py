import bpy
from mathutils import Vector
s=bpy.context.scene
s.frame_set(2)
c=s.camera
d=bpy.context.evaluated_depsgraph_get()
box=c.data.view_frame(scene=s)
x0,x1=min(v.x for v in box),max(v.x for v in box)
y0,y1=min(v.y for v in box),max(v.y for v in box)
z=box[0].z
for y in (378,391,403,412,416,420,425):
 for x in (63,76,86,96,100,104,106,111,117,125,135):
    u=Vector((x0+x/430*(x1-x0),y0+(1-y/575)*(y1-y0),z))
    dn=(c.matrix_world.to_3x3()@u).normalized()
    hit,point,_,_,o,_=s.ray_cast(d,c.matrix_world.translation,dn)
    if hit: print(x,y,o.name,list(point*518/1.8))

