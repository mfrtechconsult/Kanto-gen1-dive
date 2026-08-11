# Deep Dive Functional Backport Plan for Kanto Dive

## Goal

Bring the proven non-map gameplay and compatibility improvements from Dramatic Deep Dive into Kanto Dive while preserving Kanto Dive's simpler Emerald-style 2D underwater identity.

This is not a map port and does not turn Kanto Dive into the 3D Deep Dive engine.

Development branch: `dev/deep-dive-functional-backport`.

## Keep as-is

Kanto Dive already has several systems that should remain authoritative:

- HM08 DIVE progression and party action;
- paired surface/underwater travel model;
- validated dark DIVE surface tint;
- HM06 WHIRLPOOL and HM07 WATERFALL;
- WaterFeaturePolish;
- Crystal 251 compatibility;
- existing Surf-state underwater presentation;
- Tiled authoring workflow and public zone APIs.

## Backport 1 — Wilds-aware encounter policy

When `overworld_wild_spawns` is installed and the player is underwater:

- disable Kanto Dive's invisible/random encounter rolls;
- keep normal random encounters unchanged when Wilds is absent;
- do not change encounter behavior outside Kanto Dive underwater maps.

This matches the successful Deep Dive rule: visible overworld Pokémon become the authoritative encounter source in Wilds mode.

## Backport 2 — Visible underwater Pokémon

Adapt Deep Dive's `UnderwaterWildlife` concept to Kanto Dive's 2D maps.

Requirements:

- use each underwater map's encounter table as the ecology source;
- spawn visible Water/aquatic Pokémon around the player;
- support small schools of the same species;
- simple wandering/flee behavior appropriate to flat 2D movement;
- despawn/replenish outside the local radius;
- no dependency on Deep Dive or its 3D renderer.

## Backport 3 — Shared sprite-provider strategy

Port the robust follower/overworld sprite resolution used by Deep Dive:

Priority should include:

1. Wilds of Kanto public sprite resolver;
2. maintained PokePC Followers providers;
3. compatible legacy follower files as fallback.

Kanto Dive should not bundle duplicate Pokémon sprite sets when an installed provider can supply them.

## Backport 4 — Pokédex-height dynamic scaling

Visible underwater Pokémon should use Pokédex height to control their rendered size.

Use a compressed/non-linear curve so:

- tiny Pokémon remain readable;
- medium Pokémon remain close to normal overworld scale;
- large Pokémon are visibly impressive;
- extreme species are capped so they do not cover the entire screen.

The size calculation should be independent from movement speed.

## Backport 5 — Forgiving visible encounter interception

Adapt Deep Dive's forgiving interception to 2D.

Kanto Dive should not require pixel-perfect collision with a moving Pokémon.

Recommended behavior:

- approximately two movement cells of interception tolerance;
- size-aware bonus radius for large Pokémon;
- choose the nearest valid visible Pokémon when several overlap the radius;
- start battle against the exact visible species and level;
- remove/consume that entity when battle starts;
- short post-battle cooldown to avoid accidental encounter chains.

## Backport 6 — Safe hook architecture

Keep all new runtime behavior on cooperative public hooks such as `input.step`.

Do not add self-healing or upvalue-rewriting wrappers around `OverworldState.update`.

This rule is important for coexistence with:

- Wilds of Kanto;
- Wild Skies;
- Dramatic Sky Ride;
- renderer mods.

Kanto Dive currently has a simpler lifecycle than Deep Dive, so only the safe architecture should be copied, not obsolete Deep Dive debugging guards.

## Backport 7 — Travel lifecycle hardening

Review DIVE/SURFACE map-entry handling using the lessons from Deep Dive.

Keep activation idempotent and ensure normal warp completion is the authoritative point for presentation changes where possible.

Do not emit duplicate custom lifecycle events.

Kanto Dive's lowercase manifest id (`kanto_dive`) already matches its `mod.kanto_dive.*` event namespace, so no namespace rename is required.

## Backport 8 — Wilds / Sky-family compatibility regression tests

Add explicit tests for these stacks:

- Kanto Dive alone;
- + Wilds of Kanto;
- + Dramatic Sky Ride;
- + Wild Skies;
- + Wilds + DSR + Wild Skies;
- + Crystal 251;
- renderer combinations where applicable.

Tests should cover entering DIVE, moving underwater, visible Pokémon interception, battle return, SURFACE and repeated dives.

## Backport 9 — Shared water coverage data where practical

Longer term, Kanto Dive and Dramatic Deep Dive should consume the same generated Kanto water-atlas concept even though their underwater maps/renderers differ.

Benefits:

- both mods agree on where surface water exists;
- DIVE markers stay consistent;
- no route is supported by one mod but accidentally forgotten by the other;
- surface-water audits can be shared conceptually without creating a runtime dependency between the mods.

Each repository should keep its own generated data so neither mod becomes a hard dependency of the other.

## Suggested implementation order

1. Add Wilds-aware random encounter suppression.
2. Add shared sprite resolver module.
3. Add visible 2D underwater wildlife.
4. Add Pokédex-height scaling.
5. Add forgiving encounter interception.
6. Harden battle return and DIVE/SURFACE lifecycle.
7. Add compatibility matrix tests.
8. Update English README and launcher packaging.
9. Test as a development release before merging to `main`.

## Definition of done

With Wilds installed, Kanto Dive should feel like a populated underwater overworld: visible Pokémon swim around the player, their sizes reflect Pokédex scale, approaching them is forgiving, and the exact visible Pokémon starts the battle. Invisible random encounters are disabled only in that mode. Without Wilds, Kanto Dive retains its current classic random-encounter behavior and remains fully standalone.
