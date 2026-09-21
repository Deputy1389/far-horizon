# Far Horizon local Unreal validation

Status: FAIL
Branch: unreal/foundation-v0.1
Commit: 6922cf51353ce2bebfc8ab43aca9991accc1fa21
UE: 5.8
Tested: 2026-09-21T07:59:34.5980824Z
Failed stage: build

## Steps

- build: exit 0, 15.7s, timedOut=False

## Diagnostics

<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFrontierWorld.cpp(120,47): error C2445: result type of conditional expression is ambiguous: types 'UStaticMesh *' and 'TObjectPtr<UStaticMesh>' can be converted to multiple common types
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFrontierWorld.cpp(118,9): error C2064: term does not evaluate to a function taking 3 arguments
