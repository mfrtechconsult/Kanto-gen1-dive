# Kanto Dive

Kanto Dive adds **HM06 DIVE** and Emerald-style coordinate-linked underwater
layers to Gen1Recomp. The mod is written and distributed entirely in English.

## Included content

- Route 20 Seafloor, sized to the complete Route 20 coordinate grid
- Seafoam Sunken Cave
- Route 21 Trench, sized to the complete Route 21 coordinate grid
- Explicit deep-water cells where DIVE and SURFACE are permitted
- Surf mount sprite and bobbing animation preserved underwater
- Original underwater tileset and wild encounters
- Tiled authoring tools for expanding the system route by route
- Permanently darkened surface water on every usable DIVE cell
- Surface tint integrated into 2D, Tilt and Voxel rendering

No ROM-derived graphics or audio are included.

## Installation

Copy the `kanto_dive` directory into Gen1Recomp's `mods` directory:

```text
<gen1recomp>/mods/kanto_dive/manifest.json
```

Enable **Kanto Dive** in the F10 mod manager, then restart the game when asked.

## Obtaining HM06

1. Defeat Blaine and obtain the Volcano Badge.
2. Visit the Metronome Room in the Cinnabar Pokemon Lab.
3. Talk to the scientist who normally gives TM35.
4. He gives HM06 without removing or replacing the original TM35 reward.

## Using DIVE and SURFACE

Teach HM06 to a compatible Pokemon and Surf onto a mapped deep-water cell on
Route 20 or Route 21. DIVE appears in that Pokemon's party submenu only when
that exact cell has an underwater link.

Every usable surface cell is covered by a darker water tint. The normal water
animation remains visible beneath it. The tint is generated from the same
coordinate-link data as DIVE, so an unlinked cell is never darkened.

The underwater layer uses the same movement coordinates as the surface map.
Moving underwater changes the emergence point: SURFACE maps the current
underwater cell back to its paired surface cell, like Pokemon Emerald.

SURFACE appears only on underwater cells explicitly marked as exits. It is not
available inside Seafoam Sunken Cave.

The vanilla SURF action is removed from party submenus while underwater. The
player is already using Surf movement there, so mounting or dismounting again
is not permitted.

The player remains in the engine's Surf movement state underwater. This keeps
the Surf mount sprite, bobbing animation and water collision continuous while
the underwater map's own music plays.

## Map authoring

Read [`MAPPING_GUIDE.md`](MAPPING_GUIDE.md). The `authoring` directory contains:

- a 32 px block atlas for Tiled;
- a reusable TMX template;
- a converter that generates a Gen1Recomp map file and coordinate-link file.

New maps are listed in `data/maps.lua`. New links are attached to zones through
`data/zones.lua`.

## Coordinate-link API

Other mods can register linked layers before gameplay starts:

```lua
local dive = mod.find("kanto_dive")
local zone, err = dive.exports.registerZone("route19_layer", {
  requiredBadge = "VOLCANOBADGE",
  links = {
    {
      surface = { mapId = "ROUTE_19", x = 0, y = 0 },
      underwater = { mapId = "MY_ROUTE19_SEAFLOOR", x = 0, y = 0 },
      width = 20,
      height = 54,
      areas = {
        { x = 4, y = 8, width = 12, height = 30 },
      },
    },
  },
  submergedMaps = { "MY_ROUTE19_SEAFLOOR", "MY_EXTRA_CAVE" },
}, mod.id)
```

All marked cells are bidirectional. Irregular masks use `B` for a linked cell
and `.` for an unlinked cell. A surface map may contain multiple disjoint
links, while each underwater map belongs to one zone.

## Save safety

Saving underwater is supported. The active zone is stored in the mod's save
namespace and the Surf state is persisted by the engine.

If an old or manually modified save is loaded on a surfacing map without a
valid session origin, the emergency SURFACE action returns the player to the
last healing point. Surface before disabling or removing the mod.


## 1.4.0 authoring model

DIVE zones are now paired explicitly in Tiled. `DiveZones` marks surface cells and `DiveLandings` marks their underwater counterparts. Objects sharing the same `linkId` are translated cell-for-cell in both directions. See `MAPPING_GUIDE.md` and the editable Route 20/21 TMX examples.
