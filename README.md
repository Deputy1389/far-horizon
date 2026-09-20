# Far Horizon

A playable browser prototype for a **single-player procedural sci-fi sandbox at planetary scale**: classic systems-heavy sandbox DNA, modern action controls, large generated settlements, exploration, surveying, crafting, professions and persistent character progression.

This repository intentionally contains **no Star Wars or SWG assets/code**. It is an original technical prototype built around the gameplay ideas we want to preserve and modernize.

## Current systems slice

The current build now connects:

- deterministic procedural desert terrain and a large generated spaceport city;
- third-person movement, sprinting, aiming and action shooting;
- hostile patrol drones with health, return fire, player health and recovery;
- persistent credits, inventory, XP, skill points and character progression via browser save;
- Marksman, Scout, Artisan and Medic profession trees with prerequisites and activity XP;
- SWG-style resource batches with quality plus purity, conductivity, toughness and malleability;
- survey pulses that reveal nearby deposits and better information with Scout training;
- hand sampling, finite surface deposits and harvesting bonuses;
- crafting recipes for medkits, survey upgrades, weapon upgrades and deployable camp kits;
- crafted quality bonuses from exceptional material batches;
- drone wreck salvage and droid scrap;
- procedural mission-terminal contracts for combat, prospecting and salvage;
- a city vendor kiosk for supplies and selling resources/salvage;
- deployable Scout camps that heal nearby characters;
- lightweight moving city population and sky traffic;
- deterministic world reseeding while character progression persists.

## Run it

Serve the directory because the prototype uses ES modules:

```powershell
cd $HOME\far-horizon
git pull --ff-only
py -m http.server 8080
```

Then open <http://localhost:8080>.

## Controls

- `WASD` — move
- `Shift` — sprint
- `Mouse` — look/aim
- `Left click` — fire
- `Q` — survey pulse
- `H` — hand-sample a nearby resource deposit
- `E` — interact / salvage / use local terminal
- `1` — use medkit
- `B` — deploy a crafted field camp after training Scout
- `I` — inventory/resources
- `K` — professions and skills
- `C` — crafting
- `M` — mission terminal
- `R` — generate a new world seed

## Direction

The goal is not to reproduce an old MMO client. The goal is to find out how much of the **deep sandbox structure** works in a modern single-player procedural world, then scale outward toward vehicles, streamed terrain, larger cities, creature/ecology systems, player property, businesses, NPC economy, starships and planetary travel.

## Changelog

### 0.2.0 — systems slice

Added persistent character progression, profession trees, activity XP, health/combat consequences, resource-quality batches, sampling, crafting, permanent crafted upgrades, salvage, mission contracts, vendor economy, field camps and lightweight city population.

### 0.1.1

Fixed camera-relative movement and expanded vertical aim range.

### 0.1.0

First procedural terrain/city, third-person controls, drones and survey proof.


## Using original SWG client textures

Far Horizon can use a curated set of original SWG DDS textures from a **local SWG Restoration/client installation**. The original environment textures live in encrypted TRE archives, so they are decoded locally and are deliberately excluded from this Git repository.

The normal PowerShell workflow is:

```powershell
cd $HOME\far-horizon
git pull --ff-only
py tools\import_swg_assets.py
py -m http.server 8080
```

Then open <http://localhost:8080>. The importer scans all TRE path tables, ranks candidates by semantic terms, records the exact archive and virtual path selected for every role, extracts 14 material roles, and creates local glTF proof meshes from `ins_all_min_moisture_s01_u0_l0.msh` and a real Stormtrooper body. The browser automatically uses the local sand, normal, Tatooine wall/floor, concrete, road, spaceport and industrial-metal materials. It also replaces the capsule player and ambient crowd agents with the extracted Stormtrooper when the character proof is available. The upper-right HUD reports `SWG LOCAL 14/14` and `CHARACTER STORMTROOPER` when the local material and character textures decoded; `SWG FALLBACK` or `CAPSULE FALLBACK` means the corresponding local files are unavailable, and a partial count identifies a decode failure. The converted moisture-vaporator proof is placed on a concrete display pad near the starting area. If the manifest is absent or an asset fails to load, the procedural fallback materials remain active.

If the page was already open while pulling a new branch, use `Ctrl+F5` after rerunning the importer so the HTML/module graph is refreshed. The HUD count and browser console line beginning with `SWG LOCAL` are the quickest way to verify that the local client assets are active rather than merely present on disk.

The importer auto-detects common `SWG Restoration` install locations. If yours is elsewhere:

```powershell
py tools\import_swg_assets.py --source "D:\Games\SWG Restoration"
```

Useful inventory searches do not depend on guessed full filenames:

```powershell
py tools\import_swg_assets.py --source "C:\SWG Restoration" --search tatooine sand --extension .dds --limit 30
py tools\import_swg_assets.py --source "C:\SWG Restoration" --search mos eisley wall --extension .dds --limit 30
py tools\import_swg_assets.py --source "C:\SWG Restoration" --search industrial metal --extension .dds --limit 30
py tools\import_swg_assets.py --source "C:\SWG Restoration" --mesh-report --limit 40
```

The local decoder handles the Restoration TRE protection chain (Twofish-128 ECB followed by zlib) and validates the extracted files as real DDS/IFF payloads. The mesh proof currently supports the static `FORM MESH` subset used by `.msh` files: vertex positions/normals/UV0, index buffers, shader-group names and glTF output. The Stormtrooper proof is a static body mesh with its shader-referenced DDS files; it has no SWG skeleton, walk-cycle animation, `.lod` selection, hue customization or `.iff` appearance-object behavior yet. The importer intentionally does not pretend to resolve the full SWG `.sht` shader graph, `.lod` hierarchy, `.apt` appearance chain or `.pob` building layout; those are catalogued in `assets/local-swg/asset-catalog.json` for the next conversion pass.

The generated manifest shape is documented in [`docs/local-swg-manifest.schema.json`](docs/local-swg-manifest.schema.json).

Imported SWG files live under `assets/local-swg/` and are gitignored.
