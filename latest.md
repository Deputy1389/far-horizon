# Far Horizon local Unreal validation

Status: PASS
Branch: unreal/foundation-v0.1
Commit: 80dbfdd23f1e3ca553943d0e2958b185ea2c8a26
UE: 5.8
Tested: 2026-09-21T07:47:16.1047866Z
Failed stage: none

## Steps

- build: exit 0, 5.9s, timedOut=False
- automation: exit 0, 25.2s, timedOut=False
- boot: exit 0, 26.6s, timedOut=False

## Diagnostics

[2026.09.21-07.47.03:390][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8009a5e UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:390][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb82c2f74 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:390][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb82c1839 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:391][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb866a25b UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:391][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8673060 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:391][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8676ec2 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:391][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb86784c8 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:392][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb868b52f UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:392][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb869dab4 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:392][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb867a956 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:392][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb80c0310 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:392][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb80bff3c UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:393][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb857aeab UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:393][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb857a08f UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:393][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb857a6d4 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:394][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8588c18 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:394][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8595b5a UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:394][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb85952a9 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:395][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8594bd6 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.03:395][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc4a672e4b UnrealEditor-FarHorizon.dll!AFHGameMode::TryEnableEpicShooterFoundation() [<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp:52]
[2026.09.21-07.47.03:395][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc4a672c0a UnrealEditor-FarHorizon.dll!AFHGameMode::InitGame() [<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp:36]
[2026.09.21-07.47.03:395][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca512e758 UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.03:395][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca551c6b8 UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.03:396][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca54d4a3e UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.03:396][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca3cbc224 UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.03:396][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca3c325bd UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.03:396][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee8d645 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.03:396][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee8c3c5 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.03:397][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee8c5ba UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.03:397][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee91256 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.03:397][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7deea5c74 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.03:398][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7deea838a UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.03:398][  0]LogOutputDevice: Error: [Callstack] 0x00007ffdcf587374 KERNEL32.DLL!UnknownFunction []
[2026.09.21-07.47.03:398][  0]LogOutputDevice: Error: [Callstack] 0x00007ffdd153cc91 ntdll.dll!UnknownFunction []
[2026.09.21-07.47.03:399][  0]LogOutputDevice: Error: 
[2026.09.21-07.47.05:875][  0]LogOutputDevice: Error: === Handled ensure: ===
[2026.09.21-07.47.05:875][  0]LogOutputDevice: Error: 
[2026.09.21-07.47.05:876][  0]LogOutputDevice: Error: Ensure condition failed: SeenVariableNames.Contains(It.Key())  [File:D:\build\++UE5\Sync\Engine\Source\Editor\UMGEditor\Private\WidgetBlueprintCompiler.cpp] [Line: 815] 
[2026.09.21-07.47.05:876][  0]LogOutputDevice: Error: Variable [Thumbstick_Aim] was deleted but still has a GUID referenced by WidgetBlueprint [UI_TouchInterface_Shooter]
[2026.09.21-07.47.05:876][  0]LogOutputDevice: Error: Stack: 
[2026.09.21-07.47.05:876][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc7fd31bc0 UnrealEditor-UMGEditor.dll!UnknownFunction []
[2026.09.21-07.47.05:876][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc7fc28efb UnrealEditor-UMGEditor.dll!UnknownFunction []
[2026.09.21-07.47.05:876][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc7fc11e8f UnrealEditor-UMGEditor.dll!UnknownFunction []
[2026.09.21-07.47.05:876][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc8bd553fd UnrealEditor-Kismet.dll!UnknownFunction []
[2026.09.21-07.47.05:877][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc8bd53cf6 UnrealEditor-Kismet.dll!UnknownFunction []
[2026.09.21-07.47.05:877][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8009a5e UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:877][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb82c2f74 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:877][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb82c1839 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:877][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb866a25b UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:877][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8673060 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:878][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8676ec2 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:878][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb86784c8 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:878][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb868b52f UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:878][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb869dab4 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:878][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb867a956 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:879][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb80c0310 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:879][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb80bff3c UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:879][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb857aeab UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:879][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb857a08f UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:879][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb857a6d4 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:879][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8588c18 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:880][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8595b5a UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:880][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb85952a9 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:880][  0]LogOutputDevice: Error: [Callstack] 0x00007ffcb8594bd6 UnrealEditor-CoreUObject.dll!UnknownFunction []
[2026.09.21-07.47.05:880][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc4a672e4b UnrealEditor-FarHorizon.dll!AFHGameMode::TryEnableEpicShooterFoundation() [<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp:52]
[2026.09.21-07.47.05:880][  0]LogOutputDevice: Error: [Callstack] 0x00007ffc4a672c0a UnrealEditor-FarHorizon.dll!AFHGameMode::InitGame() [<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Source\FarHorizon\FHGameMode.cpp:36]
[2026.09.21-07.47.05:880][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca512e758 UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.05:881][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca551c6b8 UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.05:881][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca54d4a3e UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.05:881][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca3cbc224 UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.05:881][  0]LogOutputDevice: Error: [Callstack] 0x00007ffca3c325bd UnrealEditor-Engine.dll!UnknownFunction []
[2026.09.21-07.47.05:881][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee8d645 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.05:881][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee8c3c5 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.05:881][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee8c5ba UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.05:882][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7dee91256 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.05:882][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7deea5c74 UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.05:882][  0]LogOutputDevice: Error: [Callstack] 0x00007ff7deea838a UnrealEditor-Cmd.exe!UnknownFunction []
[2026.09.21-07.47.05:882][  0]LogOutputDevice: Error: [Callstack] 0x00007ffdcf587374 KERNEL32.DLL!UnknownFunction []
[2026.09.21-07.47.05:882][  0]LogOutputDevice: Error: [Callstack] 0x00007ffdd153cc91 ntdll.dll!UnknownFunction []
[2026.09.21-07.47.05:883][  0]LogOutputDevice: Error: 
[2026.09.21-07.47.12:669][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] Message node  Invalid Message Node  has an invalid interface.
[2026.09.21-07.47.12:670][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] Message node  Invalid Message Node  has an invalid interface.
[2026.09.21-07.47.12:671][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  <Unnamed>  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:671][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  Target  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:672][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] Could not find a function named "Touch Jump End" in 'UI_TouchInterface_Shooter'.
[2026.09.21-07.47.12:672][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  <Unnamed>  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:673][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  Target  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:673][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] Could not find a function named "Touch Jump Start" in 'UI_TouchInterface_Shooter'.
[2026.09.21-07.47.12:673][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  <Unnamed>  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:674][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  Target  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:674][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  Axis  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:674][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] Could not find a function named "Secondary Thumbstick" in 'UI_TouchInterface_Shooter'.
[2026.09.21-07.47.12:675][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  <Unnamed>  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:675][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  Target  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:675][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  Axis  no longer exists on node  Invalid Message Node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:676][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] Could not find a function named "Primary Thumbstick" in 'UI_TouchInterface_Shooter'.
[2026.09.21-07.47.12:676][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  NewParam  no longer exists on node  Stick Input (Thumbstick_Aim) . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:677][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Input\UI_TouchInterface_Shooter.uasset: [Compiler] In use pin  NewParam  no longer exists on node  Stick Input (Thumbstick_Move) . Please refresh node or break links to remove pin.
[2026.09.21-07.47.12:869][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_TP_Rifle.uasset: [Compiler] ABP_TP_Rifle  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.47.12:913][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_TP_Pistol.uasset: [Compiler] ABP_TP_Pistol  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.47.13:009][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] ABP_FP_Pistol  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.47.13:019][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] Can't connect pins  Object  and  ReturnValue : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.47.13:019][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] In use pin  AsShooter Character  no longer exists on node  Bad cast node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.13:020][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] Can't connect pins  ReturnValue  and  Object : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.47.13:025][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] The property associated with  FirstPersonCameraComponent  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Pistol.ABP_FP_Pistol_C'
[2026.09.21-07.47.13:025][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Pistol.uasset: [Compiler] The property associated with  FirstPersonMesh  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Pistol.ABP_FP_Pistol_C'
[2026.09.21-07.47.13:128][  0]LogStateTreeEditor: Error: Failed to compile 'StateTree /Game/Variant_Shooter/Blueprints/AI/ST_Shooter.ST_Shooter', errors follow.
[2026.09.21-07.47.13:128][  0]LogStateTreeEditor: Error: State 'Move to Roam Location': Task 'Move To': Could not find matching Context object for Context property 'AIController' on 'Task 'Root/Armed States/Search for Enemy/Move to Roam Location/Move To''. Property must have manual binding.
[2026.09.21-07.47.13:129][  0]LogStateTreeEditor: Error: State 'Attack Enemy': Task 'Run Parallel Tree': Failed to find binding source property 'Target Actor' for target Task 'Root/Armed States/Attack Enemy/Run Parallel Tree' State Tree.Parameters.Value.Target.
[2026.09.21-07.47.13:129][  0]LogStateTreeEditor: Error: State 'Move to Sniping Location': Task 'Move To': Could not find matching Context object for Context property 'AIController' on 'Task 'Root/Armed States/Attack Enemy/Move to Sniping Location/Move To''. Property must have manual binding.
[2026.09.21-07.47.13:129][  0]LogStateTreeEditor: Error: State 'Move to Investigate Location': Task 'Move To': Failed to find binding source property 'Investigate Location' for target Task 'Root/Armed States/Investigate Location/Move to Investigate Location/Move To' Destination.
[2026.09.21-07.47.13:132][  0]LogStateTreeEditor: Error: Failed to compile 'StateTree /Game/Variant_Shooter/Blueprints/AI/ST_Shooter_ShootAtTarget.ST_Shooter_ShootAtTarget', errors follow.
[2026.09.21-07.47.13:132][  0]LogStateTreeEditor: Error: State 'Shooting': Task 'Delay Task': Failed to find binding source property 'OutValue' for target Task 'Root/Attacking/Shooting/Delay Task' Duration.
[2026.09.21-07.47.13:133][  0]LogStateTreeEditor: Error: State 'Reloading': Task 'Delay Task': Failed to find binding source property 'OutValue' for target Task 'Root/Attacking/Reloading/Delay Task' Duration.
[2026.09.21-07.47.13:211][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] ABP_FP_Weapon  - The skeleton asset for this animation Blueprint is missing, so it cannot be compiled!
[2026.09.21-07.47.13:217][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] Can't connect pins  Object  and  ReturnValue : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.47.13:218][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] In use pin  AsShooter Character  no longer exists on node  Bad cast node . Please refresh node or break links to remove pin.
[2026.09.21-07.47.13:218][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] Can't connect pins  ReturnValue  and  Object : This cast has an invalid target type (was the class deleted without a redirect?).
[2026.09.21-07.47.13:224][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] The property associated with  FirstPersonCameraComponent  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Weapon.ABP_FP_Weapon_C'
[2026.09.21-07.47.13:224][  0]LogBlueprint: Error: [AssetLog] <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Content\Variant_Shooter\Anims\ABP_FP_Weapon.uasset: [Compiler] The property associated with  FirstPersonMesh  could not be found in '/Game/Variant_Shooter/Anims/ABP_FP_Weapon.ABP_FP_Weapon_C'
