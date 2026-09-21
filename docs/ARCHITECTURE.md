# Far Horizon — Architecture

## 1. Separation of scales

Far Horizon must not simulate the entire galaxy at FPS fidelity. The game uses layered representations of the same state.

### Galaxy simulation

Cheap, persistent strategic state:

- star systems and planets;
- factions;
- fleets and transport capacity;
- high-level production and logistics;
- campaign objectives;
- interplanetary routes;
- wars and scheduled/telegraphed offensives.

### Planet strategic simulation

A graph of meaningful regions and infrastructure:

- cities, settlements, bases and outposts;
- roads and supply links;
- spaceports, factories, power and communications;
- faction presence, supply and population support;
- strategic ground forces and convoys.

### Local simulation

Only the area relevant to the player is materialized at full fidelity:

- individual soldiers;
- squads;
- vehicles;
- civilians;
- projectiles;
- tactical AI;
- destructible/interactable objects.

When a force enters or leaves the local simulation, identity and aggregate state survive the transition. Casualties, supplies, destination and equipment cannot reset merely because the player moved away.

## 2. Authoritative strategic state

Strategic state is data, not scene-tree state.

Rendering and local NPC nodes are projections of that data. This is essential for:

- save/load;
- simulation while the player is elsewhere;
- future co-op/server authority;
- simulation LOD;
- deterministic debugging.

Gameplay code should avoid making a rendered NPC or building the sole owner of strategically important facts.

## 3. Planet coordinates

The long-term planet architecture is spherical from the start.

Persistent positions use double-precision planet-centered coordinates. Godot scene/physics coordinates remain local to the player so the renderer and physics engine never operate millions of meters from the origin.

Pipeline:

planet-space ECEF (float64 scalars)
→ local tangent frame
→ floating origin
→ ordinary Godot Vector3 physics/rendering.

The initial implementation provides:

- latitude/longitude ↔ ECEF helpers;
- tangent-frame construction;
- conversion between planet-space and local-space;
- floating-origin rebasing that preserves anchored object positions/orientations;
- spherical terrain sampling in the local tangent frame.

The terrain streamer begins as local spherical patches. It should evolve toward a cube-sphere quadtree for atmosphere/orbit-scale LOD without changing persistent coordinates.

## 4. Floating-origin contract

Objects that need to survive rebasing are planet-anchored. Before a rebase, their absolute planet-space positions and orientations are captured. A new tangent origin is chosen near the player, then the objects are reconstructed in the new local frame.

Procedural terrain is cheaper to regenerate after a rebase than to preserve as authoritative state.

The player remains near local origin even after traveling large distances.

## 5. Procedural generation hierarchy

Generation should be deterministic and hierarchical:

galaxy seed
→ star/system seed
→ planet seed
→ macro geology/climate
→ regions/resources
→ routes
→ settlements/infrastructure
→ districts/parcels
→ local dressing.

Do not scatter unrelated POIs first and invent a reason for them afterward.

A city should tend to exist because geography, resources, trade, population or strategic requirements made that location valuable.

## 6. Tactical AI

AI is layered by relevance.

Far strategic forces:
- aggregate strength/supply/morale/location.

Near but off-screen forces:
- simplified movement and encounter resolution.

Visible/relevant combatants:
- full perception, cover evaluation, firing, repositioning, squad roles and animation.

The first AI implementation can be simple, but its interface should already distinguish squad intent from individual movement so later cover/flanking logic does not require replacing the strategy layer.

## 7. Combat

Weapons are data-driven definitions. The initial pistol and rifle use physical/continuous-collision blaster projectiles rather than RPG-style damage rolls.

Combat authority owns:

- fire cadence;
- projectile speed;
- damage;
- spread;
- recoil;
- ADS parameters;
- hit/damage events.

Character progression must not be required to make the base gunplay enjoyable.

## 8. Vehicles

Vehicles are separate controllers, not special player movement modes.

A player enters a vehicle and delegates locomotion while retaining first-person camera control. The first speeder uses controllable hover dynamics rather than a wheeled-car model.

Later vehicles can share interaction, possession and damage contracts.

## 9. Asset pipeline

The existing local SWG Restoration tooling remains valuable infrastructure:

TRE inventory/decryption
→ local extraction
→ mesh/character conversion
→ glTF/DDS or later Godot-friendly derivatives.

Extracted client binaries stay ignored under assets/local-swg/.

The runtime must always have functional placeholder/fallback assets so gameplay development is not blocked by a specific client installation.

The asset pipeline and the gameplay engine are deliberately decoupled.

## 10. Co-op future-proofing

Co-op is not a Foundation v0.1 deliverable. Avoid choices that make it impossible:

- strategic state should be serializable;
- deterministic seeds and stable IDs should be used for generated entities;
- gameplay actions should be expressible as commands/events;
- local rendering state should not be the sole source of truth;
- time-dependent strategic simulation should be tick-based.

Do not add networking overhead to the current FPS loop.

## 11. Performance targets

Initial desktop target: stable 60 FPS during ordinary combat on the target development PC.

Architect for:
- terrain chunk streaming;
- distance-based simulation LOD;
- pooled projectiles and effects once counts justify it;
- MultiMesh/instancing for repeated environment props;
- bounded expensive AI around the player;
- asynchronous generation for heavy world chunks.

Correctness and feel come before extreme population counts in v0.1.
