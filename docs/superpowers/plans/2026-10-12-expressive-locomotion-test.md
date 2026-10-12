# Expressive locomotion integration test

Goal: a separate playable Godot review scene using approved Idle v3, refined Walk and Run v3. Production locomotion, WorldMap, all weapon scripts, Blender sources and the Showcase remain unchanged. No jump.

Architecture: retain the current CharacterBody3D controller contract and R15 sole-pose-writer / subsequent upper-body layers through test-only subclasses. Read-only Blender export samples the three approved Actions with their exact slots into a compact Godot animation library on the existing full-arm runtime skeleton. Validate rest transforms and reconstructed mesh geometry rather than silently retargeting. No new character Action is authored.

Use a shared normalized gait phase (LEFT receiving 0, RIGHT receiving .5), stride distance 1.08m Walk / 1.54m Run, speed anchors .9 / 2.31m/s, continuous speed-based pose blend, and actual distance-based cadence. Input immediately moves the capsule and interrupts idle attention; short inertial pose offsets preserve the current head/arm position and velocity. Contacts use the unequal authored support duties. Runtime-only single-foot replant handles the idle stance difference; world contact anchors compensate bounded translation during acceleration and turning. No fictitious knees or ankles, no scaling.

Files: new assets/characters/expressive_locomotion_v1 exporter/library/README; new scenes/dev/ExpressiveLocomotionTest.tscn, test controller/visual/scene scripts; new tests/validate_expressive_locomotion.gd; isolated review evidence. Update existing animation progress/workflow/AGENTS after verification. No project.godot or existing production script edits.

Implementation and validation:
- [x] Capture concurrency hashes and back up documentation.
- [x] Add failing runtime test for approved clips, immediate response, continuous phase, contacts, stop/restart, both leads and upper-body layer isolation.
- [x] Export exact approved Actions read-only; verify rest/slots, geometry, durations and loop endpoints/velocity.
- [x] Implement isolated pose writer/controller, individual foot replant, scene and input controls.
- [x] Run real Godot tests at 30 and 60 render FPS, inspect runtime pixels, capture original-speed review, repair observed defects.
- [x] Document controls, contact and transition measurements, remaining rigid-leg/turn/weapon/mobile limits. Verify protected file hashes and reopen the test scene. Pending gameplay review only.

Review focus: short taps during both idle observation directions; stopping from both support legs; acceleration across support/flight duty changes; 90/180-degree turns; weapon masks keeping the same lower gait. Flat-ground prototype only. Slope/terrain, actual weapon combat transitions and physical phone performance need subsequent validation.

Latest review refinement: 1.5x movement/cadence, normal-speed Idle; 1x and 2x comparison modes preserved. Fresh 41 checks per run at 30/60 FPS, no production promotion.
