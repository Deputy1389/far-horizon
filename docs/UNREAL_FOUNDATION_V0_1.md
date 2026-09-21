# Far Horizon — Unreal Foundation v0.1

## Decision

Far Horizon's active runtime is now **Unreal Engine 5.8**.

The browser and Godot implementations remain historical/reference implementations while migration is in progress. New gameplay/runtime work targets Unreal.

## North star

A responsive first-person galactic-conquest sandbox on large procedural spherical planets.

The strategy layer generates the adventure. The first-person world lets the player physically live it.

## What survives the engine switch

Preserve and port concepts/data from the current foundation:

- deterministic planetary seeds and procedural generation rules;
- planet-space / local-space separation;
- strategic node graph and faction-force simulation;
- materialized local proxies for strategic forces;
- capture objectives feeding back into strategic state;
- generated city/road concepts;
- local SWG extraction/conversion tooling as a reference/import source;
- movement/combat/speeder playtest requirements.

Do not mechanically port Godot controller or scene code.

## Unreal stack

- Unreal Engine 5.8
- C++ for durable gameplay/runtime systems
- Blueprints for assembly, tuning and content-facing glue
- PCG Framework for local environment/city/biome population
- Large World Coordinates for world-space precision
- Gameplay Ability System for combat, abilities and status effects
- Unreal AI stack for perception, navigation and combat decisions
- Chaos for vehicles/physics where appropriate
- Niagara for blasters, impacts, weather and atmosphere
- Animation Blueprints / Control Rig / current Epic samples for character presentation

## Reuse-first rule

Before implementing a generic system, inspect Epic samples and mature permissively licensed implementations.

Prefer adaptation over reinvention for locomotion, first-person weapon handling, animation graphs, AI perception/navigation, weapon architecture, vehicles, ability/status systems, inventory/save infrastructure, PCG utilities, profiling and LOD patterns.

Custom engineering time should go into Far Horizon-specific systems: planetary streaming, strategic-war/local-world continuity, procedural settlements/ecology, and sandbox simulation.

## Foundation v0.1 acceptance slice

1. Launch into a test planet surface.
2. Responsive FPS movement and mouse look.
3. One blaster with correct reticle/projectile alignment.
4. One enemy soldier that patrols, acquires, fires, advances and uses basic tactical positioning.
5. One hover speeder with stable, readable steering.
6. Visible planetary curvature / radial-up proof.
7. Deterministic local terrain generation from a planet seed.
8. One strategic node/capture objective whose local result changes strategic state.
9. One strategic force that materializes locally and can be physically destroyed.
10. Automated smoke checks plus a repeatable Windows playtest launcher.

## Planet architecture

Do not model a planet as one giant Landscape.

Target a deterministic seeded cube-sphere or equivalent surface with hierarchical chunk addresses, geometric LOD, radial gravity, local tangent frames, high-detail geometry only near the player, and PCG decoration only for loaded chunks. Strategic simulation stays in stable planet coordinates independent of loaded Actors.

Start with one desert planet. Do not build multiple planets or seamless orbital flight until the surface slice feels good.

## Immediate implementation order

1. Make the Unreal project compile and launch.
2. Replace the temporary smoke controller with a proven Epic first-person/animation foundation.
3. Implement weapon + reticle correctness.
4. Implement one competent enemy.
5. Implement radial gravity and curved-surface proof.
6. Add deterministic surface chunk streaming.
7. Add speeder.
8. Port strategic-node/local-proxy proof.
9. Port/import only assets needed by the slice.
10. Profile before broadening scope.

## Guardrails

No crafting/profession expansion, housing, deep economy, second planet, multiplayer, or giant procedural city yet. Do not build a bespoke animation framework where Unreal/Epic already provides a stronger foundation. Do not port janky behavior simply because it already exists in the old prototypes.
