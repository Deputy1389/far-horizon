param(
    [string]$Branch = "unreal/foundation-v0.1",
    [string]$Remote = "origin",
    [int]$PollSeconds = 20,
    [string]$EngineRoot = "",
    [string]$ResultsBranch = "automation/unreal-local-results",
    [switch]$RunOnce,
    [switch]$LaunchOnPass,
    [switch]$NoPublish
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required but was not found on PATH."
}

if ($PollSeconds -lt 5) {
    throw "PollSeconds must be at least 5."
}

function Invoke-FHNativeGit {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & git -C $RepoRoot @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    if (-not $AllowFailure -and $code -ne 0) {
        $message = $output -join [Environment]::NewLine
        throw "git $($Arguments -join ' ') failed with exit code $code.$([Environment]::NewLine)$message"
    }

    [PSCustomObject]@{
        ExitCode = $code
        Output = @($output)
    }
}

function Get-FHWatchedHead {
    $remoteRef = "+refs/heads/{0}:refs/remotes/{1}/{0}" -f $Branch, $Remote

    Invoke-FHNativeGit -Arguments @(
        "fetch",
        "--no-tags",
        $Remote,
        $remoteRef
    ) | Out-Null

    $result = Invoke-FHNativeGit -Arguments @(
        "rev-parse",
        "refs/remotes/$Remote/$Branch"
    )

    $sha = ([string]($result.Output | Select-Object -First 1)).Trim()
    if ([string]::IsNullOrWhiteSpace($sha)) {
        throw "Could not resolve $Remote/$Branch."
    }

    return $sha
}

function Export-FHFileFromCommit {
    param(
        [Parameter(Mandatory=$true)][string]$Sha,
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    $spec = "$($Sha):$RepoPath"
    $result = Invoke-FHNativeGit -Arguments @("show", $spec)

    $content = ($result.Output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Destination, $content + [Environment]::NewLine, $encoding)
}

function Invoke-FHCoreForCommit {
    param(
        [Parameter(Mandatory=$true)][string]$Sha,
        [Parameter(Mandatory=$true)][string]$RuntimeDir
    )

    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

    $corePath = Join-Path $RuntimeDir "Run-Dev-Agent-Core.ps1"
    $commonPath = Join-Path $RuntimeDir "Unreal-Common.ps1"

    Export-FHFileFromCommit -Sha $Sha -RepoPath "tools/Run-Dev-Agent-Core.ps1" -Destination $corePath
    Export-FHFileFromCommit -Sha $Sha -RepoPath "tools/Unreal-Common.ps1" -Destination $commonPath

    $powershellExe = Join-Path $PSHOME "powershell.exe"
    if (-not (Test-Path $powershellExe)) {
        throw "Could not find powershell.exe at '$powershellExe'."
    }

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add("-NoProfile")
    $arguments.Add("-ExecutionPolicy")
    $arguments.Add("Bypass")
    $arguments.Add("-File")
    $arguments.Add($corePath)
    $arguments.Add("-Branch")
    $arguments.Add($Branch)
    $arguments.Add("-Remote")
    $arguments.Add($Remote)
    $arguments.Add("-PollSeconds")
    $arguments.Add([string]$PollSeconds)
    $arguments.Add("-ResultsBranch")
    $arguments.Add($ResultsBranch)
    $arguments.Add("-RepoRootOverride")
    $arguments.Add($RepoRoot)
    $arguments.Add("-TargetSha")
    $arguments.Add($Sha)
    $arguments.Add("-RunOnce")

    if (-not [string]::IsNullOrWhiteSpace($EngineRoot)) {
        $arguments.Add("-EngineRoot")
        $arguments.Add($EngineRoot)
    }
    if ($LaunchOnPass) {
        $arguments.Add("-LaunchOnPass")
    }
    if ($NoPublish) {
        $arguments.Add("-NoPublish")
    }

    $startParams = @{
        FilePath = $powershellExe
        ArgumentList = @($arguments)
        WorkingDirectory = $RepoRoot
        NoNewWindow = $true
        PassThru = $true
    }
    $process = Start-Process @startParams

    $process.WaitForExit()
    return $process.ExitCode
}

$runtimeBase = if ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA "FarHorizonDevAgent"
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) "FarHorizonDevAgent"
}
$supervisorRuntime = Join-Path $runtimeBase "supervisor"
New-Item -ItemType Directory -Force -Path $supervisorRuntime | Out-Null

Write-Host ""
Write-Host "Far Horizon Unreal dev-agent supervisor"
Write-Host "Watching:      $Remote/$Branch"
Write-Host "Poll interval: $PollSeconds seconds"
Write-Host ""
Write-Host "The validation core is reloaded from each new commit."
Write-Host "Leave this window open. Press Ctrl+C to stop."
Write-Host ""

$lastSha = ""

while ($true) {
    try {
        $sha = Get-FHWatchedHead

        if ($sha -ne $lastSha) {
            $shortSha = $sha.Substring(0, [Math]::Min(12, $sha.Length))
            Write-Host ""
            Write-Host "New commit: $shortSha"
            Write-Host "Loading runner core from that commit..."

            $exitCode = Invoke-FHCoreForCommit -Sha $sha -RuntimeDir $supervisorRuntime
            Write-Host "Runner core exited with code $exitCode for $shortSha."

            $lastSha = $sha

            if ($RunOnce) {
                break
            }
        }
    } catch {
        Write-Warning $_.Exception.Message

        if ($RunOnce) {
            throw
        }
    }

    Start-Sleep -Seconds $PollSeconds
}
