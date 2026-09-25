[CmdletBinding()]
param([string]$GameRoot, [string]$WorkRoot, [switch]$Baseline, [switch]$VersusV16)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
if ($Baseline -and $VersusV16) { throw 'Choose either raw -Baseline or patched -VersusV16.' }
if (!$WorkRoot) {
    $WorkRoot = Join-Path $repo $(if ($VersusV16) { '.local\versus-v16-game' } elseif ($Baseline) { '.local\baseline-game' } else { '.local\game' })
}
& (Join-Path $repo 'scripts\Prepare-LocalGame.ps1') -GameRoot $GameRoot -WorkRoot $WorkRoot | Out-Null
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
if ($VersusV16) {
    $v16MarkerPath = Join-Path $WorkRoot '.hp2-versus-v16-source.json'
    if (!(Test-Path -LiteralPath $v16MarkerPath)) { throw 'Prepare the supplied v16 source in this WorkRoot first.' }
    $v16Marker = Get-Content -LiteralPath $v16MarkerPath -Raw | ConvertFrom-Json
    if ($v16Marker.sha256 -ne 'A2B13B924BF9BBA9F81C6A70E38024657C71F6F1F861FA49BF3F812C86EFB9BF' -or
        $v16Marker.classes -ne 857) { throw 'Unrecognized v16 source marker.' }
}
# Refuse to swap packages underneath a running test client or server.
foreach ($running in @(Get-Process -Name 'Game','UCC' -ErrorAction SilentlyContinue)) {
    $runningPath = $null
    try { $runningPath = $running.Path } catch { }
    if ($runningPath -and (Split-Path $runningPath -Parent) -ieq (Join-Path $WorkRoot 'System')) {
        throw "Development game is running (PID $($running.Id)). Stop that test session before rebuilding."
    }
}
if ($Baseline -and ((Test-Path -LiteralPath (Join-Path $WorkRoot '.patch-backups')) -or (Test-Path -LiteralPath (Join-Path $WorkRoot 'HGame\Classes\HPCoopHarry.uc')))) {
    throw 'Baseline builds require an untouched development copy; use a new WorkRoot.'
}
# The native M212 bootstrap reads UserFolder from Default.ini before custom INI.
# Isolate even that first step from the real campaign profile.
$defaultIni = Join-Path $WorkRoot 'System\Default.ini'
$originalDefault = Get-Content -LiteralPath $defaultIni -Raw
$safeDefault = $originalDefault -replace '(?m)^UserFolder=.*$', 'UserFolder=HP2-Multiplayer-Development'
if ($safeDefault -ne $originalDefault) {
    $defaultBackup = Join-Path $WorkRoot 'System\Default.ini.supplied'
    if (!(Test-Path -LiteralPath $defaultBackup)) { Copy-Item -LiteralPath $defaultIni -Destination $defaultBackup }
    Set-Content -LiteralPath $defaultIni -Value $safeDefault -Encoding ASCII
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$logRoot = Join-Path $repo ".local\builds\$stamp"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$sourceManifest = @()
foreach ($sourceDir in @('mod','patches','scripts')) {
    $sourceRoot = Join-Path $repo $sourceDir
    if (Test-Path -LiteralPath $sourceRoot) {
        foreach ($sourceFile in @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse | Where-Object { $_.FullName -notmatch '[\\/]__pycache__[\\/]' } | Sort-Object FullName)) {
            $sourceManifest += @{path=$sourceFile.FullName.Substring($repo.Length+1); sha256=(Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash}
        }
    }
}
$sourceManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $logRoot 'source-manifest.json') -Encoding UTF8
$buildCommit = $null
$buildBranch = $null
$buildDirty = $null
# Git metadata is useful for a cloned checkout, but GitHub's Download ZIP has
# no .git marker by design. Do not invoke git there: recent PowerShell versions
# can promote git.exe's "not a repository" stderr to a terminating error.
$repoGitMarker = Join-Path $repo '.git'
if ((Test-Path -LiteralPath $repoGitMarker) -and
    (Get-Command git -ErrorAction SilentlyContinue)) {
    try {
        $commitOutput = @(& git -C $repo rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $commitOutput.Count -gt 0) {
            $buildCommit = $commitOutput[0]
            $branchOutput = @(& git -C $repo branch --show-current 2>$null)
            if ($LASTEXITCODE -eq 0 -and $branchOutput.Count -gt 0) {
                $buildBranch = $branchOutput[0]
            }
            $dirtyOutput = @(& git -C $repo status --porcelain 2>$null)
            if ($LASTEXITCODE -eq 0) { $buildDirty = $dirtyOutput.Count -gt 0 }
        }
    } catch {
        # Provenance stays null; compilation and package hashes remain valid.
        $buildCommit = $null
        $buildBranch = $null
        $buildDirty = $null
    }
}
if (!$Baseline) {
    $recipeFilter = if ($VersusV16) { 'versus-v16-*.json' } else { '*.json' }
    $recipes = @(Get-ChildItem -LiteralPath (Join-Path $repo 'patches') -Filter $recipeFilter -ErrorAction SilentlyContinue |
        Where-Object { $VersusV16 -or $_.Name -notlike 'versus-v16-*' } | Sort-Object Name)
    if ($VersusV16 -and $recipes.Count -eq 0) { throw 'No versus-v16 patch recipes found.' }
    if ($recipes.Count -gt 0) {
        # One batch validates all files and orders each source/result hash chain.
        # File-name order cannot express recipes that patch the same source.
        $recipePaths = @($recipes | ForEach-Object { $_.FullName })
        & python (Join-Path $repo 'scripts\apply_patches.py') --work-root $WorkRoot @recipePaths
        if ($LASTEXITCODE -ne 0) { throw 'Patch batch failed; no build was started.' }
    }
    $overlay = Join-Path $repo 'mod\HGame\Classes'
    if (!$VersusV16 -and (Test-Path -LiteralPath $overlay)) {
        Get-ChildItem -LiteralPath $overlay -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($overlay.Length).TrimStart('\')
            $dest = Join-Path $WorkRoot "HGame\Classes\$relative"
            New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
    }
    if ($VersusV16) {
        $versusOverlay = Join-Path $repo 'mod\versus-v16\HGame\Classes'
        foreach ($sourceFile in @(Get-ChildItem -LiteralPath $versusOverlay -File -Filter '*.uc')) {
            $destination = Join-Path $WorkRoot "HGame\Classes\$($sourceFile.Name)"
            if (Test-Path -LiteralPath $destination) {
                if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne
                    (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash) {
                    throw "Versus overlay would overwrite v16 source: $($sourceFile.Name)"
                }
            } else {
                Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination
            }
        }
    }
}
$system = Join-Path $WorkRoot 'System'
# A failed compiler run must leave the last known-good packages intact.
$previousPackages = @{}
$packagesReadyForBuild = $false
$pass = $false
try {
    # Force a real rebuild; retain the originals until success is verified.
    foreach ($package in @('HGame.u','M212Share.u')) {
        $binary = Join-Path $system $package
        if (Test-Path -LiteralPath $binary) {
            $backup = Join-Path $logRoot "$package.before"
            Move-Item -LiteralPath $binary -Destination $backup
            $previousPackages[$package] = $backup
        }
    }
    $packagesReadyForBuild = $true
    $ini = Join-Path $system 'HP2Build.ini'
    $config = Get-Content -LiteralPath (Join-Path $system 'Default.ini') -Raw
    $config = $config -replace '(?m)^UserFolder=.*$', 'UserFolder=HP2-Multiplayer-Development'
    Set-Content -LiteralPath $ini -Value $config -Encoding ASCII
    Copy-Item -LiteralPath $ini -Destination (Join-Path $logRoot 'Build.ini')
    $output = Join-Path $logRoot 'ucc-output.log'
    $errorLog = Join-Path $logRoot 'ucc-stderr.log'
    # The supplied executable requests elevation even for a user-owned build tree.
    # Run it with ordinary user rights; no privileged installation writes are needed.
    $previousCompat = $env:__COMPAT_LAYER
    try {
        $env:__COMPAT_LAYER = 'RunAsInvoker'
        $p = Start-Process -FilePath (Join-Path $system 'UCC.exe') -ArgumentList @('make', 'INI=HP2Build.ini', '-unattended', '-log=Make.log') -WorkingDirectory $system -RedirectStandardOutput $output -RedirectStandardError $errorLog -WindowStyle Hidden -PassThru -Wait
    } finally { $env:__COMPAT_LAYER = $previousCompat }
    $text = (Get-Content -LiteralPath $output -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $errorLog -Raw -ErrorAction SilentlyContinue)
    $pass = $p.ExitCode -eq 0 -and (Test-Path -LiteralPath (Join-Path $system 'HGame.u')) -and (Test-Path -LiteralPath (Join-Path $system 'M212Share.u')) -and $text -match 'Success - 0 error\(s\)' -and $text -notmatch '(?im)(Error in |Critical:|Compile failed|Failed to compile|\b[1-9][0-9]* error\(s\))'
} finally {
    if (!$pass) {
        foreach ($package in @('HGame.u','M212Share.u')) {
            if (!$packagesReadyForBuild -and !$previousPackages.ContainsKey($package)) { continue }
            $binary = Join-Path $system $package
            if (Test-Path -LiteralPath $binary) { Remove-Item -LiteralPath $binary -Force }
            if ($previousPackages.ContainsKey($package)) {
                Move-Item -LiteralPath $previousPackages[$package] -Destination $binary
            }
        }
    }
}
$result = @{passed=$pass; exitCode=$p.ExitCode; baseline=[bool]$Baseline; versusV16=[bool]$VersusV16; log=$output; workRoot=$WorkRoot; origin='local-ucc'; localUccRun=$true; commit=$buildCommit; branch=$buildBranch; sourceDirty=$buildDirty; sourceManifest=(Join-Path $logRoot 'source-manifest.json')}
if ($VersusV16) { $result.sourceArchiveSha256 = $v16Marker.sha256 }
if (Test-Path -LiteralPath (Join-Path $system 'HGame.u')) { $result.hgameSha256=(Get-FileHash -LiteralPath (Join-Path $system 'HGame.u') -Algorithm SHA256).Hash }
if (Test-Path -LiteralPath (Join-Path $system 'M212Share.u')) { $result.m212ShareSha256=(Get-FileHash -LiteralPath (Join-Path $system 'M212Share.u') -Algorithm SHA256).Hash }
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if ($pass) {
    $result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo '.local\last-build.json') -Encoding UTF8
    if ($VersusV16) {
        $result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo '.local\last-build-v16.json') -Encoding UTF8
    } elseif (!$Baseline) {
        $result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo '.local\last-build-coop.json') -Encoding UTF8
    }
}
Get-Content -LiteralPath $output -Tail 24
Write-Output "Build logs: $logRoot"
if (!$pass) { throw 'UCC make failed; inspect the preserved build logs.' }
