const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

export function facingRotation(yaw, usesImportedPlusZForward) {
  return yaw + (usesImportedPlusZForward ? 0 : Math.PI);
}

export function createLocomotionState() {
  return {
    phase: 0,
    moveBlend: 0,
    bob: 0,
    sway: 0,
    lean: 0,
    roll: 0,
    recoil: 0,
    time: 0,
  };
}

export function updateLocomotion(state, dt, inputMagnitude, speed, sprinting) {
  const elapsed = Math.max(0, Number(dt) || 0);
  const input = Math.max(0, Number(inputMagnitude) || 0);
  const movementSpeed = Math.max(0, Number(speed) || 0);
  const moving = input > 0.001;

  state.time += elapsed;
  const blendRate = 8;
  const targetBlend = moving ? 1 : 0;
  state.moveBlend += clamp(targetBlend - state.moveBlend, -blendRate * elapsed, blendRate * elapsed);

  if (moving) {
    const pace = sprinting ? 10.5 : 7.5;
    const speedScale = clamp(movementSpeed / 18, 0.75, 1.8);
    state.phase += elapsed * pace * speedScale;
  }

  const gait = Math.sin(state.phase);
  const idleAmount = 1 - state.moveBlend;
  const idleBreath = Math.sin(state.time * 1.8) * 0.012 * idleAmount;

  state.bob = idleBreath + Math.max(0, gait) * 0.055 * state.moveBlend;
  state.sway = Math.sin(state.phase * 0.5) * 0.035 * state.moveBlend;
  state.lean = 0.045 * state.moveBlend;
  state.roll = Math.sin(state.phase) * 0.018 * state.moveBlend;
  state.recoil = Math.max(0, state.recoil - elapsed * 7);

  return state;
}

export function triggerLocomotionRecoil(state) {
  state.recoil = Math.min(1, state.recoil + 1);
  return state;
}

export function createBoltFlight(start, end, speed = 420) {
  const from = start.slice(0, 3).map((value) => Number(value) || 0);
  const target = end.slice(0, 3).map((value) => Number(value) || 0);
  const delta = target.map((value, index) => value - from[index]);
  const distance = Math.hypot(delta[0], delta[1], delta[2]);
  const direction = distance > 0
    ? delta.map((value) => value / distance)
    : [0, 0, 1];

  return {
    start: from,
    end: target,
    direction,
    distance,
    duration: Math.max(distance / Math.max(1, Number(speed) || 420), 0.000001),
    elapsed: 0,
    position: [...from],
  };
}

export function advanceBolt(flight, dt) {
  flight.elapsed += Math.max(0, Number(dt) || 0);
  const t = flight.distance === 0
    ? 1
    : clamp(flight.elapsed / flight.duration, 0, 1);

  flight.position = flight.start.map((value, index) => (
    value + (flight.end[index] - value) * t
  ));

  return {
    done: t >= 1,
    position: flight.position,
    progress: t,
  };
}
