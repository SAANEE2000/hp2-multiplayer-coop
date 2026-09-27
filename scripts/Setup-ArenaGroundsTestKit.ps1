[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GameRoot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$donor = Join-Path $repo 'HPVersus_v16_remote_bottom_align_20260905.zip'
$artifact = Join-Path $repo 'private-test\hp2-versus-arena-build.zip'
$startup = Join-Path $repo 'private-test\Maps\startup.unr'
$arena = Join-Path $repo 'private-test\Maps\Arena_Grounds_hub.unr'
$versusRoot = Join-Path $repo '.local\versus-v16-game'
$menuRoot = Join-Path $repo '.local\game'
$expected = @{
    $donor = 'A2B13B924BF9BBA9F81C6A70E38024657C71F6F1F861FA49BF3F812C86EFB9BF'
    $startup = '77AA6B898B5297A3663E6A4544CC3A2BE37ACC3CF6F74F55A3FF7C6EBAF9F7B8'
    $arena = '25A8168CE20520179A24542DC75F0C649B07443BC8450420E176938992659D49'
}
$GameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
foreach ($exe in @('Game.exe','UCC.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $GameRoot "System\$exe") -PathType Leaf)) {
        throw "HP2/M212 $exe was not found under $GameRoot\System"
    }
}
foreach ($path in $expected.Keys) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Test kit file is missing: $path" }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($hash -ne $expected[$path]) { throw "Test kit file hash mismatch: $path actual=$hash" }
}
if (!(Test-Path -LiteralPath $artifact -PathType Leaf)) { throw "Test build is missing: $artifact" }

& (Join-Path $PSScriptRoot 'Prepare-LocalGame.ps1') -GameRoot $GameRoot -WorkRoot $menuRoot | Out-Null
$v16Marker = Join-Path $versusRoot '.hp2-versus-v16-source.json'
if (!(Test-Path -LiteralPath $v16Marker -PathType Leaf)) {
    $resume = Test-Path -LiteralPath $versusRoot -PathType Container
    & (Join-Path $PSScriptRoot 'Prepare-VersusV16.ps1') -GameRoot $GameRoot `
        -ArchivePath $donor -WorkRoot $versusRoot -ResumePreparedCopy:$resume | Out-Null
}
$mapRoot = Join-Path $versusRoot 'Maps'
foreach ($name in @('startup.unr','HPV_Interactions.unr','HPV_HideSeek.unr')) {
    $target = Join-Path $mapRoot $name
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($hash -ne $expected[$startup]) {
            throw "Existing test map differs: $target. Keep it and prepare a fresh WorkRoot."
        }
    } else {
        Copy-Item -LiteralPath $startup -Destination $target
    }
}
& (Join-Path $PSScriptRoot 'Prepare-ArenaGroundsHub.ps1') -SourcePath $arena -WorkRoot $versusRoot | Out-Null
& (Join-Path $PSScriptRoot 'Import-TestBuild.ps1') -Artifact $artifact -WorkRoot $versusRoot -ValidateOnly | Out-Null
& (Join-Path $PSScriptRoot 'Import-TestBuild.ps1') -Artifact $artifact -WorkRoot $versusRoot | Out-Null
Write-Output 'Arena Grounds test kit installed. Open Play-Menu-Test.cmd, then Versus > Free For All > Arena Grounds Hub.'
Write-Output "WorkRoot: $versusRoot"
