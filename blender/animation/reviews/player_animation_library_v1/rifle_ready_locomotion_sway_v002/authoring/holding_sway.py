"""Gait-driven rifle overlap, informed by the accepted gameplay landing carry.

Only upper-body twist and holding overlap change; legs/body bounce stay intact.
The source crossbow layer cancels 80% of body yaw; restore a bounded portion to
the upper torso/holding set, with independently authored lag; existing roll is retained.
This addition is an adaptation, not a newly discovered crossbow source clip.
"""
import math
from mathutils import Matrix

SETTINGS = {
    'Walk': {'yaw_deg': 3., 'lag_s': .060, 'roll_deg': 0., 'roll_lag_s': .080, 'holding_seat_m': 0.},
    'Run': {'yaw_deg': 9., 'lag_s': .040, 'roll_deg': 0., 'roll_lag_s': .060, 'holding_seat_m': .005},
}
HOLD = ['UpperArm.R', 'ForeArm.R', 'WeaponCarrier', 'UpperArm.L', 'ForeArm.L']

def yaw_angle(kind, t, entry):
    p = SETTINGS[kind]
    phase = entry['source_phase_origin'] + t * entry['phase_rate_cycles_s']
    a = 2 * math.pi * (phase - p['lag_s'] * entry['phase_rate_cycles_s'])
    # Exact phase convention of the original Walk/Run body-yaw expressions;
    # the amount, upper-body mask and lag are this refinement.
    yaw = p['yaw_deg'] * (math.sin(a) if kind == 'Run' else -math.cos(a + math.radians(40)))
    return math.radians(yaw)

def apply(kind, t, entry, source, rest, palm):
    M = {n: m.copy() for n, m in source.items()}
    yaw = yaw_angle(kind, t, entry)
    C = M['Chest'].to_3x3()
    # The liked runtime carry is Chest-led, not a loose weapon-only oscillation.
    # Rotate the upper torso and holding set together about the source body
    # pivot at the seated head base; shoulder attachment and vertical bounce
    # remain intact. Keep the existing world-space head observation unchanged.
    pivot = M['Head'].translation.copy()
    T = Matrix.Translation(pivot) @ Matrix.Rotation(yaw, 4, C.col[1].normalized()) @ Matrix.Translation(-pivot)
    for n in ['Chest', 'Neck'] + HOLD:
        M[n] = T @ M[n]
    # Millimetre-only native square-block clearance for the stronger twist.
    # The complete assembly moves together, retaining both original contacts.
    seat = Matrix.Translation(M['Chest'].to_3x3().col[1].normalized() * SETTINGS[kind]['holding_seat_m'])
    for n in HOLD:
        M[n] = seat @ M[n]
    # Retain the approved waist roll, crossbow bob and living left-support
    # curves exactly. An additional holding roll was rejected by the actual
    # rifle/leg geometry probe; the Chest-led yaw is the approved-gameplay cue.
    return M
