# Local Unreal Dev Agent

Far Horizon uses a persistent local validation runner so the user's Windows machine can continuously test commits pushed to the active Unreal branch without repeatedly copying PowerShell commands or screenshots.

## What it does

The runner watches:

- `origin/unreal/foundation-v0.1`

When that branch changes, the runner:

1. resolves the new remote commit;
2. updates an isolated Git worktree under the user's local app-data directory;
3. keeps Unreal-generated build caches in that isolated worktree for incremental builds;
4. links local-only SWG imported assets into the test worktree when they exist;
5. builds `FarHorizonEditor Win64 Development` with UnrealBuildTool;
6. runs Far Horizon C++ automation tests headlessly;
7. runs a headless game boot smoke;
8. extracts a bounded set of useful diagnostics;
9. sanitizes user-home, test-workspace and Unreal-install paths;
10. publishes only the compact result to `automation/unreal-local-results`;
11. waits for the next commit.

The user's normal Far Horizon checkout is not reset, cleaned, switched or otherwise mutated by the runner.

## Start it

After Unreal Engine 5.8 has finished installing:

```powershell
cd $HOME\far-horizon
git switch unreal/foundation-v0.1
git pull --ff-only
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Run-Dev-Agent.ps1
```

Leave that PowerShell window open. Stop it with `Ctrl+C`.

The runner immediately validates the current remote head, then polls every 20 seconds.

## Useful options

Run exactly one validation:

```powershell
.\tools\Run-Dev-Agent.ps1 -RunOnce
```

Use a custom Unreal install:

```powershell
.\tools\Run-Dev-Agent.ps1 -EngineRoot "D:\Epic Games\UE_5.8"
```

Do not publish compact results to GitHub:

```powershell
.\tools\Run-Dev-Agent.ps1 -NoPublish
```

Launch the tested isolated Unreal project after a fully green run:

```powershell
.\tools\Run-Dev-Agent.ps1 -LaunchOnPass
```

Watch another development branch:

```powershell
.\tools\Run-Dev-Agent.ps1 -Branch "some/other-branch"
```

## Local state

By default the runner stores disposable state under:

```text
%LOCALAPPDATA%\FarHorizonDevAgent\
```

That contains:

- `test-worktree\` — isolated checkout used for builds/tests;
- `logs\` — complete local build/test/boot logs;
- `results-clone\` — tiny clone used only to publish sanitized results.

Full logs remain local. The public result branch receives only `latest.json` and `latest.md` with compact diagnostics.

## GitHub result contract

The latest local-machine result is published to:

```text
automation/unreal-local-results
```

The stable machine-readable file is:

```text
latest.json
```

It contains:

- source branch;
- tested commit SHA;
- PASS/FAIL;
- failed stage;
- Unreal version;
- per-stage exit code, timeout state and duration;
- sanitized diagnostic lines.

This branch is intentionally separate from gameplay development branches. Local-machine validation results never create commits on the branch being tested.

## Validation stages

### 1. Compile

The runner calls the engine's `Build.bat` with:

```text
Target: FarHorizonEditor Win64 Development
Project: FarHorizon.uproject
```

### 2. Unreal automation

The runner launches `UnrealEditor-Cmd.exe` with `NullRHI` and runs the `FarHorizon` automation-test namespace.

Initial C++ tests cover the spherical planet math foundation. New systems should add automation coverage under the same `FarHorizon.*` namespace where practical.

### 3. Headless boot

After compile and automation pass, the runner starts the project in unattended game mode with `NullRHI` and immediately quits. Fatal errors, assertions and unhandled exceptions fail this stage.

## Design rules

- The runner never performs a pull/reset/clean on the user's active checkout.
- It tests exact remote SHAs rather than "whatever happens to be local."
- Generated Unreal caches are kept locally for faster incremental builds.
- Proprietary/local SWG assets are never copied into Git history.
- Full machine logs are not published.
- Published diagnostics are bounded and path-sanitized.
- A failed test waits for a new commit rather than hammering the same failure indefinitely.
- Build/test timeouts prevent an unattended process from hanging forever.

## What this does not do

The runner removes the user's manual role from compiler errors, startup crashes and automated-test failures. It does not make a normal ChatGPT conversation continue executing after a response on its own. A coding agent or active work session can read the published result branch and iterate on it; ordinary chat still needs another turn before additional work can be performed.

Visual and feel judgments still require a real playtest: animation quality, weapon feel, AI believability, vehicle handling, layout and art direction cannot be proven by a headless smoke test.
