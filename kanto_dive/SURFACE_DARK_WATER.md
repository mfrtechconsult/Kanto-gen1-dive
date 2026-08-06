# Surface dark-water rendering

Dark water is generated from the exact `DiveZones` cells exported by Tiled. It does not change map collision, encounters, warps or the original map data.

## 2D and Tilt

The tint is drawn in the tile renderer immediately after the animated water layer and before characters. The hero therefore remains naturally above it. Tilt transforms that already-composited terrain normally.

## World pipelines / Voxel

The linked cell runs are projected through the active world pipeline's `ctx.drawFx` camera. Each run becomes a quadrilateral following camera angle and perspective, so the same Tiled-authored DIVE zones remain visible in Voxel mode.

World pipelines composite field effects after their terrain and character pass. To prevent the dark projection from covering the hero, Kanto Dive redraws the exact live player sprite at the same projected foot position whenever the player overlaps a dark cell. Facing, Surf animation, palette and sprite replacements remain synchronized because the normal `Player:draw` path is reused.
