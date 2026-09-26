[CmdletBinding()]
param([string]$ArchivePath, [string]$GameRoot, [string]$WorkRoot, [switch]$ResumePreparedCopy)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$expectedHash = 'A2B13B924BF9BBA9F81C6A70E38024657C71F6F1F861FA49BF3F812C86EFB9BF'
if (!$ArchivePath) {
    $archives = @(Get-ChildItem -LiteralPath $repo -File -Filter 'HPVersus_v16_remote_bottom_align_20260905*.zip' | Sort-Object Name)
    $validArchives = @($archives | Where-Object {
        (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $expectedHash
    })
    if ($validArchives.Count -eq 0) {
        throw "No v16 archive with expected SHA-256 found in $repo; checked $($archives.Count) candidate(s)."
    }
    $ArchivePath = $validArchives[0].FullName
}
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\versus-v16-game' }
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path
$WorkRoot = [IO.Path]::GetFullPath($WorkRoot)
$actualHash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) { throw "Unexpected v16 archive SHA-256: $actualHash" }
if (Test-Path -LiteralPath $WorkRoot) {
    if (!$ResumePreparedCopy -or !(Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-development-copy.json')) -or
        (Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-versus-v16-source.json'))) {
        throw "WorkRoot already exists; use a fresh path: $WorkRoot"
    }
}

& (Join-Path $PSScriptRoot 'Prepare-LocalGame.ps1') -GameRoot $GameRoot -WorkRoot $WorkRoot | Out-Null
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

# Fail during preparation, rather than much later in the patch batch, if a
# supposedly clean archive did not land byte-for-byte in the expected tree.
$cleanSourceHashes = [ordered]@{
    'Internal\HPConsole.uc' = '73AB38BBC4B63D7F319CCE57989CDC2F6E640497A3DE177B128D0E91F3E4CCD2'
    'harry.uc' = 'C4DFE134FDC5DA24D691296CC65F60999CB5B8FA60E1E6DACEFA485FEF09F6C3'
    'HPVersusHarry.uc' = 'D59AEE7B9718D296B70BAC246B8C8DF0D6EDA39D434AEF604DD206F381505146'
}
foreach ($relative in $cleanSourceHashes.Keys) {
    $sourcePath = Join-Path $classesRoot $relative
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($sourceHash -ne $cleanSourceHashes[$relative]) {
        throw "Prepared v16 source mismatch: $relative actual=$sourceHash expected=$($cleanSourceHashes[$relative]). WorkRoot preserved: $WorkRoot"
    }
}

# M212 reads Default.ini before its per-session INI, so keep the test profile isolated.
$defaultIni = Join-Path $systemRoot 'Default.ini'
$defaultText = Get-Content -LiteralPath $defaultIni -Raw
if ([regex]::Matches($defaultText, '(?im)^UserFolder=.*$').Count -ne 1) {
    throw 'Expected exactly one UserFolder in v16 Default.ini.'
}
$defaultText = $defaultText -replace '(?im)^UserFolder=.*$', 'UserFolder=HP2-Multiplayer-Development'
Set-Content -LiteralPath $defaultIni -Value $defaultText -Encoding ASCII
@{archive=$ArchivePath; sha256=$actualHash; classes=$classCount; created=(Get-Date -Format o); cleanSourceHashes=$cleanSourceHashes} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $WorkRoot '.hp2-versus-v16-source.json') -Encoding UTF8
Write-Output "Prepared v16 sources: $WorkRoot ($classCount classes; SHA-256 $actualHash)"
