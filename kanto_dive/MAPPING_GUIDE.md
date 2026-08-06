# Kanto Dive map authoring — paired Tiled regions

Kanto Dive 1.5.0 uses explicit paired regions, closer to Pokémon Emerald. You decide in Tiled both **where DIVE is allowed on the surface** and **where the matching cells exist underwater**.

## The three layers

- `Blocks`: the underwater map, on the normal 32 px Gen 1 block grid.
- `DiveZones` (blue): surface-space rectangles or polygons where DIVE is allowed.
- `DiveLandings` (green): underwater-space rectangles or polygons where the player arrives and may use SURFACE.

Every blue object must have a green object with the same `linkId` property or object name. Their local cell shape and dimensions must match. Their absolute positions may be completely different.

Example:

```text
DiveZones / reef_path       surface Route 20: (12, 4), size 8 x 3
DiveLandings / reef_path    underwater map:  (30, 9), size 8 x 3
```

Surface `(12,4)` maps to underwater `(30,9)`. Surface `(17,6)` maps to underwater `(35,11)`. Moving underwater to `(33,10)` and using SURFACE returns to surface `(15,5)`.

This is a real bidirectional coordinate translation, not a return-to-entry teleport.

## Creating a region

1. Draw a rectangle or polygon on `DiveZones` at the surface coordinates.
2. Set its name or `linkId`, for example `reef_path`.
3. Draw the same-sized rectangle or the same local polygon shape on `DiveLandings`.
4. Give it the same name or `linkId`.
5. Drag the green object to the exact underwater landing location you want.

Large seas, narrow passages and irregular coastlines can all use separate paired objects. Multiple regions may target different parts of the same underwater map.

## Surface coloration

The blue `DiveZones` data is also the source for dark surface water. Only cells that are both marked and actually water in the original surface map are darkened. You never paint the dark water separately.

## Polygons

Polygon vertices must be aligned to the 16 px movement grid. The converter rasterizes the polygon into linked movement cells. The paired landing polygon must have exactly the same local shape, but it may be translated anywhere on the underwater map.

## Map properties

Required map properties:

```text
mapId       = KD_MY_SEAFLOOR
label       = KantoDiveMySeafloor
index       = 1200
borderBlock = 15
surfaceMap  = ROUTE_19
```

A `DiveZones` object may override `surfaceMap` with an object property when one underwater map links to several surface maps. Optional object properties are `diveFacing` and `surfaceFacing`; both default to `same`.

## Converting

```bash
python3 authoring/tiled_to_kanto_dive.py authoring/my_route.tmx \
  --map-out maps/KD_MY_ROUTE_SEAFLOOR.lua \
  --link-out data/links/my_route.lua
```

The link output contains one independent link per paired Tiled object.

## Included editable examples

- `authoring/route19_reef_passage.tmx` — two separated surface squares connected by one underwater corridor
- `authoring/route20_seafloor.tmx`
- `authoring/route21_trench.tmx`
- `authoring/route_template.tmx`

Open the examples and toggle the blue and green layers. Dragging a green region changes the underwater landing coordinates without changing the surface zone.

## Registering generated files

Add the map to `data/maps.lua`, then add its link file and underwater maps to `data/zones.lua`. The Route 19, Route 20 and Route 21 entries are working examples.

## Runtime rules

- DIVE appears only while surfing on a marked surface-water cell.
- SURFACE appears only on the paired underwater cell.
- Every link is bidirectional.
- SURF is removed and rejected underwater because the player is already using the Surf movement state and sprite.
- The underwater map song plays while the Surf sprite and collision state remain active.

## Compact two-entrance passage example

`route19_reef_passage.tmx` demonstrates two independent surface regions that
land in the same underwater map. The left and right `DiveLandings` rectangles
cover square chambers, while the `Blocks` layer joins those chambers with a
narrow corridor. Corridor cells are traversable but have no paired
`DiveZones`, so SURFACE is available only inside the two square chambers.
