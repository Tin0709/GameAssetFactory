"""Geometry helpers used only by this additive Blender review study."""
import math

def visible_bounds(mesh,image):
 """Opaque nearest texel support on planar horizontal-ring card quads."""
 W,H=image.size;pixels=list(image.pixels);uvs=mesh.uv_layers['UV_Atlas'];points=[]
 for p in mesh.polygons:
  vs=[mesh.vertices[i].co for i in p.vertices];uv=[uvs.data[i].uv for i in p.loop_indices]
  u0,u1=uv[0].x,uv[1].x;v0,v1=uv[0].y,uv[3].y
  for y in range(max(0,int(v0*H)),min(H,math.ceil(v1*H))):
   for x in range(max(0,int(u0*W)),min(W,math.ceil(u1*W))):
    if pixels[(y*W+x)*4+3]<.5:continue
    for u in [max(u0,x/W),min(u1,(x+1)/W)]:
     for v in [max(v0,y/H),min(v1,(y+1)/H)]:
      s=(u-u0)/(u1-u0);t=(v-v0)/(v1-v0)
      points.append(vs[0]*(1-s)*(1-t)+vs[1]*s*(1-t)+vs[2]*s*t+vs[3]*(1-s)*t)
 return [[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]

def asset_record(obj,image):
 m=obj.data;visible=visible_bounds(m,image)
 return {'name':obj.name,'mesh':m.name,'triangles':sum(len(p.vertices)-2 for p in m.polygons),'vertices':len(m.vertices),'cards':int(obj['cards']),'mesh_xy_size':[max(v.co[i] for v in m.vertices)-min(v.co[i] for v in m.vertices) for i in [0,1]],'root_xy_size':[max(v.co[i] for v in m.vertices if v.co.z<0)-min(v.co[i] for v in m.vertices if v.co.z<0) for i in [0,1]],'visible_xy_size':[b-a for a,b in visible[:2]],'visible_height':visible[2][1],'mesh_height':max(v.co.z for v in m.vertices),'root_z':min(v.co.z for v in m.vertices),'materials':len(m.materials)}
