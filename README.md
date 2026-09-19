# Far Horizon — First Slice

A tiny playable browser prototype for a **single-player procedural sci-fi sandbox at planetary scale**: systemic sandbox DNA, modern action controls, large generated settlements, exploration, surveying and eventually seamless world/space traversal.

This repository intentionally contains **no Star Wars or SWG assets/code**. It is an original technical prototype inspired by the design goals discussed for a modern systems-heavy sandbox.

## What is in v0.1

- Deterministic procedural desert terrain from a seed.
- A large generated spaceport city with a dense core, roads, landing pads, outskirts and sparse frontier buildings.
- Third-person WASD movement with mouse look and sprinting.
- Basic action shooting against patrol drones.
- SWG-inspired survey pulse that locates generated resource deposits with quality values.
- Lightweight sky traffic and atmospheric presentation.
- Deterministic reseeding (`R`) so different worlds can be generated quickly.

## Run it

Because the prototype uses ES modules, serve the directory rather than double-clicking `index.html`.

### Windows PowerShell

```powershell
cd path\to\far-horizon-prototype
py -m http.server 8080
```

Then open <http://localhost:8080>.

No install/build step is required. Three.js is loaded from the public unpkg CDN.

## Controls

- `WASD` — move
- `Shift` — sprint
- `Mouse` — look
- `Left click` — fire
- `Q` — survey pulse
- `R` — generate a new seed

## Why this slice

The first proof is intentionally narrow: **stand on a ridge, see a city that reads at meaningful scale, descend into it, fight something, and interact with a procedural resource system**.

If that feels right, the next milestones are:

1. Speeder traversal and vehicle handling.
2. Chunk-streamed terrain so the playable world becomes effectively unbounded.
3. Procedural districts rather than the current block grammar.
4. NPC population LOD (district simulation -> instantiated street NPCs).
5. Resource surveying, extraction and a first crafting chain.
6. Interior generation for selected buildings.
7. Persistent save state.
8. Seamless ship takeoff / atmosphere / orbital transition prototype.

## Architecture direction

Keep simulation data independent from rendering. Generated terrain, districts, populations, resources, economy and persistence should eventually live in deterministic data layers. Three.js is only the presentation/client layer for this first experiment.


## Changelog

### 0.1.1

- Fixed camera-relative strafing: A is left and D is right.
- Fixed avatar facing so forward movement no longer looks like walking backward.
