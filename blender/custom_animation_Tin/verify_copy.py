import bpy, json, os
images = [im for im in bpy.data.images if im.source == 'FILE']
missing = [im.filepath for im in images if not im.packed_file and not os.path.isfile(bpy.path.abspath(im.filepath))]
result = dict(file=bpy.data.filepath, actions=len(bpy.data.actions),
              armatures=len(bpy.data.armatures), meshes=len(bpy.data.meshes),
              images=len(images), missing_images=missing,
              linked_libraries=[lib.filepath for lib in bpy.data.libraries])
print('TIN_COPY_VERIFIED ' + json.dumps(result))
assert bpy.data.armatures and bpy.data.meshes
assert not missing, missing
assert not bpy.data.libraries, 'Practice copy must be independent'
