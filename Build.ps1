[CmdletBinding()]
param([string]$GameRoot, [string]$WorkRoot, [switch]$Baseline)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
if (!$WorkRoot) { $WorkRoot = Join-Path $repo '.local\game' }
& (Join-Path $repo 'scripts\Prepare-LocalGame.ps1') -GameRoot $GameRoot -WorkRoot $WorkRoot | Out-Null
$WorkRoot = (Resolve-Path -LiteralPath $WorkRoot).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$logRoot = Join-Path $repo ".local\builds\$stamp"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
if (!$Baseline) {
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
$pass = $p.ExitCode -eq 0 -and (Test-Path -LiteralPath (Join-Path $system 'HGame.u')) -and $text -match 'Success - 0 error\(s\)' -and $text -notmatch '(?im)(Error in |Critical:|Compile failed|Failed to compile|\b[1-9][0-9]* error\(s\))'
$result = @{passed=$pass; exitCode=$p.ExitCode; baseline=[bool]$Baseline; log=$output; workRoot=$WorkRoot}
if (Test-Path -LiteralPath (Join-Path $system 'HGame.u')) { $result.hgameSha256=(Get-FileHash -LiteralPath (Join-Path $system 'HGame.u') -Algorithm SHA256).Hash }
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo '.local\last-build.json') -Encoding UTF8
Get-Content -LiteralPath $output -Tail 24
Write-Output "Build logs: $logRoot"
if (!$pass) { throw 'UCC make failed; inspect the preserved build logs.' }
