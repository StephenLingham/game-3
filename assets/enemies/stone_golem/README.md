Ancient stone golem
==================

Opening enemy type (index 0): 100 HP, movement speed 3.2, original collision
and contact damage. The opening minute spawns only this type.

Concept and textured mesh generated using Scenario MCP in Default Project,
Pentex 1's Organization. Art direction: ancient stone golem, Studio Ghibli
inspired painterly textures, carved spirals, moss, amber eyes.

- Concept: asset_P4LZwN6iYUqQpTJy8485FfYU (FLUX.1 Schnell)
- Source mesh: asset_pzsbBvUMqtHu1KxfxzHbnDqr (Tripo 3.1)
- Animated model saved back to Scenario: asset_xZSBvXKDoZ8S61zmVBh5CXF1
- Runtime: stone_golem.glb, 5,910 triangles, 16 bones, 1.35 units tall,
  facing Godot -Z; embedded Walk animation is 1.6 seconds and loops in place.

Rigging and walk animation authored locally in Blender because Scenario's
humanoid rigging/animation models required an upgraded plan. Rebuild with:

    blender --background --python tools/rig_stone_golem.py

Source mesh and concept are preserved under tools/golem_source, excluded
from Godot's runtime resource scan. The runtime importer extracts its texture
beside the GLB. Walking pauses when frozen or held by a vortex and uses the
actual movement speed for playback. Godot controls world movement.
