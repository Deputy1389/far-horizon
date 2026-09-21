# Far Horizon local Unreal validation

Status: PASS
Branch: unreal/foundation-v0.1
Commit: 3682aa10a3b92339f7f03ca66fd20c6f456076ff
UE: 5.8
Tested: 2026-09-21T07:53:28.8851914Z
Failed stage: none

## Steps

- build: exit 0, 13.8s, timedOut=False
- automation: exit 0, 26.9s, timedOut=False
- boot: exit 0, 20.6s, timedOut=False

## Diagnostics

[2026.09.21-07.53.07:684][584]LogAutomationCommandLine: Shutting down. GIsCriticalError=0
[2026.09.21-07.53.25:603][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\FirstPerson\Anims\ABP_FP_Copy.uasset: [Compiler] ABP_FP_Copy  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.53.25:692][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_TP_Rifle.uasset: [Compiler] ABP_TP_Rifle  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.53.25:754][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_TP_Pistol.uasset: [Compiler] ABP_TP_Pistol  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.53.25:869][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] ABP_FP_Pistol  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.53.25:880][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] Can't connect pins  Object  and  ReturnValue : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.53.25:881][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] In use pin  AsShooter Character  no longer exists on node  Bad cast node . Please refresh node or break links to remove pin.
[2026.09.21-07.53.25:882][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] Can't connect pins  ReturnValue  and  Object : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.53.25:888][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] The property associated with  FirstPersonCameraComponent  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Pistol.ABP_FP_Pistol_C'
[2026.09.21-07.53.25:889][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] The property associated with  FirstPersonMesh  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Pistol.ABP_FP_Pistol_C'
[2026.09.21-07.53.26:269][  0]LogStateTreeEditor: Error: Failed to compile 'StateTree /Game/Variant_Shooter/Blueprints/AI/ST_Shooter.ST_Shooter', errors follow.
[2026.09.21-07.53.26:271][  0]LogStateTreeEditor: Error: State 'Move to Roam Location': Task 'Move To': Could not find matching Context object for Context property 'AIController' on 'Task 'Root/Armed States/Search for Enemy/Move to Roam Location/Move To''. Property must have manual binding.
[2026.09.21-07.53.26:271][  0]LogStateTreeEditor: Error: State 'Attack Enemy': Task 'Run Parallel Tree': Failed to find binding source property 'Target Actor' for target Task 'Root/Armed States/Attack Enemy/Run Parallel Tree' State Tree.Parameters.Value.Target.
[2026.09.21-07.53.26:271][  0]LogStateTreeEditor: Error: State 'Move to Sniping Location': Task 'Move To': Could not find matching Context object for Context property 'AIController' on 'Task 'Root/Armed States/Attack Enemy/Move to Sniping Location/Move To''. Property must have manual binding.
[2026.09.21-07.53.26:272][  0]LogStateTreeEditor: Error: State 'Move to Investigate Location': Task 'Move To': Failed to find binding source property 'Investigate Location' for target Task 'Root/Armed States/Investigate Location/Move to Investigate Location/Move To' Destination.
[2026.09.21-07.53.26:273][  0]LogStateTreeEditor: Error: Failed to compile 'StateTree /Game/Variant_Shooter/Blueprints/AI/ST_Shooter_ShootAtTarget.ST_Shooter_ShootAtTarget', errors follow.
[2026.09.21-07.53.26:273][  0]LogStateTreeEditor: Error: State 'Shooting': Task 'Delay Task': Failed to find binding source property 'OutValue' for target Task 'Root/Attacking/Shooting/Delay Task' Duration.
[2026.09.21-07.53.26:273][  0]LogStateTreeEditor: Error: State 'Reloading': Task 'Delay Task': Failed to find binding source property 'OutValue' for target Task 'Root/Attacking/Reloading/Delay Task' Duration.
[2026.09.21-07.53.26:366][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] ABP_FP_Weapon  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.53.26:371][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] Can't connect pins  Object  and  ReturnValue : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.53.26:371][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] In use pin  AsShooter Character  no longer exists on node  Bad cast node . Please refresh node or break links to remove pin.
[2026.09.21-07.53.26:372][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] Can't connect pins  ReturnValue  and  Object : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.53.26:377][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] The property associated with  FirstPersonCameraComponent  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Weapon.ABP_FP_Weapon_C'
[2026.09.21-07.53.26:378][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] The property associated with  FirstPersonMesh  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Weapon.ABP_FP_Weapon_C'
