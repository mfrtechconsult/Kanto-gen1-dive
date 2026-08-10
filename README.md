# Kanto Dive for Gen1Recomp

Kanto Dive adds **HM08 DIVE**, Emerald-style underwater exploration, and Crystal-style **HM06 WHIRLPOOL / HM07 WATERFALL** mechanics to Gen1Recomp.

The mod is written and distributed entirely in English. It contains no commercial ROM, ROM-derived graphics, or proprietary audio.

## Download

Download the latest ready-to-install ZIP from the GitHub Releases page. The `compat/wilds-of-kanto` branch is development work and is not the current stable release.

Starting with version `1.5.3`, release ZIPs use the Gen1Recomp Mod Index / launcher layout with `manifest.json` directly at the archive root.

## Main features

- HM08 DIVE as a usable battle move and field action
- HM06 WHIRLPOOL using its Generation II battle stats and Crystal-style removable field barriers
- HM07 WATERFALL using its Generation II battle stats and Crystal-style upward waterfall traversal
- Generation I WHIRLPOOL/WATERFALL learnsets based on Pokémon Crystal
- Extended HM deletion protection for DIVE, WHIRLPOOL and WATERFALL
- Standalone HM06/HM07 acquisition when Crystal 251 is absent
- Optional Crystal 251 interoperability without duplicate move/item records
- Explicit DIVE zones authored in Tiled
- Paired underwater landing regions with bidirectional coordinate mapping
- Dark DIVE water visible in 2D, Tilt, and Voxel modes
- Surf mount sprite and bobbing animation preserved underwater
- SURF hidden and rejected while already underwater
- Dramatic Sky Ride compatibility
- Wilds of Kanto compatibility
- Route 19 Reef Passage, Route 20 Seafloor, Seafoam Sunken Cave and Route 21 Trench
- Public APIs for DIVE zones, whirlpools and waterfalls

## HM numbering

Kanto Dive keeps the stable `HM_DIVE` item id for save compatibility, but DIVE is presented as **HM08**. This leaves the Crystal machine numbers free for:

- **HM06 — WHIRLPOOL**
- **HM07 — WATERFALL**
- **HM08 — DIVE**

## Crystal 251 compatibility

Crystal 251 is optional.

When it is installed, Kanto Dive reuses Crystal's `WHIRLPOOL`, `WATERFALL`, `HM_06` and `HM_07` records instead of creating duplicates. Crystal keeps ownership of its imported Generation II TM/HM compatibility, while Kanto Dive additively enables HM08 DIVE on the compatible imported species.

When Crystal 251 is absent, Kanto Dive supplies WHIRLPOOL/WATERFALL itself and adds standalone Kanto acquisition points for HM06 and HM07.

## Field behavior

WHIRLPOOL behaves like the Crystal field move: an authored whirlpool blocks Surf movement until a compatible Pokémon uses WHIRLPOOL. The barrier remains cleared for the current map visit and returns after the map is reloaded.

WATERFALL is required only to climb an authored waterfall from below. Descending remains ordinary Surf movement. Because Kanto has no Glacier Badge or Rising Badge, the mod maps Crystal's 7th/8th-badge progression slots to Kanto's **Volcano Badge** and **Earth Badge**.

The development branch currently authors a whirlpool barrier in the Route 20 Seafoam channel and a waterfall barrier in Route 21. External content mods can add more through `registerWhirlpool` and `registerWaterfall`.

## Obtaining HM08 DIVE

1. Defeat Blaine and obtain the Volcano Badge.
2. Visit the Metronome Room in the Cinnabar Pokémon Lab.
3. Talk to the scientist who normally gives TM35.
4. He gives HM08 without replacing the original TM35 reward.

The historical save flag name is retained internally so existing saves do not lose their DIVE reward state.

## DIVE and SURFACE

Teach HM08 to a compatible Pokémon and Surf onto a darkened DIVE cell on Route 19, Route 20, or Route 21.

- `DIVE` appears only on an explicitly linked surface-water cell.
- `SURFACE` appears only on its paired underwater cell.
- Every authored link is bidirectional.
- Moving underwater can change the surface emergence point, like Pokémon Emerald.
- `SURF` cannot be used again while underwater because the player is already in the Surf movement state.

## Tiled authoring

The repository includes editable examples and a converter:

```text
kanto_dive/authoring/route19_reef_passage.tmx
kanto_dive/authoring/route20_seafloor.tmx
kanto_dive/authoring/route21_trench.tmx
kanto_dive/authoring/route_template.tmx
kanto_dive/authoring/tiled_to_kanto_dive.py
```

Two object layers define each DIVE connection:

- `DiveZones`: surface cells where DIVE is available
- `DiveLandings`: corresponding underwater cells where the player arrives and may use SURFACE

Objects are paired by their shared `linkId`. Their shapes must match, but their absolute positions may differ.

See `kanto_dive/MAPPING_GUIDE.md` for the complete authoring workflow.

## Repository layout

```text
kanto_dive/            Installable Gen1Recomp mod source
.github/workflows/     Automated GitHub release packaging
README.md              Project overview
```

## Current stable version

**Kanto Dive 1.5.3**

The Wilds compatibility branch contains unreleased development work described above.

## License

Released under the MIT License (`kanto_dive/LICENSE`).
