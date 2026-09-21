# Far Horizon local Unreal validation

Status: FAIL
Branch: unreal/foundation-v0.1
Commit: fbecbf09074e6b3b93996b1875efd4010c633668
UE: 5.8
Tested: 2026-09-21T07:52:00.8585948Z
Failed stage: build

## Steps

- build: exit 0, 29.5s, timedOut=False

## Diagnostics

<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp(30,19): error C2509: 'InitGame': member function not declared in 'AFHGameMode'
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp(39,19): error C2039: 'TryEnableEpicShooterFoundation': is not a member of 'AFHGameMode'
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp(64,5): error C2065: 'DefaultPawnClass': undeclared identifier
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp(65,5): error C2065: 'PlayerControllerClass': undeclared identifier
<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp(66,5): error C2065: 'bUsingEpicShooterFoundation': undeclared identifier
