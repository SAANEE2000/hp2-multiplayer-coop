[CmdletBinding()]
param([string]$WorkRoot, [string]$BuildRecord)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\game' }
if (!$BuildRecord) { $BuildRecord = Join-Path $repo '.local\last-build.json' }
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
if (!(Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-development-copy.json') -PathType Leaf)) {
    throw 'Export requires a marked development copy.'
}
$system = Join-Path $WorkRoot 'System'
foreach ($running in @(Get-Process -Name Game,UCC -ErrorAction SilentlyContinue)) {
    $runningPath = $null
    try { $runningPath = $running.Path } catch { }
    if (!$runningPath -or [string]::Equals((Split-Path $runningPath -Parent), $system, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Stop matching Game/UCC before exporting (PID $($running.Id)); an unknown path is not safe to ignore."
    }
}
$build = Get-Content -LiteralPath $BuildRecord -Raw -Encoding UTF8 | ConvertFrom-Json
if ($build.passed -isnot [bool] -or !$build.passed -or
    ![string]::Equals($build.workRoot, $WorkRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The build record must be a verified PASS for this WorkRoot.'
}
if ($build.origin -eq 'imported-test-build') {
    if ($build.artifactIntegrityVerified -isnot [bool] -or !$build.artifactIntegrityVerified) {
        throw 'Imported build integrity was not verified.'
    }
    $sourceBuild = $build.sourceBuild
} else {
    $sourceBuild = [ordered]@{passed=$build.passed; exitCode=$build.exitCode; baseline=$build.baseline; commit=$build.commit}
}
if ($sourceBuild.passed -isnot [bool] -or !$sourceBuild.passed -or $sourceBuild.exitCode -ne 0 -or
    $sourceBuild.baseline -isnot [bool]) { throw 'A recorded source UCC PASS and explicit baseline flag are required.' }

function Get-BytesHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Assert-Package([byte[]]$Bytes, [string]$Name) {
    if ($Bytes.Length -lt 56 -or $Bytes.Length -gt 268435456 -or
        [BitConverter]::ToUInt32($Bytes,0) -ne 0x9E2A83C1L -or
        ([BitConverter]::ToUInt32($Bytes,4) -band 65535) -ne 115) { throw "Invalid M212 package header/size: $Name" }
}
$payload = @{}
$files = @()
foreach ($name in @('HGame.u','M212Share.u')) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $system $name))
    Assert-Package $bytes $name
    $sha = Get-BytesHash $bytes
    $recorded = if ($name -eq 'HGame.u') { $build.hgameSha256 } else { $build.m212ShareSha256 }
    if (($name -eq 'HGame.u' -and !$recorded) -or ($recorded -and $recorded -ne $sha)) {
        throw "$name does not match the recorded build."
    }
    $payload[$name] = $bytes
    $files += [ordered]@{name=$name; bytes=$bytes.Length; sha256=$sha}
}
$logBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $build.log).Path)
if ($logBytes.Length -gt 8388608) { throw 'Source UCC log is too large.' }
$logText = [Text.Encoding]::UTF8.GetString($logBytes)
if ($logText -notmatch 'Success - 0 error\(s\)' -or $logText -match '(?im)(Error in |Critical:|Compile failed|Failed to compile|\b[1-9][0-9]* error\(s\))') {
    throw 'The source UCC log does not confirm a successful compilation.'
}
$payload['ucc-output.log'] = $logBytes
$files += [ordered]@{name='ucc-output.log'; bytes=$logBytes.Length; sha256=(Get-BytesHash $logBytes)}
$exportCommit = $null
if (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        $head = & git -C $repo rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and "$head" -match '^[0-9a-f]{40,64}$') { $exportCommit = "$head" }
    } catch { Write-Verbose 'No Git commit is available for this export.' }
}
$manifest = [ordered]@{
    schemaVersion=1; kind='hp2-private-test-build'; createdUtc=[DateTime]::UtcNow.ToString('o')
    sourceBuild=$sourceBuild; exportCommit=$exportCommit
    commitNote='exportCommit is the HEAD at export time; sourceBuild.commit is unknown unless recorded by the source build.'
    files=$files
    distribution='Private transfer between licensed development copies only; do not publish game packages.'
}
$payload['manifest.json'] = [Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Depth 8))
$distribution = Join-Path $repo '.local\distribution'
New-Item -ItemType Directory -Path $distribution -Force | Out-Null
$id = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$output = Join-Path $distribution "hp2-test-build-$id.zip"
$partial = "$output.partial"
Add-Type -AssemblyName System.IO.Compression
$stream = [IO.File]::Open($partial, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($name in @('manifest.json','ucc-output.log','HGame.u','M212Share.u')) {
            $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open()
            try { $entryStream.Write($payload[$name], 0, $payload[$name].Length) }
            finally { $entryStream.Dispose() }
        }
    } finally { $zip.Dispose() }
} finally { $stream.Dispose() }
[IO.File]::Move($partial, $output)
[ordered]@{artifact=$output; sha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant(); sourceBuild=$sourceBuild; files=$files} | ConvertTo-Json -Depth 8
