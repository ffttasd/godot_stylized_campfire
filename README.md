# Stylized Campfire

Standalone Godot 4.6 stylized campfire effect.

## Files

- `scenes/campfire_stylized.tscn`: the clean standalone campfire scene
- `scenes/campfire_preview.tscn`: minimal preview scene with camera and floor
- `scripts/stylized_fire_effect.gd`: fire flicker and ember driver
- `shaders/*.gdshader`: flame, ground glow, and ember shaders

## Use

Open this folder as a Godot project, or copy `scenes`, `scripts`, and `shaders` into another Godot project.

The asset has no texture dependency. The hidden smoke plume from the source project was intentionally removed to keep the share package clean.
