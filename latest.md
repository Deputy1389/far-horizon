# Far Horizon local Unreal validation

Status: PASS
Branch: unreal/foundation-v0.1
Commit: 185f1d4fa22ad6e93724c6634092c88c3b57282e
UE: 5.8
Tested: 2026-09-21T06:43:39.0622595Z
Failed stage: none

## Steps

- build: exit 0, 15.4s, timedOut=False
- automation: exit 0, 25.5s, timedOut=False
- boot: exit 0, 17.7s, timedOut=False

## Diagnostics

<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(147,21): error C2248: 'UNavigationSystemV1::RebuildAll': cannot access protected member declared in class 'UNavigationSystemV1'
[2026.09.21-06.43.20:858][594]LogAutomationCommandLine: Shutting down. GIsCriticalError=0
