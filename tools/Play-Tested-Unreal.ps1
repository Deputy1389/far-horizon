param(
    [string]$Branch = "unreal/foundation-v0.1",
    [string]$Remote = "origin",
    [string]$EngineRoot = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"

if (-not (Test-Path $Common)) {
    throw "Missing shared Unreal tooling: $Common"
}

. $Common

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$tools = Get-FHUnrealTools -EngineRoot $engine.Root

$runtimeBase = if ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA "FarHorizonDevAgent"
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) "FarHorizonDevAgent"
}

$testedRoot = Join-Path $runtimeBase "test-worktree"
$testedProject = Join-Path $testedRoot "FarHorizon.uproject"

if (-not (Test-Path $testedProject)) {
    throw "The validated Unreal worktree does not exist yet. Leave tools\Run-Dev-Agent.ps1 running until a PASS result appears."
}

$remoteLine = & git -C $RepoRoot ls-remote $Remote "refs/heads/$Branch"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$remoteLine)) {
    throw "Could not resolve $Remote/$Branch."
}

$remoteSha = ([string]$remoteLine -split "\s+")[0]
$testedSha = (& git -C $testedRoot rev-parse HEAD).Trim()

if ($LASTEXITCODE -ne 0) {
    throw "Could not resolve the tested worktree commit."
}

if ($remoteSha -ne $testedSha) {
    Write-Host "The dev-agent is still validating a newer commit."
    Write-Host "Remote: $remoteSha"
    Write-Host "Tested: $testedSha"
    throw "Wait for the supervisor to publish PASS for the latest commit, then run this command again."
}

Write-Host "Launching validated Far Horizon commit $($testedSha.Substring(0, 12))..."
Write-Host "Controls: WASD move, mouse look, Shift sprint, Ctrl crouch, RMB aim, LMB fire, Space jump."
Write-Host ""

$args = @(
    ('"{0}"' -f $testedProject),
    "-game",
    "-windowed",
    "-ResX=1600",
    "-ResY=900",
    "-log"
)

Start-Process $tools.Editor -ArgumentList $args
