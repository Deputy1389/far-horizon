# Far Horizon local Unreal validation

Status: FAIL
Branch: unreal/foundation-v0.1
Commit: d23cfc42414957834ed71947354d11709afc8ae4
UE: 5.8
Tested: 2026-09-21T05:28:06.0060148Z
Failed stage: build

## Steps

- build: exit , 7s, timedOut=False

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
Warning: [Upgrade]
Warning: [Upgrade] Using backward-compatible build settings. The latest version of UE sets the following values by default, which may require code changes:
Warning: [Upgrade]     FPSemantics = Precise                              => Updates default floating point semantics for Editor and Program targets to Precise for Microsoft platforms. Game, Client, & Server default remains Imprecise. (Previously: Imprecise for MSVC, Precise for Clang)
Warning: [Upgrade]     ReturnTypeWarningLevel = WarningLevel.Error        => Validates that non-void functions return a value. (Previously: Off for VCClang, Error for MSVC and non-VC Clang).
Warning: [Upgrade]     DanglingWarningLevel = WarningLevel.Error          => Enables clang warnings related possible dangling references or pointers. (Previously: Off for VCClang, Error for non-VC Clang).
Warning: [Upgrade]     UnreachableCodeWarningLevel = WarningLevel.Error   => Enables compile-time validation of unreachable code. (Previously: Error for MSVC, Off for Clang).
Warning: [Upgrade] Suppress this message by setting 'DefaultBuildSettings = BuildSettingsVersion.V7;' in FarHorizonEditor.Target.cs, and explicitly overriding settings that differ from the new defaults.
Warning: [Upgrade]
Wrote partial receipt to <USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\Binaries\Win64\FarHorizonEditor.target
FarHorizonEditor modifies the values of properties: [ UnreachableCodeWarningLevel: Off != Error, ReturnTypeWarningLevel: Off != Error, DanglingWarningLevel: Off != Error ]. This is not allowed, as FarHorizonEditor has build products in common with UnrealEditor.
Remove the modified setting, change FarHorizonEditor to use a unique build environment by setting 'BuildEnvironment = TargetBuildEnvironment.Unique;' in the FarHorizonEditorTarget constructor, or set bOverrideBuildEnvironment = true to force this setting on.
Result: Failed (OtherCompilationError)
Total execution time: 6.40 seconds
Trace written to file <USER_HOME>\AppData\Local\UnrealBuildTool\Trace.uba with size 2.1kb
