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
$resultsJson = Join-Path (Join-Path $runtimeBase "results-clone") "latest.json"
New-Item -ItemType Directory -Force -Path $supervisorRuntime | Out-Null

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "FAR HORIZON BACKGROUND TESTER" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Leave this window open."
Write-Host ""
Write-Host "What the messages mean:"
Write-Host "  TESTING = new code is being checked" -ForegroundColor Yellow
Write-Host "  READY   = latest code passed and is playable" -ForegroundColor Green
Write-Host "  FAILED  = testing finished and found a problem; NOT stuck" -ForegroundColor Red
Write-Host "  IDLE    = nothing to do; waiting for new code" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Press Ctrl+C only when you intentionally want to stop the tester."
Write-Host ""

$lastSha = ""
$lastIdleMessage = Get-Date

while ($true) {
    try {
        $sha = Get-FHWatchedHead

        if ($sha -ne $lastSha) {
            $shortSha = $sha.Substring(0, [Math]::Min(12, $sha.Length))
            Write-Host ""
            Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
            Write-Host "STATUS: TESTING NEW CODE" -ForegroundColor Yellow
            Write-Host "The newest changes are being built and tested."
            Write-Host "You do not need to do anything."
            Write-Host "------------------------------------------------------------" -ForegroundColor Yellow

            $exitCode = Invoke-FHCoreForCommit -Sha $sha -RuntimeDir $supervisorRuntime

            $reportedStatus = $null
            $reportedStage = $null
            $reportedSha = $null

            if (Test-Path $resultsJson) {
                try {
                    $result = Get-Content $resultsJson -Raw | ConvertFrom-Json
                    $reportedStatus = [string]$result.status
                    $reportedStage = [string]$result.failedStage
                    $reportedSha = [string]$result.sha
                } catch {
                }
            }

            if ($reportedSha -eq $sha -and $reportedStatus -eq "PASS") {
                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Green
                Write-Host "STATUS: READY TO PLAY" -ForegroundColor Green
                Write-Host "Latest code passed build + tests + boot."
                Write-Host "The tester is now IDLE and watching for future changes."
                Write-Host "============================================================" -ForegroundColor Green
            } elseif ($reportedSha -eq $sha -and $reportedStatus -eq "FAIL") {
                $stageText = if ([string]::IsNullOrWhiteSpace($reportedStage)) { "unknown" } else { $reportedStage }
                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Red
                Write-Host "STATUS: FAILED - NOT STUCK" -ForegroundColor Red
                Write-Host "Testing finished and found a problem."
                Write-Host "Failed stage: $stageText"
                Write-Host "Nothing is still compiling."
                Write-Host "Leave this window open; it will test the next fix automatically."
                Write-Host "============================================================" -ForegroundColor Red
            } else {
                Write-Host ""
                Write-Host "STATUS: TEST FINISHED, RESULT NOT PUBLISHED" -ForegroundColor Magenta
                Write-Host "The test process ended, but the result file was not updated."
                Write-Host "This may need attention if it repeats."
            }

            $lastSha = $sha
            $lastIdleMessage = Get-Date

            if ($RunOnce) {
                break
            }
        } elseif (((Get-Date) - $lastIdleMessage).TotalSeconds -ge 60) {
            Write-Host "STATUS: IDLE - watching for new code. Nothing is stuck." -ForegroundColor DarkGray
            $lastIdleMessage = Get-Date
        }
    } catch {
        Write-Host ""
        Write-Host "STATUS: TESTER PROBLEM" -ForegroundColor Magenta
        Write-Host $_.Exception.Message
        Write-Host "The supervisor will retry automatically." -ForegroundColor Magenta

        if ($RunOnce) {
            throw
        }
    }

    Start-Sleep -Seconds $PollSeconds
}
