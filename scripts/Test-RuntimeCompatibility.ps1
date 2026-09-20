[CmdletBinding(DefaultParameterSetName='Validate')]
param(
    [string]$WorkRoot,
    [Parameter(Mandatory=$true,ParameterSetName='Generate')][switch]$Generate,
    [Parameter(Mandatory=$true,ParameterSetName='Validate')][string]$Manifest
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\game' }
$WorkRoot = [IO.Path]::GetFullPath($WorkRoot)
# Fixed names are the entire contract. Manifest paths never become read paths.
# This M212 test kit uses IpDrv.TcpNetDriver; its DLL and script package are required.
$required = @('System/Engine.dll','System/Core.dll','System/Game.exe','System/UCC.exe',
    'System/Engine.u','System/Core.u','System/IpDrv.dll','System/IpDrv.u',
    'Maps/Entry.unr','Maps/Ch1Rictusempra.unr')
$issues = [Collections.Generic.List[object]]::new()
$records = [Collections.Generic.List[object]]::new()

function Add-Issue([string]$Code, [string]$Path, [string]$Detail) {
    $issues.Add([ordered]@{code=$Code; path=$Path; detail=$Detail})
}
function Assert-PlainAncestors([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse point is not an unambiguous runtime/output path: $current"
            }
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}
function Get-UniqueChild([string]$Parent, [string]$Name, [bool]$Directory) {
    $matches = @(Get-ChildItem -LiteralPath $Parent -Force | Where-Object { $_.Name -ieq $Name })
    if ($matches.Count -eq 0) {
        Add-Issue 'MISSING' (Join-Path $Parent $Name) 'Expected file or directory is absent.'
        return $null
    }
    if ($matches.Count -ne 1) {
        Add-Issue 'AMBIGUOUS' (Join-Path $Parent $Name) 'Several case-insensitive matches; choose one exact runtime layout.'
        return $null
    }
    $item = $matches[0]
    if ($item.PSIsContainer -ne $Directory -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Add-Issue 'AMBIGUOUS' $item.FullName 'Wrong entry type or reparse point; no target is guessed.'
        return $null
    }
    return $item
}
function Write-Failure {
    [ordered]@{status='INCOMPATIBLE'; workRoot=$WorkRoot; issues=$issues.ToArray()} | ConvertTo-Json -Depth 6
    exit 1
}

try {
    Assert-PlainAncestors $WorkRoot
    if (!(Test-Path -LiteralPath $WorkRoot -PathType Container)) { throw 'WorkRoot directory is missing.' }
    $marker = Get-UniqueChild $WorkRoot '.hp2-development-copy.json' $false
    if (!$marker) { Add-Issue 'UNMARKED' $WorkRoot 'Prepare a separate development copy first; the source installation is never modified.' }
    else {
        try { $null = Get-Content -LiteralPath $marker.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { Add-Issue 'UNMARKED' $marker.FullName 'The development marker is not valid JSON.' }
    }
} catch { Add-Issue 'AMBIGUOUS' $WorkRoot $_.Exception.Message }
if ($issues.Count) { Write-Failure }

$expected = @{}
if (!$Generate) {
    try {
        $manifestItem = Get-Item -LiteralPath $Manifest -Force
        if ($manifestItem.PSIsContainer -or $manifestItem.Length -gt 65536) { throw 'Manifest must be a JSON file of at most 64 KiB.' }
        $reference = Get-Content -LiteralPath $manifestItem.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($reference.schemaVersion -ne 1 -or $reference.kind -cne 'hp2-runtime-compatibility' -or
            @($reference.files).Count -ne $required.Count) { throw 'Unexpected manifest schema, kind or file count.' }
        foreach ($record in $reference.files) {
            if ($required -cnotcontains $record.path -or $expected.ContainsKey($record.path) -or
                $record.sha256 -isnot [string] -or $record.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
                ($record.bytes -isnot [int] -and $record.bytes -isnot [long]) -or $record.bytes -le 0) {
                throw 'Invalid, duplicate or unexpected file record; use an unchanged generated manifest.'
            }
            $expected[$record.path] = $record
        }
    } catch { Add-Issue 'INVALID_MANIFEST' $Manifest $_.Exception.Message }
    if ($issues.Count) { Write-Failure }
}

$folders = @{}
foreach ($name in @('System','Maps')) {
    $folders[$name] = Get-UniqueChild $WorkRoot $name $true
}
foreach ($relative in $required) {
    $parts = $relative.Split('/')
    $folder = $folders[$parts[0]]
    if (!$folder) { continue }
    $item = Get-UniqueChild $folder.FullName $parts[1] $false
    if (!$item) { continue }
    try {
        $size = $item.Length
        $modified = $item.LastWriteTimeUtc
        if ($size -le 0) { throw 'Empty runtime file.' }
        $sha = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $item.Refresh()
        if ($item.Length -ne $size -or $item.LastWriteTimeUtc -ne $modified) { throw 'File changed during hashing; stop builds and retry.' }
        $record = [ordered]@{path=$relative; bytes=$size; sha256=$sha}
        $records.Add($record)
        if (!$Generate -and ($expected[$relative].bytes -ne $size -or $expected[$relative].sha256 -cne $sha)) {
            Add-Issue 'MISMATCH' $relative ("expected SHA256={0}, bytes={1}; actual SHA256={2}, bytes={3}" -f
                $expected[$relative].sha256,$expected[$relative].bytes,$sha,$size)
        }
    } catch { Add-Issue 'UNREADABLE_OR_CHANGED' $relative $_.Exception.Message }
}
if ($issues.Count) { Write-Failure }

if (!$Generate) {
    [ordered]@{status='COMPATIBLE'; workRoot=$WorkRoot; manifest=$manifestItem.FullName;
        filesChecked=$records.Count; scope='Exact hashes of this runtime subset only; not a gameplay PASS.'} | ConvertTo-Json -Depth 4
    exit 0
}

# The sole write destination is private local distribution, never WorkRoot/System
# or the marker's source installation. Assets and absolute source paths are omitted.
$distribution = Join-Path $repo '.local\distribution'
Assert-PlainAncestors $distribution
New-Item -ItemType Directory -Path $distribution -Force | Out-Null
$id = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$output = Join-Path $distribution "hp2-runtime-$id.json"
$document = [ordered]@{schemaVersion=1; kind='hp2-runtime-compatibility'; createdUtc=[DateTime]::UtcNow.ToString('o');
    files=$records.ToArray(); scope='M212 native/core/network runtime and Entry/Ch1 maps; HGame.u and M212Share.u are verified by the separate private build import.'}
$bytes = [Text.Encoding]::UTF8.GetBytes(($document | ConvertTo-Json -Depth 6))
$stream = [IO.File]::Open($output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
[ordered]@{status='GENERATED'; manifest=$output; sha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant();
    filesChecked=$records.Count} | ConvertTo-Json -Depth 4
