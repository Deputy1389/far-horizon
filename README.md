# Far Horizon

Far Horizon is being rebuilt around one clear target:

> **a first-person galactic-conquest sandbox where a persistent war unfolds across large procedural planets and the player can physically participate in it.**

The immediate foundation is intentionally narrower than the older browser systems prototype: make moving, shooting, fighting, driving and traversing a procedural spherical planet feel good first. Crafting, professions, deep economy and construction come later.

See:

- [Game vision](docs/GAME_VISION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Foundation v0.1 gates](docs/FOUNDATION_V0_1.md)

## Authoritative gameplay foundation: Godot

The repository root is now a Godot 4 project. The current foundation includes:

- first-person mouse look;
- responsive walk/sprint acceleration;
- jump with anti-bunny-hop cadence;
- stairs/step-up support;
- mantle;
- crouch and prone;
- pistol and rifle with hip fire + ADS;
- fast visible blaster projectiles;
- damage/respawn loop;
- a first enemy squad with perception, alerts, suppress/advance/flank roles and return fire;
- a first-person hover speeder with enter/exit, banking and drift;
- float64 planet-space coordinates separated from local physics coordinates;
- floating-origin rebasing;
- spherical procedural terrain patches streamed around the player;
- a generated Tatooine-like city combat space;
- a simple strategic Rebel/Imperial node graph with moving abstract forces;
- a local capture point that changes the strategic balance;
- an adapter that can instantiate the locally converted SWG Restoration Stormtrooper glTF when it is available.

The old Three.js prototype remains in the repository as a systems/asset-pipeline proof, but it is no longer the gameplay architecture to build on.

## Run Foundation v0.1

Install Godot 4.3+ and open this repository folder directly as the project.

From PowerShell, if the Godot executable is on PATH:

```powershell
cd $HOME\far-horizon
git switch chatgpt/foundation-v0.1
git pull --ff-only
godot --editor --path .
```

Press **F6/F5** in the editor, or run:

```powershell
godot --path .
```

Controls:

- `WASD` — move
- `Shift` — sprint
- `Space` — jump / mantle
- `C` — crouch
- `Z` — prone
- mouse — look
- left mouse — fire
- right mouse — ADS
- `1` — blaster pistol
- `2` — blaster rifle
- `E` — enter/exit speeder or interact
- `Esc` — release/capture mouse

The first playable target is deliberately simple: start outside the city, enter it, fight the Imperial garrison, capture the objective, then get on the speeder and drive back into streamed desert.

## Planet architecture

Persistent positions are stored in double-precision planet-centered coordinates while Godot physics stays close to a local origin.

The current terrain streamer renders spherical local patches around the player. It is the first step toward a cube-sphere quadtree rather than a permanent flat-world map.

The floating-origin layer preserves anchored actors during rebases so long-distance planetary travel does not depend on giant single-precision scene coordinates.

## Strategy architecture

The strategic war is data-first rather than being encoded only in NPC scene nodes.

Foundation v0.1 contains a small planetary graph:

- Rebel Outpost
- South Checkpoint
- Mos Eisley prototype
- Imperial Garrison

Forces move between those nodes in the strategic simulation. Local player actions can change node strength/control. Later versions can materialize nearby strategic forces as real squads/convoys and collapse them back to aggregate state when they move out of local simulation range.

That is the intended path toward thousands of strategically participating troops without running thousands of full combat AIs simultaneously.

## Local SWG Restoration asset pipeline

The existing local asset work is preserved.

Far Horizon can scan a local SWG Restoration install, decode its TRE archives, inventory the client assets, extract useful DDS material roles and convert selected SWG meshes/characters into glTF.

Normal workflow:

```powershell
cd $HOME\far-horizon
py tools\import_swg_assets.py
```

The importer auto-detects common `SWG Restoration` locations. An explicit location also works:

```powershell
py tools\import_swg_assets.py --source "C:\SWG Restoration"
```

Useful searches:

```powershell
py tools\import_swg_assets.py --search tatooine sand --extension .dds --limit 30
py tools\import_swg_assets.py --search mos eisley wall --extension .dds --limit 30
py tools\import_swg_assets.py --mesh-report --limit 40
```

The pipeline currently understands enough of the local client to:

- parse the Restoration TRE set;
- decode protected/zlib payloads;
- select real environment material candidates;
- convert a real static environmental SWG mesh to glTF;
- convert the weighted Stormtrooper MGN + skeleton + selected animations to a skinned glTF;
- preserve asset provenance in the generated manifest.

Generated client assets stay under `assets/local-swg/` and are gitignored. Godot's enemy visual bridge uses the generated Stormtrooper scene when it is importable and otherwise keeps a functional placeholder.

The browser prototype can still be served with:

```powershell
py -m http.server 8080
```

but new gameplay work should target the Godot foundation.

## Current priority

Do not broaden the game until these are good:

1. FPS movement feel.
2. Blaster combat feel.
3. Six-to-eight-enemy combat.
4. Stable spherical terrain streaming/floating origin.
5. Speeder handling.
6. City combat space.
7. Local actions affecting the strategic war.

Once one Tatooine-like planet is enjoyable, the next meaningful expansion is a second planet and the travel/galactic-conquest layer between them.
