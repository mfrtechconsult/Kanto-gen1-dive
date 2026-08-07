# Kanto Dive for Gen1Recomp

Kanto Dive adds **HM06 DIVE** and Emerald-style underwater exploration to Gen1Recomp.

The mod is written and distributed entirely in English. It contains no commercial ROM, ROM-derived graphics, or proprietary audio.

## Download

Download the latest ready-to-install ZIP from the [GitHub Releases page](https://github.com/mfrtechconsult/Kanto-gen1-dive/releases/latest).

Starting with version `1.5.3`, the release ZIP uses the Gen1Recomp Mod Index / launcher layout with `manifest.json` directly at the archive root.

## Main features

- HM06 DIVE as a usable battle move and field action
- Explicit DIVE zones authored in Tiled
- Paired underwater landing regions with bidirectional coordinate mapping
- Dark DIVE water visible in 2D, Tilt, and Voxel modes
- Surf mount sprite and bobbing animation preserved underwater
- SURF hidden and rejected while already underwater
- Dramatic Sky Ride compatibility: mounted players are no longer rendered twice over Voxel DIVE zones
- Route 19 Reef Passage with two separate entrances and an underwater corridor
- Route 20 Seafloor
- Seafoam Sunken Cave
- Route 21 Trench
- Wild encounters on underwater maps
- Public API for other mods to register additional DIVE zones

## Installation

### Launcher / Mod Index

Import `kanto_dive-1.5.3.zip` directly through the Gen1Recomp launcher.

### Manual installation

1. Download `kanto_dive-1.5.3.zip` from Releases.
2. Create:

```text
<Gen1Recomp>/mods/kanto_dive/
```

3. Extract the ZIP contents directly into that folder.
4. Confirm the final path is:

```text
<Gen1Recomp>/mods/kanto_dive/manifest.json
```

5. Enable **Kanto Dive** in the F10 mod manager.
6. Restart Gen1Recomp completely.

## Obtaining HM06

1. Defeat Blaine and obtain the Volcano Badge.
2. Visit the Metronome Room in the Cinnabar Pokémon Lab.
3. Talk to the scientist who normally gives TM35.
4. He gives HM06 without replacing the original TM35 reward.

## DIVE and SURFACE

Teach HM06 to a compatible Pokémon and Surf onto a darkened DIVE cell on Route 19, Route 20, or Route 21.

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

Two object layers define each connection:

- `DiveZones`: surface cells where DIVE is available
- `DiveLandings`: corresponding underwater cells where the player arrives and may use SURFACE

Objects are paired by their shared `linkId`. Their shapes must match, but their absolute positions may differ.

See [MAPPING_GUIDE.md](kanto_dive/MAPPING_GUIDE.md) for the complete authoring workflow.

## Repository layout

```text
kanto_dive/            Installable Gen1Recomp mod source
.github/workflows/     Automated GitHub release packaging
README.md              Project overview
```

## Current version

**Kanto Dive 1.5.3**

See the [changelog](kanto_dive/CHANGELOG.md) for version details.

## License

Released under the [MIT License](kanto_dive/LICENSE).
