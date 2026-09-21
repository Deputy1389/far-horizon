# Foundation v0.1

## Goal

Prove the smallest version of the full game:

**good FPS + large spherical procedural desert + competent enemies + first-person speeder + one physical strategic conflict.**

The foundation is successful when this loop is fun before crafting, professions, base building, a second planet or full spaceflight are added.

## Scope gates

### Gate A — FPS movement

Required before broad world work:

- mouse look feels direct and stable;
- walk/sprint acceleration and stopping feel intentional;
- stairs and slopes do not snag;
- jump is useful but cannot be spammed for speed;
- crouch and prone are reliable;
- mantle works on readable waist/chest-height obstacles;
- collision does not routinely clip through walls;
- movement is stable at 60 physics ticks.

Test in a deliberately ugly movement course.

### Gate B — blaster combat

- pistol + rifle;
- hip fire + ADS;
- visible fast bolts;
- recoil and spread are predictable;
- hits have clear feedback;
- normal soldiers are lethal but not spongey;
- shooting is enjoyable without progression bonuses.

### Gate C — one useful enemy squad

- patrol;
- visual acquisition/LOS;
- alert squad;
- shoot;
- approach/retreat/reposition;
- basic left/right flanking roles;
- nearby combatants can join an alert.

Do not scale to hundreds until a six-to-eight-enemy encounter is good.

### Gate D — planet foundation

- persistent float64 planet-space coordinates;
- local floating origin;
- spherical local terrain patches;
- deterministic terrain seed;
- chunk streaming around the player;
- several kilometers of travel without precision collapse.

Next terrain step after this proof: cube-sphere quadtree LOD.

### Gate E — speeder

- enter/exit;
- first-person driving;
- hover height control;
- banking/drift presentation;
- high-speed traversal over generated terrain;
- predictable recovery from bumps/slopes.

### Gate F — city/combat space

- one large Tatooine-like city;
- hybrid authored/procedural structure;
- roads, alleys, plazas and a garrison/objective;
- important spaces traversable;
- enough occlusion/cover to test squad combat.

Visual replacement with converted SWG modules can proceed independently.

### Gate G — strategic proof

One planet graph with at least:

- Rebel outpost;
- contested city;
- Imperial garrison;
- checkpoints/roads;
- strategic forces that move between nodes;
- ownership/control events;
- local combat hooks that can affect strategic state.

The strategic simulation remains data-first and runs without materializing every soldier.

## First playable scenario

1. Spawn at a Rebel position outside the city.
2. Use polished FPS movement to navigate the outskirts.
3. Take or ignore a nearby speeder.
4. Encounter an Imperial patrol/convoy.
5. Enter the contested city.
6. Fight a squad that alerts/repositions rather than standing still.
7. Capture or influence one strategic objective.
8. Observe the strategic state change.
9. Enter the speeder in first person.
10. Drive several kilometers into streamed desert terrain.

## Explicitly postponed

Until the loop above is solid:

- crafting/profession expansion;
- resource economy depth;
- player housing;
- large building system;
- deep character progression;
- full civilian economy;
- large creature/ecology simulation;
- second planet;
- seamless spaceflight;
- fleet combat;
- multiplayer.

Existing prototype code for those concepts may remain as reference, but it does not set current priorities.

## Development rule

Every new task should answer one of these questions:

- Does it improve movement?
- Does it improve combat?
- Does it improve enemy behavior?
- Does it prove planetary streaming/scale?
- Does it improve the speeder?
- Does it make the city a better combat space?
- Does it connect local action to the strategic war?

If not, it is probably later work.
