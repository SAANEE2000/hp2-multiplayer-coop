[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Artifact, [string]$WorkRoot, [switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\game' }
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
$Artifact = (Resolve-Path -LiteralPath $Artifact).Path
$system = Join-Path $WorkRoot 'System'
$local = Join-Path $repo '.local'

function Assert-PlainPath([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse points are not accepted as import targets: $current"
            }
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}
function Assert-Stopped {
    foreach ($running in @(Get-Process -Name Game,UCC -ErrorAction SilentlyContinue)) {
        $runningPath = $null
        try { $runningPath = $running.Path } catch { }
        if (!$runningPath -or [string]::Equals((Split-Path $runningPath -Parent), $system, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Stop matching Game/UCC before importing (PID $($running.Id)); an unknown path is not safe to ignore."
        }
    }
}
function Get-BytesHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Read-ZipBytes($Entry, [long]$Limit) {
    if ($Entry.Length -lt 0 -or $Entry.Length -gt $Limit) { throw "Archive entry exceeds its size limit: $($Entry.FullName)" }
    $inputStream = $Entry.Open()
    $memory = [IO.MemoryStream]::new()
    try {
        $buffer = New-Object byte[] 65536
        while (($count = $inputStream.Read($buffer,0,$buffer.Length)) -gt 0) {
            if ($memory.Length + $count -gt $Entry.Length) { throw 'Archive entry exceeds its declared length.' }
            $memory.Write($buffer,0,$count)
        }
        if ($memory.Length -ne $Entry.Length) { throw 'Truncated archive entry.' }
        return ,$memory.ToArray()
    } finally { $inputStream.Dispose(); $memory.Dispose() }
}
foreach ($path in @($WorkRoot,$system,$local,(Join-Path $local 'imports'),(Join-Path $local 'last-build.json'))) { Assert-PlainPath $path }
if (!(Test-Path -LiteralPath $system -PathType Container) -or
    !(Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-development-copy.json') -PathType Leaf)) {
    throw 'Import requires a marked development copy with a System directory.'
}
foreach ($name in @('HGame.u','M212Share.u')) { Assert-PlainPath (Join-Path $system $name) }
Assert-Stopped

# No archive-supplied path is ever used as a filesystem extraction destination.
Add-Type -AssemblyName System.IO.Compression
$stream = [IO.File]::Open($Artifact,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try {
    $archiveSha = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    $zip = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$true)
    try {
        $allowed = @('manifest.json','ucc-output.log','HGame.u','M212Share.u')
        $entries = @{}
        if ($zip.Entries.Count -ne $allowed.Count) { throw 'Archive must contain exactly four entries.' }
        foreach ($entry in $zip.Entries) {
            if ($allowed -cnotcontains $entry.FullName -or $entries.ContainsKey($entry.FullName) -or
                (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
                throw "Unexpected, duplicate or symbolic-link archive entry: $($entry.FullName)"
            }
            $entries[$entry.FullName] = $entry
        }
        $manifestBytes = Read-ZipBytes $entries['manifest.json'] 65536
        $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
        if ($manifest.schemaVersion -ne 1 -or $manifest.kind -cne 'hp2-private-test-build' -or
            $manifest.sourceBuild.passed -isnot [bool] -or !$manifest.sourceBuild.passed -or
            $manifest.sourceBuild.exitCode -ne 0 -or $manifest.sourceBuild.baseline -isnot [bool] -or
            @($manifest.files).Count -ne 3) { throw 'Invalid source build or artifact manifest.' }
        $payload = @{}
        $records = @{}
        foreach ($record in $manifest.files) {
            if (@('HGame.u','M212Share.u','ucc-output.log') -cnotcontains $record.name -or $records.ContainsKey($record.name) -or
                $record.sha256 -notmatch '^[0-9a-fA-F]{64}$' -or $record.bytes -isnot [ValueType]) { throw 'Invalid or duplicate file record.' }
            $limit = if ($record.name -eq 'ucc-output.log') { 8388608 } else { 268435456 }
            $bytes = Read-ZipBytes $entries[$record.name] $limit
            if ($bytes.Length -ne $record.bytes -or (Get-BytesHash $bytes) -ne $record.sha256) { throw "Artifact hash/size mismatch: $($record.name)" }
            if ($record.name -ne 'ucc-output.log' -and ($bytes.Length -lt 56 -or
                [BitConverter]::ToUInt32($bytes,0) -ne 0x9E2A83C1L -or ([BitConverter]::ToUInt32($bytes,4) -band 65535) -ne 115)) {
                throw "Invalid M212 package header: $($record.name)"
            }
            $payload[$record.name] = $bytes
            $records[$record.name] = $record
        }
        $logText = [Text.Encoding]::UTF8.GetString($payload['ucc-output.log'])
        if ($logText -notmatch 'Success - 0 error\(s\)' -or $logText -match '(?im)(Error in |Critical:|Compile failed|Failed to compile|\b[1-9][0-9]* error\(s\))') {
            throw 'Source log does not confirm a successful UCC compilation.'
        }
    } finally { $zip.Dispose() }
} finally { $stream.Dispose() }
if ($ValidateOnly) {
    [ordered]@{status='VALIDATED'; artifact=$Artifact; artifactSha256=$archiveSha; workRoot=$WorkRoot; sourceBuild=$manifest.sourceBuild; files=$manifest.files} | ConvertTo-Json -Depth 8
    return
}

# Validation above performs no writes. Recheck processes immediately before mutation.
Assert-Stopped
$id = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$importRoot = Join-Path $local "imports\$id"
New-Item -ItemType Directory -Path $importRoot -Force | Out-Null
[IO.File]::WriteAllBytes((Join-Path $importRoot 'manifest.json'),$manifestBytes)
[IO.File]::WriteAllBytes((Join-Path $importRoot 'ucc-output.log'),$payload['ucc-output.log'])
$lastBuild = Join-Path $local 'last-build.json'
$originals = @{}
$targets = @((Join-Path $system 'HGame.u'),(Join-Path $system 'M212Share.u'),$lastBuild)
foreach ($target in $targets) {
    $backup = Join-Path $importRoot ((Split-Path $target -Leaf) + '.before')
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        [IO.File]::Copy($target,$backup,$false)
        $originals[$target] = $backup
    } else { $originals[$target] = $null }
}
$changed = [Collections.Generic.List[string]]::new()
$temporaries = [Collections.Generic.List[string]]::new()
function Replace-Bytes([string]$Target, [byte[]]$Bytes) {
    $temporary = "$Target.hp2-import-$id.tmp"
    $temporaries.Add($temporary)
    [IO.File]::WriteAllBytes($temporary,$Bytes)
    if ([IO.File]::Exists($Target)) { [IO.File]::Replace($temporary,$Target,[NullString]::Value) }
    else { [IO.File]::Move($temporary,$Target) }
}
try {
    foreach ($name in @('HGame.u','M212Share.u')) {
        $target = Join-Path $system $name
        Replace-Bytes $target $payload[$name]
        $changed.Add($target)
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $records[$name].sha256) { throw "Installed hash mismatch: $name" }
    }
    $result = [ordered]@{
        passed=$true; origin='imported-test-build'; localUccRun=$false; exitCode=$null
        validation='Source UCC PASS plus verified imported artifact; no local compiler run.'
        artifactIntegrityVerified=$true; sourceBuild=$manifest.sourceBuild; exportCommit=$manifest.exportCommit
        baseline=$manifest.sourceBuild.baseline; commit=$manifest.sourceBuild.commit
        workRoot=$WorkRoot; log=(Join-Path $importRoot 'ucc-output.log'); importedUtc=[DateTime]::UtcNow.ToString('o')
        artifact=$Artifact; artifactSha256=$archiveSha; importRoot=$importRoot
        hgameSha256=$records['HGame.u'].sha256; m212ShareSha256=$records['M212Share.u'].sha256
    }
    $resultBytes = [Text.Encoding]::UTF8.GetBytes(($result | ConvertTo-Json -Depth 8))
    Replace-Bytes $lastBuild $resultBytes
    $changed.Add($lastBuild)
    [IO.File]::WriteAllBytes((Join-Path $importRoot 'import-result.json'),$resultBytes)
} catch {
    $failure = $_
    $rollbackFailures = @()
    for ($i=$changed.Count-1; $i -ge 0; $i--) {
        $target = $changed[$i]
        try {
            if ($originals[$target]) { Replace-Bytes $target ([IO.File]::ReadAllBytes($originals[$target])) }
            else { [IO.File]::Delete($target) }
        } catch { $rollbackFailures += "$target : $_" }
    }
    if ($rollbackFailures.Count) { throw "Import failed: $failure. Restore preserved backups in $importRoot. Rollback errors: $($rollbackFailures -join '; ')" }
    throw $failure
} finally {
    foreach ($temporary in $temporaries) { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
$result | ConvertTo-Json -Depth 8
