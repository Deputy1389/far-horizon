# Far Horizon local Unreal validation

Status: FAIL
Branch: unreal/foundation-v0.1
Commit: f2aa03effbca69b03f11ec499cf0e1354f68e4e6
UE: 5.8
Tested: 2026-09-21T07:19:30.5054931Z
Failed stage: build

## Steps

- build: exit 0, 12.5s, timedOut=False

## Diagnostics

<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(135,35): error C2039: 'SetAtmosphereSunLight': is not a member of 'ULightComponent'
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(136,35): error C2039: 'SetAtmosphereSunLightIndex': is not a member of 'ULightComponent'
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(137,35): error C2039: 'SetDynamicShadowDistanceMovableLight': is not a member of 'ULightComponent'
