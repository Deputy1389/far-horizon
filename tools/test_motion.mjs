import assert from 'node:assert/strict';
import {
  advanceBolt,
  createBoltFlight,
  createLocomotionState,
  deriveWeaponPose,
  facingRotation,
  updateLocomotion,
} from '../src/motion.mjs';

const approximately = (actual, expected, epsilon = 1e-6) => {
  assert.ok(
    Math.abs(actual - expected) <= epsilon,
    `expected ${actual} to be within ${epsilon} of ${expected}`,
  );
};

assert.equal(facingRotation(0, true), 0, 'the imported Stormtrooper faces +Z');
approximately(facingRotation(0, false), Math.PI, 1e-12);

const walking = createLocomotionState();
updateLocomotion(walking, 0.1, 1, 18, false);
assert.ok(walking.phase > 0, 'walking advances the gait phase');
assert.ok(walking.moveBlend > 0, 'walking blends into locomotion');
assert.ok(walking.bob >= 0, 'walking produces a grounded vertical bob');

const idle = createLocomotionState();
updateLocomotion(idle, 0.5, 0, 18, false);
assert.equal(idle.moveBlend, 0, 'idle remains out of the walk cycle');
assert.ok(Number.isFinite(idle.bob), 'idle breathing stays finite');

const flight = createBoltFlight([0, 0, 0], [10, 0, 0], 20);
approximately(flight.duration, 0.5);
let progress = advanceBolt(flight, 0.25);
approximately(progress.position[0], 5);
assert.equal(progress.done, false, 'a bolt is still in flight halfway through');
progress = advanceBolt(flight, 0.25);
approximately(progress.position[0], 10);
assert.equal(progress.done, true, 'a bolt completes at its target');

const weaponPose = deriveWeaponPose([4, 2, 1], [1, 3, 1]);
assert.deepEqual(weaponPose.origin, [4, 2, 1], 'the weapon grip follows the right wrist');
approximately(weaponPose.direction[0], -3 / Math.sqrt(10));
approximately(weaponPose.direction[1], 1 / Math.sqrt(10));
approximately(weaponPose.direction[2], 0);
assert.ok(weaponPose.distance > 0, 'a two-handed weapon has a valid hand span');

console.log('motion tests passed');
