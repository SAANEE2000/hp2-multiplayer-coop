[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GameRoot)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$payloadRoot = Join-Path $repo 'private-test'
$archivePath = Join-Path $repo 'HPVersus_v16_remote_bottom_align_20260905.zip'
$artifactPath = Join-Path $payloadRoot 'hp2-versus-v16-test-build.zip'
$arenaPath = Join-Path $payloadRoot 'Maps\startup.unr'
$menuRoot = Join-Path $repo '.local\game'
$versusRoot = Join-Path $repo '.local\versus-v16-game'

$expected = [ordered]@{
    $archivePath = 'A2B13B924BF9BBA9F81C6A70E38024657C71F6F1F861FA49BF3F812C86EFB9BF'
    $artifactPath = 'DDF9CADFCF1ADBB41F0B3B74FCB90CC3D045FC37CF8812EA7DD1D87D5C6AB9D8'
    $arenaPath = '77AA6B898B5297A3663E6A4544CC3A2BE37ACC3CF6F74F55A3FF7C6EBAF9F7B8'
}

$GameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
if (!(Test-Path -LiteralPath (Join-Path $GameRoot 'System\Game.exe') -PathType Leaf) -or
    !(Test-Path -LiteralPath (Join-Path $GameRoot 'System\UCC.exe') -PathType Leaf)) {
    throw "HP2/M212 executables were not found in: $GameRoot"
}
foreach ($item in $expected.GetEnumerator()) {
    if (!(Test-Path -LiteralPath $item.Key -PathType Leaf)) {
        throw "The complete test archive is missing: $($item.Key)"
    }
    $actual = (Get-FileHash -LiteralPath $item.Key -Algorithm SHA256).Hash
    if (![string]::Equals($actual, $item.Value, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Test payload hash mismatch: $($item.Key)"
    }
}

# The external menu reads its original art from this separate development copy.
& (Join-Path $PSScriptRoot 'Prepare-LocalGame.ps1') -GameRoot $GameRoot -WorkRoot $menuRoot | Out-Null

$v16Marker = Join-Path $versusRoot '.hp2-versus-v16-source.json'
if (!(Test-Path -LiteralPath $v16Marker -PathType Leaf)) {
    $resume = Test-Path -LiteralPath $versusRoot -PathType Container
    & (Join-Path $PSScriptRoot 'Prepare-VersusV16.ps1') -ArchivePath $archivePath `
        -GameRoot $GameRoot -WorkRoot $versusRoot -ResumePreparedCopy:$resume | Out-Null
}

$destinationMap = Join-Path $versusRoot 'Maps\startup.unr'
Copy-Item -LiteralPath $arenaPath -Destination $destinationMap -Force
if ((Get-FileHash -LiteralPath $destinationMap -Algorithm SHA256).Hash -ne $expected[$arenaPath]) {
    throw 'Installed Startup arena hash mismatch.'
}

& (Join-Path $PSScriptRoot 'Import-TestBuild.ps1') -Artifact $artifactPath -WorkRoot $versusRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $repo '.local\last-build.json') `
    -Destination (Join-Path $repo '.local\last-build-v16.json') -Force

Write-Output 'Versus v16 test installation completed successfully.'
Write-Output "Arena: $destinationMap"
Write-Output "Launcher: $(Join-Path $repo 'Play-Menu-Test.cmd')"
