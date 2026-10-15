"""Explicit source hierarchy -> unchanged native rest rig, no pose repair/IK."""
import math
from mathutils import Matrix,Vector

class JumpRetarget:
    def __init__(self,rig):
        self.base={b.name:b.matrix.copy() for b in rig.pose.bones}
        self.unit=self.base['Hips'].translation.z/12
        self.C=Matrix(((-1,0,0),(0,0,1),(0,1,0)))
        self.Ci=self.C.inverted()

    def transform(self,v,pivot):
        x,y,z=map(math.radians,v['rotation'])
        rot=(self.C@(Matrix.Rotation(z,3,'Z')@Matrix.Rotation(-y,3,'Y')@Matrix.Rotation(-x,3,'X'))@self.Ci).to_4x4()
        x,y,z=v['position'];pos=Vector((x,z,y))*self.unit
        x,y,z=v['scale'];scale=Matrix.Diagonal((x,z,y,1.))
        return Matrix.Translation(pos)@Matrix.Translation(pivot)@rot@scale@Matrix.Translation(-pivot)

    def desired(self,v,entity_head=True):
        b=self.base
        root=self.transform(v['root'],Vector())
        waist=root@self.transform(v['waist'],b['Hips'].translation)
        body=waist@self.transform(v['body'],b['Head'].translation)
        d={'Root':root@b['Root']}
        for n in ['Hips','Spine']:d[n]=waist@b[n]
        for n in ['Chest','Neck','WeaponCarrier']:d[n]=body@b[n]
        head_local=self.transform(v['head'],b['Head'].translation)
        if entity_head:
            # Entity-relative orientation; preserve source local translation and
            # inherited root scale. Nonuniform rotated ancestors can require
            # shear compensation that the native TRS rig cannot represent.
            # Cancel only ancestor rotations; leave source scale inherited.
            # This yields native TRS without silently removing root squash.
            pure=[]
            for name in ['root','waist','body']:
                neutral=dict(v[name],position=[0,0,0],scale=[1,1,1])
                pure.append(self.transform(neutral,Vector()).to_3x3())
            ancestor=pure[0]@pure[1]@pure[2]
            local=ancestor.inverted().to_4x4()@head_local
            head=body@local@b['Head']
            x,y,z=v['head']['position']
            head.translation=(body@b['Head']).translation+body.to_3x3()@(Vector((x,z,y))*self.unit)
            d['Head']=head
        else:d['Head']=body@head_local@b['Head']
        for side,src in [('L','leftarm'),('R','rightarm')]:
            n='UpperArm.'+side
            arm=body@self.transform(v[src],b[n].translation-Vector((0,0,2*self.unit)))
            d[n]=arm@b[n];d['ForeArm.'+side]=arm@b['ForeArm.'+side]
            n='Leg.'+side
            d[n]=root@self.transform(v['leftleg' if side=='L' else 'rightleg'],b[n].translation)@b[n]
        return d
