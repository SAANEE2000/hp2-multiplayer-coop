[CmdletBinding()]
param([string]$GameRoot, [string]$WorkRoot, [switch]$Baseline)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
if (!$WorkRoot) {
    $WorkRoot = Join-Path $repo $(if ($Baseline) { '.local\baseline-game' } else { '.local\game' })
}
& (Join-Path $repo 'scripts\Prepare-LocalGame.ps1') -GameRoot $GameRoot -WorkRoot $WorkRoot | Out-Null
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
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
$buildCommit = (& git -C $repo rev-parse HEAD 2>$null)
$buildBranch = (& git -C $repo branch --show-current 2>$null)
$buildDirty = [bool](& git -C $repo status --porcelain 2>$null)
if (!$Baseline) {
    $recipes = @(Get-ChildItem -LiteralPath (Join-Path $repo 'patches') -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($recipes.Count -gt 0) {
        # One batch validates all files and orders each source/result hash chain.
        # File-name order cannot express recipes that patch the same source.
        $recipePaths = @($recipes | ForEach-Object { $_.FullName })
        & python (Join-Path $repo 'scripts\apply_patches.py') --work-root $WorkRoot @recipePaths
        if ($LASTEXITCODE -ne 0) { throw 'Patch batch failed; no build was started.' }
    }
    $overlay = Join-Path $repo 'mod\HGame\Classes'
    if (Test-Path -LiteralPath $overlay) {
        Get-ChildItem -LiteralPath $overlay -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($overlay.Length).TrimStart('\')
            $dest = Join-Path $WorkRoot "HGame\Classes\$relative"
            New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
    }
}
$system = Join-Path $WorkRoot 'System'
# Force a real rebuild; preserve previous packages instead of deleting them.
foreach ($package in @('HGame.u','M212Share.u')) {
    $binary = Join-Path $system $package
    if (Test-Path -LiteralPath $binary) { Move-Item -LiteralPath $binary -Destination (Join-Path $logRoot "$package.before") }
}
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
$result = @{passed=$pass; exitCode=$p.ExitCode; baseline=[bool]$Baseline; log=$output; workRoot=$WorkRoot; origin='local-ucc'; localUccRun=$true; commit=$buildCommit; branch=$buildBranch; sourceDirty=$buildDirty; sourceManifest=(Join-Path $logRoot 'source-manifest.json')}
if (Test-Path -LiteralPath (Join-Path $system 'HGame.u')) { $result.hgameSha256=(Get-FileHash -LiteralPath (Join-Path $system 'HGame.u') -Algorithm SHA256).Hash }
if (Test-Path -LiteralPath (Join-Path $system 'M212Share.u')) { $result.m212ShareSha256=(Get-FileHash -LiteralPath (Join-Path $system 'M212Share.u') -Algorithm SHA256).Hash }
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo '.local\last-build.json') -Encoding UTF8
Get-Content -LiteralPath $output -Tail 24
Write-Output "Build logs: $logRoot"
if (!$pass) { throw 'UCC make failed; inspect the preserved build logs.' }
