# Far Horizon local Unreal validation

Status: PASS
Branch: unreal/foundation-v0.1
Commit: 8dd6407622cbcddb624b459d73d93c29dcbec709
UE: 5.8
Tested: 2026-09-21T06:27:42.4316153Z
Failed stage: none

## Steps

- build: exit 0, 24.2s, timedOut=False
- automation: exit 0, 25.9s, timedOut=False
- boot: exit 0, 17.7s, timedOut=False

## Diagnostics

[2026.09.21-06.27.12:687][  0]LogClass: Error: StructProperty FDataflowToolNodeSnapshot::Date is not initialized properly even though its struct probably has a custom default constructor. Non deterministic fields should use UPROPERTY(Meta = (IgnoreForMemberInitializationTest)) to avoid errors from this test. Module:DataflowNodes File:Public/Dataflow/DataflowToolNode.h
[2026.09.21-06.27.12:706][  0]LogAutomationTest: Error: LogClass: StructProperty FDataflowToolNodeSnapshot::Date is not initialized properly even though its struct probably has a custom default constructor. Non deterministic fields should use UPROPERTY(Meta = (IgnoreForMemberInitializationTest)) to avoid errors from this test. Module:DataflowNodes File:Public/Dataflow/DataflowToolNode.h
[2026.09.21-06.27.24:093][586]LogAutomationCommandLine: Shutting down. GIsCriticalError=0
