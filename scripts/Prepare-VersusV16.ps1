[CmdletBinding()]
param([string]$ArchivePath, [string]$WorkRoot, [switch]$ResumePreparedCopy)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$ArchivePath) {
    $archives = @(Get-ChildItem -LiteralPath $repo -File -Filter 'HPVersus_v16_remote_bottom_align_20260905*.zip')
    if ($archives.Count -ne 1) { throw "Expected one v16 archive in $repo; found $($archives.Count)." }
    $ArchivePath = $archives[0].FullName
}
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\versus-v16-game' }
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path
$WorkRoot = [IO.Path]::GetFullPath($WorkRoot)
$expectedHash = 'A2B13B924BF9BBA9F81C6A70E38024657C71F6F1F861FA49BF3F812C86EFB9BF'
$actualHash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) { throw "Unexpected v16 archive SHA-256: $actualHash" }
if (Test-Path -LiteralPath $WorkRoot) {
    if (!$ResumePreparedCopy -or !(Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-development-copy.json')) -or
        (Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-versus-v16-source.json'))) {
        throw "WorkRoot already exists; use a fresh path: $WorkRoot"
    }
}

& (Join-Path $PSScriptRoot 'Prepare-LocalGame.ps1') -WorkRoot $WorkRoot | Out-Null
$classesRoot = Join-Path $WorkRoot 'HGame\Classes'
$systemRoot = Join-Path $WorkRoot 'System'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
try {
    $sourceFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $classCount = 0
    foreach ($entry in $zip.Entries) {
        if (!$entry.FullName.StartsWith('Classes/', [StringComparison]::OrdinalIgnoreCase) -or
            !$entry.FullName.EndsWith('.uc', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $relative = $entry.FullName.Substring(8).Replace('/', '\')
        if (!$relative -or $relative.Contains('..')) { throw "Unsafe archive entry: $($entry.FullName)" }
        $target = [IO.Path]::GetFullPath((Join-Path $classesRoot $relative))
        if (!$target.StartsWith($classesRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Archive entry leaves HGame/Classes: $($entry.FullName)"
        }
        [void]$sourceFiles.Add($relative)
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        $inputStream = $entry.Open()
        try {
            $outputStream = [IO.File]::Create($target)
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
        } finally { $inputStream.Dispose() }
        $classCount++
    }
    if ($classCount -ne 857) { throw "Expected 857 v16 classes; extracted $classCount" }
    foreach ($file in Get-ChildItem -LiteralPath $classesRoot -Recurse -File -Filter '*.uc') {
        $relative = $file.FullName.Substring($classesRoot.Length + 1)
        if (!$sourceFiles.Contains($relative)) { Remove-Item -LiteralPath $file.FullName }
    }
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.Contains('/') -or !$entry.FullName.EndsWith('.ini', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $target = Join-Path $systemRoot $entry.FullName
        $inputStream = $entry.Open()
        try {
            $outputStream = [IO.File]::Create($target)
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
        } finally { $inputStream.Dispose() }
    }
} finally { $zip.Dispose() }

# M212 reads Default.ini before its per-session INI, so keep the test profile isolated.
$defaultIni = Join-Path $systemRoot 'Default.ini'
$defaultText = Get-Content -LiteralPath $defaultIni -Raw
if ([regex]::Matches($defaultText, '(?im)^UserFolder=.*$').Count -ne 1) {
    throw 'Expected exactly one UserFolder in v16 Default.ini.'
}
$defaultText = $defaultText -replace '(?im)^UserFolder=.*$', 'UserFolder=HP2-Multiplayer-Development'
Set-Content -LiteralPath $defaultIni -Value $defaultText -Encoding ASCII
@{archive=$ArchivePath; sha256=$actualHash; classes=$classCount; created=(Get-Date -Format o)} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $WorkRoot '.hp2-versus-v16-source.json') -Encoding UTF8
Write-Output "Prepared v16 sources: $WorkRoot ($classCount classes; SHA-256 $actualHash)"
