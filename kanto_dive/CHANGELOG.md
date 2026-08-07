# Changelog

## 1.5.3

- Added the GitHub repository identifier used by the Gen1Recomp launcher and Mod Index for update tracking.
- Switched the release ZIP to the Mod Index-compatible layout with `manifest.json` at the archive root.
- No gameplay behaviour changed from 1.5.2.

## 1.5.2

- Fixed duplicate player/mount rendering over dark DIVE zones in Voxel mode when Dramatic Sky Ride is active.
- Kanto Dive now detects Dramatic Sky Ride flight, ground-ride and water-ride states through its public exports.
- While Dramatic Sky Ride owns the mounted player render, Kanto Dive no longer calls `Player:draw()` a second time from its post-world DIVE tint pass.
- Preserved the existing dark DIVE-zone projection in Voxel mode and the normal 2D/Tilt rendering path.

## 1.5.1

- Restored always-visible dark DIVE zones in Voxel mode following playtest feedback.
- Restored projection of the exact linked surface regions through the active world-pipeline camera.
- Restored the live Surf player redraw above projected dark water so the hero remains readable.
- Kept the Route 19 compact two-entrance reef passage introduced in 1.5.0.

## 1.5.0

- Removed the post-composite world-pipeline tint that appeared as a large shadow in Voxel mode.
- Kept dark DIVE water in 2D and Tilt, where it is rendered below characters.
- Added Route 19 Reef Passage with two separated 4 x 4 surface DIVE squares.
- Added a compact underwater map with two square chambers connected by a two-cell-high corridor.
- Added an editable `route19_reef_passage.tmx` example and updated authoring documentation.

## 1.4.0

- Replaced the global-origin Tiled link model with paired `DiveZones` and `DiveLandings` objects.
- Each paired region now has an independently authored underwater landing origin.
- Added rectangle and 16 px-aligned polygon support.
- Added editable Route 20 and Route 21 TMX source maps.
- Fixed world-pipeline/Voxel layering by redrawing the live Surf player above projected dark water.
- Kept underwater SURF suppression from 1.3.0.

## 1.3.0

- Replaced invisible decorative marker objects with a direct dark-water tint.
- Darkens every valid surface DIVE cell while preserving the normal water animation.
- Draws the tint before characters in 2D and Tilt modes.
- Projects the same linked regions onto the ground in the Voxel pipeline.
- Removes SURF from party submenus while underwater.
- Blocks SURF through the field-move eligibility hook during an underwater session.
- Defers underwater visual indicators to a later release.

## 1.2.1

- Replaced the unused `world.marker_descriptors` hook with real decorative map objects.
- Surface whirlpools and underwater light columns now render through the normal world entity pipeline.
- Added six-frame true-colour animations shared by flat, Tilt and Voxel renderers.
- Made marker objects passable, non-interactive and sorted beneath the player.
- Filters visual markers against the actual water cells on both linked maps.
- Removed stale authoring layers and generated Python cache files from the release.

## 1.2.0

- Added permanent renderer-neutral DIVE/SURFACE marker descriptors.
- Added pixel-art surface whirlpool and underwater bubble assets.
- Added Voxel world-space ring, halo, light-column and particle descriptors.
- Simplified Tiled authoring to one `DiveZones` layer.
- Removed one-way DIVE/SURFACE modes; all links are bidirectional.

## [1.1.0] - 2026-08-06

### Added
- Emerald-style coordinate links between surface and underwater cells.
- Independent `both`, `dive` and `surface` cell permissions through rectangles or masks.
- Full-size Route 20 and Route 21 underwater layers matching their surface-map coordinates.
- Tiled block atlas, TMX template and converter for authoring new underwater maps.
- A dedicated map catalog and link-file workflow for expanding Kanto route by route.

### Changed
- The Surf mount sprite and bobbing animation now remain active underwater.
- SURFACE now uses the current underwater coordinate, allowing entry at one point and emergence at another.
- DIVE is available only on explicitly mapped deep-water cells.
- Underwater traversable tiles use water collision so the engine cannot auto-dismount the player.

## [1.0.0] - 2026-08-05

### Added
- HM06 DIVE as a teachable Water move and field action.
- Volcano Badge progression through the Cinnabar Lab Metronome scientist.
- Route 20 Seafloor, Seafoam Sunken Cave and Route 21 Trench.
- Original true-colour underwater tileset and complete map collision data.
- Wild encounter tables for all three underwater maps.
- Save/load recovery for orphaned underwater sessions.
- Public exports for other mods to register additional dive zones.
