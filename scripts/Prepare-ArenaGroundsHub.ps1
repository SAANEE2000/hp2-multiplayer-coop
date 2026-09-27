[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SourcePath,
    [string]$WorkRoot
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\versus-v16-game' }
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
if (!(Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-development-copy.json') -PathType Leaf) -or
    !(Test-Path -LiteralPath (Join-Path $WorkRoot '.hp2-versus-v16-source.json') -PathType Leaf)) {
    throw 'Prepare the v16 development WorkRoot first with Prepare-VersusV16.ps1.'
}
$SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
$expected = '25A8168CE20520179A24542DC75F0C649B07443BC8450420E176938992659D49'
$mapName = 'Arena_Grounds_hub.unr'
$target = Join-Path $WorkRoot "Maps\$mapName"
if (Test-Path -LiteralPath $target) {
    $existing = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($existing -ne $expected) { throw "Existing map hash mismatch: $target actual=$existing" }
    Write-Output "Arena Grounds Hub already installed: $target SHA-256=$existing"
    return
}
$extension = [IO.Path]::GetExtension($SourcePath)
if ($extension -notin @('.unr','.zip')) { throw 'SourcePath must be Arena_Grounds_hub.unr or Maps.zip.' }
if ($extension -eq '.unr' -and [IO.Path]::GetFileName($SourcePath) -ine $mapName) {
    throw "Expected source filename $mapName"
}
$mapsRoot = Join-Path $WorkRoot 'Maps'
New-Item -ItemType Directory -Path $mapsRoot -Force | Out-Null
$temporary = Join-Path $mapsRoot ('.' + $mapName + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
try {
    if ($extension -eq '.unr') {
        Copy-Item -LiteralPath $SourcePath -Destination $temporary
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($SourcePath)
        try {
            $entries = @($archive.Entries | Where-Object { $_.FullName -ieq $mapName })
            if ($entries.Count -ne 1 -or $entries[0].Length -ne 4214943) {
                throw "Maps.zip must contain exactly one $mapName (4214943 bytes)."
            }
            $inputStream = $entries[0].Open()
            try {
                $outputStream = [IO.File]::Create($temporary)
                try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
        } finally { $archive.Dispose() }
    }
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw "Arena Grounds Hub source hash mismatch: actual=$actual expected=$expected" }
    Move-Item -LiteralPath $temporary -Destination $target
    Write-Output "Arena Grounds Hub installed: $target SHA-256=$actual"
} finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
}
