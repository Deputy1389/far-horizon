# Far Horizon local Unreal validation

Status: FAIL
Branch: unreal/foundation-v0.1
Commit: b146032d03d57cad962667a82408ad2e53432391
UE: 5.8
Tested: 2026-09-21T06:07:02.9660209Z
Failed stage: build

## Steps

- build: exit , 21.8s, timedOut=False

## Diagnostics

Using bundled DotNet SDK version: 10.0 win-x64
Running UnrealBuildTool: dotnet "..\..\Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll" -Target="FarHorizonEditor Win64 Development" -Project="<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree\FarHorizon.uproject" -WaitMutex -NoHotReloadFromIDE
Log file: <USER_HOME>\AppData\Local\UnrealBuildTool\Log.txt
Determining max actions to execute in parallel (8 physical cores, 16 logical cores)
  Executing up to 8 processes, one per physical core
Using 'git status' to determine working set for adaptive non-unity build (<USER_HOME>\AppData\Local\FarHorizonDevAgent\test-worktree).
UbaServer - Listening on 0.0.0.0:1345
Available x64 toolchains (1):
 * C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.51.36231
    (Family=14.51.36231, FamilyRank=2, Version=14.51.36246, HostArchitecture=x64, ReleaseChannel=Latest, Architecture=x64)
Visual Studio compiler version 14.51.36246 is newer than latest preferred version 14.50.35717. Please use caution as this compiler has not been heavily tested
Building FarHorizonEditor...
===== Toolchain Information =====
Using ISPC compiler (<ENGINE_ROOT>\Engine\Source\ThirdParty\Intel\ISPC\bin\Windows\ispc.exe)
  Intel(r) Implicit SPMD Program Compiler (Intel(r) ISPC), 1.24.0 (build commit  @ 20250404, LLVM 18.1.2) 
Using Visual Studio 14.51.36246 toolchain (C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.51.36231) and Windows 10.0.26100.0 SDK (C:\Program Files (x86)\Windows Kits\10).
Warning: Visual Studio compiler 14.51.36246 is not a preferred version
=================================
Using Unreal Build Accelerator local executor to run 4 action(s)
  CPU 8 physical cores, 16 logical cores
  Memory 47.93 GB physical, 45.23 GB/71.93 GB committed
  UBA Storage capacity 40 GB
[1/4] Compile [x64] FHAutomationTests.cpp
[2/4] Link [x64] UnrealEditor-FarHorizon.lib
[3/4] Link [x64] UnrealEditor-FarHorizon.dll
[4/4] WriteMetadata FarHorizonEditor.target [NoUba]
Total time in Unreal Build Accelerator local executor: 18.57 seconds
Output binary: <ENGINE_ROOT>\Engine\Binaries\Win64\UnrealEditor.exe
Result: Succeeded
Total execution time: 21.28 seconds
Trace written to file <USER_HOME>\AppData\Local\UnrealBuildTool\Trace.uba with size 6.8kb
