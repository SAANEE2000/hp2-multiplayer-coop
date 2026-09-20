[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][int]$ServerProcessId,
    [Parameter(Mandatory=$true)][long]$ServerStartTicks,
    [Parameter(Mandatory=$true)][int]$ClientProcessId,
    [Parameter(Mandatory=$true)][long]$ClientStartTicks,
    [Parameter(Mandatory=$true)][string]$SystemDirectory
)
$ErrorActionPreference = 'Stop'
$system = (Resolve-Path -LiteralPath $SystemDirectory).Path
$serverExe = Join-Path $system 'UCC.exe'
$clientExe = Join-Path $system 'Game.exe'

function Get-ExactProcess {
    param([int]$ProcessId, [string]$Executable, [long]$StartTicks)
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (!$process) { return $null }
    if (![string]::Equals($process.Path, $Executable,
            [StringComparison]::OrdinalIgnoreCase) -or
        $process.StartTime.Ticks -ne $StartTicks) { return $null }
    return $process
}

while ($true) {
    $server = Get-ExactProcess $ServerProcessId $serverExe $ServerStartTicks
    if (!$server) { Write-Output 'Server has exited; watcher finished.'; return }
    $client = Get-ExactProcess $ClientProcessId $clientExe $ClientStartTicks
    if (!$client) {
        Stop-Process -Id $ServerProcessId -ErrorAction Stop
        Write-Output 'Local player closed the game; stopped the matching co-op server.'
        return
    }
    Start-Sleep -Seconds 2
}
