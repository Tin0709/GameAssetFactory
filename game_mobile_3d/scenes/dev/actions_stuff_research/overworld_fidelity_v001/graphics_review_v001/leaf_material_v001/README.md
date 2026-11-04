# Optional source-weighted leaf material

In the existing Overworld lab, press **F7**, then enable **Leaf channels - captured Oak Var2**. Default OFF. Uncheck for the old material; Original restores the session. HDR baseline/Neutral suppress it while retaining the A/B cache. Original/phase/Auto/fault release it.

The original shader uses supplied per-vertex weights for color rotation and linear transmission. A private external profile must identify the loaded source mesh and its imported position/UV/index hashes. The optional linear RGBA8 lookup is sampled by vertex index; no mesh is rebuilt and no reference arrays or textures are embedded here. Missing/changed/unsupported inputs leave the effect disabled. Only a proven matching mesh is affected.

This corrects material inputs, not Godot's complete lighting model. Native material AO, specular/roughness, view-dependent opacity and indirect back irradiance are still separate gaps. BACKLIGHT remains the existing Godot approximation of native two-sided light integration. Other tree variants retain their previous material.

Private validation is under Research `godot_lab/leaf_vertex_material_v001`: same-input GPU response/native GBuffer comparison, importer-order audit, actual-scene A/B/restoration/gameplay, fault injection, profile guards and paired desktop timing. The current lookup payload is6208B, with one optional vertex sample/two interpolated weights and no extra render pass. Actual handset30/60/120Hz validation is still required.
