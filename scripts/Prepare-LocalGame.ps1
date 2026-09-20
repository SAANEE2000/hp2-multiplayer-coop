[CmdletBinding()]
param([string]$GameRoot, [string]$WorkRoot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
function Set-DevelopmentProfile([string]$PreparedRoot) {
    # M212 reads this before per-session INI, including on a PC that imports
    # packages without ever running Build.ps1. Never select the retail profile.
    $defaultIni = Join-Path $PreparedRoot 'System\Default.ini'
    $supplied = Get-Content -LiteralPath $defaultIni -Raw
    if ([regex]::Matches($supplied, '(?im)^UserFolder=.*$').Count -ne 1) {
        throw 'Expected exactly one UserFolder in development Default.ini.'
    }
    $isolated = $supplied -replace '(?im)^UserFolder=.*$', 'UserFolder=HP2-Multiplayer-Development'
    if ($isolated -ne $supplied) {
        $backup = "$defaultIni.supplied"
        if (!(Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $defaultIni -Destination $backup }
        Set-Content -LiteralPath $defaultIni -Value $isolated -Encoding ASCII
    }
}
if (!$GameRoot) { $GameRoot = Join-Path $repo 'Гарри Поттер и Тайная комната' }
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\game' }
$marker = Join-Path ([IO.Path]::GetFullPath($WorkRoot)) '.hp2-development-copy.json'
if (Test-Path -LiteralPath $marker) {
    Set-DevelopmentProfile ([IO.Path]::GetFullPath($WorkRoot))
    Write-Output ([IO.Path]::GetFullPath($WorkRoot)); exit 0
}
$source = (Resolve-Path -LiteralPath $GameRoot).Path
$target = [IO.Path]::GetFullPath($WorkRoot)
if ($source.TrimEnd('\') -eq $target.TrimEnd('\')) { throw 'WorkRoot must be a separate copy.' }
if (!(Test-Path -LiteralPath (Join-Path $source 'System\UCC.exe'))) { throw 'M212 System/UCC.exe missing.' }
New-Item -ItemType Directory -Path $target -Force | Out-Null
$marker = Join-Path $target '.hp2-development-copy.json'
if (Test-Path -LiteralPath $marker) {
    Set-DevelopmentProfile $target
    Write-Output $target; exit 0
}
# Copy, never mirror or delete: the supplied installation is read-only input.
& robocopy $source $target /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XD AutoSaves Save Cache .git /XF '*.log' /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }
Set-DevelopmentProfile $target
@{source=$source; created=(Get-Date -Format o)} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
Write-Output $target
