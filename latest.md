# Far Horizon local Unreal validation

Status: PASS
Branch: unreal/foundation-v0.1
Commit: 262c5717b6a0940e4e7e6b9d22db51765fca352f
UE: 5.8
Tested: 2026-09-21T06:44:56.1168540Z
Failed stage: none

## Steps

- build: exit 0, 11.1s, timedOut=False
- automation: exit 0, 23.3s, timedOut=False
- boot: exit 0, 16s, timedOut=False

## Diagnostics

<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHFoundationArena.cpp(147,21): error C2248: 'UNavigationSystemV1::RebuildAll': cannot access protected member declared in class 'UNavigationSystemV1'
[2026.09.21-06.44.39:626][589]LogAutomationCommandLine: Shutting down. GIsCriticalError=0
