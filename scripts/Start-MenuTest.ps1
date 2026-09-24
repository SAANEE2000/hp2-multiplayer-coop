[CmdletBinding()]
param(
    [ValidateSet('Original','Single','CoopHost','CoopJoin','VersusHost','VersusJoin')]
    [string]$LaunchMode = 'Original',
    [string]$Server = '127.0.0.1',
    [ValidateRange(1024,65535)][int]$Port = 7777,
    [string]$PlayerName = 'Harry',
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{0,39}$')][string]$Character = 'Harry',
    [ValidateRange(2,8)][int]$MaxPlayers = 8,
    [ValidateRange(1,99)][int]$ScoreLimit = 3,
    [ValidateRange(-32768,32767)][int]$WindowX = 20,
    [ValidateRange(-32768,32767)][int]$WindowY = 40,
    [ValidateRange(320,7680)][int]$WindowWidth = 800,
    [ValidateRange(240,4320)][int]$WindowHeight = 600,
    [ValidateSet('Ch1Rictusempra','Ch2Skurge','Ch3Diffindo','Ch4Spongify')]
    [string]$CoopMap = 'Ch1Rictusempra',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

function Set-ProcessWindowPosition {
    param(
        [Parameter(Mandatory=$true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory=$true)][int]$X,
        [Parameter(Mandatory=$true)][int]$Y,
        [Parameter(Mandatory=$true)][int]$Width,
        [Parameter(Mandatory=$true)][int]$Height,
        [string]$Title = 'Harry Potter 2 Multiplayer',
        [int]$TimeoutMilliseconds = 12000
    )

    if (!('HP2MP.NativeWindow' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace HP2MP {
    public static class NativeWindow {
        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int Left, Top, Right, Bottom; }
        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
        private static extern int GetWindowLong(IntPtr hWnd, int index);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool SetWindowText(IntPtr hWnd, string text);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(
            IntPtr hWnd, IntPtr hWndInsertAfter,
            int X, int Y, int cx, int cy, uint uFlags);

        public static bool HasResizableFrame(IntPtr hWnd) {
            const int GWL_STYLE = -16;
            int style = GetWindowLong(hWnd, GWL_STYLE);
            return (style & 0x00C00000) != 0 && (style & 0x00040000) != 0;
        }

        public static bool SetTitleAndPlace(IntPtr hWnd, string title, int x, int y, int width, int height) {
            if (!String.IsNullOrEmpty(title)) SetWindowText(hWnd, title);
            return SetWindowPos(hWnd, IntPtr.Zero, x, y, width, height, 0x0014);
        }

        public static IntPtr FindLargestVisibleWindow(int processId) {
            IntPtr best = IntPtr.Zero;
            long bestArea = 0;
            EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
                uint owner;
                RECT rect;
                GetWindowThreadProcessId(hWnd, out owner);
                if (owner != (uint)processId || !IsWindowVisible(hWnd) || !GetWindowRect(hWnd, out rect))
                    return true;
                long width = Math.Max(0, rect.Right - rect.Left);
                long height = Math.Max(0, rect.Bottom - rect.Top);
                long area = width * height;
                if (area > bestArea) { bestArea = area; best = hWnd; }
                return true;
            }, IntPtr.Zero);
            return best;
        }
    }
}
'@
    }

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $stableHandle = [IntPtr]::Zero
    $stableSince = $null
    do {
        $Process.Refresh()
        if ($Process.HasExited) { return $false }
        $windowHandle = [HP2MP.NativeWindow]::FindLargestVisibleWindow($Process.Id)
        if ($windowHandle -ne [IntPtr]::Zero) {
            if ($windowHandle -ne $stableHandle) {
                $stableHandle = $windowHandle
                $stableSince = [DateTime]::UtcNow
            } elseif (([DateTime]::UtcNow - $stableSince).TotalSeconds -ge 2 -and
                      [HP2MP.NativeWindow]::HasResizableFrame($windowHandle)) {
                return [HP2MP.NativeWindow]::SetTitleAndPlace(
                    $windowHandle, $Title, $X, $Y, $Width, $Height)
            }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)

    return $false
}

$repo = Split-Path $PSScriptRoot -Parent
$gameRoot = Join-Path $repo $(if ($LaunchMode -like 'Versus*') { '.local\versus-v16-game' } else { '.local\game' })
$system = Join-Path $gameRoot 'System'
$exe = Join-Path $system 'Game.exe'
$modeBuild = Join-Path $repo $(if ($LaunchMode -like 'Versus*') { '.local\last-build-v16.json' } else { '.local\last-build-coop.json' })
$buildRecord = if (Test-Path -LiteralPath $modeBuild) { $modeBuild } else { Join-Path $repo '.local\last-build.json' }

if (!(Test-Path -LiteralPath (Join-Path $gameRoot '.hp2-development-copy.json') -PathType Leaf)) {
    throw "Development game copy is missing: $gameRoot"
}
if (!(Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Game.exe is missing: $exe" }
if (!(Test-Path -LiteralPath $buildRecord -PathType Leaf)) { throw 'Build record is missing. Run Build.ps1 first.' }

$build = Get-Content -LiteralPath $buildRecord -Raw -Encoding UTF8 | ConvertFrom-Json
if (!$build.passed -or
    ![string]::Equals($build.workRoot, (Resolve-Path -LiteralPath $gameRoot).Path, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The local game does not have a verified successful build.'
}
if ($build.origin -eq 'imported-test-build') {
    if (!$build.artifactIntegrityVerified -or !$build.sourceBuild.passed -or $build.sourceBuild.exitCode -ne 0) {
        throw 'The imported test build was not verified.'
    }
} elseif ($build.exitCode -ne 0) {
    throw 'The local UCC build did not pass.'
}
foreach ($name in @('HGame.u', 'M212Share.u')) {
    $expected = if ($name -eq 'HGame.u') { $build.hgameSha256 } else { $build.m212ShareSha256 }
    $package = Join-Path $system $name
    if (!$expected -or !(Test-Path -LiteralPath $package -PathType Leaf) -or
        ![string]::Equals((Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash, $expected,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Test package differs from the verified build: $name"
    }
}

if ($PlayerName -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,22}$') {
    throw 'Player name must be 1-23 letters, digits, _ or -.'
}
if ($LaunchMode -in @('CoopJoin','VersusJoin')) {
    if ($Server -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$' -or
        [Uri]::CheckHostName($Server) -notin @([UriHostNameType]::Dns,[UriHostNameType]::IPv4)) {
        throw 'Server must be an IPv4 address or DNS name without URL options.'
    }
}

$logName = 'HP2MP-menu-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log'
$profileMode = if ($LaunchMode -like 'Versus*') { 'Versus' } else { 'Coop' }
$prepared = $null
if ($LaunchMode -notin @('CoopHost','VersusHost')) {
    $prepared = & (Join-Path $PSScriptRoot 'Launch-Multiplayer.ps1') `
        -Mode $profileMode -Role Join -WorkRoot $gameRoot -PrepareOnly -PlayerName $PlayerName `
        -WindowX $WindowX -WindowY $WindowY -WindowWidth $WindowWidth -WindowHeight $WindowHeight
    if ($prepared.status -ne 'PREPARED') { throw 'Could not prepare the isolated menu profile.' }
    $runRoot = $prepared.runRoot
}
$url = switch ($LaunchMode) {
    Original   { 'startup.unr?game=Engine.GameInfo' }
    Single     { 'PrivetDr.unr?game=Engine.GameInfo' }
    CoopHost   { "$CoopMap.unr?game=HGame.HPCoopGame?MaxPlayers=2" }
    CoopJoin   { "unreal://${Server}:${Port}/?Name=$PlayerName`?MPMode=Coop" }
    VersusHost { "startup.unr?game=HGame.HPVersusGame?MaxPlayers=$MaxPlayers`?ScoreLimit=$ScoreLimit" }
    VersusJoin { "unreal://${Server}:${Port}/?Name=$PlayerName`?MPMode=Versus`?MPCharacter=$Character" }
}
$mapName = switch ($LaunchMode) {
    Original { 'startup.unr' }
    Single { 'PrivetDr.unr' }
    CoopHost { "$CoopMap.unr" }
    VersusHost { 'startup.unr' }
    default { 'Entry.unr' }
}
if (!(Test-Path -LiteralPath (Join-Path $gameRoot "Maps\$mapName") -PathType Leaf)) {
    throw "Map is missing from the test game: $mapName"
}
$arguments = if ($LaunchMode -in @('CoopHost','VersusHost')) {
    @('server', $url, "port=$Port", '-unattended', '-FORCEFLUSH')
} else {
    @($url, '-windowed', '-NOFRONTEND', '-NewWindow',
        ('INI=' + (Split-Path $prepared.engineIni -Leaf)),
        ('USERINI=' + (Split-Path $prepared.userIni -Leaf)), "-log=$logName", '-FORCEFLUSH')
}
if ($DryRun) {
    [PSCustomObject]@{LaunchMode=$LaunchMode; CoopMap=$CoopMap; Character=$Character; MaxPlayers=$MaxPlayers; ScoreLimit=$ScoreLimit; URL=$url; Arguments=$arguments;
        Windowed=$true; WindowX=$WindowX; WindowY=$WindowY; WindowWidth=$WindowWidth; WindowHeight=$WindowHeight;
        EngineIni=$prepared.engineIni; UserIni=$prepared.userIni;
        Executable=$(if ($LaunchMode -in @('CoopHost','VersusHost')) { Join-Path $system 'UCC.exe' } else { $exe });
        LocalClientExecutable=$exe}
    return
}
if ($LaunchMode -in @('CoopHost','VersusHost')) {
    # A playable host is a dedicated server plus a separate local client.
    # The single-process listen path gives the host a second BaseCam and breaks
    # the original CutScript capture/command pairing on campaign intros.
    $hostRun = $null
    $localRun = $null
    try {
        $hostMap = if ($LaunchMode -eq 'CoopHost') { $CoopMap } else { 'startup' }
        $hostSlots = if ($LaunchMode -eq 'CoopHost') { 2 } else { $MaxPlayers }
        $hostRun = & (Join-Path $PSScriptRoot 'Launch-Multiplayer.ps1') `
            -Mode $profileMode -Role Host -WorkRoot $gameRoot -Map $hostMap -Port $Port `
            -MaxPlayers $hostSlots -ScoreLimit $ScoreLimit -PlayerName $PlayerName -Unattended
        if ($hostRun.status -ne 'STARTED') { throw 'The server did not start.' }
        $hostOutput = Join-Path $hostRun.runRoot 'server-stdout.log'
        $serverReady = $false
        for ($attempt = 0; $attempt -lt 40; $attempt++) {
            $running = Get-Process -Id $hostRun.processId -ErrorAction SilentlyContinue
            if (!$running) { throw 'The server exited during startup.' }
            if ((Test-Path -LiteralPath $hostOutput) -and
                (Select-String -LiteralPath $hostOutput -SimpleMatch 'Game engine initialized' -Quiet)) {
                $serverReady = $true
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if (!$serverReady) { throw 'The server did not become ready within 20 seconds.' }
        $localRun = & (Join-Path $PSScriptRoot 'Launch-Multiplayer.ps1') `
            -Mode $profileMode -Role Join -WorkRoot $gameRoot -Server '127.0.0.1' -Port $Port -PlayerName $PlayerName -Character $Character `
            -WindowX $WindowX -WindowY $WindowY -WindowWidth $WindowWidth -WindowHeight $WindowHeight
        if ($localRun.status -ne 'STARTED') { throw 'The local client did not start.' }
        Start-Sleep -Seconds 3
        $serverProcess = Get-Process -Id $hostRun.processId -ErrorAction SilentlyContinue
        $clientProcess = Get-Process -Id $localRun.processId -ErrorAction SilentlyContinue
        if (!$serverProcess -or !$clientProcess) {
            throw 'The server or local client exited immediately.'
        }
        $watcherScript = Join-Path $PSScriptRoot 'Watch-MenuCoopServer.ps1'
        $watcherArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $watcherScript +
            '" -ServerProcessId ' + $hostRun.processId +
            ' -ServerStartTicks ' + $serverProcess.StartTime.Ticks +
            ' -ClientProcessId ' + $localRun.processId +
            ' -ClientStartTicks ' + $clientProcess.StartTime.Ticks +
            ' -SystemDirectory "' + $system + '"'
        $watcher = Start-Process -FilePath 'powershell.exe' -ArgumentList $watcherArgs `
            -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $hostRun.runRoot 'menu-watch-stdout.log') `
            -RedirectStandardError (Join-Path $hostRun.runRoot 'menu-watch-stderr.log')
        Write-Output "$profileMode server running (PID $($hostRun.processId), map $hostMap, slots $hostSlots, score limit $ScoreLimit)."
        Write-Output "Your local game client is running (PID $($localRun.processId)); the second player connects to port $Port."
        Write-Output "Server log: $(Join-Path $hostRun.runRoot 'server-stdout.log')"
        Write-Output "Local client session: $($localRun.session)"
        Write-Output "The server will stop when your local game window closes (watcher PID $($watcher.Id))."
        return
    } catch {
        foreach ($run in @($localRun, $hostRun)) {
            if ($null -eq $run -or !$run.processId) { continue }
            $running = Get-Process -Id $run.processId -ErrorAction SilentlyContinue
            if ($running -and [string]::Equals($running.Path, $run.executable,
                    [StringComparison]::OrdinalIgnoreCase)) {
                Stop-Process -Id $run.processId -ErrorAction SilentlyContinue
            }
        }
        throw
    }
}
$previousCompat = $env:__COMPAT_LAYER
try {
    $env:__COMPAT_LAYER = 'RunAsInvoker'
    # This is the visible, interactive game window the user will control.
    $process = Start-Process -FilePath $exe -WorkingDirectory $system `
        -ArgumentList $arguments -PassThru -WindowStyle Normal `
        -RedirectStandardOutput (Join-Path $runRoot 'menu-stdout.log') `
        -RedirectStandardError (Join-Path $runRoot 'menu-stderr.log')
} finally {
    $env:__COMPAT_LAYER = $previousCompat
}
Start-Sleep -Seconds 3
$process.Refresh()
if ($process.HasExited) { throw "Game.exe exited immediately with code $($process.ExitCode)." }
$windowTitle = "HP2 $profileMode - $PlayerName"
$windowPositionApplied = Set-ProcessWindowPosition -Process $process `
    -X $WindowX -Y $WindowY -Width $WindowWidth -Height $WindowHeight -Title $windowTitle
if (!$windowPositionApplied) {
    Write-Warning 'The game is windowed, but its window handle was not available for positioning within 12 seconds.'
}
$documents = [Environment]::GetFolderPath('MyDocuments')
Write-Output "Test game is running (PID $($process.Id), mode $LaunchMode): $exe"
Write-Output "Native resizable window requested: ${WindowWidth}x${WindowHeight} at X=$WindowX, Y=$WindowY; applied=$windowPositionApplied"
Write-Output "Expected log: $(Join-Path (Join-Path $documents 'HP2-Multiplayer-Development') $logName)"
