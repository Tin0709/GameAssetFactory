"""Additive native interaction layer; the original Wind tree is never edited."""
import bpy
from field import NAME, BOUNDS


def make_group(image):
    assert NAME not in bpy.data.node_groups
    tree = bpy.data.node_groups.new(NAME, 'GeometryNodeTree'); tree.is_modifier = True
    tree.description = 'Pending original shared-field interaction on incoming Wind; immutable roots.'
    sockets = {}
    for name, kind, value in [('Geometry', 'NodeSocketGeometry', None),
                              ('Enabled', 'NodeSocketBool', True),
                              ('World Origin', 'NodeSocketVector', (0.,0.,0.)),
                              ('Local Heading', 'NodeSocketFloat', 0.),
                              ('Response', 'NodeSocketFloat', 1.)]:
        s = tree.interface.new_socket(name=name, in_out='INPUT', socket_type=kind)
        if value is not None: s.default_value = value
        sockets[name] = s.identifier
    tree.interface.new_socket(name='Geometry', in_out='OUTPUT', socket_type='NodeSocketGeometry')
    nodes, links = tree.nodes, tree.links
    inp = nodes.new('NodeGroupInput'); out = nodes.new('NodeGroupOutput'); counter = 0
    inp.location = (-1500,0); out.location = (1600,0)
    def node(kind, label=''):
        nonlocal counter
        n = nodes.new(kind); n.label = label
        n.location = (-1200+(counter//10)*280,800-(counter%10)*170); counter+=1
        return n
    def put(target, value):
        if isinstance(value,(float,int,tuple,list)): target.default_value=value
        else: links.new(value,target)
    def m(op,a,b=None):
        n=node('ShaderNodeMath',op); n.operation=op; put(n.inputs[0],a)
        if b is not None: put(n.inputs[1],b)
        return n.outputs[0]
    def v(op,a,b):
        n=node('ShaderNodeVectorMath',op);n.operation=op;put(n.inputs[0],a)
        put(n.inputs[3] if op=='SCALE' else n.inputs[1],b)
        return n.outputs['Value' if op=='DOT_PRODUCT' else 'Vector']
    def xyz(x,y,z=0.):
        n=node('ShaderNodeCombineXYZ')
        for key,val in zip(['X','Y','Z'],[x,y,z]):put(n.inputs[key],val)
        return n.outputs[0]
    def sep(vector):
        n=node('ShaderNodeSeparateXYZ');put(n.inputs[0],vector);return n.outputs
    def attr(name,kind='FLOAT'):
        n=node('GeometryNodeInputNamedAttribute',name);n.data_type=kind;n.inputs['Name'].default_value=name
        return n.outputs['Attribute']
    def rotate(vector,angle):
        n=node('ShaderNodeVectorRotate');n.rotation_type='AXIS_ANGLE';n.inputs['Axis'].default_value=(0.,0.,1.)
        put(n.inputs['Vector'],vector);put(n.inputs['Angle'],angle);return n.outputs[0]
    g=inp.outputs;position=node('GeometryNodeInputPosition').outputs[0]
    rest=attr('md2_wind_rest','FLOAT_VECTOR');root=attr('md2_wind_root','FLOAT_VECTOR')
    t=attr('md2_wind_t');length=attr('md2_wind_length')
    world=sep(v('ADD',rotate(root,g['Local Heading']),g['World Origin']))
    xmin,xmax,ymin,ymax=BOUNDS
    uv=xyz(m('DIVIDE',m('SUBTRACT',world['X'],xmin),xmax-xmin),m('DIVIDE',m('SUBTRACT',world['Y'],ymin),ymax-ymin))
    sample=node('GeometryNodeImageTexture','One shared spring field; immutable root UV')
    sample.inputs['Image'].default_value=image;sample.extension='EXTEND';sample.interpolation='Linear'
    put(sample.inputs['Vector'],uv)
    channels=sep(sample.outputs['Color'])
    field=xyz(m('MULTIPLY',m('SUBTRACT',channels['X'],.5),2.),m('MULTIPLY',m('SUBTRACT',channels['Y'],.5),2.))
    inside=m('MULTIPLY',m('MULTIPLY',m('GREATER_THAN',world['X'],xmin),m('LESS_THAN',world['X'],xmax)),m('MULTIPLY',m('GREATER_THAN',world['Y'],ymin),m('LESS_THAN',world['Y'],ymax)))
    contact=v('SCALE',rotate(field,m('MULTIPLY',g['Local Heading'],-1.)),m('MULTIPLY',g['Response'],inside))
    wind=v('SUBTRACT',position,rest);w=sep(wind)
    arc_weight=m('MULTIPLY',m('MULTIPLY',length,.5),m('POWER',t,2.))
    wind_angle=v('SCALE',xyz(w['X'],w['Y']),m('DIVIDE',1.,m('MAXIMUM',arc_weight,.00001)))
    total=v('ADD',wind_angle,contact)
    magnitude=m('SQRT',v('DOT_PRODUCT',total,total))
    bounded=v('SCALE',total,m('MINIMUM',1.,m('DIVIDE',1.1,m('MAXIMUM',magnitude,.00001))))
    xy=sep(v('SCALE',bounded,arc_weight))
    z_correction=m('MULTIPLY',m('MULTIPLY',m('MULTIPLY',length,m('POWER',t,3.)),-1./6.),m('SUBTRACT',v('DOT_PRODUCT',bounded,bounded),v('DOT_PRODUCT',wind_angle,wind_angle)))
    combined=v('ADD',rest,xyz(xy['X'],xy['Y'],m('ADD',w['Z'],z_correction)))
    active=m('MULTIPLY',g['Enabled'],m('GREATER_THAN',v('DOT_PRODUCT',contact,contact),1e-14))
    switch=node('GeometryNodeSwitch','Exact incoming Wind when disabled / zero / outside');switch.input_type='VECTOR'
    put(switch.inputs['Switch'],active);put(switch.inputs['False'],position);put(switch.inputs['True'],combined)
    setpos=node('GeometryNodeSetPosition','Incoming Wind + bounded contact curvature')
    links.new(g['Geometry'],setpos.inputs['Geometry']);links.new(switch.outputs[0],setpos.inputs['Position'])
    links.new(setpos.outputs[0],out.inputs['Geometry'])
    tree['review_status']='Pending';tree['original_wind_unchanged']=True
    return tree,sockets


def add_modifier(obj,controller,group,sockets,response):
    mod=obj.modifiers.new(NAME,'NODES');mod.node_group=group
    inputs=mod.properties.inputs
    def path(name):return 'modifiers["'+mod.name+'"].properties.inputs["'+sockets[name]+'"]["value"]'
    inputs[sockets['Response']]['value']=response
    inputs[sockets['World Origin']]['value']=tuple(obj.location)
    inputs[sockets['Local Heading']]['value']=obj.rotation_euler.z
    fc=obj.driver_add(path('Enabled'));var=fc.driver.variables.new();var.name='value';var.type='SINGLE_PROP'
    var.targets[0].id=controller;var.targets[0].data_path='["Player Interaction On/Off"]';fc.driver.expression='value'
    for name,axes in [('World Origin',['LOC_X','LOC_Y','LOC_Z']),('Local Heading',['ROT_Z'])]:
        for i,axis in enumerate(axes):
            fc=obj.driver_add(path(name),i) if name=='World Origin' else obj.driver_add(path(name))
            var=fc.driver.variables.new();var.name='value';var.type='TRANSFORMS'
            var.targets[0].id=obj;var.targets[0].transform_type=axis;var.targets[0].transform_space='WORLD_SPACE'
            fc.driver.expression='value'
    return mod
