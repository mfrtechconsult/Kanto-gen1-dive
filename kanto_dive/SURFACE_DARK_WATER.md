# Surface dark-water rendering

Dark water is generated from the exact `DiveZones` cells exported by Tiled. It does not change map collision, encounters, warps or the original map data.

## 2D

The tint is drawn in the tile renderer immediately after the animated water layer and before characters. The hero therefore remains naturally above it.

## World pipelines / Voxel

Gen1Recomp world pipelines expose their projection only during the field-effect composite, after their terrain and character scene has already been rendered. Kanto Dive projects the dark-water polygons through that camera, then redraws the exact live player sprite at the same projected world foot position whenever the player overlaps a dark cell. This prevents the tint from covering the Surf sprite while keeping the patch attached to the 3D ground.

The redraw uses `Player:draw`, so facing, Surf animation, palettes and sprite replacements stay synchronized with the engine. It is limited to the player and only runs while touching a dark-water cell.
