[CmdletBinding()]
param([string]$GameRoot, [string]$WorkRoot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$GameRoot) { $GameRoot = Join-Path $repo 'Гарри Поттер и Тайная комната' }
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\game' }
$source = (Resolve-Path -LiteralPath $GameRoot).Path
$target = [IO.Path]::GetFullPath($WorkRoot)
if ($source.TrimEnd('\') -eq $target.TrimEnd('\')) { throw 'WorkRoot must be a separate copy.' }
if (!(Test-Path -LiteralPath (Join-Path $source 'System\UCC.exe'))) { throw 'M212 System/UCC.exe missing.' }
New-Item -ItemType Directory -Path $target -Force | Out-Null
$marker = Join-Path $target '.hp2-development-copy.json'
if (Test-Path -LiteralPath $marker) { Write-Output $target; exit 0 }
# Copy, never mirror or delete: the supplied installation is read-only input.
& robocopy $source $target /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XD AutoSaves Save Cache .git /XF '*.log' /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }
@{source=$source; created=(Get-Date -Format o)} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
Write-Output $target
