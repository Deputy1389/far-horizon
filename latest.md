# Far Horizon local Unreal validation

Status: FAIL
Branch: unreal/foundation-v0.1
Commit: 0fbca5e1b675b2b9790d0d9e8e8eb83a3ca158d4
UE: 5.8
Tested: 2026-09-21T05:33:56.5494695Z
Failed stage: build

## Steps

- build: exit , 8.9s, timedOut=False

## Diagnostics

Using bundled DotNet SDK version: 10.0 win-x64
Running UnrealBuildTool: dotnet "..\..\Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll" -Target="FarHorizonEditor Win64 Development" -Project="<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\FarHorizon.uproject" -WaitMutex -NoHotReloadFromIDE
Log file: <USER_HOME>\AppData\Local\UnrealBuildTool\Log.txt
Determining max actions to execute in parallel (8 physical cores, 16 logical cores)
  Executing up to 8 processes, one per physical core
Using 'git status' to determine working set for adaptive non-unity build (<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree).
Creating makefile for FarHorizonEditor (no existing makefile)
UbaServer - Listening on 0.0.0.0:1345
Available x64 toolchains (1):
 * C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.51.36231
    (Family=14.51.36231, FamilyRank=2, Version=14.51.36246, HostArchitecture=x64, ReleaseChannel=Latest, Architecture=x64)
Visual Studio compiler version 14.51.36246 is newer than latest preferred version 14.50.35717. Please use caution as this compiler has not been heavily tested
Unable to instantiate module 'SwarmInterface': Could not find NetFxSDK install dir; this will prevent SwarmInterface from installing.  Install a version of .NET Framework SDK at 4.6.0 or higher.
(referenced via FarHorizonEditor -> Launch.Build.cs -> SessionServices.Build.cs -> Core.Build.cs -> Virtualization.Build.cs -> SourceControl.Build.cs -> RenderCore.Build.cs -> RHI.Build.cs -> D3D11RHI.Build.cs -> Engine.Build.cs -> AssetRegistry.Build.cs -> TargetPlatform.Build.cs -> TurnkeySupport.Build.cs -> LauncherServices.Build.cs -> TurnkeyIO.Build.cs -> ToolWidgets.Build.cs -> AppFramework.Build.cs -> SlateReflector.Build.cs -> PropertyEditor.Build.cs -> EditorConfig.Build.cs -> UnrealEd.Build.cs)
Result: Failed (RulesError)
Total execution time: 8.17 seconds
Trace written to file <USER_HOME>\AppData\Local\UnrealBuildTool\Trace.uba with size 2.4kb
