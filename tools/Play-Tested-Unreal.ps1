param(
    [string]$Branch = "unreal/foundation-v0.1",
    [string]$Remote = "origin",
    [string]$EngineRoot = "",
    [int]$TimeoutSeconds = 900
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
$resultsJson = Join-Path (Join-Path $runtimeBase "results-clone") "latest.json"

if (-not (Test-Path $testedProject)) {
    throw "The validated Unreal worktree does not exist yet. Leave tools\Run-Dev-Agent.ps1 running first."
}

$started = Get-Date
$lastMessage = ""

while ($true) {
    $remoteLine = & git -C $RepoRoot ls-remote $Remote "refs/heads/$Branch"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$remoteLine)) {
        throw "Could not resolve $Remote/$Branch."
    }

    $remoteSha = ([string]$remoteLine -split "\s+")[0]
    $testedSha = (& git -C $testedRoot rev-parse HEAD).Trim()

    $status = $null
    $resultSha = $null

    if (Test-Path $resultsJson) {
        try {
            $result = Get-Content $resultsJson -Raw | ConvertFrom-Json
            $status = [string]$result.status
            $resultSha = [string]$result.sha
        } catch {
        }
    }

    if (
        $remoteSha -eq $testedSha -and
        $resultSha -eq $remoteSha -and
        $status -eq "PASS"
    ) {
        break
    }

    $shortRemote = $remoteSha.Substring(0, [Math]::Min(12, $remoteSha.Length))
    $shortTested = if ($testedSha) {
        $testedSha.Substring(0, [Math]::Min(12, $testedSha.Length))
    } else {
        "none"
    }

    $message = "Waiting for dev-agent PASS... remote=$shortRemote tested=$shortTested result=$status"
    if ($message -ne $lastMessage) {
        Write-Host $message
        $lastMessage = $message
    }

    if (((Get-Date) - $started).TotalSeconds -ge $TimeoutSeconds) {
        throw "Timed out waiting for the latest Far Horizon commit to pass validation."
    }

    Start-Sleep -Seconds 5
}

Write-Host ""
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
