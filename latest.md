# Far Horizon local Unreal validation

Status: FAIL
Branch: unreal/foundation-v0.1
Commit: 09724326143c486293c41fac5f7da4f270371c78
UE: 5.8
Tested: 2026-09-21T07:20:01.5760047Z
Failed stage: build

## Steps

- build: exit 0, 5.3s, timedOut=False

## Diagnostics

<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(135,35): error C2039: 'SetAtmosphereSunLight': is not a member of 'ULightComponent'
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(136,35): error C2039: 'SetAtmosphereSunLightIndex': is not a member of 'ULightComponent'
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(137,35): error C2039: 'SetDynamicShadowDistanceMovableLight': is not a member of 'ULightComponent'
