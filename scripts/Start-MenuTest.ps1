[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$gameRoot = Join-Path $repo '.local\game'
$system = Join-Path $gameRoot 'System'
$exe = Join-Path $system 'Game.exe'
$buildRecord = Join-Path $repo '.local\last-build.json'

if (!(Test-Path -LiteralPath (Join-Path $gameRoot '.hp2-development-copy.json') -PathType Leaf)) {
    throw "Development game copy is missing: $gameRoot"
}
if (!(Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Game.exe is missing: $exe" }
if (!(Test-Path -LiteralPath $buildRecord -PathType Leaf)) { throw 'Build record is missing. Run Build.ps1 first.' }

$build = Get-Content -LiteralPath $buildRecord -Raw -Encoding UTF8 | ConvertFrom-Json
if (!$build.passed -or
    ![string]::Equals($build.workRoot, (Resolve-Path -LiteralPath $gameRoot).Path, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The local game does not have a verified successful build.'
}
if ($build.origin -eq 'imported-test-build') {
    if (!$build.artifactIntegrityVerified -or !$build.sourceBuild.passed -or $build.sourceBuild.exitCode -ne 0) {
        throw 'The imported test build was not verified.'
    }
} elseif ($build.exitCode -ne 0) {
    throw 'The local UCC build did not pass.'
}
foreach ($name in @('HGame.u', 'M212Share.u')) {
    $expected = if ($name -eq 'HGame.u') { $build.hgameSha256 } else { $build.m212ShareSha256 }
    $package = Join-Path $system $name
    if (!$expected -or !(Test-Path -LiteralPath $package -PathType Leaf) -or
        ![string]::Equals((Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash, $expected,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Test package differs from the verified build: $name"
    }
}

foreach ($running in @(Get-Process -Name Game -ErrorAction SilentlyContinue)) {
    $path = $null
    try { $path = $running.Path } catch { }
    if ($path -and [string]::Equals($path, $exe, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Output "Test game is already running (PID $($running.Id)): $exe"
        return
    }
}

$logName = 'HP2MP-menu-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log'
$prepared = & (Join-Path $PSScriptRoot 'Launch-Multiplayer.ps1') -Mode Coop -Role Join -PrepareOnly
if ($prepared.status -ne 'PREPARED') { throw 'Could not prepare the isolated menu profile.' }
$runRoot = $prepared.runRoot
$arguments = @('startup.unr?game=Engine.GameInfo', '-windowed', '-NOFRONTEND', '-NewWindow',
    ('INI=' + (Split-Path $prepared.engineIni -Leaf)),
    ('USERINI=' + (Split-Path $prepared.userIni -Leaf)), "-log=$logName", '-FORCEFLUSH')
$previousCompat = $env:__COMPAT_LAYER
try {
    $env:__COMPAT_LAYER = 'RunAsInvoker'
    # This is the visible, interactive game window the user will control.
    $process = Start-Process -FilePath $exe -WorkingDirectory $system `
        -ArgumentList $arguments -PassThru -WindowStyle Normal `
        -RedirectStandardOutput (Join-Path $runRoot 'menu-stdout.log') `
        -RedirectStandardError (Join-Path $runRoot 'menu-stderr.log')
} finally {
    $env:__COMPAT_LAYER = $previousCompat
}
Start-Sleep -Seconds 3
$process.Refresh()
if ($process.HasExited) { throw "Game.exe exited immediately with code $($process.ExitCode)." }
$documents = [Environment]::GetFolderPath('MyDocuments')
Write-Output "Test game is running (PID $($process.Id)): $exe"
Write-Output "Expected log: $(Join-Path (Join-Path $documents 'HP2-Multiplayer-Development') $logName)"
