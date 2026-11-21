"""Add a bounded pose-driven cape return on the Scout experiment."""
import bpy
from mathutils import Matrix

def add(rig, scene, scale):
    name="Scout Canon | Long cloak with tapered supporting folds"
    cape=scene.objects[name]
    # Preserve the rest pose and side silhouette. The reserve elbow of the
    # drape opens behind whichever upper leg rotates backward.
    for side in ("L","R"):
        key=cape.shape_key_add(name="Rear clearance "+side)
        baseline=cape.data.shape_keys.key_blocks[0]
        sign=1 if side=="L" else -1
        for item,reference in zip(key.data,baseline.data):
            x,y,z=reference.co/scale
            drift=max(0.0,min(1.0,(238-z)/105))
            side_factor=max(0.0,min(1.0,.4+sign*x/60))
            item.co.y+=.22*drift*side_factor
        driver=key.driver_add("value").driver
        driver.type="SCRIPTED"
        v=driver.variables.new()
        v.name="swing"
        v.type="TRANSFORMS"
        target=v.targets[0]
        target.id=rig
        target.bone_target="Leg."+side
        target.transform_type="ROT_X"
        target.transform_space="LOCAL_SPACE"
        target.rotation_mode="XYZ"
        driver.expression="0 if frame == 2 else max(0.0, min(1.0, (-swing + 0.08) / 0.75))"

