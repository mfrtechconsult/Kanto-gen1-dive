# Kanto Dive for Gen1Recomp

Kanto Dive adds **HM08 DIVE** and a complete **2D underwater Kanto** to Gen1Recomp, together with Crystal-style **HM06 WHIRLPOOL** and **HM07 WATERFALL** field mechanics.

The `1.6.0-alpha.1` development line brings Kanto Dive to functional parity with the Full-Kanto architecture developed for Dramatic Deep Dive while deliberately preserving Kanto Dive's simpler **flat, Emerald-style 2D identity**.

Kanto Dive does **not** use a voxel renderer and does **not** add free vertical swimming. Its maps, movement, Pokémon and exploration remain 2D.

## Full-Kanto rule

The surface rule is now simple:

> **If Gen1Recomp considers a Kanto movement cell to be real water, that cell is intended to support DIVE.**

There is therefore no longer a special darkened subset of DIVE water to find. The old surface DIVE tint is disabled in Full-Kanto mode.

The underwater rule is broader:

> **A bridge, dock or pontoon may be walkable on the surface while the same body of water continues underneath it.**

This lets the generated underwater world preserve real hydrological continuity instead of turning every surface structure into an artificial underwater wall.

## Runtime Kanto Water Atlas

At startup, Kanto Dive scans the actual Kanto map data using Gen1Recomp's water-cell rules.

For every water-bearing map it records:

- every real surface-water movement cell;
- a separate underwater-hydrology mask;
- inferred water below narrow bridges, docks and pontoons;
- connected water bodies across normal Kanto map connections;
- shoreline distance;
- exact water-to-water map seams;
- regional biome identity;
- an underwater map id named `KD_SEABED_<SURFACE_MAP>`.

`SHIP_PORT` receives an explicit hydrology rule for the S.S. Anne boarding platform, while generic short walkable spans across water are inferred automatically. Broad land masses remain solid.

The old four-map runtime (`Route 19`, `Route 20`, `Route 21`, and the prototype Seafoam layer) is no longer the source of underwater coverage. Full-Kanto maps are generated from the live surface topology.

## Large 2D underwater spaces

The surface geography remains recognizable, but the underwater world is allowed to feel much larger than the compact Generation I overworld.

Current requested scales are:

- **open ocean:** up to `x3` width and height, giving roughly **9x the 2D swim area**;
- **volcanic open water:** up to `x3`;
- **coastal water:** up to `x2`, roughly **4x the area**;
- **harbors:** up to `x2`;
- **caves / Seafoam-style water:** up to `x2`;
- **freshwater and marshes:** normally `x1`.

When directly connected underwater maps share a normal route seam, Kanto Dive reconciles their scale so their borders remain compatible. The result is a continuous 2D sea rather than a series of cramped one-tile corridors.

Each real surface-water cell maps to the center of its enlarged underwater footprint. Any valid cell inside that footprint can SURFACE back to the correct original surface cell.

## Bridges, docks and pontoons

Surface water and underwater hydrology are separate concepts.

A pontoon therefore behaves as expected:

- the player cannot DIVE while standing on the pontoon;
- the player cannot SURFACE through the pontoon;
- the water underneath remains swimmable;
- water on both sides can stay part of one underwater body;
- genuine solid land remains an underwater boundary.

This applies across Kanto rather than only to Vermilion.

## Seamless underwater Kanto

Normal Kanto map connections are mirrored underwater whenever connected border cells belong to the same hydrological body.

This allows routes such as the southern ocean network to be crossed **underwater without surfacing between maps**.

The generated underwater map connections preserve the active DIVE session and continue to use ordinary Gen1Recomp map handoff instead of rewriting `OverworldState.update`.

## Submerged cave and harbor links

Normal map seams are not enough for multi-floor caves and authored port structures. Kanto Dive also derives additional 2D submerged portals from real surface warps when both ends are semantically compatible:

- cave -> cave;
- harbor -> harbor.

This is intended for places such as Seafoam's connected cave floors and coherent harbor areas. Unrelated doors are not converted into underwater shortcuts.

## 2D biome identity

Every generated underwater map uses the existing Kanto Dive 2D tileset, but decoration changes by region.

Current profiles include:

- **coastal** — reefs, vegetation and open shelves;
- **ocean** — the largest, calmest open-water spaces;
- **harbor** — engineered/murky seabed patterns around Vermilion;
- **volcanic** — darker mineral seabed around Cinnabar;
- **cave** — darker rock/crystal-style patterns for Seafoam and other cave water;
- **freshwater** — restrained rivers, ponds and inland waterways;
- **marsh** — denser wetland-style vegetation around Fuchsia/Safari areas.

Decorative blocks used inside valid water are fully swimmable. Visual decoration is never allowed to turn an atlas water cell into an accidental collision wall.

## Living 2D underwater Pokémon

When **Wilds of Kanto** (`overworld_wild_spawns`) is installed, Kanto Dive populates the generated underwater maps with visible Pokémon.

The 2D wildlife system:

- selects species from the current biome ecology;
- uses shoreline distance to distinguish shallow, mid-water and deep-area populations;
- spawns Pokémon around the player rather than across the entire map;
- supports loose same-species schooling;
- lets Pokémon wander and gently flee from the player;
- keeps movement inside the generated underwater hydrology;
- despawns distant wildlife and repopulates the local area;
- remains entirely 2D.

## Pokédex-sized Pokémon

Visible underwater Pokémon use Pokédex height to determine their displayed size.

The compressed scaling curve is intentionally the same design used by Dramatic Deep Dive:

- tiny Pokémon remain readable;
- medium Pokémon remain close to normal overworld scale;
- large species become visibly imposing;
- extreme sizes are capped so one sprite cannot cover the screen.

Visual scale and swimming speed are calculated separately.

## Sprite providers

Kanto Dive does not need to bundle a duplicate Pokémon sprite collection when a compatible mod can provide one.

The resolver prefers compatible public providers such as:

1. Wilds of Kanto;
2. PokePC Followers / VoxelMerge-style providers;
3. Followers EX-compatible providers;
4. compatible legacy `follower_###.png` assets as fallback.

Water-specific artwork is requested first when the provider exposes it.

## Forgiving visible encounters

A moving 2D Pokémon does not require pixel-perfect contact.

Kanto Dive uses an automatic interception envelope of approximately **2.5 movement cells**, with a small bonus for physically larger Pokémon.

When several visible Pokémon are in range, the nearest valid Pokémon is selected. The battle uses the **exact visible species and level**, and that exact overworld entity is removed when the battle begins.

A short post-battle cooldown prevents accidental encounter chains.

## Wilds of Kanto: visible encounters only

With Wilds of Kanto installed, **invisible/random underwater encounters are disabled**.

Kanto Dive enforces this at two levels:

- generated engine-facing underwater encounter tables have a permanent encounter rate of `0`;
- high-priority public `encounter.roll` and `encounter.species` gates suppress classic underwater encounters, including another wrapper attempting to force a species through the normal encounter chain.

Therefore the intended Wilds behavior is:

> **See a Pokémon -> approach/intercept it -> battle that Pokémon.**

Outside Kanto Dive underwater maps, normal encounter behavior is untouched.

When Wilds is **not** installed, Kanto Dive stays standalone: its encounter policy dynamically restores the generated classic underwater encounter table for the current map.

## Sparse 2D salvage

Large generated underwater areas receive a small number of deterministic salvage signals.

Salvage is biased toward interior/deeper-looking parts of the 2D water body. Tiny ponds do not receive treasure spam.

Biome-specific pools include harbor debris, cave finds, volcanic/thermal-area finds and ordinary seabed salvage.

Because Kanto Dive has no free vertical depth, there is no `SIGNAL BELOW` / `SIGNAL ABOVE` mechanic. When close enough, the HUD displays the signal and then `A SALVAGE`; press **A** to recover the item.

The salvage update uses the public fixed-step input hook rather than wrapping `OverworldState.update`.

## HM06 / HM07 / HM08

Kanto Dive keeps its complete water-field-move set:

- **HM06 WHIRLPOOL** — Crystal-style removable current barriers;
- **HM07 WATERFALL** — downward traversal is free, upward climbing requires WATERFALL;
- **HM08 DIVE** — enter and leave the generated 2D underwater Kanto.

Kanto Dive keeps the stable `HM_DIVE` item id for save compatibility while presenting it as HM08.

Because Kanto has no Glacier Badge or Rising Badge, the current field progression maps the corresponding late-game gates to Kanto's **Volcano Badge** and **Earth Badge**.

## Obtaining HM08 DIVE

1. Defeat Blaine and obtain the Volcano Badge.
2. Visit the Metronome Room in the Cinnabar Pokémon Lab.
3. Talk to the scientist who normally gives TM35.
4. He gives HM08 without replacing the original TM35 reward.

The historical save flag is retained so older Kanto Dive saves keep their progression.

## Crystal 251 compatibility

Crystal 251 is optional.

When present, Kanto Dive reuses compatible `WHIRLPOOL`, `WATERFALL`, HM06/HM07 and imported Generation II data instead of creating conflicting duplicate records. DIVE compatibility is added only where required.

Without Crystal 251, Kanto Dive remains standalone and provides its own HM06/HM07 contracts and acquisition path.

## Dramatic Sky Ride / Wild Skies compatibility

The Full-Kanto 2D overhaul follows the safe hook architecture learned from Dramatic Deep Dive:

- no self-healing `OverworldState.update` wrappers;
- no closure/upvalue retargeting;
- wildlife, interception, salvage and submerged portals run through public `input.step` hooks;
- normal Gen1Recomp map connections handle route-to-route underwater travel;
- Wilds encounter suppression uses the public encounter hook chain.

This keeps Kanto Dive's runtime independent from Dramatic Deep Dive while allowing it to coexist with the wider Sky/Wilds stack.

## Public compatibility surface

The mod exposes compatibility helpers for:

- current underwater state and zone;
- DIVE/SURFACE availability and target lookup;
- generated surface/underwater map lookup;
- Full-Kanto water-atlas statistics;
- swimmable-cell lookup;
- visible wildlife/interception statistics;
- encounter-policy status;
- submerged portal statistics;
- salvage remaining;
- external DIVE-zone registration;
- WHIRLPOOL/WATERFALL registration.

`getVisualDiveMarkers()` intentionally returns an empty set in Full-Kanto mode because the surface dark-water mask is disabled.

## Validation

The development branch includes dedicated headless contracts in addition to launcher packaging.

Automated checks cover:

- parsing every Lua source file;
- Full-Kanto water scanning;
- enlarged `x3` ocean topology;
- surface-water versus under-structure hydrology;
- bridge/pontoon continuity;
- generated 2D map dimensions and block counts;
- zero-rate engine-facing underwater encounters;
- standalone encounter restoration without Wilds;
- DIVE to the center of an enlarged underwater footprint;
- SURFACE from every cell of that footprint back to the correct surface cell;
- Wilds `encounter.roll` hard suppression;
- Wilds `encounter.species` forced-encounter suppression;
- normal encounter behavior outside Kanto Dive.

## Development status

Current development preview: **Kanto Dive 1.6.0-alpha.1**.

The overhaul lives on `dev/deep-dive-functional-backport` and its pull request remains a development draft. The published `main` branch remains the stable line until this Full-Kanto 2D version is explicitly approved after gameplay testing.

## License

Released under the MIT License (`kanto_dive/LICENSE`).
