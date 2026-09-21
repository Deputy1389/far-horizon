# Far Horizon — Game Vision

## North star

Far Horizon is a first-person galactic-conquest sandbox.

The player lives inside the same persistent war that the strategy layer simulates. A planet is not a menu node that launches a match, and procedural generation is not an end in itself. The strategy layer creates reasons to travel, fight, defend, build, and eventually command; the first-person layer is how the player experiences those consequences.

The target experience combines:

- responsive, readable first-person combat with visible blaster projectiles;
- the freedom to travel across large procedural planets and eventually between them;
- a persistent Rebel-versus-Empire war with physical armies, convoys, fleets, territory, supply and infrastructure;
- large hybrid cities and settlements whose strategic value comes from what they contain and connect;
- vehicles and ships that make near-real planetary scale practical;
- an optional command/building layer that grows from squad orders into faction infrastructure and strategic direction.

The guiding rule is:

> The strategy layer generates the adventure; the FPS layer lets the player live it.

## Player fantasy

The player starts as one capable person, not automatically the supreme commander.

They can begin neutral, choose who to help, join a faction, build trust and eventually gain authority. Early command may mean ordering a nearby squad to follow, defend or assault. Later command can grow into directing battalions, armor, aircraft, fleets, engineering and construction.

The game should support the fantasy of opening a strategic map, ordering a force to attack a city, closing the map, shouldering a blaster and personally participating in the attack.

## War model

The war continues when the player is elsewhere. Major changes should be telegraphed strongly enough that the player can choose to participate.

Territory emerges from actual conditions rather than an arbitrary capture percentage:

- military presence and casualties;
- control of cities, settlements and bases;
- roads, supply routes and logistics;
- spaceports and transport capacity;
- factories, power and infrastructure;
- population support;
- orbital superiority;
- special strategic objectives.

Armies and fleets are strategic pieces. Ground forces physically move between locations when the player is nearby, and their abstract strategic state is preserved when the player is far away.

A destroyed convoy does not arrive at its destination. A captured starport changes reinforcement options. A lost factory changes production. Space and ground warfare eventually feed the same strategic simulation.

## World model

Planets are large, spherical and procedurally generated from stable seeds. Large areas can be genuinely empty because speeders, aircraft and starships make distance meaningful rather than tedious.

Procedural generation follows world logic. Terrain, resources, routes and strategic needs help determine where settlements, roads, industry and military installations appear. Authored landmarks can be embedded in generated regions.

The first testbed is a Tatooine-like desert planet because the existing local SWG asset pipeline already provides useful environmental and character material.

## Combat

The first release target is skill-forward rather than RPG-stat-forward.

Normal soldiers should die quickly enough that aim, positioning, movement and cover matter. The player is also vulnerable. Blasters use visible fast projectiles: close-range shots feel immediate while long-range shots require meaningful lead.

Initial weapons:

- blaster pistol;
- blaster rifle.

Both support hip fire and ADS. More weapons and equipment come after the foundation feels good.

## Movement

The player is first-person only for the initial foundation.

Required movement:

- responsive walk and sprint;
- useful jump without bunny-hopping;
- reliable stairs and slopes;
- mantle/vault;
- crouch;
- prone;
- predictable grounded and airborne control.

Movement quality is a release gate, not polish to add later.

## Vehicles

The first vehicle is a first-person speeder.

It should be easy to control but physically expressive: hover response, banking, some drift and strong high-speed desert traversal. Roads improve speed and reliability without making wilderness inaccessible.

## Cities

Cities use a hybrid approach:

- authored landmark and strategic structures;
- procedural districts, streets, alleys and outskirts;
- reusable modular environment assets;
- important interiors first, exterior-shell buildings elsewhere.

The architecture must support hundreds of visible civilians/soldiers in busy areas while only nearby/relevant agents run expensive AI.

## Space

The long-term target is seamless ground → atmosphere → orbit → hyperspace → another planet, with meaningful dogfights and fleet battles.

Foundation v0.1 does not need full spaceflight. The strategic model should already treat fleets and orbital control as real pieces so the later space layer connects to existing systems rather than becoming a separate minigame.

## Building and strategy

Construction grows in scope over time:

personal camp → forward base → military installation → settlement → factories/logistics → roads/defenses/infrastructure → broader strategic development.

Building is deliberately postponed until movement, combat, terrain, vehicles and the first planetary war loop are fun.

## Foundation v0.1 acceptance fantasy

One Tatooine-like planet. Empire versus Rebels.

The player spawns outside a large city, moves through the world with a polished FPS controller, encounters a physical Imperial convoy, enters a contested city, fights competent squads, changes a strategically meaningful objective, sees the planetary situation react, gets onto a first-person speeder and drives several kilometers back into continuously streamed wilderness while the battle continues behind them.

If that is not enjoyable, adding more planets or simulation depth is not the priority.
