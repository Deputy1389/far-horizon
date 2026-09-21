param(
    [string]$Branch = "unreal/foundation-v0.1",
    [string]$Remote = "origin",
    [int]$PollSeconds = 20,
    [string]$EngineRoot = "",
    [string]$ResultsBranch = "automation/unreal-local-results",
    [string]$RepoRootOverride = "",
    [string]$TargetSha = "",
    [switch]$RunOnce,
    [switch]$LaunchOnPass,
    [switch]$NoPublish
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$RepoRoot = if (-not [string]::IsNullOrWhiteSpace($RepoRootOverride)) {
    [System.IO.Path]::GetFullPath($RepoRootOverride)
} else {
    Split-Path -Parent $PSScriptRoot
}
$Common = Join-Path $PSScriptRoot "Unreal-Common.ps1"

if (-not (Test-Path $Common)) {
    throw "Missing shared Unreal tooling: $Common"
}
. $Common

function Invoke-FHGit {
    param(
        [Parameter(Mandatory=$true)][string]$WorkingDirectory,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    # Windows PowerShell 5 promotes native stderr records when the caller uses
    # ErrorActionPreference=Stop. Git writes normal progress (for example
    # "Preparing worktree..." / "Cloning into...") to stderr, so temporarily
    # downgrade only while the native process runs and trust its exit code.
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & git -C $WorkingDirectory @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
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

function Get-FHRemoteSha {
    $result = Invoke-FHGit -WorkingDirectory $RepoRoot -Arguments @("ls-remote", $Remote, "refs/heads/$Branch")
    $line = [string]($result.Output | Select-Object -First 1)

    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "Remote branch '$Remote/$Branch' was not found."
    }

    $parts = $line -split '\s+'
    return $parts[0]
}

function Ensure-FHTestWorktree {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Sha
    )

    if (Test-Path (Join-Path $Path ".git")) {
        Invoke-FHGit -WorkingDirectory $Path -Arguments @("reset", "--hard", $Sha) | Out-Null
        Invoke-FHGit -WorkingDirectory $Path -Arguments @("clean", "-ffd") | Out-Null
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        if (Test-Path $Path) {
            Remove-Item -Recurse -Force $Path
        }
        Invoke-FHGit -WorkingDirectory $RepoRoot -Arguments @("worktree", "add", "--detach", $Path, $Sha) | Out-Null
    }

    $sourceAssets = Join-Path $RepoRoot "assets\local-swg"
    $testAssetsParent = Join-Path $Path "assets"
    $testAssets = Join-Path $testAssetsParent "local-swg"

    if ((Test-Path $sourceAssets) -and -not (Test-Path $testAssets)) {
        New-Item -ItemType Directory -Force -Path $testAssetsParent | Out-Null
        try {
            New-Item -ItemType Junction -Path $testAssets -Target $sourceAssets | Out-Null
        } catch {
            Write-Warning "Could not link local SWG assets into the test worktree: $($_.Exception.Message)"
        }
    }
}

function Invoke-FHLoggedProcess {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string[]]$ArgumentList,
        [Parameter(Mandatory=$true)][string]$WorkingDirectory,
        [Parameter(Mandatory=$true)][string]$LogDirectory,
        [int]$TimeoutSeconds = 1800
    )

    New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
    $stdout = Join-Path $LogDirectory "$Name.stdout.log"
    $stderr = Join-Path $LogDirectory "$Name.stderr.log"
    Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $startParams = @{
        FilePath = $FilePath
        ArgumentList = $ArgumentList
        WorkingDirectory = $WorkingDirectory
        NoNewWindow = $true
        PassThru = $true
        RedirectStandardOutput = $stdout
        RedirectStandardError = $stderr
    }
    $process = Start-Process @startParams
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    $timedOut = -not $finished

    if ($timedOut) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
        } catch {
        }
        $exitCode = 124
    } else {
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }

    $sw.Stop()

    [PSCustomObject]@{
        Name = $Name
        ExitCode = $exitCode
        TimedOut = $timedOut
        DurationSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Test-FHLogFailure {
    param(
        [Parameter(Mandatory=$true)][string[]]$Paths,
        [Parameter(Mandatory=$true)][string[]]$Patterns
    )

    foreach ($path in $Paths) {
        if (-not (Test-Path $path)) {
            continue
        }
        foreach ($pattern in $Patterns) {
            if (Select-String -Path $path -Pattern $pattern -Quiet) {
                return $true
            }
        }
    }
    return $false
}

function ConvertTo-FHSafeText {
    param(
        [AllowEmptyString()][string]$Text,
        [string]$TestRoot,
        [string]$EnginePath
    )

    if ($null -eq $Text) {
        return ""
    }

    $safe = $Text
    $replacements = @(
        @($env:USERPROFILE, "<USER_HOME>"),
        @($TestRoot, "<TEST_ROOT>"),
        @($EnginePath, "<ENGINE_ROOT>")
    )

    foreach ($pair in $replacements) {
        if (-not [string]::IsNullOrWhiteSpace([string]$pair[0])) {
            $safe = $safe -replace [Regex]::Escape([string]$pair[0]), [string]$pair[1]
        }
    }
    return $safe
}

function Get-FHDiagnostics {
    param(
        [Parameter(Mandatory=$true)][object[]]$Steps,
        [string]$TestRoot,
        [string]$EnginePath
    )

    $patterns = @(
        "error C[0-9]{4}",
        "fatal error",
        "Unhandled Exception",
        "Assertion failed",
        "Automation Test Failed",
        "LogAutomation.*Error",
        "Log.*: Error:",
        "BUILD FAILED",
        "ERROR:"
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    foreach ($step in $Steps) {
        foreach ($path in @($step.StdErr, $step.StdOut)) {
            if (-not (Test-Path $path)) {
                continue
            }
            $matches = Select-String -Path $path -Pattern $patterns -ErrorAction SilentlyContinue
            foreach ($match in $matches) {
                $line = ConvertTo-FHSafeText -Text ([string]$match.Line) -TestRoot $TestRoot -EnginePath $EnginePath
                if (-not [string]::IsNullOrWhiteSpace($line) -and -not $lines.Contains($line)) {
                    $lines.Add($line)
                }
            }
        }
    }

    if ($lines.Count -eq 0) {
        $failed = $Steps | Where-Object { $_.ExitCode -ne 0 } | Select-Object -First 1
        if ($failed) {
            foreach ($path in @($failed.StdErr, $failed.StdOut)) {
                if (-not (Test-Path $path)) {
                    continue
                }
                foreach ($line in (Get-Content $path -Tail 80 -ErrorAction SilentlyContinue)) {
                    $safe = ConvertTo-FHSafeText -Text ([string]$line) -TestRoot $TestRoot -EnginePath $EnginePath
                    if (-not [string]::IsNullOrWhiteSpace($safe)) {
                        $lines.Add($safe)
                    }
                }
            }
        }
    }

    $joined = (@($lines | Select-Object -Last 120)) -join [Environment]::NewLine
    if ($joined.Length -gt 24000) {
        $joined = $joined.Substring($joined.Length - 24000)
    }
    return $joined
}

function Ensure-FHResultsClone {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$RemoteUrl,
        [Parameter(Mandatory=$true)][string]$BranchName
    )

    if (Test-Path (Join-Path $Path ".git")) {
        return
    }

    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
    }

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    $clone = Invoke-FHGit -WorkingDirectory $parent -Arguments @(
        "clone",
        "--filter=blob:none",
        "--no-checkout",
        $RemoteUrl,
        $Path
    )
    if ($clone.Output.Count -gt 0) {
        $clone.Output | ForEach-Object { Write-Host ([string]$_) }
    }

    $probe = Invoke-FHGit -WorkingDirectory $Path -Arguments @(
        "ls-remote",
        "--exit-code",
        "--heads",
        "origin",
        $BranchName
    ) -AllowFailure
    $remoteExists = ($probe.ExitCode -eq 0)

    if ($remoteExists) {
        $fetch = Invoke-FHGit -WorkingDirectory $Path -Arguments @("fetch", "origin", $BranchName)
        if ($fetch.Output.Count -gt 0) {
            $fetch.Output | ForEach-Object { Write-Host ([string]$_) }
        }
        Invoke-FHGit -WorkingDirectory $Path -Arguments @("checkout", "-B", $BranchName, "FETCH_HEAD") | Out-Null
    } else {
        Invoke-FHGit -WorkingDirectory $Path -Arguments @("checkout", "--orphan", $BranchName) | Out-Null
    }

    Invoke-FHGit -WorkingDirectory $Path -Arguments @("config", "user.name", "Far Horizon Local Runner") | Out-Null
    Invoke-FHGit -WorkingDirectory $Path -Arguments @("config", "user.email", "far-horizon-runner@localhost") | Out-Null
}

function Publish-FHResult {
    param(
        [Parameter(Mandatory=$true)][string]$ResultsPath,
        [Parameter(Mandatory=$true)][string]$RemoteUrl,
        [Parameter(Mandatory=$true)][string]$BranchName,
        [Parameter(Mandatory=$true)][hashtable]$Payload,
        [Parameter(Mandatory=$true)][string]$Markdown
    )

    Ensure-FHResultsClone -Path $ResultsPath -RemoteUrl $RemoteUrl -BranchName $BranchName
    $jsonPath = Join-Path $ResultsPath "latest.json"
    $mdPath = Join-Path $ResultsPath "latest.md"

    ($Payload | ConvertTo-Json -Depth 8) | Set-Content -Path $jsonPath -Encoding UTF8
    $Markdown | Set-Content -Path $mdPath -Encoding UTF8

    Invoke-FHGit -WorkingDirectory $ResultsPath -Arguments @("add", "latest.json", "latest.md") | Out-Null

    $diff = Invoke-FHGit -WorkingDirectory $ResultsPath -Arguments @("diff", "--cached", "--quiet") -AllowFailure
    if ($diff.ExitCode -eq 0) {
        return
    }
    if ($diff.ExitCode -ne 1) {
        throw "Could not inspect the staged local-runner result (git diff exit $($diff.ExitCode))."
    }

    $shortSha = $Payload.sha.Substring(0, [Math]::Min(8, $Payload.sha.Length))
    $commit = Invoke-FHGit -WorkingDirectory $ResultsPath -Arguments @(
        "commit",
        "-m",
        "runner: $($Payload.status) $shortSha"
    )
    if ($commit.Output.Count -gt 0) {
        $commit.Output | ForEach-Object { Write-Host ([string]$_) }
    }

    $push = Invoke-FHGit -WorkingDirectory $ResultsPath -Arguments @(
        "push",
        "origin",
        "HEAD:refs/heads/$BranchName"
    )
    if ($push.Output.Count -gt 0) {
        $push.Output | ForEach-Object { Write-Host ([string]$_) }
    }
}

function Invoke-FHValidation {
    param(
        [Parameter(Mandatory=$true)][string]$Sha,
        [Parameter(Mandatory=$true)][string]$TestPath,
        [Parameter(Mandatory=$true)][string]$LogsRoot,
        [Parameter(Mandatory=$true)][object]$Engine,
        [Parameter(Mandatory=$true)][object]$UnrealTools
    )

    $shortSha = $Sha.Substring(0, [Math]::Min(12, $Sha.Length))
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDir = Join-Path $LogsRoot "$stamp-$shortSha"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Testing $Branch @ $shortSha"
    Write-Host "============================================================"

    Ensure-FHTestWorktree -Path $TestPath -Sha $Sha
    $project = Join-Path $TestPath "FarHorizon.uproject"
    if (-not (Test-Path $project)) {
        throw "FarHorizon.uproject is missing from tested commit $Sha."
    }

    $steps = [System.Collections.Generic.List[object]]::new()

    $buildCommand = '""{0}" -Target="FarHorizonEditor Win64 Development" -Project="{1}" -WaitMutex -NoHotReloadFromIDE"' -f $UnrealTools.Build, $project
    Write-Host "[1/3] Building FarHorizonEditor..."
    $buildParams = @{
        Name = "build"
        FilePath = $env:ComSpec
        ArgumentList = @("/d", "/s", "/c", $buildCommand)
        WorkingDirectory = $TestPath
        LogDirectory = $logDir
        TimeoutSeconds = 2700
    }
    $build = Invoke-FHLoggedProcess @buildParams
    $steps.Add($build)

    $buildPass = ($build.ExitCode -eq 0)
    $automationPass = $false
    $bootPass = $false

    if ($buildPass) {
        Write-Host "[2/3] Running Far Horizon automation tests..."
        $reportPath = Join-Path $logDir "automation-report"
        $automationArgs = @(
            ('"{0}"' -f $project),
            "-unattended",
            "-nop4",
            "-nosplash",
            "-NullRHI",
            "-NoSound",
            "-stdout",
            "-FullStdOutLogOutput",
            '-ExecCmds="Automation RunTest FarHorizon;Quit"',
            ('-ReportExportPath="{0}"' -f $reportPath)
        )
        $automationParams = @{
            Name = "automation"
            FilePath = $UnrealTools.EditorCmd
            ArgumentList = $automationArgs
            WorkingDirectory = $TestPath
            LogDirectory = $logDir
            TimeoutSeconds = 900
        }
        $automation = Invoke-FHLoggedProcess @automationParams
        $steps.Add($automation)

        $automationFailure = Test-FHLogFailure -Paths @($automation.StdOut, $automation.StdErr) -Patterns @("Automation Test Failed", "LogAutomation.*Error", "Result=Fail")
        $automationPass = ($automation.ExitCode -eq 0 -and -not $automationFailure)

        if ($automationPass) {
            Write-Host "[3/3] Running headless game boot smoke..."
            $bootArgs = @(
                ('"{0}"' -f $project),
                "-game",
                "-unattended",
                "-nop4",
                "-nosplash",
                "-NullRHI",
                "-NoSound",
                "-stdout",
                "-FullStdOutLogOutput",
                '-ExecCmds="quit"'
            )
            $bootParams = @{
                Name = "boot"
                FilePath = $UnrealTools.EditorCmd
                ArgumentList = $bootArgs
                WorkingDirectory = $TestPath
                LogDirectory = $logDir
                TimeoutSeconds = 180
            }
            $boot = Invoke-FHLoggedProcess @bootParams
            $steps.Add($boot)

            $bootFailure = Test-FHLogFailure -Paths @($boot.StdOut, $boot.StdErr) -Patterns @("Fatal error", "Unhandled Exception", "Assertion failed")
            $bootPass = ($boot.ExitCode -eq 0 -and -not $bootFailure)
        }
    }

    $status = if ($buildPass -and $automationPass -and $bootPass) { "PASS" } else { "FAIL" }
    $failedStage = $null
    if (-not $buildPass) {
        $failedStage = "build"
    } elseif (-not $automationPass) {
        $failedStage = "automation"
    } elseif (-not $bootPass) {
        $failedStage = "boot"
    }

    $diagnostics = Get-FHDiagnostics -Steps @($steps) -TestRoot $TestPath -EnginePath $Engine.Root
    $stepSummary = @()
    foreach ($step in $steps) {
        $stepSummary += @{
            name = $step.Name
            exitCode = $step.ExitCode
            timedOut = $step.TimedOut
            durationSeconds = $step.DurationSeconds
        }
    }

    return @{
        status = $status
        branch = $Branch
        sha = $Sha
        shortSha = $shortSha
        testedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        engineVersion = $Engine.Version
        failedStage = $failedStage
        steps = $stepSummary
        diagnostics = $diagnostics
        localLogDirectory = $logDir
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required but was not found on PATH."
}

Invoke-FHGit -WorkingDirectory $RepoRoot -Arguments @("rev-parse", "--show-toplevel") | Out-Null

if ($PollSeconds -lt 5) {
    throw "PollSeconds must be at least 5."
}

$engine = Resolve-FHUnrealEngine -EngineRoot $EngineRoot -TargetVersion "5.8"
$unrealTools = Get-FHUnrealTools -EngineRoot $engine.Root

if (-not (Test-Path $unrealTools.EditorCmd)) {
    throw "UnrealEditor-Cmd.exe was not found at '$($unrealTools.EditorCmd)'."
}

$programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
$vswhere = Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsInstall = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ([string]::IsNullOrWhiteSpace([string]($vsInstall | Select-Object -First 1))) {
        Write-Warning "Visual Studio C++ build tools were not detected. UnrealBuildTool will report the exact missing component if the build fails."
    }
}

$runtimeBase = if ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA "FarHorizonDevAgent"
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) "FarHorizonDevAgent"
}

$testPath = Join-Path $runtimeBase "test-worktree"
$resultsPath = Join-Path $runtimeBase "results-clone"
$logsRoot = Join-Path $runtimeBase "logs"
New-Item -ItemType Directory -Force -Path $runtimeBase, $logsRoot | Out-Null

$remoteResult = Invoke-FHGit -WorkingDirectory $RepoRoot -Arguments @("remote", "get-url", $Remote)
$remoteUrl = ([string]($remoteResult.Output | Select-Object -First 1)).Trim()

Write-Host ""
Write-Host "Far Horizon Unreal local dev agent"
Write-Host "Watching:       $Remote/$Branch"
Write-Host "Engine:         UE $($engine.Version)"
Write-Host "Poll interval:  $PollSeconds seconds"
Write-Host "Test workspace: $testPath"
Write-Host "Local logs:     $logsRoot"
if (-not $NoPublish) {
    Write-Host "Results branch: $ResultsBranch"
}
Write-Host ""
Write-Host "Leave this window open. Press Ctrl+C to stop."
Write-Host ""

$lastSha = ""

while ($true) {
    try {
        $sha = if (-not [string]::IsNullOrWhiteSpace($TargetSha)) {
            $TargetSha
        } else {
            Get-FHRemoteSha
        }

        if ($sha -ne $lastSha) {
            # Ensure the newly advertised remote commit actually exists in the
            # local object database before the isolated worktree resets to it.
            Invoke-FHGit -WorkingDirectory $RepoRoot -Arguments @(
                "fetch",
                "--no-tags",
                $Remote,
                "refs/heads/$Branch"
            ) | Out-Null

            $validationParams = @{
                Sha = $sha
                TestPath = $testPath
                LogsRoot = $logsRoot
                Engine = $engine
                UnrealTools = $unrealTools
            }
            try {
                $result = Invoke-FHValidation @validationParams
            } catch {
                $shortSha = $sha.Substring(0, [Math]::Min(12, $sha.Length))
                $safeException = ConvertTo-FHSafeText -Text ([string]$_.Exception.ToString()) -TestRoot $testPath -EnginePath $engine.Root
                $result = @{
                    status = "FAIL"
                    branch = $Branch
                    sha = $sha
                    shortSha = $shortSha
                    testedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
                    engineVersion = $engine.Version
                    failedStage = "runner"
                    steps = @()
                    diagnostics = $safeException
                    localLogDirectory = $logsRoot
                }
            }

            $status = [string]$result.status
            $failedStageText = if ($result.failedStage) { " ($($result.failedStage))" } else { "" }

            Write-Host ""
            Write-Host "RESULT: $status$failedStageText  $($result.shortSha)"
            Write-Host "Logs:   $($result.localLogDirectory)"

            if ($result.failedStage -eq "runner" -and -not [string]::IsNullOrWhiteSpace([string]$result.diagnostics)) {
                Write-Host ""
                Write-Host "Runner diagnostic:"
                Write-Host ([string]$result.diagnostics)
            }

            $stepLines = ($result.steps | ForEach-Object {
                "- $($_.name): exit $($_.exitCode), $($_.durationSeconds)s, timedOut=$($_.timedOut)"
            }) -join [Environment]::NewLine
            $failedStageForMarkdown = if ($result.failedStage) { [string]$result.failedStage } else { "none" }

            $markdown = @"
# Far Horizon local Unreal validation

Status: $status
Branch: $Branch
Commit: $sha
UE: $($engine.Version)
Tested: $($result.testedAtUtc)
Failed stage: $failedStageForMarkdown

## Steps

$stepLines

## Diagnostics

$($result.diagnostics)
"@

            if (-not $NoPublish) {
                try {
                    $payload = @{
                        status = $result.status
                        branch = $result.branch
                        sha = $result.sha
                        shortSha = $result.shortSha
                        testedAtUtc = $result.testedAtUtc
                        engineVersion = $result.engineVersion
                        failedStage = $result.failedStage
                        steps = $result.steps
                        diagnostics = $result.diagnostics
                    }
                    $publishParams = @{
                        ResultsPath = $resultsPath
                        RemoteUrl = $remoteUrl
                        BranchName = $ResultsBranch
                        Payload = $payload
                        Markdown = $markdown
                    }
                    Publish-FHResult @publishParams
                    Write-Host "Published result to $ResultsBranch."
                } catch {
                    Write-Warning "Validation finished, but publishing the result failed: $($_.Exception.Message)"
                }
            }

            if ($LaunchOnPass -and $status -eq "PASS") {
                Write-Host "Launching tested Unreal project..."
                $testedProject = Join-Path $testPath "FarHorizon.uproject"
                Start-Process $unrealTools.Editor -ArgumentList ('"' + $testedProject + '"')
            }

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
