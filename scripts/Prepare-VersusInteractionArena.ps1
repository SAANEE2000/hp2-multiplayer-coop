[CmdletBinding()]
param([string]$WorkRoot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\versus-v16-game' }
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
$marker = Join-Path $WorkRoot '.hp2-versus-v16-source.json'
if (!(Test-Path -LiteralPath $marker -PathType Leaf)) {
    throw 'WorkRoot is not a prepared Versus v16 development copy.'
}
$source = Join-Path $WorkRoot 'Maps\startup.unr'
$destination = Join-Path $WorkRoot 'Maps\HPV_Interactions.unr'
$hideSeekDestination = Join-Path $WorkRoot 'Maps\HPV_HideSeek.unr'
if (!(Test-Path -LiteralPath $source -PathType Leaf)) {
    throw 'Accepted startup.unr is missing.'
}
Copy-Item -LiteralPath $source -Destination $destination -Force
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) {
    throw 'Interaction arena copy hash mismatch.'
}
Copy-Item -LiteralPath $source -Destination $hideSeekDestination -Force
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $hideSeekDestination -Algorithm SHA256).Hash) {
    throw 'Hide & Seek arena copy hash mismatch.'
}
Write-Output $destination
Write-Output $hideSeekDestination
