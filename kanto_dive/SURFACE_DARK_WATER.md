# Surface dark-water rendering

Dark water is generated from the exact `DiveZones` cells exported by Tiled. It does not change map collision, encounters, warps or the original map data.

## 2D and Tilt

The tint is drawn in the tile renderer immediately after the animated water layer and before characters. The hero therefore remains naturally above it. Tilt transforms that already-composited terrain normally.

## World pipelines / Voxel

Kanto Dive does not draw a post-composite tint in world-pipeline renderers. Their `drawFx` projection runs after terrain and characters, so a translucent polygon becomes a broad screen-space shadow and cannot participate in the pipeline depth buffer.

DIVE and SURFACE remain fully functional in Voxel mode. The water stays at its normal material until Gen1Recomp exposes a supported per-cell terrain-material or pre-character geometry hook.
