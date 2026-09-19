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
