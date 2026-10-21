"""Original rest-based wind deformation, native Geometry Nodes, Blender review."""
import math
import bpy

NAME = 'MD2_Grass_Wind_v001'
CONTROLS = {
    'Wind Enabled': (True, None, None, 'Animate the independent wind copies.'),
    'Wind Direction': (.60, -math.pi, math.pi, 'Global horizontal direction, radians.'),
    'Wind Strength': (.85, 0., 2., 'Overall authored wind amplitude; zero is exact rest.'),
    'Wind Speed': (1., 0., 2., 'Time multiplier; zero freezes the wind field.'),
    'Gust Strength': (.70, 0., 1.5, 'Smooth traveling gust amplitude.'),
    'Gust Frequency': (.05, .01, .15, 'Gust cycles per second before the speed multiplier.'),
    'Per-Clump Variation': (.65, 0., 1., 'Small phase, noise and tip differences.'),
    'Short Grass Response': (.38, 0., 1.5, 'Dense grounded short grass response.'),
    'Tall Grass Response': (1., 0., 1.5, 'More readable tall-grass bending.'),
}


def make_group():
    assert not bpy.data.node_groups.get(NAME), 'Do not replace the completed wind group.'
    tree = bpy.data.node_groups.new(NAME, 'GeometryNodeTree')
    tree.is_modifier = True
    tree.description = 'Pending authored MD2-inspired wind, fixed roots, coherent gusts, tip flutter.'
    sockets = {}
    def socket(name, kind, default=None, lo=None, hi=None, description=''):
        s = tree.interface.new_socket(name=name, in_out='INPUT', socket_type=kind)
        if default is not None: s.default_value = default
        if lo is not None: s.min_value = lo
        if hi is not None: s.max_value = hi
        s.description = description
        sockets[name] = s.identifier
    socket('Geometry', 'NodeSocketGeometry')
    tree.interface.new_socket(name='Geometry', in_out='OUTPUT', socket_type='NodeSocketGeometry')
    for name, (value, lo, hi, description) in CONTROLS.items():
        socket(name, 'NodeSocketBool' if isinstance(value, bool) else 'NodeSocketFloat', value, lo, hi, description)
    socket('World Origin', 'NodeSocketVector', (0., 0., 0.))
    socket('Local Heading', 'NodeSocketFloat', 0.)
    socket('Tall', 'NodeSocketFloat', 0., 0., 1.)
    socket('Clump Phase', 'NodeSocketFloat', 0.)
    nodes, links = tree.nodes, tree.links
    inp = nodes.new('NodeGroupInput'); out = nodes.new('NodeGroupOutput')
    inp.location = (-1400, 0); out.location = (1200, 0)
    counter = 0
    def node(kind, label=''):
        nonlocal counter
        n = nodes.new(kind); n.label = label
        n.location = (-1100 + (counter // 12) * 280, 750 - (counter % 12) * 150)
        counter += 1
        return n
    def put(target, value):
        if isinstance(value, (int, float, tuple, list)): target.default_value = value
        else: links.new(value, target)
    def mathop(operation, a, b=None):
        n = node('ShaderNodeMath', operation); n.operation = operation
        put(n.inputs[0], a)
        if b is not None: put(n.inputs[1], b)
        return n.outputs[0]
    def vecop(operation, a, b):
        n = node('ShaderNodeVectorMath', operation); n.operation = operation
        put(n.inputs[0], a); put(n.inputs[3] if operation == 'SCALE' else n.inputs[1], b)
        return n.outputs['Value' if operation == 'DOT_PRODUCT' else 'Vector']
    def xyz(x, y, z=0.):
        n = node('ShaderNodeCombineXYZ')
        for name, value in zip(['X', 'Y', 'Z'], [x, y, z]): put(n.inputs[name], value)
        return n.outputs[0]
    def attr(name, kind='FLOAT'):
        n = node('GeometryNodeInputNamedAttribute', name); n.data_type = kind
        n.inputs['Name'].default_value = name
        return n.outputs['Attribute']
    def rotate(vector, angle):
        n = node('ShaderNodeVectorRotate'); n.rotation_type = 'AXIS_ANGLE'
        n.inputs['Axis'].default_value = (0., 0., 1.)
        put(n.inputs['Vector'], vector); put(n.inputs['Angle'], angle)
        return n.outputs['Vector']
    add = lambda a, b: mathop('ADD', a, b)
    mul = lambda a, b: mathop('MULTIPLY', a, b)
    sub = lambda a, b: mathop('SUBTRACT', a, b)
    sin = lambda a: mathop('SINE', a)
    cos = lambda a: mathop('COSINE', a)
    power = lambda a, b: mathop('POWER', a, b)
    g = inp.outputs
    t = attr('md2_wind_t'); length = attr('md2_wind_length')
    rest = attr('md2_wind_rest', 'FLOAT_VECTOR')
    phase = attr('md2_wind_phase')
    root_world = vecop('ADD', rotate(attr('md2_wind_root', 'FLOAT_VECTOR'), g['Local Heading']), g['World Origin'])
    direction = xyz(cos(g['Wind Direction']), sin(g['Wind Direction']))
    along = vecop('DOT_PRODUCT', root_world, direction)
    seconds = node('GeometryNodeInputSceneTime').outputs['Seconds']
    time = mul(seconds, g['Wind Speed'])
    p = mul(g['Clump Phase'], g['Per-Clump Variation'])
    noise = node('ShaderNodeTexNoise', 'Slow advected world field'); noise.noise_dimensions = '3D'
    noise.inputs['Scale'].default_value = 1.; noise.inputs['Detail'].default_value = 0.
    put(noise.inputs['Vector'], vecop('ADD', vecop('SCALE', root_world, .23), vecop('SCALE', direction, mul(time, -.18))))
    centered_noise = sub(noise.outputs['Fac'], .5)
    ambient = add(.13, add(mul(sin(add(sub(mul(time, math.tau * .17), mul(along, .62)), mul(p, .25))), .038),
                            add(mul(sin(add(mul(time, math.tau * .31), mul(along, .39))), .025),
                                mul(mul(centered_noise, .065), g['Per-Clump Variation']))))
    gust_phase = mul(sub(sub(mul(time, g['Gust Frequency']), mul(along, .055)), .25), math.tau)
    gust = power(mathop('MAXIMUM', sin(gust_phase), 0.), 4.)
    response = add(g['Short Grass Response'], mul(g['Tall'], sub(g['Tall Grass Response'], g['Short Grass Response'])))
    gain = mul(mul(g['Wind Strength'], response), g['Wind Enabled'])
    bend = mathop('MINIMUM', mul(add(ambient, mul(mul(gust, g['Gust Strength']), .72)), gain), .9)
    side = mul(add(mul(sin(add(mul(time, math.tau * .23), mul(along, .45))), .04), mul(centered_noise, .035)), gain)
    flutter_phase = add(add(mul(time, math.tau * 1.1), phase), add(mul(along, .71), p))
    flutter = mul(mul(mul(add(sin(flutter_phase), mul(sin(add(mul(time, math.tau * 1.7), mul(phase, .7))), .35)), .018),
                          mul(g['Per-Clump Variation'], add(.45, mul(gust, .55)))), gain)
    # Small-angle circular-arc expansion: curvature grows smoothly from the root.
    # Ring pairs keep the same offset/width. No whole-object rocking or drift.
    local_angle = sub(g['Wind Direction'], g['Local Heading'])
    along_local = xyz(cos(local_angle), sin(local_angle))
    side_local = xyz(mul(sin(local_angle), -1.), cos(local_angle))
    main_distance = add(mul(mul(mul(length, .5), power(t, 2.)), bend), mul(mul(length, power(t, 4.)), flutter))
    side_distance = mul(mul(mul(length, .5), power(t, 2.)), side)
    z = mul(mul(mul(length, power(t, 3.)), add(power(bend, 2.), power(side, 2.))), -1. / 6.)
    displacement = vecop('ADD', vecop('ADD', vecop('SCALE', along_local, main_distance), vecop('SCALE', side_local, side_distance)), xyz(0., 0., z))
    setpos = node('GeometryNodeSetPosition', 'Rest + wind (future interaction adds here)')
    links.new(g['Geometry'], setpos.inputs['Geometry'])
    links.new(vecop('ADD', rest, displacement), setpos.inputs['Position'])
    links.new(setpos.outputs['Geometry'], out.inputs['Geometry'])
    tree['review_status'] = 'Pending'
    tree['controls'] = str(list(CONTROLS))
    return tree, sockets


def add_modifier(obj, controller, group, sockets, tall, phase):
    modifier = obj.modifiers.new(NAME, 'NODES'); modifier.node_group = group
    # Blender 5.2 stores inputs in properties.inputs, not modifier ID properties.
    # Driver paths must start on the owning Object (runtime-probed on 5.2.2).
    inputs = modifier.properties.inputs
    def path(name):
        return 'modifiers["' + modifier.name + '"].properties.inputs["' + sockets[name] + '"]["value"]'
    for name, (value, *_rest) in CONTROLS.items():
        inputs[sockets[name]]['value'] = value
    inputs[sockets['World Origin']]['value'] = tuple(obj.location)
    inputs[sockets['Local Heading']]['value'] = obj.rotation_euler.z
    for name in CONTROLS:
        fc = obj.driver_add(path(name))
        variable = fc.driver.variables.new(); variable.name = 'value'; variable.type = 'SINGLE_PROP'
        variable.targets[0].id = controller; variable.targets[0].data_path = '["' + name + '"]'
        fc.driver.expression = 'value'
    for index, axis in enumerate(['X', 'Y', 'Z']):
        fc = obj.driver_add(path('World Origin'), index)
        variable = fc.driver.variables.new(); variable.name = 'value'; variable.type = 'TRANSFORMS'
        variable.targets[0].id = obj; variable.targets[0].transform_type = 'LOC_' + axis
        variable.targets[0].transform_space = 'WORLD_SPACE'; fc.driver.expression = 'value'
    fc = obj.driver_add(path('Local Heading'))
    variable = fc.driver.variables.new(); variable.name = 'value'; variable.type = 'TRANSFORMS'
    variable.targets[0].id = obj; variable.targets[0].transform_type = 'ROT_Z'
    variable.targets[0].transform_space = 'WORLD_SPACE'; fc.driver.expression = 'value'
    inputs[sockets['Tall']]['value'] = float(tall)
    inputs[sockets['Clump Phase']]['value'] = phase
    return modifier
