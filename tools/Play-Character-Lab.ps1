[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
Set-Location $Repo

function Find-GodotExecutable {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $wingetRoot) {
        $candidate = Get-ChildItem $wingetRoot -Recurse -File -Filter "Godot*.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "console" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    throw "Godot 4 was not found."
}

$godot = Find-GodotExecutable
Write-Host "Launching Far Horizon Character Lab..." -ForegroundColor Cyan
Start-Process -FilePath $godot -ArgumentList @("--path", $Repo, "res://game/scenes/character_lab.tscn") -WorkingDirectory $Repo
