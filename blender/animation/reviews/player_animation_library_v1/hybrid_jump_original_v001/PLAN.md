# Original MD2-foundation / A&S-inspired Jump implementation plan

Authorized by the user's new Jump request. Existing Walk/Run remain Pending; no status promotion or Godot integration. Reuse the existing 13-bone original Showcase character and central Animation_Showcase.blend.

- [ ] Pin110existing Action signatures,72registrations/5reviews, rig rest and all Godot source/config bytes; back up the shared library before edits.
- [ ] Author independent Takeoff0.40s, Airborne0.80s loop, Landing0.30s Actions. MD2 source durations0.40/0.30 are factual timing references, not copied pose keys. Original asymmetry, quick arm release, bounded head motion,45mm rigid-hip compression and a diminishing landing recovery; unit scales and straight full limbs. No imposed grounded anticipation delay.
- [ ] Build a complete normal-time context take with separate presentation elevation:0.52s flight,0.25s apex time,1.20m height. This preserves the previously accepted lab's approximate snappy trajectory style; it is an ORIGINAL PREVIEW ADAPTER, not recovered native MD2 physics. Runtime captures show~0.52s flights but terrain/capsule coordinates prevent equating recorded height to a flat-ground arc.
- [ ] Check actual saved pose/phase boundaries, sole contact/penetration, unit scale, helper identity, angular continuity, landing settlement, front/side/three-quarter frames and normal-time playback. Correct findings before publishing.
- [ ] Append only the new Pending Actions and one context review to the existing library; preserve old signatures/metadata, save/reopen/select and verify unchanged Godot. Open the working Blender review and produce an actual-render GIF for artistic review.

Physics owns world elevation. The source library's in-place air phases may place a sole below Root; their declared constant preview-floor offset is inspection framing, not a foot solver. Actual grounded contacts are checked in the complete context with its presentation arc. The landing uses hidden rigid-leg-origin compensation for hip compression, not rubber scale or added articulation. Moving/turning/terrain integration is deferred until artistic approval.
