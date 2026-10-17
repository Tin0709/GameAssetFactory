"""Gait-driven rifle overlap, informed by the accepted gameplay landing carry.

Only upper-body twist and holding overlap change; legs/body bounce stay intact.
The source crossbow layer cancels 80% of body yaw; restore a bounded portion to
the weapon/arms, with independently authored lag and restrained counter-roll.
This addition is an adaptation, not a newly discovered crossbow source clip.
"""
import math
from mathutils import Matrix, Vector

SETTINGS = {
    'Walk': {'yaw_deg': 4.8, 'lag_s': .060, 'roll_deg': .35, 'roll_lag_s': .080},
    'Run': {'yaw_deg': 12., 'lag_s': .040, 'roll_deg': .85, 'roll_lag_s': .060},
}
HOLD = ['UpperArm.R', 'ForeArm.R', 'WeaponCarrier', 'UpperArm.L', 'ForeArm.L']

def angles(kind, t, entry):
    p = SETTINGS[kind]
    phase = entry['source_phase_origin'] + t * entry['phase_rate_cycles_s']
    a = 2 * math.pi * (phase - p['lag_s'] * entry['phase_rate_cycles_s'])
    ar = 2 * math.pi * (phase - p['roll_lag_s'] * entry['phase_rate_cycles_s'])
    # Exact phase convention of the original Walk/Run body-yaw expressions;
    # the amount, holding-only mask, lag and counter-roll are this refinement.
    yaw = p['yaw_deg'] * (math.sin(a) if kind == 'Run' else -math.cos(a + math.radians(40)))
    roll = p['roll_deg'] * (math.cos(ar) if kind == 'Run' else math.cos(ar + math.radians(45)))
    return math.radians(yaw), math.radians(roll)

def apply(kind, t, entry, source, rest, palm):
    M = {n: m.copy() for n, m in source.items()}
    yaw, roll = angles(kind, t, entry)
    C = M['Chest'].to_3x3()
    # The liked runtime carry is Chest-led, not a loose weapon-only oscillation.
    # Rotate the upper torso and holding set together about the source body
    # pivot at the seated head base; shoulder attachment and vertical bounce
    # remain intact. Keep the existing world-space head observation unchanged.
    pivot = M['Head'].translation.copy()
    T = Matrix.Translation(pivot) @ Matrix.Rotation(yaw, 4, C.col[1].normalized()) @ Matrix.Translation(-pivot)
    for n in ['Chest', 'Neck'] + HOLD:
        M[n] = T @ M[n]
    # A much smaller delayed roll supplies hand/weapon overlap. Keep the right
    # shoulder fixed in the twisting torso rather than detaching it from Chest.
    pivot = M['UpperArm.R'].translation.copy()
    T = Matrix.Translation(pivot) @ Matrix.Rotation(roll, 4, M['Chest'].to_3x3().col[2].normalized()) @ Matrix.Translation(-pivot)
    for n in HOLD:
        M[n] = T @ M[n]
    # Keep the source's tiny moving support point in rifle space, and seat the
    # support shoulder at the closest reachable original native socket. This is
    # a whole-arm rotation; no elbow, stretch, mesh or rest-rig alteration.
    P = M['ForeArm.L'] @ palm
    socket = (M['Chest'] @ rest['Chest'].inverted() @ rest['UpperArm.L']).translation + C.col[0].normalized() * .004
    q = (M['UpperArm.L'].translation - P).rotation_difference(socket - P)
    D = Matrix.Translation(P) @ q.to_matrix().to_4x4() @ Matrix.Translation(-P)
    for n in ['UpperArm.L', 'ForeArm.L']:
        M[n] = D @ M[n]
    return M
